import SwiftUI

// MARK: - PlayerInfoPanel

/// Infuse-style bottom sheet that slides up over the player without covering
/// the video. Four tabs: Audio, Subtitles, Speed, Info — each presents rich
/// stream metadata and lets the user flip tracks without leaving playback.
///
/// Design goals:
/// - Non-destructive: the video keeps playing behind the panel.
/// - Focus-aware: the segmented header gets focus first, then content.
/// - High contrast: readable over any video background via blur + dimming.
/// - Keyboard/remote friendly: all interactive elements reachable via d-pad.
struct PlayerInfoPanel: View {

    // MARK: - Tabs

    enum Tab: Hashable, CaseIterable, Identifiable {
        case audio, subtitles, speed, info

        var id: Self { self }

        var title: String {
            switch self {
            case .audio: return "Audio"
            case .subtitles: return "Subtitles"
            case .speed: return "Speed"
            case .info: return "Info"
            }
        }

        var symbol: String {
            switch self {
            case .audio: return "speaker.wave.2.fill"
            case .subtitles: return "captions.bubble.fill"
            case .speed: return "speedometer"
            case .info: return "info.circle.fill"
            }
        }
    }

    // MARK: - Inputs

    let viewModel: PlayerViewModel
    let vlcWrapper: VLCPlayerWrapper
    var onClose: () -> Void

    // MARK: - State

    @State private var selectedTab: Tab = .audio
    @FocusState private var focusedTab: Tab?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                tabBar
                Divider()
                    .background(.white.opacity(0.12))
                content
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 60)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .background(panelBackground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 420, maxHeight: 540)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onExitCommand { onClose() }
        .onAppear {
            // Default focus to whichever tab has useful content.
            focusedTab = defaultTab
            selectedTab = defaultTab
        }
    }

    // MARK: - Panel Background

    private var panelBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [.black.opacity(0.25), .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 12) {
            ForEach(Tab.allCases) { tab in
                tabButton(tab)
            }
            Spacer()
            closeButton
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.symbol)
                    .font(.title3)
                Text(tab.title)
                    .font(.headline)
            }
            .foregroundStyle(selectedTab == tab ? Color.black : Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                selectedTab == tab
                    ? AnyShapeStyle(.white)
                    : AnyShapeStyle(.white.opacity(focusedTab == tab ? 0.28 : 0.12)),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(focusedTab == tab && selectedTab != tab ? 0.9 : 0), lineWidth: 2)
            )
            .scaleEffect(focusedTab == tab ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: focusedTab)
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
        }
        .buttonStyle(.plain)
        .focused($focusedTab, equals: tab)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(14)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Routing

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .audio:
            AudioTracksTab(viewModel: viewModel, vlcWrapper: vlcWrapper)
        case .subtitles:
            SubtitlesTab(viewModel: viewModel, vlcWrapper: vlcWrapper)
        case .speed:
            PlaybackSpeedTab(vlcWrapper: vlcWrapper)
        case .info:
            InfoTab(viewModel: viewModel, vlcWrapper: vlcWrapper)
        }
    }

    // MARK: - Default tab selection

    /// Picks the most useful starting tab: Subtitles if there are tracks the
    /// user probably wants to toggle, otherwise Audio if there are multiple
    /// languages, otherwise Info.
    private var defaultTab: Tab {
        if !vlcWrapper.subtitleTracks.filter({ $0.index >= 0 }).isEmpty {
            return .subtitles
        }
        if vlcWrapper.audioTracks.count > 1 {
            return .audio
        }
        return .info
    }
}

// MARK: - Audio Tab

