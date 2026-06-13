import Foundation
import WebKit

/// Entry point for a future AVFoundation-based QR/barcode scanner.
final class NativeScannerBridge: NSObject, WKScriptMessageHandler {
    static let messageHandlerName = "nativeScanner"

    weak var webView: WKWebView?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName else {
            return
        }

        guard
            let body = message.body as? [String: Any],
            let action = body["action"] as? String,
            action == "scan"
        else {
            sendError("未対応のネイティブスキャナー要求です。")
            return
        }

        // The web app remains usable while native scanning is introduced later.
        sendError("ネイティブスキャナーは準備中です。現在は画面内の入力機能を利用してください。")
    }

    private func sendError(_ message: String) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: ["message": message]),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        let script = """
        window.dispatchEvent(new CustomEvent('seatflow-native-scanner-error', { detail: \(json) }));
        """
        webView?.evaluateJavaScript(script)
    }
}
