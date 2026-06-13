//
//  ContentView.swift
//  SeatFlow
//
//  Created by 川岡哲也 on 2026/06/13.
//

import SwiftUI
import WebKit
@preconcurrency import AVFoundation
import os

struct ContentView: View {
    var body: some View {
        SeatFlowWebView()
            .ignoresSafeArea()
    }
}

struct SeatFlowWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(context.coordinator, name: "seatflow")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        if let htmlURL = Bundle.main.url(forResource: "SeatFlow_iPad", withExtension: "html") {
            webView.loadFileURL(
                htmlURL,
                allowingReadAccessTo: htmlURL.deletingLastPathComponent()
            )
        } else {
            webView.loadHTMLString(
                """
                <html lang="ja">
                <body style="font-family:-apple-system;padding:24px">
                    <h1>SeatFlow</h1>
                    <p>SeatFlow_iPad.html がアプリに含まれていません。</p>
                </body>
                </html>
                """,
                baseURL: nil
            )
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private let logger = Logger(subsystem: "com.llld.SeatFlow", category: "Camera")
        private let cameraRotationKey = "seatflow.cameraRotationAngle"
        weak var webView: WKWebView?
        weak var scannerViewController: NativeScannerViewController?

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func applicationDidEnterBackground() {
            stopScanner()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == "seatflow",
                let body = message.body as? [String: Any],
                let action = body["action"] as? String
            else {
                return
            }

            switch action {
            case "export":
                exportFile(body)
            case "scan":
                startScanner(body)
            case "stopScan":
                stopScanner()
            case "updateScannerFrame":
                updateScannerFrame(body)
            case "rotateCamera":
                rotateCamera()
            default:
                break
            }
        }

        private func exportFile(_ body: [String: Any]) {
            guard
                let filename = body["filename"] as? String,
                let text = body["text"] as? String,
                let data = text.data(using: .utf8),
                let presenter = topViewController()
            else {
                return
            }

            let safeName = filename.replacingOccurrences(of: "/", with: "_")
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)

            do {
                try data.write(to: fileURL, options: .atomic)
                let activity = UIActivityViewController(
                    activityItems: [fileURL],
                    applicationActivities: nil
                )
                activity.popoverPresentationController?.sourceView = presenter.view
                activity.popoverPresentationController?.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
                presenter.present(activity, animated: true)
            } catch {
                showAlert(title: "書き出しエラー", message: error.localizedDescription)
            }
        }

        private func startScanner(_ body: [String: Any]) {
            logger.info("Camera button message received")
            if scannerViewController != nil {
                stopScanner()
            }

            guard let presenter = topViewController() else {
                logger.error("Could not find camera overlay host")
                sendCameraStatus("カメラ画面を開けません")
                return
            }

            let target = body["target"] as? String ?? "scanInput"
            let autoApply = body["autoApply"] as? Bool ?? false
            let continuous = body["continuous"] as? Bool ?? false
            let scanner = NativeScannerViewController()
            scanner.rotationAngle = cameraRotationAngle
            scanner.closesAfterResult = !continuous
            scanner.showsCloseButton = !continuous
            scanner.onResult = { [weak self] code in
                self?.sendScanResult(target: target, code: code, autoApply: autoApply)
            }
            scanner.onClose = { [weak self] in
                self?.scannerViewController = nil
                self?.sendCameraStatus("停止中")
            }
            scanner.onStatus = { [weak self] status in
                self?.sendCameraStatus(status)
            }
            scannerViewController = scanner
            presenter.addChild(scanner)
            scanner.view.frame = scannerFrame(from: body, in: presenter)
            scanner.view.autoresizingMask = []
            scanner.view.layer.cornerRadius = 14
            scanner.view.clipsToBounds = true
            presenter.view.addSubview(scanner.view)
            scanner.didMove(toParent: presenter)
            sendCameraStatus("カメラ許可を確認中")
            sendCameraRotation()
            logger.info("Camera overlay attached")
        }

        private func stopScanner() {
            scannerViewController?.close()
            scannerViewController = nil
            sendCameraStatus("停止中")
        }

        private func updateScannerFrame(_ body: [String: Any]) {
            guard
                let scanner = scannerViewController,
                let presenter = scanner.parent
            else {
                return
            }
            scanner.view.frame = scannerFrame(from: body, in: presenter)
        }

        private var cameraRotationAngle: CGFloat {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: cameraRotationKey) != nil else {
                return 90
            }
            return CGFloat(defaults.double(forKey: cameraRotationKey))
        }

        private func rotateCamera() {
            let nextAngle = (cameraRotationAngle + 90)
                .truncatingRemainder(dividingBy: 360)
            UserDefaults.standard.set(Double(nextAngle), forKey: cameraRotationKey)
            scannerViewController?.setRotationAngle(nextAngle)
            sendCameraRotation()
        }

        private func sendCameraRotation() {
            let angle = Int(cameraRotationAngle)
            webView?.evaluateJavaScript(
                "window.seatflowNativeCameraRotation?.(\(angle));"
            )
        }

        private func scannerFrame(
            from body: [String: Any],
            in presenter: UIViewController
        ) -> CGRect {
            guard
                let webView,
                let x = number(body["x"]),
                let y = number(body["y"]),
                let width = number(body["width"]),
                let height = number(body["height"]),
                let viewportWidth = number(body["viewportWidth"]),
                let viewportHeight = number(body["viewportHeight"]),
                viewportWidth > 0,
                viewportHeight > 0,
                width > 0,
                height > 0
            else {
                let size = CGSize(
                    width: min(520, presenter.view.bounds.width - 32),
                    height: min(360, presenter.view.bounds.height - 80)
                )
                return CGRect(
                    x: presenter.view.bounds.midX - size.width / 2,
                    y: presenter.view.bounds.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
            }

            let scaleX = webView.bounds.width / viewportWidth
            let scaleY = webView.bounds.height / viewportHeight
            let localFrame = CGRect(
                x: webView.bounds.minX + x * scaleX,
                y: webView.bounds.minY + y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            )
            let converted = webView.convert(localFrame, to: presenter.view)
            return converted.intersection(presenter.view.bounds)
        }

        private func number(_ value: Any?) -> CGFloat? {
            if let number = value as? NSNumber {
                return CGFloat(truncating: number)
            }
            return nil
        }

        private func sendCameraStatus(_ message: String) {
            guard let json = encodeJavaScriptValue(message) else {
                return
            }
            webView?.evaluateJavaScript("window.seatflowNativeCameraStatus?.(\(json));")
        }

        private func sendScanResult(target: String, code: String, autoApply: Bool) {
            guard
                let data = try? JSONSerialization.data(
                    withJSONObject: [target, code, autoApply]
                ),
                let arguments = String(data: data, encoding: .utf8)
            else {
                return
            }

            webView?.evaluateJavaScript(
                "window.seatflowNativeScanResult(...\(arguments));"
            )
        }

        private func encodeJavaScriptValue<T: Encodable>(_ value: T) -> String? {
            guard
                let data = try? JSONEncoder().encode(value),
                let json = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return json
        }

        private func topViewController(
            from root: UIViewController? = nil
        ) -> UIViewController? {
            let base = root ?? webView?.window?.rootViewController

            if let presented = base?.presentedViewController {
                return topViewController(from: presented)
            }
            if let navigation = base as? UINavigationController {
                return topViewController(from: navigation.visibleViewController)
            }
            if let tabs = base as? UITabBarController {
                return topViewController(from: tabs.selectedViewController)
            }
            return base
        }

        private func showAlert(title: String, message: String) {
            guard let presenter = topViewController() else {
                return
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            sendCameraRotation()
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            completionHandler()
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            completionHandler(true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            completionHandler(defaultText)
        }
    }
}

final class NativeScannerViewController: UIViewController, nonisolated AVCaptureMetadataOutputObjectsDelegate {
    private let logger = Logger(subsystem: "com.llld.SeatFlow", category: "Camera")
    var onResult: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onStatus: ((String) -> Void)?
    var rotationAngle: CGFloat = 90
    var closesAfterResult = false
    var showsCloseButton = false

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.llld.seatflow.modal-camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastResult: (value: String, date: Date)?
    private var isClosing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        logger.info("Camera overlay loaded")
        if showsCloseButton {
            addCloseButton()
        }
        requestCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        configurePreviewConnection()
    }

    private func configurePreviewConnection() {
        guard let connection = previewLayer?.connection else {
            return
        }
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    func setRotationAngle(_ angle: CGFloat) {
        rotationAngle = angle
        configurePreviewConnection()
    }

    private func addCloseButton() {
        let button = UIButton(type: .system)
        button.setTitle("閉じる", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            button.widthAnchor.constraint(equalToConstant: 76),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc private func closeButtonTapped() {
        close()
    }

    private func requestCameraAccess() {
        logger.info("Checking camera authorization")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.info("Camera authorization already granted")
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.logger.info("Camera authorization granted")
                        self?.configureCamera()
                    } else {
                        self?.logger.error("Camera authorization denied")
                        self?.showCameraError("カメラの使用が許可されていません。")
                    }
                }
            }
        default:
            logger.error("Camera authorization is unavailable")
            showCameraError("設定アプリでSeatFlowのカメラ使用を許可してください。")
        }
    }

    private func configureCamera() {
        onStatus?("内カメラを準備中")
        logger.info("Starting camera configuration")
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard
                let camera = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .front
                ),
                let input = try? AVCaptureDeviceInput(device: camera)
            else {
                DispatchQueue.main.async {
                    self.logger.error("Front camera input creation failed")
                    self.showCameraError("内カメラを開始できませんでした。")
                }
                return
            }

            captureSession.beginConfiguration()
            captureSession.sessionPreset = .high

            guard captureSession.canAddInput(input) else {
                captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    self.logger.error("Front camera input could not be added")
                    self.showCameraError("内カメラを利用できませんでした。")
                }
                return
            }
            captureSession.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(output) else {
                captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    self.logger.error("Metadata output could not be added")
                    self.showCameraError("QRコード読取を開始できませんでした。")
                }
                return
            }

            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [
                .qr, .code128, .code39, .code93,
                .ean8, .ean13, .upce, .pdf417,
                .dataMatrix, .aztec, .itf14
            ].filter { output.availableMetadataObjectTypes.contains($0) }
            captureSession.commitConfiguration()

            DispatchQueue.main.async {
                let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                preview.videoGravity = .resizeAspectFill
                preview.frame = self.view.bounds
                self.view.layer.insertSublayer(preview, at: 0)
                self.previewLayer = preview
                self.configurePreviewConnection()
            }

            self.logger.info("Calling camera startRunning")
            captureSession.startRunning()
            DispatchQueue.main.async {
                self.logger.info("Camera startRunning completed")
                self.onStatus?("内カメラで読み取り中")
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = object.stringValue,
            !value.isEmpty
        else {
            return
        }

        if let lastResult,
           lastResult.value == value,
           Date().timeIntervalSince(lastResult.date) < 2 {
            return
        }
        lastResult = (value, Date())
        logger.info("Barcode result received")
        onResult?(value)
        if closesAfterResult {
            close()
        }
    }

    func close() {
        guard !isClosing else {
            return
        }
        isClosing = true
        logger.info("Closing camera overlay")
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
        onClose?()
    }

    private func showCameraError(_ message: String) {
        onStatus?("カメラを開始できません")
        let alert = UIAlertController(title: "カメラ", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "閉じる", style: .default) { [weak self] _ in
            self?.close()
        })
        present(alert, animated: true)
    }
}

#Preview {
    ContentView()
}
