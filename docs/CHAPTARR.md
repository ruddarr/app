# Chaptarr

Notes on the Chaptarr integration and its API. Measurements were taken 2026-08-11 against a
live instance running **v0.9.879** with a 19,739-book catalogue. Chaptarr is beta software;
re-verify anything surprising before relying on it.

## What Chaptarr is

An audiobook and eBook collection manager, an independent fork of Readarr. Default UI port
**8789**. Source: [github.com/Chaptarr/chaptarr](https://github.com/Chaptarr/chaptarr).

It publishes a committed OpenAPI 3.0.4 spec at `src/Chaptarr.Api.V1/openapi.json` (236 paths).
That file is the fastest way to answer shape questions, but see "The spec lies about include"
below — the controller source is the authority.

Useful source files when the spec is ambiguous:

- `src/Chaptarr.Api.V1/Books/BookController.cs` — the list/detail actions
- `src/Chaptarr.Api.V1/Books/BookControllerWithSignalR.cs` — `MapToResource` overloads

## API basics

- Base path is **`/api/v1`** (inherited from Readarr), not `/api/v3` like Radarr/Sonarr.
  This is why `InstanceType.apiPath` and `Instance.apiURL(_:)` exist.
- Auth is `X-Api-Key`, identical to the other *arrs, so `Instance.auth` needed no changes.
- `/api/v1/system/status` returns `appName: "Chaptarr"`, `instanceName` and `version`, which
  is exactly what `InstanceStatus` decodes — instance validation works unmodified.

## `/api/v1/book` returns the whole bibliography, not the library

This is the single most important thing to know.

Unfiltered, the endpoint returns **every book by every tracked author** — the full metadata
catalogue, not what the user owns or wants. On the test instance that is 19,739 books, of
which only ~354 are actually the library. Radarr's `/api/v3/movie` has no equivalent
behaviour, so the analogy misleads.

`monitored=true` is the filter that means "the library". Server-side it resolves to
**monitored OR has files** (see the monitored branch in `GetBooks`), so it includes downloaded
books the user never explicitly monitored.

| request | books | gzipped | time |
| --- | ---: | ---: | ---: |
| `/api/v1/book` | 19,739 | 4.5 MB | ~17–21 s |
| `/api/v1/book?monitored=true` | 354 | 131 KB | ~2.6 s |
| `/api/v1/book?monitored=true&include=author` | 354 | 406 KB | ~2.5 s |

**The server gzips and URLSession negotiates it automatically.** Raw `curl` reports 29 MB for
the full list; the app only ever transferred 4.5 MB. Always measure with `--compressed` or the
numbers are meaningless.

## The spec lies about `include`

`include` is a comma-separated list; `IncludeRequested()` accepts `all` or an exact token
match. Known tokens: `author`, `overview`, `links`.

It is **only honoured on the general (unfiltered) list path**. The `bookIds`, `authorId` and
`titleSlug` branches all call `MapToResource(x, false)` with `includeAuthor` hardcoded off.
Probing with `?bookIds=1&include=author` therefore shows no effect and leads you to conclude
`include` is broken — it isn't, you just picked a branch that ignores it.

`include=author` embeds the **entire** `AuthorResource` (~50 fields) into every book. On the
full list that takes it from 29 MB to 88 MB. At library scale it is a win: 406 KB in one
request versus 445 KB for a separate `/api/v1/author` join, so we use it there — but never
reach for it on an unfiltered list.

`include=overview` also works on the library path, and would remove the per-book detail
request entirely (see the next section — the description is the only thing that request is
for). Measured on a 387-book library: `include=author,links` is 1,914 KB with 0 overviews,
`include=author,links,overview` is 2,251 KB with 353. That is +17% on every library fetch to
drop one round-trip per book view and render the description immediately. **Not adopted** —
it is a bandwidth call, not a correctness one; decide it deliberately.

## Field availability differs per endpoint

| field | general list | `+include=author,links` | `/book/{id}` |
| --- | --- | --- | --- |
| `author` | absent | present | present |
| `links` | absent | present | present |
| `overview` | absent | **absent** | present |
| `durationMinutes` | present | present | **often absent** |

The `include=author,links` the app actually sends does **not** bring back `overview` — only the
explicit `include=overview` token or `/book/{id}` will. Measured over 30 library books, list (`include=author,links`) vs `/book/{id}`, across every
field the app decodes — only two ever differ:

| field | differs | detail adds | detail loses |
| --- | ---: | ---: | ---: |
| `overview` | 30/30 | 29 | 0 |
| `durationMinutes` | 27/30 | 3 | **15** |

So the detail request is worth making for exactly one field, the description — and it is a
**strictly worse** copy of the book in every other respect. Never assign the detail response
over the listed copy; merge the one field in (`Book.attach(overview:)`). Replacing the whole
record silently drops the runtime for about half the library.

If `include=overview` is ever added to the library fetch (see above), `API.getBook` and
`BookView.loadDetails()` can both go.

`/api/v1/book/{id}/overview` returns `{"id": N, "overview": ""}` — it appears broken. Use
`/api/v1/book/{id}`, which always maps with `includeAuthor: true`.

Book IDs are sparse. A missing id returns HTTP 500 with
`{"message":"Expected query to return 1 rows but returned 0"}`, not a 404.

## Resource gotchas

- **No `added` date on `BookResource`.** There is no "recently added" sort like Movies/Series.
- **`overview` contains HTML.** Hardcover and Goodreads both serve markup (`<p>`, `<br />`,
  `<i>`, `<a href=…>`) and character references (`&#39;`), unlike the plain text Radarr and
  Sonarr return. `Book.overviewText` runs it through `String.htmlDecoded`, which hands the fragment to
  NSAttributedString's HTML importer. That needs AppKit/UIKit — Foundation alone has no HTML
  document type — so `Utilities/Extensions.swift` carries a `canImport` guard, and it costs
  ~2 ms per call versus ~0.12 ms for a regex, on the main thread. `BookView` therefore decodes
  the overview once per render into a local rather than calling it from both the emptiness
  check and the body. The stored copy
  is also whatever the metadata provider has, which for a UK-edition record can be publisher
  pull-quotes rather than a synopsis — not something the client can improve.
- `pageCount` is `0` for audiobooks. Audiobooks carry `durationMinutes` (double) and
  `duration` (`"02:22:00"`); both are absent from `/book/{id}`, present on the list.
- `authorTitle` is a sort string (`"vaillant, john The Golden Spruce"`), **not** a display
  name. For display use `author.authorName`.
- `AuthorResource` name fields: `authorName` `"Byung-Chul Han"`, `sortName` (same),
  `authorNameLastFirst` `"Han, Byung-Chul"`, `sortNameLastFirst` `"han, byung-chul"`.
- `mediaType` is `"audiobook"` or `"ebook"`.
- Cover `coverType` is `"cover"`, not `"poster"`.
- `RootFolderResource` **does** carry `accessible`, `freeSpace` and `totalSpace` (re-checked
  2026-08-12 on v0.9.879), so `InstanceRootFolder` decodes unchanged. An earlier revision of
  this file claimed otherwise. It also carries per-media-type defaults
  (`audiobookQualityProfileId`, `audiobookMetadataProfileId`, `ebookTags`, …) that have no
  Radarr equivalent. `qualityprofile` entries are tagged `profileType: "ebook" | "audiobook"`,
  and `metadataprofile` has no Radarr analogue at all.
- **Covers can be unreachable.** 25 of 354 library books (7%) return a *relative*
  `/MediaCoverProxy/…` path as `images[].remoteUrl`, with no absolute URL anywhere in the
  record. `MediaCoverProxy` sits behind form auth — an API key in the header or as `?apikey=`
  gets 401, and unauthenticated gets a 302 to `/login` — so the app cannot fetch it. Those
  books fall back to the title-card placeholder, which is the correct outcome; there is
  nothing to fix client-side. Lookup results are unaffected: their `url`/`remoteCover` are
  proxy paths too, but `images[].remoteUrl` is an absolute Goodreads URL.
- `DiskSpaceResource`, `TagResource` and `QualityProfileResource` match the Radarr shapes and
  decode as-is.
- The spec marks almost every field `nullable: true`. That is a C# generator artifact, the
  same as Radarr's spec — it does not mean the field is really optional. `Book` still decodes
  defensively because the server is beta.

## Cover art has no reliable aspect ratio

`Book.posterAspect` / `posterHeightRatio` say audiobooks are square and eBooks are 2:3. That
is the *nominal* shape, not a guarantee. Measured 2026-08-12 by downloading every cover in the
354-book library (322 measurable — 5 books carry no image, 25 carry an unreachable one):

| height ÷ width | covers |
| --- | ---: |
| exactly 1.00 | 276 |
| 0.75 – 0.95 | 8 |
| 1.03 – 1.35 | 15 |
| 1.47 – 1.61 | 23 |

So **86% are square and 14% are not**, in an all-audiobook library, ranging from 0.75
(500×375) to 1.61 (312×500). The API never states the dimensions, so the real ratio is
unknowable until the bitmap loads.

There were two independent bugs here, and the first one is not in the views at all.

**1. The Nuke pipeline cropped every cover to 2:3 before SwiftUI saw it.** `Images.request`
used `.resize(size: 250×375, contentMode: .aspectFill, crop: true)` for all images. That is
correct for movies and series, whose art really is 2:3, but it destroyed book covers.
Measured by running the real processor over the real files:

| cover | source | old `.poster` | new `.album` |
| --- | --- | --- | --- |
| Unmasking Autism | 2400×2400 (1.000) | 250×375 (**1.500**) | 250×250 (1.000) |
| Being Mortal | 994×1500 (1.509) | 250×375 (1.500) | 249×375 (1.506) |
| Memoirs of a Geisha | 500×375 (0.750) | 250×375 (**1.500**) | 250×188 (0.752) |
| Project Hail Mary | 316×500 (1.582) | 250×375 (**1.500**) | 237×375 (1.582) |

A square cover lost a third of its width in the pipeline, and the square grid cell then
scaled the already-cropped bitmap up to fill, cropping the top and bottom too. `ImageType`
now has an `.album` case — same bounding size, but `.aspectFit` with `crop: false`, so `size`
bounds the image instead of cropping it. All book views use `.album`; movies and series keep
`.poster` unchanged.

**2. A fixed frame on a bare `.resizable()` image stretches it.** `CachedAsyncImage` returns
`image.resizable()` with no content mode, so an outer `.aspectRatio(_, .fill)` plus
`.frame(width:height:)` distorts the bitmap to the declared ratio. Movies get away with it
because their art matches the declared ratio; books do not.

`BookView` now sizes a `Color.card` box from the nominal ratio and puts two layers in it: the
cover `.scaledToFit()` so nothing is cropped or stretched, over a `.scaledToFill()` copy that
is scaled up and blurred to fill the letterbox bars. When the cover matches the box — the 86%
case — the sharp layer covers the blurred one completely and nothing changes.

Do not "fix" this by applying `.scaledToFit()` inside `CachedAsyncImage`: the same modifier
would hit `PlaceholderImage`, whose ideal size is square, so the title card would letterbox
itself into a square band inside a 2:3 eBook box (measured: 150×150 inset at y=38 in a 150×225
box). Fitting from the outside leaves the placeholder filling the box.

A `LazyVGrid` cell overflows its width if you put `.aspectRatio(_, contentMode: .fill)` on the
image and let the row height come from a taller sibling — the square scales up to cover and
bleeds past the cell. Size the cell first, then fill inside it:

```swift
Color.card
    .aspectRatio(book.posterAspect, contentMode: .fit)
    .overlay { CachedAsyncImage(.poster, book.remotePoster).scaledToFill() }
    .clipShape(RoundedRectangle(cornerRadius: 14))
```

This is moot while the format picker forces a single format at a time (every cell then shares
a ratio), but it matters again if a mixed grid ever comes back.

## Searching: use `book/lookup`

There are two search endpoints and they are not interchangeable.

`/api/v1/search?term=&provider=` is a *universal* search: each `SearchResource` holds a book,
an author **or** a series, and you must switch on which one is populated. Measured cold, on
fresh terms:

| `provider=` | latency | results | book covers |
| --- | ---: | --- | --- |
| `hardcover` (also the default when omitted) | ~1.0–1.5 s | books + authors + series | **half missing** |
| `goodreads` | ~2.2–3.0 s | books + authors | all present |
| `audible` | **~61–64 s** | books + authors | all present |

An unrecognised provider returns `200` with an empty array — no error, so a typo silently
looks like "no results".

`/api/v1/book/lookup?term=` is the one to use for adding books: it returns plain
`BookResource` objects and answers in ~0.9 s. `API.lookupBooks` uses it. Audible is far too
slow to sit behind a search field, and Hardcover drops covers.

### `book/lookup` is not one search — `term` picks the path

Free-text terms are Goodreads (which is why every `foreignBookId` on a title search comes back
`gr:…`), but a provider-prefixed term is not. `BookLookupController` first tries the local
database, and on a miss hands the raw term to `BookInfoProxy.SearchForNewBook`, which branches
three ways:

1. **A canonical provider prefix** — `hc`, `gr`, `ol`, `gb`, `az`, per
   `ProviderIdHelper.CanonicalPrefixes`, with exactly one colon in the term — routes to
   `SearchByV5WorkId`, the **BookInfo V5 work endpoint**. The source comment says it outright:
   *"should route to the V5 work endpoint, not to Goodreads text search."* A
   `BookNotFoundException` becomes an empty list, which is why a bad `ol:`/`gr:` id returns
   `n=0` instantly instead of erroring.
2. **A legacy Readarr prefix** — `author:`, `work:`, `edition:` map to Goodreads id lookups
   (`SearchByGoodreadsAuthorId` / `WorkId` / `BookId`). `isbn:` and `asin:` merely strip the
   prefix and fall through to (3).
3. **Anything else** — `Search(q)`, the Goodreads text search.

This explains every oddity measured above:

- `hc:122424` resolves a book that is **not** in the library, because (1) queries Hardcover's
  work endpoint directly rather than searching Goodreads for the literal string `hc:122424`.
- `isbn:1234567890123` returns an unrelated book because (2) drops the prefix and (3) runs a
  plain **text search for the digits** — it is not an ISBN resolution at all, so a hit proves
  nothing.
- `gb:` fails with `Invalid response received from Goodreads` even though `gb:` never touches
  Goodreads: the catch-all at the bottom of `SearchForNewBook` wraps *any* exception in a
  `GoodreadsException` with that wording. The message names the wrong provider.
- `gr:` work ids resolve through the V5/Hardcover layer rather than Goodreads, which is how
  Hardcover's bad `goodreadsWorkId` cross-reference returns the wrong book.

**Book search must only ever return books.** That is a product requirement, and it is the
reason `/api/v1/search` is not used — its results are books, authors *and* series mixed into
one list, and there is no parameter to restrict it. `book/lookup` cannot return an author:
searching an author's name returns that author's books (`brandon sanderson` → Mistborn, The
Way of Kings, …), which is the behaviour we want anyway.

Sharp edges:

- **Lookup results have no `id`.** They also lack `releaseDate`, `statistics`, `narrator`,
  `seriesTitle` and `durationMinutes`, and `authorId` / `author.id` are absent or `0`. `Book`
  therefore maps `id` → `guid: Int?` exactly like `Movie` does, exposes `exists` (`guid !=
  nil`), and synthesises an identity from `foreignBookId` (`gr:73586702` → `73586702`) so grid
  cells and `NavigationLink(value:)` still work. `BookAuthor.id` had to become optional.
- Anything holding a looked-up book must not call `getBook` — its `id` is a Goodreads id, not
  a database id. `BookView.loadDetails()` guards on `exists`.
- **`mediaType=ebook` returns zero for a title search, but works for a provider id.** It is a
  post-filter applied after the search. A *title* search only ever yields `audiobook`-typed
  records, so filtering to ebook empties the list (`piranesi` + `mediaType=ebook` → 0). A
  *provider-id* lookup returns the work in both formats, so the filter does something real
  (`hc:175280` + `mediaType=ebook` → 1). Note a repeated term answers in ~10 ms because the
  search proxy caches — that speed is the cache, not a short-circuit.
- **A provider-id lookup returns the same work once per media type**, both records carrying
  the *same* `foreignBookId` and differing only in `mediaType` and `editions[].
  foreignEditionId` (`hc:edition:30404125-audiobook` vs `-ebook`). `foreignBookId` alone is
  therefore not a unique identity, and two rows with the same SwiftUI id render undefined.
  `Book.foreignId` negates the id for eBooks to keep the two variants distinct; the value is
  only ever a grid identity, since anything with a derived id is `!exists` and routes to
  `BooksPath.preview`, never to `.book(id)` or `getBook`.
- `term` also accepts provider-prefixed ids, but **only four of the six actually work**.
  `BookLookupController` parses `hc|gr|ol|gb|az|isbn` for a *local* database lookup; on a miss
  it falls through to the remote search with the raw prefixed term, and whether that resolves
  depends on the provider. Probed 2026-08-12:

  | prefix | result |
  | --- | --- |
  | `hc:524080` | works — local hit, otherwise resolved remotely |
  | `gr:73586702` | works for **work** ids only |
  | `gr:50202953` | 0 results — an *edition* id (`goodreadsBookId`) does not resolve |
  | `az:B002V8H660` | works (ASIN) |
  | `isbn:9780441013593` | works, ISBN-10 and ISBN-13 both |
  | `ol:OL45804W` | always 0 results, instantly — no OpenLibrary provider configured |
  | `gb:wrOQLV6xB-wC` | **HTTP 503**, `Invalid response received from Google Books` |
  | `bogus:12345` | 0 results |

  Three traps. `gb:` is the only term that returns an *error* rather than an empty list, so it
  surfaces as an API alert instead of "no results". A malformed ISBN does not fail — it falls
  through to a text search and confidently returns an unrelated book (`isbn:1234567890123` → a
  Hebrew-German dictionary), so an ISBN hit is never proof of a match.

  Worst of all, **`gr:` ids do not reliably round-trip**. Title search is Goodreads-sourced and
  reports the correct work id, but id *resolution* goes through Hardcover, whose
  cross-references are wrong often enough to matter. Taking the `gr:` id from a title search
  and searching it back, 6 tries:

  | book | its reported `gr:` work id | searching that id returns |
  | --- | --- | --- |
  | The Name of the Wind | `gr:2502879` | **The Wise Man's Fear** |
  | The Hobbit | `gr:1540236` | **El Hobbit** (Spanish edition) |
  | Dune | `gr:3634639` | a Spanish omnibus pack |
  | Piranesi | `gr:73586702` | Piranesi |
  | Project Hail Mary | `gr:79106958` | Project Hail Mary |
  | Circe | `gr:53043399` | Circe |

  Hardcover's Wise Man's Fear record simply has `goodreadsWorkId: gr:2502879` — The Name of the
  Wind's id — baked into it. `gr:2502879` *is* the correct Goodreads work id for The Name of
  the Wind; it is Chaptarr's resolution of it that is wrong, so the id is right to advertise
  even though this instance resolves it to the wrong book today. The search placeholder uses
  it (`The Name of the Wind, gr:2502879`) to show the accepted term format.

## Links

`Links` is `{ "url": String?, "name": String? }` — the same shape Radarr and Sonarr use, so a
`BookLinks` menu could mirror `MovieLinks`. Two things differ from the other *arrs.

**They are not in the list response.** `links` needs `include=links` (or `all`); the plain
`?monitored=true` list has no `links` key at all. `/book/{id}` always includes them.
`include=links,author` cost 458 KB / 2.6 s for 383 books versus 406 KB for `include=author`
alone, so adding it to `API.fetchBooks` would be cheap.

**`SeriesResource.links` is not this type.** It is `SeriesBookLinkResource`
(`{id, position, seriesPosition, seriesId, bookId}`) — the series↔book join rows, not web
URLs. Only books and authors carry real links.

Measured over the 383-book library (every book had at least one) and its 243 authors:

| name | books | authors |
| --- | ---: | ---: |
| `hardcover` | 95% | 97% |
| `goodreads` | 64% | 98% |
| `amazon` | 57% | 97% |
| `audible` | 54% | — |

Books carry 1–4 links (133 had all four, 69 had only one). URL shapes:

- `https://hardcover.app/books/<slug>/editions/<id>` · `https://hardcover.app/authors/<slug>`
- `https://www.goodreads.com/book/show/<id>` · `https://www.goodreads.com/author/show/<id>.<slug>`
- `https://www.amazon.com/dp/<asin>` · `https://www.amazon.com/stores/author/<id>`
- `https://www.audible.<tld>/pd/<asin>`

**Do not rebuild these URLs from ids.** Audible links are region-split across at least eight
domains in one library — `.com` (173), `.com.br`, `.ca`, `.fr`, `.es`, `.de`, `.co.uk`,
`.co.jp`, `.com.au` — so the stored `url` is the only correct one. Note also that `name` comes
back lowercase (`"hardcover"`, not `"Hardcover"`), unlike Radarr's `"TMDb"`/`"IMDb"`, so a
display label needs casing applied.

## Series

`GET /api/v1/series?authorId={id}` returns every series for that author, each `SeriesResource`
carrying its full `books` array inline — no second request per series. It answered in ~0.08 s
for a 14-series author (96 books), so it is cheap enough to fire from a detail screen.
`API.getBookSeries` uses it; `/api/v1/series/{seriesId}` exists but is not needed.

The join is by **name, not id**: `BookResource` has no `seriesId`, only a `seriesTitle` string
that bakes the position in — `"The Hainish Cycle #5"` — while `SeriesResource.title` is
`"The Hainish Cycle"`. `Book.seriesName` strips everything from the first `#` so the two can be
matched. A book with no `#` (`"Catwings"`) is passed through unchanged, and a degenerate
`"#3"` falls back to the raw string rather than an empty name.

Field audit over every series of all 243 library authors — 700 series, 3,507 entries:

| field | absent | null | empty |
| --- | ---: | ---: | ---: |
| `SeriesResource.id` / `.title` / `.books` | 0 | 0 | 0 |
| `SeriesBookResource.title` | 0 | 0 | 0 |
| `SeriesBookResource.position` | 0 | 0 | **855** |
| `SeriesBookResource.foreignBookId` | **18** | 0 | 0 |

So `BookSeries` needs no defensive `init(from:)` — synthesized `Decodable` is enough — while
`BookSeriesBook.foreignBookId` **must** be optional or those 18 entries throw. An empty
`position` is the `#` case, not an error.

**Do not join on a bare `foreignBookId`.** Two library books carry `foreignBookId: ""`, and
18 series entries have none, so a defaulted `""` on both sides matches and navigates to the
wrong book. `BookSeriesBook.libraryKey` returns nil for a blank id, and the lookup skips blank
library ids too.

`SeriesBookResource` gives `title`, `position` (a **string**, and sometimes `""` or `"4.5"`),
`foreignBookId`, `releaseDate`, `images` and `ratings`. The images are `/MediaCoverProxy/…`
paths with no absolute `remoteUrl`, so they are unreachable — see the covers gotcha above.
Positions are not dense or unique, so do not use them as a SwiftUI identity.

**Expect the join to miss, often.** `seriesTitle` is frequently not a series at all but an
Amazon/Kindle browse category carried over from Audible metadata — `"Humorous Literary Fiction
#51"`, `"Business Negotiating (Kindle Store) #4"`, `"Media Studies (Kindle Store) #1"`,
`"One World Essentials #4"`. Those never match a `SeriesResource`, because the author has no
such series. Measured over 40 live library books that carry a `seriesTitle`: **25 matched, 15
did not**, and several authors returned an empty series list despite their books having one.
A missing section is therefore the normal case, not a bug — but note the same junk strings
still render in the `Series` detail row.

## Monitoring

`PUT /api/v1/book/monitor` with `{"bookIds": [Int], "monitored": Bool}` — the same shape as
Sonarr's `episode/monitor`, and what `API.monitorBook` sends. Two things differ from the
Radarr/Sonarr endpoints Ruddarr already calls:

- it answers **202**, not 200 (still inside the accepted `200..<400`), and
- the body is a **JSON array of the updated `BookResource`s**, not empty.

Declaring the response as `API.Empty` is still correct: `API.request` short-circuits
`Response.self == Empty.self` and decodes `{}` without looking at the body, so the array is
discarded rather than failing to decode. Verified against a live instance with an idempotent
write (re-setting an already-monitored book to `monitored: true`).

Per-row toggles (the series list on the book screen) follow the Sonarr episode pattern:
optimistic write into `Books.items`, `items.revert(_:to:id:)` on failure, and `Books.isMonitoring`
holding the in-flight id so `RowMonitorButton` can pulse. The endpoint also flips
`audiobookMonitored`/`ebookMonitored` to match, which the app does not read.

**Adding is not implemented.** The lookup and preview screens exist; there is no `POST /book`,
no add form and no `fetchMetadata()` for Chaptarr. Root folders, quality profiles and tags all
decode (see the gotchas above), so the remaining work is the add form, the per-media-type
profile pickers and the POST body shape.

## How the integration is wired

- `InstanceType.chaptarr` + `apiPath`; `Instance.apiURL(_:)` builds versioned URLs.
  `/api/v3/system/status` had been hardcoded in `API+Live` and twice in
  `InstanceEditView+Functions` — all three now derive the version from the instance type.
- `ChaptarrInstance` → `Books` + `BookLookup` → `Book`, mirroring `RadarrInstance` → `Movies` +
  `MovieLookup` → `Movie`. There is still no `fetchMetadata()`: root folders, quality profiles
  and tags are not needed until adding is implemented.
- `API.fetchBooks` is the list (`monitored=true&include=author,links`); `API.getBook` is the
  detail (`/book/{id}`, the only source of `overview`); `API.lookupBooks` is the search
  (`/book/lookup?term=`). `Books.binding(for:)` hands `BookView` a `Binding<Book>` into
  `items` — the library array is the single source of truth, and `loadDetails()` merges only
  the description into it, guarded on `book.overview == nil`.
- `Books.fetchSeries(_:)` caches `/series?authorId=` per author (cleared on library refetch),
  so moving between books by the same author does not refetch.
- `BooksPath` mirrors `MoviesPath`: `.search(String)`, `.preview(Data?)`, `.book(Book.ID)` and
  `.metadata(Book.ID)` (Files & History). A lookup result that is already in the library
  (`exists`) links straight to `.book`; everything else is JSON-encoded into `.preview`, which
  renders the same `BookView` with a constant binding.
- The Books tab is conditional on `settings.chaptarrInstances` being non-empty, so nothing
  changes for users without Chaptarr.
- Format is a **mode, not a filter**: `BookSort.BookMediaType` has no `.all` case, one of
  audiobook/eBook is always active, defaulting to audiobook.
- Queue, History and Calendar now include Chaptarr and go through `instance.apiURL(_:)`, so
  they resolve `/api/v1` per instance type. `AppSettings.mediaInstances` and `queueInstances`
  are gone; use `settings.instances`. The one real exclusion is notifications, expressed as
  `Instance.supportsNotifications`.
- **Anything reached with more than one instance type must build its URL with `apiURL(_:)`.**
  `command`, `history` and `manualimport` were left hardcoded to `/api/v3` when the queue was
  widened to every instance, which 404'd every Activity poll and made `BookSearch` unreachable
  while still showing its success toast (`Books.command` only checks for a throw).

## Files, history, queue, calendar and commands

All of these are plain `/api/v1` equivalents of the Radarr/Sonarr endpoints, reached with
`instance.apiURL(_:)`:

| screen | request |
| --- | --- |
| Files | `GET /bookfile?bookId=` (also accepts `authorId=`), `DELETE /bookfile/{id}` |
| History (per book) | `GET /history/author?authorId=&bookId=` — there is **no** `history/book` |
| History (tab) | `GET /history?page=&pageSize=` — same paged wrapper as v3 |
| Queue | `GET /queue?includeAuthor=true&includeBook=true&pageSize=250` |
| Calendar | `GET /calendar?start=&end=&unmonitored=true&includeAuthor=true` |
| Search | `POST /command` with `{"name": "BookSearch", "bookIds": [Int]}` |

The calendar returns bare `BookResource`s, so `Book` decodes it directly — no separate model.
The queue returns the usual `QueueResource` with `bookId`/`book` in place of
`movieId`/`seriesId`, so `QueueItem` only needed those two optional fields.

Command names come from `Chaptarr/chaptarr` source, not the OpenAPI spec, which does not
enumerate them: `src/NzbDrone.Core/IndexerSearch/BookSearchCommand.cs` is `BookSearch` +
`BookIds`. `RefreshMonitoredDownloads` and `ManualImport` exist too.

### `QualityModel` has no `source` or `resolution`

Chaptarr qualities describe formats (`M4B`, `EPUB`, `MP3`), so the resource carries only
`{id, name, isConversionTarget}` plus the usual `revision`. `MediaQualityDetails` declared
`source` and `resolution` non-optional, which failed the decode for **every** book file,
history event and queue item until both were given `decodeIfPresent` defaults (`.unknown`, `0`).

`mediaInfo` on a book file is audio-only and pre-formatted as strings — `audioBitRate:
"62 kbps"`, `audioSampleRate: "22.1kHz"`, `audioChannels` numeric — nothing like
`FileMediaInfo`, hence the separate `BookMediaInfo`.

### History event types

`EntityHistoryEventType` adds eight values Radarr/Sonarr never send: `bookFileImported`,
`bookFileDeleted`, `bookFileRenamed`, `bookFileRetagged`, `bookFileConverted`,
`bookFileConversionFailed`, `bookImportIncomplete`, `downloadImported`. `HistoryEventType` is a
plain `String` enum with no unknown-value fallback, so a missing case fails the whole page.
Book history carries no `languages`, so `MediaHistoryItem` hides that bullet when `bookId` is set.

## Hazard: never HTML-decode while rendering

Chaptarr overviews contain HTML. `String.htmlDecoded` uses `NSAttributedString(documentType:
.html)`, which **spins its own run loop**. Calling it during a SwiftUI `body` evaluation — even
as an innocent-looking `let overview = book.overviewText` — permanently wedges that view's
update graph: the body evaluates twice and then no `@State` write ever reaches the screen again.
It presents as "the data loads but the view never changes", with no crash and no warning.

Decode off the render pass (`.task(id:)` into `@State`), and treat any run-loop-reentrant or
WebKit-backed API the same way.

## Wire-format hazard (unresolved)

Adding the `chaptarr` case to `InstanceType` is **not** a safe additive change for builds
already in the field.

Shipped v1.8.x builds decode the iCloud `instances` value strictly — the per-element
`FailableInstance` salvage in `RawRepresentable.swift` landed in `535f7da1`, which is still
unreleased. A v1.8.x device that syncs a record with `"type":"Chaptarr"` fails to decode the
whole array, reads `[]`, and writes `[]` back to iCloud the moment the user touches instances,
wiping every device. `Tests/InstanceWireFormatTests.swift` documents this exact failure mode
and its fixtures still assert `["Radarr", "Sonarr"]`.

Options if 2.0.0 has not shipped first: gate Chaptarr instances into a separate store key, or
encode a legacy-safe `type` with an additive `appType` key alongside it.

`InstanceStats` gained a `books` field. That one *is* safe: old builds ignore the unknown key,
and the new `init(from:)` reads every field with `decodeIfPresent ?? 0` so records written
before the field decode as zero instead of throwing and taking the instance down with them.

## Local development

`Ruddarr/Preview Content` holds three fixtures, all pulled from a live instance and trimmed to
the fields the models decode. Regenerate them together — `book-series.json` only covers the
authors that `books.json` actually references, and the series rows join back to `books.json` by
`foreignBookId`.

- `books.json` — 24 library records, chosen to cover the awkward cases rather than at random:
  books whose series resolves, an unreachable `/MediaCoverProxy/` cover, missing narrator,
  missing runtime, monitored-but-missing, unwanted-but-downloaded, no series, and one each of
  `gr:`/`az:`-keyed and single-link records.
- `book-series.json` — 8 series / 153 entries, of which 21 link back into `books.json`.
- `book-lookup.json` — 27 `book/lookup` results, exercising the no-`id` shape.

**The live library is 100% audiobooks, so `books.json` has no eBooks and `pageCount` is 0
throughout.** eBook coverage lives in `book-lookup.json` instead: three eBook-typed records
obtained with `book/lookup?term=hc:…&mediaType=ebook`, which is the only way to get one (a
title search never returns `ebook`). Anything exercising the 2:3 poster, the page-count row or
`ebookRootFolderPath` has to go through the search screen in previews.

Seeding a simulator with a Chaptarr instance, without tapping through Settings:

```sh
DEV=<device-id>
GROUP=$(xcrun simctl get_app_container $DEV com.ruddarr group.com.ruddarr)
PLIST="$GROUP/Library/Preferences/group.com.ruddarr.plist"

xcrun simctl shutdown $DEV          # cfprefsd caches and will overwrite a live edit
plutil -replace debugInstances -string '[{"id":"...","type":"Chaptarr","mode":{"normal":{}},...}]' "$PLIST"
xcrun simctl boot $DEV
```

Three traps here, all of which cost time once:

- The DEBUG defaults key is `debugInstances`, not `instances`.
- `xcrun simctl spawn $DEV defaults write group.com.ruddarr ...` writes the **wrong domain** —
  the sim's global preferences, not the app group container the app reads. Use the plist path.
  `PlistBuddy` also mangles JSON string values; `plutil -replace -string` does not.
- Edit only while the device is shut down, or `cfprefsd` flushes its cache over the change.

Building the simulator app with `CODE_SIGNING_ALLOWED=NO` (as CI does for tests) strips the
CloudKit entitlement, and the app then aborts on launch inside `setSentryCloudKitContext()`.
Use those flags for `xcodebuild test`, but build signed if you intend to actually run the app.

This Xcode install has no standalone `Simulator.app` and no `idb`, so UI taps cannot be
automated — screenshots of menus or any pushed screen are not currently reproducible headlessly.