private struct AudioTracksTab: View {
    let viewModel: PlayerViewModel
    let vlcWrapper: VLCPlayerWrapper

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if vlcWrapper.audioTracks.isEmpty {
                    EmptyStateView(
                        symbol: "speaker.slash",
                        title: "No audio tracks",
                        subtitle: "This title only has a single audio stream."
                    )
                } else {
                    ForEach(vlcWrapper.audioTracks, id: \.index) { track in
                        PlayerTrackRow(
                            title: displayTitle(for: track),
                            subtitle: subtitleText(for: track),
                            badges: badges(for: track),
                            isSelected: vlcWrapper.selectedAudioTrackIndex == track.index,
                            icon: "speaker.wave.2.fill",
                            action: {
                                vlcWrapper.setAudioTrack(index: track.index)
                                if let jf = jellyfinTrack(for: track) {
                                    viewModel.selectAudioTrack(jf)
                                }
                            }
                        )
                    }
                }
            }
        }
        .focusSection()
    }

    // MARK: - Track enrichment

    private func jellyfinTrack(for track: (index: Int, title: String)) -> MediaStreamDTO? {
        viewModel.audioTracks.first(where: { $0.index == track.index })
    }

    private func displayTitle(for track: (index: Int, title: String)) -> String {
        if let jf = jellyfinTrack(for: track), let display = jf.displayTitle, !display.isEmpty {
            return display
        }
        return track.title
    }

    private func subtitleText(for track: (index: Int, title: String)) -> String? {
        guard let jf = jellyfinTrack(for: track) else { return nil }
        var pieces: [String] = []
        if let language = jf.language?.uppercased(), !language.isEmpty {
            pieces.append(languageName(for: language) ?? language)
        }
        if let bitrate = jf.bitRate {
            pieces.append("\(bitrate / 1000) kbps")
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: "  ·  ")
    }

    private func badges(for track: (index: Int, title: String)) -> [TrackBadge] {
        var badges: [TrackBadge] = []
        guard let jf = jellyfinTrack(for: track) else { return badges }

        if let codec = jf.codec?.uppercased(), !codec.isEmpty {
            badges.append(TrackBadge(text: codec, tint: .blue))
        }
        if let channels = jf.channels {
            badges.append(TrackBadge(text: channelLabel(channels), tint: .green))
        }
        if jf.isDefault == true {
            badges.append(TrackBadge(text: "DEFAULT", tint: .orange))
        }
        return badges
    }

    private func channelLabel(_ channels: Int) -> String {
        switch channels {
        case 1: return "MONO"
        case 2: return "STEREO"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)ch"
        }
    }

    private func languageName(for code: String) -> String? {
        Locale.current.localizedString(forLanguageCode: code.lowercased())
    }
}

// MARK: - Subtitles Tab

