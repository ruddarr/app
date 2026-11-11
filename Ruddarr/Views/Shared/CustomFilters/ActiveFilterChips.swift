import SwiftUI

/// A horizontally scrolling row of chips for the active filters, shown above the Movies and Series grids.
struct ActiveFilterChips<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                content
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        // The grid's `ScrollView` can set content margins, which would otherwise inset this row twice.
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .containerHorizontalMargins()
        #if os(macOS)
            .padding(.top)
        #else
            .padding(.top, 4)
            .padding(.bottom, 12)
        #endif
    }
}

/// One active filter. Tapping it clears that filter.
struct ActiveFilterChip<Title: View>: View {
    /// What kind of filter this is, read by VoiceOver before the title, e.g. "Tag".
    let kind: LocalizedStringKey
    let clear: () -> Void
    @ViewBuilder let title: Title

    var body: some View {
        Button(action: clear) {
            HStack(spacing: 6) {
                title
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .imageScale(.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .tint(.primary)
        .accessibilityLabel { label in
            Text(kind)
            label
            Text("Remove Filter")
        }
    }
}

extension MoviesView {
    /// The chips of the active filters, above the grid.
    @ViewBuilder
    var filterChips: some View {
        if sort.isFiltered {
            ActiveFilterChips {
                if sort.filter != .all {
                    ActiveFilterChip(kind: "Filter") { sort.filter = .all } title: { sort.filter.label }
                }

                if sort.folder != .all {
                    ActiveFilterChip(kind: "Root Folder") { sort.folder = .all } title: {
                        Label(instance.rootFolders.chipLabel(for: sort.folder), systemImage: "folder")
                    }
                }

                if let tag = sort.tag {
                    ActiveFilterChip(kind: "Tag") { sort.tag = nil } title: {
                        Label(instance.tags.label(for: tag) ?? String(localized: "Tag"), systemImage: "tag")
                    }
                }

                if sort.customFilter != nil {
                    ActiveFilterChip(kind: "Custom Filter") { sort.customFilter = nil } title: {
                        Label(instance.customFilters.chipLabel(for: sort.customFilter), systemImage: "line.3.horizontal.decrease")
                    }
                }
            }
        }
    }

    @ViewBuilder
    var gridWithFilterChips: some View {
        filterChips
        mediaGrid
    }
}

extension SeriesView {
    /// The chips of the active filters, above the grid.
    @ViewBuilder
    var filterChips: some View {
        if sort.isFiltered {
            ActiveFilterChips {
                if sort.filter != .all {
                    ActiveFilterChip(kind: "Filter") { sort.filter = .all } title: { sort.filter.label }
                }

                if sort.folder != .all {
                    ActiveFilterChip(kind: "Root Folder") { sort.folder = .all } title: {
                        Label(instance.rootFolders.chipLabel(for: sort.folder), systemImage: "folder")
                    }
                }

                if let tag = sort.tag {
                    ActiveFilterChip(kind: "Tag") { sort.tag = nil } title: {
                        Label(instance.tags.label(for: tag) ?? String(localized: "Tag"), systemImage: "tag")
                    }
                }

                if sort.customFilter != nil {
                    ActiveFilterChip(kind: "Custom Filter") { sort.customFilter = nil } title: {
                        Label(instance.customFilters.chipLabel(for: sort.customFilter), systemImage: "line.3.horizontal.decrease")
                    }
                }
            }
        }
    }

    @ViewBuilder
    var gridWithFilterChips: some View {
        filterChips
        mediaGrid
    }
}

private extension [InstanceRootFolder] {
    func chipLabel(for path: String) -> String {
        first { $0.path == path }?.menuLabel(among: self) ?? path
    }
}

private extension CustomFilters {
    func chipLabel(for id: CustomFilter.ID?) -> String {
        byId(id)?.label ?? String(localized: "Custom Filter")
    }
}
