import GameController
import Foundation
import os

// MARK: - RemoteCommandHandler

/// Handles Siri Remote and game controller input for the video player.
///
/// On tvOS the Siri Remote is exposed as a `GCController` with a
/// `microGamepad` profile. This handler observes controller connection
/// events and maps physical button presses to player actions via
/// closable callbacks.
///
/// Button mapping:
/// - **Play/Pause (buttonX)** -- toggle play/pause
/// - **D-pad right press** -- seek forward 15 seconds
/// - **D-pad left press** -- seek backward 15 seconds
/// - **Menu button** -- dismiss player / show menu
/// - **Button A (select / click)** -- generic select action
@Observable
final class RemoteCommandHandler {

    // MARK: - Callbacks

    /// Invoked when the play/pause button is pressed.
    var onPlayPause: (() -> Void)?
    /// Invoked when the user presses right on the d-pad or swipes right.
    var onSeekForward: (() -> Void)?
    /// Invoked when the user presses left on the d-pad or swipes left.
    var onSeekBackward: (() -> Void)?
    /// Invoked when the menu button is pressed.
    var onMenu: (() -> Void)?
    /// Invoked when the select/click button (button A) is pressed.
    var onSelect: (() -> Void)?

    // MARK: - Private

    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var configuredControllers: Set<ObjectIdentifier> = []

    private let logger = Logger.player

    // MARK: - Public API

    /// Begins monitoring for Siri Remote and game controller input.
    /// Configures any already-connected controllers and observes future
    /// connections.
    func startHandling() {
        // Configure any controllers that are already connected.
        for controller in GCController.controllers() {
            configureController(controller)
        }

        // Watch for new controllers.
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.configureController(controller)
        }

        // Clean up when controllers disconnect.
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.configuredControllers.remove(ObjectIdentifier(controller))
        }

        logger.debug("RemoteCommandHandler: started handling input")
    }

    /// Stops monitoring for controller input and removes all observers.
    func stopHandling() {
        if let connectObserver {
            NotificationCenter.default.removeObserver(connectObserver)
        }
        if let disconnectObserver {
            NotificationCenter.default.removeObserver(disconnectObserver)
        }

        connectObserver = nil
        disconnectObserver = nil
        configuredControllers.removeAll()

        logger.debug("RemoteCommandHandler: stopped handling input")
    }

    deinit {
        stopHandling()
    }

    // MARK: - Private

    /// Binds button handlers to a specific controller. Supports both the
    /// Siri Remote (micro gamepad) and extended gamepad profiles.
    private func configureController(_ controller: GCController) {
        let id = ObjectIdentifier(controller)
        guard !configuredControllers.contains(id) else { return }
        configuredControllers.insert(id)

        // Siri Remote appears as a microGamepad on tvOS.
        if let micro = controller.microGamepad {
            configureMicroGamepad(micro)
            logger.debug("RemoteCommandHandler: configured micro gamepad (Siri Remote)")
        }

        // Extended gamepad (MFi controllers, Xbox, PlayStation).
        if let extended = controller.extendedGamepad {
            configureExtendedGamepad(extended)
            logger.debug("RemoteCommandHandler: configured extended gamepad")
        }
    }

    /// Configures the Siri Remote micro gamepad profile.
    private func configureMicroGamepad(_ pad: GCMicroGamepad) {
        // Allow the d-pad to report absolute directional values.
        pad.reportsAbsoluteDpadValues = true
        pad.allowsRotation = false

        // Button X on the Siri Remote is the play/pause button.
        pad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onPlayPause?()
        }

        // Button A is the click/select on the touchpad.
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onSelect?()
        }

        // Menu button.
        pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onMenu?()
        }

        // D-pad for directional seek. We use a threshold to distinguish
        // intentional presses from resting-state noise.
        pad.dpad.valueChangedHandler = { [weak self] _, xValue, _ in
            let threshold: Float = 0.7
            if xValue > threshold {
                self?.onSeekForward?()
            } else if xValue < -threshold {
                self?.onSeekBackward?()
            }
        }
    }

    /// Configures an extended (MFi / console) gamepad profile.
    private func configureExtendedGamepad(_ pad: GCExtendedGamepad) {
        // A button = select / play-pause toggle.
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onPlayPause?()
        }

        // B / Menu = back.
        pad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onMenu?()
        }

        pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onMenu?()
        }

        // D-pad left / right for seeking.
        pad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onSeekForward?()
        }

        pad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onSeekBackward?()
        }

        // Left thumbstick as an alternative seek mechanism.
        pad.leftThumbstick.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onSeekForward?()
        }

        pad.leftThumbstick.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.onSeekBackward?()
        }
    }
}