private struct SubtitlesTab: View {
    let viewModel: PlayerViewModel
    let vlcWrapper: VLCPlayerWrapper

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            // Left column: track list
            VStack(alignment: .leading, spacing: 14) {
                Text("Track")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        PlayerTrackRow(
                            title: "Off",
                            subtitle: nil,
                            badges: [],
                            isSelected: vlcWrapper.selectedSubtitleTrackIndex == -1,
                            icon: "eye.slash",
                            action: {
                                vlcWrapper.setSubtitleTrack(index: -1)
                                viewModel.selectSubtitleTrack(nil)
                            }
                        )

                        ForEach(vlcWrapper.subtitleTracks.filter { $0.index >= 0 }, id: \.index) { track in
                            PlayerTrackRow(
                                title: displayTitle(for: track),
                                subtitle: subtitleText(for: track),
                                badges: badges(for: track),
                                isSelected: vlcWrapper.selectedSubtitleTrackIndex == track.index,
                                icon: "captions.bubble.fill",
                                action: {
                                    vlcWrapper.setSubtitleTrack(index: track.index)
                                    if let jf = jellyfinTrack(for: track) {
                                        viewModel.selectSubtitleTrack(jf)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column: timing adjustment
            VStack(alignment: .leading, spacing: 14) {
                Text("Timing")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)

                SubtitleDelayControl(vlcWrapper: vlcWrapper)
            }
            .frame(width: 320, alignment: .topLeading)
        }
        .focusSection()
    }

    // MARK: - Track enrichment

    private func jellyfinTrack(for track: (index: Int, title: String)) -> MediaStreamDTO? {
        viewModel.subtitleTracks.first(where: { $0.index == track.index })
    }

    private func displayTitle(for track: (index: Int, title: String)) -> String {
        if let jf = jellyfinTrack(for: track), let display = jf.displayTitle, !display.isEmpty {
            return display
        }
        return track.title
    }

    private func subtitleText(for track: (index: Int, title: String)) -> String? {
        guard let jf = jellyfinTrack(for: track) else { return nil }
        if let language = jf.language?.uppercased(), !language.isEmpty {
            return Locale.current.localizedString(forLanguageCode: language.lowercased()) ?? language
        }
        return nil
    }

    private func badges(for track: (index: Int, title: String)) -> [TrackBadge] {
        var badges: [TrackBadge] = []
        guard let jf = jellyfinTrack(for: track) else { return badges }

        if let codec = jf.codec?.uppercased(), !codec.isEmpty {
            badges.append(TrackBadge(text: codec, tint: .blue))
        }
        if jf.isForced == true {
            badges.append(TrackBadge(text: "FORCED", tint: .orange))
        }
        if jf.isExternal == true {
            badges.append(TrackBadge(text: "EXTERNAL", tint: .cyan))
        }
        if jf.isDefault == true {
            badges.append(TrackBadge(text: "DEFAULT", tint: .green))
        }
        return badges
    }
}

// MARK: - Subtitle Delay Control

private struct SubtitleDelayControl: View {
    let vlcWrapper: VLCPlayerWrapper

    private let step: Double = 0.25

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delay")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Shift subtitles earlier or later if they're out of sync.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                stepperButton(symbol: "minus") {
                    vlcWrapper.setSubtitleDelay(seconds: vlcWrapper.subtitleDelaySeconds - step)
                }

                Text(formatted)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 140)
                    .multilineTextAlignment(.center)

