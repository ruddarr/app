import SwiftUI

struct ProwlarrSearchSheet: View {
    var release: ProwlarrRelease
    @Bindable var search: ProwlarrSearch

    @EnvironmentObject var settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var isGrabbing: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    header.padding(.bottom)
                    actions.padding(.bottom)
                    details
                }
                .scenePadding(.horizontal)
                .padding(.top, deviceType == .mac ? 24 : (reduceTransparency ? 0 : -45))
            }
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .hideIconOnMac()
                        .tint(.primary)
                }
            }
            .alert(
                isPresented: search.errorBinding,
                error: search.error
            ) { _ in
                Button("OK") { search.error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }.tint(nil)
        }
    }

    var header: some View {
        VStack(alignment: .leading) {
            Text(release.network.label)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(settings.theme.tint)

            Text(release.title.breakable())
                .font(.title2.bold())
                .kerning(-0.5)
                .padding(.trailing, 56)

            HStack(spacing: 6) {
                Text(release.sizeLabel)
                Bullet()
                Text(release.ageLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if !release.categories.isEmpty {
                categoryChips.padding(.top, 6)
            }
        }
    }

    var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(release.categories) { category in
                    if let name = category.name {
                        Text(name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.card)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    var actions: some View {
        HStack(spacing: 24) {
            if deviceType != .phone { Spacer() }

            if let url = URL(string: release.infoUrl ?? "") {
                Link(destination: url) {
                    let label: LocalizedStringKey = deviceType == .phone ? "Website" : "Open Website"

                    ButtonLabel(text: label, icon: "arrow.up.right.square")
                        .modifier(MediaPreviewActionModifier())
                }
                .buttonStyle(.bordered)
                .tint(.buttonTint)
                .contextMenu { LinkContextMenu(url) }
            }

            Button {
                Task { await grab() }
            } label: {
                let label: String = deviceType == .phone
                    ? String(localized: "Download", comment: "Short version of Download Release")
                    : String(localized: "Download Release")

                ButtonLabel(text: label, icon: "arrow.down.circle", isLoading: isGrabbing)
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.buttonTint)
            .allowsHitTesting(!isGrabbing)

            if deviceType != .phone { Spacer() }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var details: some View {
        Section {
            VStack(spacing: 6) {
                row("Indexer", value: release.indexerLabel)

                if release.isTorrent {
                    Divider()
                    row("Peers", value: String(format: "S: %i  L: %i", release.seeders ?? 0, release.leechers ?? 0))
                }

                if let grabs = release.grabs {
                    Divider()
                    row("Grabs", value: String(grabs))
                }

                if let publishDate = release.publishDate {
                    Divider()
                    row("Published", value: publishDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .padding(.bottom)
        } header: {
            Text("Information")
                .font(.title2.bold())
        }
    }

    func row(_ label: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer(); Spacer(); Spacer()
            Text(value).foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }

    func grab() async {
        isGrabbing = true
        let ok = await search.grab(release)
        isGrabbing = false

        guard ok else { return }
        dismiss()
        dependencies.toast.show(.downloadQueued)
    }
}

#Preview {
    let releases: [ProwlarrRelease] = PreviewData.load(name: "prowlarr-search")
    let dummy = Instance.prowlarrDummy
    let search = ProwlarrSearch(dummy)

    Text(verbatim: "Sheet")
        .sheet(isPresented: .constant(true)) {
            ProwlarrSearchSheet(release: releases[1], search: search)
                .presentationDetents([.medium])
                .presentationBackground(.sheetBackground)
        }
        .withAppState()
}
