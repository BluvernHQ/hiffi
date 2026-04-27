import AVFoundation
import AVKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pipChannelName = "com.hiffi.app/pip"
  private var pipChannel: FlutterMethodChannel?
  private var isPlayerActiveForPip = false
  private var pipController: AVPictureInPictureController?
  private weak var pipPlayerLayer: AVPlayerLayer?
  /// Bumped when PiP stops so pending `asyncAfter` retry chains do not call `startPictureInPicture` late.
  private var pipCancelToken: UInt64 = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    setupPipChannel()
    observeAppLifecycleForPip()
    configureBackgroundAudioSession()
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Avoid a black flash between launch screen and first Flutter frame.
    window?.backgroundColor = UIColor.white
    return result
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    if isPlayerActiveForPip {
      enterPiPIfPossible()
    }
    super.applicationWillResignActive(application)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    if isPlayerActiveForPip,
       pipController?.isPictureInPictureActive != true {
      enterPiPIfPossible()
    }
    super.applicationDidEnterBackground(application)
  }

  private func configureBackgroundAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .moviePlayback,
        options: [.allowAirPlay, .allowBluetoothA2DP]
      )
    } catch {
      NSLog("HiffiPiP: AVAudioSession category failed: \(error)")
    }
  }

  private func setupPipChannel() {
    guard
      let flutterController = window?.rootViewController as? FlutterViewController
    else {
      NSLog("HiffiPiP: setupPipChannel skipped — no FlutterViewController yet")
      return
    }
    let channel = FlutterMethodChannel(
      name: pipChannelName,
      binaryMessenger: flutterController.binaryMessenger
    )
    pipChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "updatePlayerStatus":
        let isActive = (call.arguments as? Bool) ?? false
        self.isPlayerActiveForPip = isActive
        if !isActive {
          self.pipCancelToken += 1
          self.pipController = nil
          self.pipPlayerLayer = nil
        }
        let refresh: () -> Void = { [weak self] in
          guard let self else { return }
          self.refreshPipControllerIfNeeded()
        }
        if Thread.isMainThread {
          refresh()
          DispatchQueue.main.async(execute: refresh)
        } else {
          DispatchQueue.main.async(execute: refresh)
        }
        result(nil)
      case "enterPiP":
        let startPiP: () -> Void = { [weak self] in
          guard let self else { return }
          self.isPlayerActiveForPip = true
          self.enterPiPIfPossible()
        }
        if Thread.isMainThread {
          startPiP()
        } else {
          DispatchQueue.main.sync(execute: startPiP)
        }
        result(nil)
      case "expandFromPip":
        let expand: () -> Void = { [weak self] in
          guard let self else { return }
          self.stopPiPIfNeeded()
        }
        if Thread.isMainThread {
          expand()
        } else {
          DispatchQueue.main.sync(execute: expand)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func observeAppLifecycleForPip() {
    if #available(iOS 13.0, *) {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleSceneWillDeactivate(_:)),
        name: UIScene.willDeactivateNotification,
        object: nil
      )
    }
  }

  @objc private func handleSceneWillDeactivate(_ notification: Notification) {
    guard let scene = notification.object as? UIScene else { return }
    guard scene == window?.windowScene else { return }
    guard isPlayerActiveForPip else { return }
    enterPiPIfPossible()
  }

  private func enterPiPIfPossible() {
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      NSLog("HiffiPiP: PiP not supported on this device / OS build")
      return
    }
    let token = pipCancelToken
    attemptStartPictureInPicture(attempt: 0, cancelToken: token)
  }

  private func attemptStartPictureInPicture(attempt: Int, cancelToken: UInt64) {
    guard cancelToken == pipCancelToken else { return }
    refreshPipControllerIfNeeded()
    guard let controller = pipController else {
      if attempt == 0 || attempt == 6 {
        NSLog("HiffiPiP: no pipController yet (attempt \(attempt)) — layer search may have failed")
      }
      if attempt < 28 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
          guard let self else { return }
          guard cancelToken == self.pipCancelToken else { return }
          self.attemptStartPictureInPicture(attempt: attempt + 1, cancelToken: cancelToken)
        }
      } else {
        NSLog("HiffiPiP: gave up starting PiP — AVPlayerLayer not found or controller nil")
      }
      return
    }
    if controller.isPictureInPictureActive {
      return
    }
    guard cancelToken == pipCancelToken else { return }
    do {
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("HiffiPiP: setActive(true) failed: \(error)")
    }
    if let p = pipPlayerLayer?.player, p.rate == 0, p.currentItem != nil {
      p.play()
    }
    NSLog("HiffiPiP: invoking startPictureInPicture (attempt \(attempt))")
    controller.startPictureInPicture()
  }

  private func stopPiPIfNeeded() {
    guard let controller = pipController, controller.isPictureInPictureActive else {
      return
    }
    controller.stopPictureInPicture()
  }

  /// All window root views in foreground-ish scenes — Flutter + platform views can
  /// live under a non-key window during transitions.
  private func rootViewsForLayerSearch() -> [UIView] {
    var views: [UIView] = []
    if let v = window?.rootViewController?.view {
      views.append(v)
    }
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        guard let ws = scene as? UIWindowScene else { continue }
        // Include `.background`: by the time Flutter's `paused` invokes `enterPiP`,
        // or `applicationDidEnterBackground` runs, the scene is often already
        // `.background` — excluding it made layer search empty and PiP never started.
        if ws.activationState == .unattached { continue }
        for w in ws.windows {
          if let v = w.rootViewController?.view {
            views.append(v)
          }
        }
      }
    }
    return views
  }

  private func refreshPipControllerIfNeeded() {
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      pipController = nil
      pipPlayerLayer = nil
      return
    }
    if !isPlayerActiveForPip {
      return
    }

    var discovered: AVPlayerLayer?
    var bestArea: CGFloat = 0
    func consider(_ candidate: AVPlayerLayer?) {
      guard let c = candidate, c.player != nil else { return }
      let a = layerArea(c)
      if a > bestArea {
        bestArea = a
        discovered = c
      }
    }
    let roots = rootViewsForLayerSearch()
    for root in roots {
      consider(bestPlayerLayerForPiP(in: root.layer))
      consider(bestPlayerLayerInViewHierarchy(root))
    }
    if discovered == nil, let cached = pipPlayerLayer, cached.player != nil {
      discovered = cached
      NSLog("HiffiPiP: using cached AVPlayerLayer (hierarchy search empty this frame)")
    }
    guard let playerLayer = discovered else {
      return
    }
    let reuseExistingController = pipController != nil && pipPlayerLayer === playerLayer
    pipPlayerLayer = playerLayer
    if reuseExistingController, let existing = pipController {
      applyAutoPiPPreferenceIfAvailable(to: existing)
      return
    }

    let controller: AVPictureInPictureController?
    if #available(iOS 15.0, *) {
      let source = AVPictureInPictureController.ContentSource(playerLayer: playerLayer)
      controller = AVPictureInPictureController(contentSource: source)
    } else {
      controller = AVPictureInPictureController(playerLayer: playerLayer)
    }
    guard let created = controller else {
      NSLog("HiffiPiP: AVPictureInPictureController init returned nil")
      pipController = nil
      return
    }
    created.delegate = self
    applyAutoPiPPreferenceIfAvailable(to: created)
    pipController = created
  }

  private func applyAutoPiPPreferenceIfAvailable(to controller: AVPictureInPictureController) {
    if #available(iOS 14.2, *) {
      controller.canStartPictureInPictureAutomaticallyFromInline = isPlayerActiveForPip
    }
  }

  private func bestPlayerLayerForPiP(in root: CALayer) -> AVPlayerLayer? {
    var found: [AVPlayerLayer] = []
    collectPlayerLayers(in: root, into: &found)
    return found
      .filter { $0.player != nil }
      .max(by: { layerArea($0) < layerArea($1) })
  }

  /// `video_player` iOS uses `FVPPlayerView` (`layerClass == AVPlayerLayer`). Walking only
  /// `CALayer.sublayers` can miss some Flutter platform-view embeddings; also walk UIViews.
  private func bestPlayerLayerInViewHierarchy(_ view: UIView) -> AVPlayerLayer? {
    var found: [AVPlayerLayer] = []
    collectPlayerLayersFromViews(view, into: &found)
    return found
      .filter { $0.player != nil }
      .max(by: { layerArea($0) < layerArea($1) })
  }

  private func collectPlayerLayersFromViews(_ view: UIView, into array: inout [AVPlayerLayer]) {
    if let pl = view.layer as? AVPlayerLayer, pl.player != nil {
      array.append(pl)
    }
    for sub in view.subviews {
      collectPlayerLayersFromViews(sub, into: &array)
    }
  }

  private func layerArea(_ layer: AVPlayerLayer) -> CGFloat {
    let b = layer.bounds
    return b.width * b.height
  }

  private func collectPlayerLayers(in layer: CALayer, into array: inout [AVPlayerLayer]) {
    if let playerLayer = layer as? AVPlayerLayer, playerLayer.player != nil {
      array.append(playerLayer)
    }
    guard let sublayers = layer.sublayers else { return }
    for sublayer in sublayers {
      collectPlayerLayers(in: sublayer, into: &array)
    }
  }
}

extension AppDelegate: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    NSLog("HiffiPiP: didStartPictureInPicture")
    pipChannel?.invokeMethod("onPictureInPictureModeChanged", arguments: true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    NSLog("HiffiPiP: didStopPictureInPicture")
    pipCancelToken += 1
    pipChannel?.invokeMethod("onPictureInPictureModeChanged", arguments: false)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    NSLog("HiffiPiP: failedToStartPictureInPicture: \(error.localizedDescription)")
  }
}