                stepperButton(symbol: "plus") {
                    vlcWrapper.setSubtitleDelay(seconds: vlcWrapper.subtitleDelaySeconds + step)
                }
            }

            if vlcWrapper.subtitleDelaySeconds != 0 {
                Button {
                    vlcWrapper.setSubtitleDelay(seconds: 0)
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var formatted: String {
        let seconds = vlcWrapper.subtitleDelaySeconds
        if seconds == 0 { return "0.00s" }
        let sign = seconds > 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(seconds)))s"
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playback Speed Tab

private struct PlaybackSpeedTab: View {
    let vlcWrapper: VLCPlayerWrapper

    private let presets: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Playback Speed")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)

            HStack(spacing: 14) {
                ForEach(presets, id: \.self) { rate in
                    speedButton(for: rate)
                }
                Spacer()
            }

            Text("Audio pitch is corrected automatically so dialogue stays intelligible at slower or faster speeds.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }

    private func speedButton(for rate: Float) -> some View {
        let selected = abs(vlcWrapper.playbackRate - rate) < 0.01
        return Button {
            vlcWrapper.setPlaybackRate(rate)
        } label: {
            VStack(spacing: 4) {
                Text(label(for: rate))
                    .font(.title3)
                    .fontWeight(.semibold)
                if rate == 1.0 {
                    Text("Normal")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 110, height: 80)
            .foregroundStyle(selected ? Color.black : Color.white)
            .background(
                selected
                    ? AnyShapeStyle(.white)
                    : AnyShapeStyle(.white.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }

    private func label(for rate: Float) -> String {
        if rate == rate.rounded() {
            return "\(Int(rate))×"
        }
        return String(format: "%.2g×", rate)
    }
}

// MARK: - Info Tab

private struct InfoTab: View {
    let viewModel: PlayerViewModel
    let vlcWrapper: VLCPlayerWrapper

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                infoSection(title: "Video") {
                    infoRow(label: "Codec", value: videoCodec)
                    infoRow(label: "Resolution", value: videoResolution)
                    infoRow(label: "Bitrate", value: videoBitrate)
                    infoRow(label: "Frame size", value: frameSize)
                }

                infoSection(title: "Audio") {
                    if let audio = selectedAudio {
                        infoRow(label: "Codec", value: audio.codec?.uppercased())
                        infoRow(label: "Channels", value: audio.channels.map(channelLabel))
                        infoRow(label: "Language", value: audio.language.map { languageName(for: $0) })
                        infoRow(label: "Bitrate", value: audio.bitRate.map { "\($0 / 1000) kbps" })
                    } else {
                        Text("No active audio stream.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                infoSection(title: "File") {
                    infoRow(label: "Container", value: viewModel.mediaSource?.container?.uppercased())
                    infoRow(label: "Overall bitrate", value: viewModel.mediaSource?.bitrate.map { "\($0 / 1000) kbps" })
                    infoRow(label: "Size", value: fileSize)
                    infoRow(label: "Runtime", value: runtime)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .focusSection()
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func infoSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 160, alignment: .leading)
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Derived values

    private var videoStream: MediaStreamDTO? { viewModel.videoStream }
    private var selectedAudio: MediaStreamDTO? {
        viewModel.audioTracks.first(where: { $0.index == vlcWrapper.selectedAudioTrackIndex })
            ?? viewModel.selectedAudioTrack
    }

    private var videoCodec: String? {
        videoStream?.codec?.uppercased()
    }

    private var videoResolution: String? {
        guard let width = videoStream?.width, let height = videoStream?.height else { return nil }
        let pretty = prettyResolution(width: width, height: height)
        return pretty
    }

    private var videoBitrate: String? {
        videoStream?.bitRate.map { "\($0 / 1000) kbps" }
    }

    private var frameSize: String? {
        guard let width = videoStream?.width, let height = videoStream?.height else { return nil }
        return "\(width) × \(height)"
    }

    private var fileSize: String? {
        guard let bytes = viewModel.mediaSource?.size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private var runtime: String? {
        // TimeFormatter.runtime returns nil for zero/nil input, so we can
        // pass the raw duration directly.
        TimeFormatter.runtime(from: viewModel.duration)
    }

    // MARK: - Formatting

    private func prettyResolution(width: Int, height: Int) -> String {
        switch (width, height) {
        case let (w, h) where w >= 3800 && h >= 2000: return "4K UHD (\(w)×\(h))"
        case let (w, h) where w >= 1900 && h >= 1000: return "1080p (\(w)×\(h))"
        case let (w, h) where w >= 1200 && h >= 700:  return "720p (\(w)×\(h))"
        case let (w, h) where w >= 800  && h >= 500:  return "576p (\(w)×\(h))"
        default: return "\(width)×\(height)"
        }
    }

    private func channelLabel(_ channels: Int) -> String {
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1 Surround"
        case 8: return "7.1 Surround"
        default: return "\(channels) channels"
        }
    }

    private func languageName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code.lowercased()) ?? code.uppercased()
    }
}

// MARK: - Reusable row + helpers

private struct TrackBadge: Hashable {
    let text: String
    let tint: Color
}

private struct PlayerTrackRow: View {
    let title: String
    let subtitle: String?
    let badges: [TrackBadge]
    let isSelected: Bool
    let icon: String
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .white.opacity(0.6))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge.text)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(badge.tint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badge.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(badge.tint.opacity(0.35), lineWidth: 1)
                                )
                        }

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 12)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                rowBackground,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isFocused ? .white.opacity(0.9) : .white.opacity(0.08), lineWidth: isFocused ? 2 : 1)
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }

    private var rowBackground: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.blue.opacity(isFocused ? 0.35 : 0.2))
        }
        return AnyShapeStyle(.white.opacity(isFocused ? 0.18 : 0.06))
    }
}

private struct EmptyStateView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.5))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
