import UIKit
import os

// MARK: - VLCPlayerViewController

/// UIViewController that hosts the VLC video rendering surface.
///
/// This controller owns the lifecycle of the VLC player view: it adds the
/// `VLCPlayerWrapper.videoView` as a subview pinned to all edges, triggers
/// `setup()` on load, and ensures the player is stopped when the controller
/// disappears to avoid orphaned audio or network connections.
final class VLCPlayerViewController: UIViewController {

    // MARK: - Properties

    let playerWrapper: VLCPlayerWrapper
    var onDismiss: (() -> Void)?
    private let logger = Logger.player

    // MARK: - Initialisation

    init(playerWrapper: VLCPlayerWrapper) {
        self.playerWrapper = playerWrapper
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("VLCPlayerViewController does not support Interface Builder.")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        let videoView = playerWrapper.videoView
        videoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoView)

        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        #if targetEnvironment(simulator)
        addSimulatorBadge()
        #endif

        playerWrapper.setup()
        logger.debug("VLCPlayerViewController: viewDidLoad complete")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        playerWrapper.stop()
        logger.debug("VLCPlayerViewController: viewDidDisappear, player stopped")
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure the VLC drawable picks up any safe-area or rotation changes.
        playerWrapper.videoView.frame = view.bounds
    }

    // MARK: - Menu Button

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu {
                onDismiss?()
                return
            }
        }
        super.pressesBegan(presses, with: event)
    }

    // MARK: - Simulator Badge

    #if targetEnvironment(simulator)
    private func addSimulatorBadge() {
        let badge = UILabel()
        badge.text = "VLC Player (Simulator Mode)"
        badge.textColor = UIColor.white.withAlphaComponent(0.8)
        badge.font = .systemFont(ofSize: 22, weight: .semibold)
        badge.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.6)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 8
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(badge)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            badge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badge.widthAnchor.constraint(equalToConstant: 400),
            badge.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
    #endif
}
