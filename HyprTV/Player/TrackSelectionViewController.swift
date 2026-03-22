import UIKit
import SwiftUI

/// Custom info view controller displayed when the user swipes down during playback.
/// Shows audio track and subtitle selection lists.
/// This is set via AVPlayerViewController.customInfoViewController.
final class TrackSelectionViewController: UIViewController {

    private let audioTracks: [AudioTrack]
    private let subtitleTracks: [SubtitleTrack]
    private var currentAudioIndex: Int
    private var currentSubtitleIndex: Int?
    private let onAudioSelected: (Int) -> Void
    private let onSubtitleSelected: (Int?) -> Void

    init(
        audioTracks: [AudioTrack],
        subtitleTracks: [SubtitleTrack],
        currentAudioIndex: Int,
        onAudioSelected: @escaping (Int) -> Void,
        onSubtitleSelected: @escaping (Int?) -> Void
    ) {
        self.audioTracks = audioTracks
        self.subtitleTracks = subtitleTracks
        self.currentAudioIndex = currentAudioIndex
        self.onAudioSelected = onAudioSelected
        self.onSubtitleSelected = onSubtitleSelected
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(rootView: TrackSelectionView(
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks,
            currentAudioIndex: currentAudioIndex,
            currentSubtitleIndex: currentSubtitleIndex,
            onAudioSelected: { [weak self] idx in
                self?.currentAudioIndex = idx
                self?.onAudioSelected(idx)
            },
            onSubtitleSelected: { [weak self] idx in
                self?.currentSubtitleIndex = idx
                self?.onSubtitleSelected(idx)
            }
        ))

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}

// MARK: - SwiftUI View

struct TrackSelectionView: View {

    let audioTracks: [AudioTrack]
    let subtitleTracks: [SubtitleTrack]
    @State var currentAudioIndex: Int
    @State var currentSubtitleIndex: Int?
    let onAudioSelected: (Int) -> Void
    let onSubtitleSelected: (Int?) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 80) {
            // Audio tracks
            if !audioTracks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Audio", systemImage: "speaker.wave.3.fill")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    ForEach(audioTracks) { track in
                        Button {
                            currentAudioIndex = track.id
                            onAudioSelected(track.id)
                        } label: {
                            HStack {
                                if track.id == currentAudioIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                } else {
                                    Color.clear.frame(width: 24, height: 1)
                                }
                                Text(track.label)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minWidth: 350)
            }

            // Subtitle tracks
            if !subtitleTracks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Subtitles", systemImage: "captions.bubble.fill")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    // "Off" option
                    Button {
                        currentSubtitleIndex = nil
                        onSubtitleSelected(nil)
                    } label: {
                        HStack {
                            if currentSubtitleIndex == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                            } else {
                                Color.clear.frame(width: 24, height: 1)
                            }
                            Text("Off")
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)

                    ForEach(subtitleTracks) { track in
                        Button {
                            currentSubtitleIndex = track.id
                            onSubtitleSelected(track.id)
                        } label: {
                            HStack {
                                if track.id == currentSubtitleIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                } else {
                                    Color.clear.frame(width: 24, height: 1)
                                }
                                Text(track.label)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minWidth: 350)
            }
        }
        .padding(40)
    }
}
