import SwiftUI
import WebKit

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

        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(
            context.coordinator.nativeScannerBridge,
            name: NativeScannerBridge.messageHandlerName
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        context.coordinator.nativeScannerBridge.webView = webView
        loadSeatFlow(in: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: NativeScannerBridge.messageHandlerName
        )
        coordinator.nativeScannerBridge.webView = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    private func loadSeatFlow(in webView: WKWebView) {
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            let folderURL = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: folderURL)
        } else {
            webView.loadHTMLString(Self.fallbackHTML, baseURL: nil)
        }
    }

    private static let fallbackHTML = """
    <!doctype html>
    <html lang="ja">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>SeatFlow</title>
    </head>
    <body style="font-family:-apple-system;padding:24px;">
      <h1>SeatFlow</h1>
      <p>index.html がアプリに含まれていません。</p>
      <p>Xcodeで index.html を Add to targets: SeatFlow に追加してください。</p>
    </body>
    </html>
    """

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let nativeScannerBridge = NativeScannerBridge()

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

        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            switch type {
            case .camera:
                decisionHandler(.prompt)
            default:
                decisionHandler(.deny)
            }
        }
    }
}
