# SeatFlow iPad専用アプリ化 実装指示書

## 目的

既存の `SeatFlow_Studio_v32_iPad安定版.html` を利用して、iPad上で専用アプリのように起動・動作確認できる状態を作る。

まずは **App Store公開や社内配布設定の前段階** として、Xcodeから実機iPadへ直接インストールし、以下を確認する。

- iPadアプリとして起動できる
- 既存HTMLがアプリ内で表示できる
- 編集Studioと操作Boardを切り替えられる
- レイアウト作成・保存ができる
- JSONバックアップの導線が使える
- QR/バーコード運用の基本導線が壊れていない
- 将来的にネイティブカメラ読み取りへ拡張できる構成にする

---

## 前提

### 既にあるもの

- HTMLファイル  
  `SeatFlow_Studio_v32_iPad安定版.html`

### 使用する技術

- Xcode
- Swift
- SwiftUI
- WKWebView
- iPad実機
- Apple ID

### 今回の実装方針

今回の第一段階では、SeatFlow本体をSwiftで作り直さない。

既存HTMLをiPadアプリ内に同梱し、`WKWebView` で表示する。

```text
SeatFlow iPad App
├─ SwiftUIアプリ本体
├─ WKWebView
├─ 同梱HTML
│  └─ index.html
└─ iPad実機で動作確認
```

---

## 完成イメージ

iPadのホーム画面から `SeatFlow` アプリを起動すると、アプリ内でSeatFlowのHTML画面が開く。

Safariではなく、専用アプリとして起動する。

ただし、初期段階ではカメラ読み取りはWebView内のHTML側機能に依存する。  
もしWebView内でカメラやバーコード検出が不安定な場合は、次フェーズでSwift側のネイティブカメラ読み取りを実装する。

---

# Step 1. Xcodeプロジェクトを作成する

## 1-1. 新規プロジェクト作成

Xcodeを開き、以下の手順で新規プロジェクトを作成する。

```text
File
→ New
→ Project
→ iOS
→ App
```

設定は以下。

```text
Product Name: SeatFlow
Team: 自分のApple ID / Personal Team
Organization Identifier: com.llld
Bundle Identifier: com.llld.seatflow
Interface: SwiftUI
Language: Swift
Storage: None
```

保存先は任意。例：

```text
~/Desktop/SeatFlow-iPad-App
```

---

# Step 2. HTMLファイルをアプリに同梱する

## 2-1. HTMLファイル名を変更する

既存のHTMLファイルを以下の名前に変更する。

```text
index.html
```

元ファイル名：

```text
SeatFlow_Studio_v32_iPad安定版.html
```

変更後：

```text
index.html
```

## 2-2. Xcodeに追加する

`index.html` をXcodeのプロジェクトナビゲータにドラッグ&ドロップする。

追加時の設定：

```text
Copy items if needed: チェック
Add to targets: SeatFlow にチェック
```

---

# Step 3. WKWebViewでHTMLを表示する

## 3-1. ContentView.swiftを差し替える

`ContentView.swift` を以下に差し替える。

```swift
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

        let websiteDataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = websiteDataStore

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            let folderURL = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: folderURL)
        } else {
            let fallbackHTML = """
            <html>
            <body style="font-family:-apple-system;padding:24px;">
            <h1>SeatFlow</h1>
            <p>index.html がアプリに含まれていません。</p>
            <p>Xcodeで index.html を Add to targets: SeatFlow に追加してください。</p>
            </body>
            </html>
            """
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
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
```

---

# Step 4. カメラ権限を追加する

QR/バーコード読み取りや将来のネイティブカメラ化に備えて、`Info.plist` にカメラ利用目的を追加する。

## 4-1. Info.plistを開く

Xcodeのプロジェクト設定から `Info` を開く。

または `Info.plist` を直接編集する。

## 4-2. 以下を追加する

```text
Privacy - Camera Usage Description
```

値：

```text
座席登録用のQRコード・バーコードを読み取るためにカメラを使用します。
```

XMLで直接書く場合は以下。

```xml
<key>NSCameraUsageDescription</key>
<string>座席登録用のQRコード・バーコードを読み取るためにカメラを使用します。</string>
```

---

# Step 5. iPad横画面を基本にする

SeatFlowは座席レイアウトを扱うため、基本は横画面が望ましい。

## 5-1. TARGETSの設定

Xcodeで以下を開く。

```text
Project
→ TARGETS SeatFlow
→ General
→ Deployment Info
```

`Device Orientation` を以下にする。

```text
Portrait: OFF
Upside Down: OFF
Landscape Left: ON
Landscape Right: ON
```

これでiPad横画面中心の運用にする。

---

# Step 6. 実機iPadで起動確認する

## 6-1. iPadをMacに接続する

USB-CまたはLightningケーブルでiPadをMacに接続する。

iPad側で「このコンピュータを信頼しますか？」が出たら、信頼する。

## 6-2. Xcodeの実行先をiPadにする

Xcode上部の実行先から接続中のiPadを選択する。

## 6-3. Runする

Xcodeで以下を押す。

```text
▶ Run
```

初回ビルドで署名エラーが出る場合は、Xcodeの `Signing & Capabilities` でTeamを選び直す。

---

# Step 7. iPad側で開発元を信頼する

初回起動時にアプリが開けない場合は、iPadで以下を確認する。

```text
設定
→ 一般
→ VPNとデバイス管理
→ 開発元アプリ
→ 信頼
```

その後、再度アプリを起動する。

---

# Step 8. 動作確認項目

以下を順番に確認する。

## 8-1. 起動確認

- SeatFlowアプリが起動する
- 白画面にならない
- `index.html がアプリに含まれていません` と表示されない
- SeatFlowのトップバーが表示される

## 8-2. 画面表示

- 編集Studioが表示される
- 操作Boardに切り替えられる
- 右パネルがiPad画面内に収まる
- 横画面で操作しやすい
- 座席レイアウトが表示される

## 8-3. 編集Studio

- 座席を追加できる
- 机・棚・面談室などを追加できる
- オブジェクトを移動できる
- サイズ変更できる
- 座席登録可/不可が切り替えられる
- レイアウト保存できる

## 8-4. 操作Board

- 座席をタップして状態変更できる
- 利用者名を入力できる
- 名簿から利用者を選べる
- 使用中・予約・面談・離席に切り替えられる
- 空席に戻せる

## 8-5. 保存

- アプリを閉じて再起動してもレイアウトが残る
- 名簿が残る
- 座席状態が残る
- JSONバックアップを書き出せる
- JSONバックアップを読み込める

## 8-6. カメラ・QR

初期段階では以下を確認する。

- カメラ開始ボタンを押してもアプリが落ちない
- 権限ダイアログが出る
- 許可/拒否後に画面が崩れない
- 読み取り非対応でも手入力運用に戻れる
- 外付けバーコードリーダーで入力欄にコードが入る

---

# Step 9. 想定されるエラーと対応

## 9-1. index.htmlが表示されない

原因：

- HTMLファイルがXcodeターゲットに入っていない
- ファイル名が `index.html` ではない
- Bundleに含まれていない

対応：

- Xcodeで `index.html` を選択
- 右側のFile Inspectorを開く
- `Target Membership` の `SeatFlow` にチェックを入れる

---

## 9-2. 白画面になる

原因：

- HTML内JavaScriptのエラー
- WKWebViewでfile URLから一部機能が制限されている
- 外部ファイル参照が切れている

対応：

- MacのSafariでWeb Inspectorを有効化
- iPadを接続
- Safariの開発メニューから対象WebViewを確認
- Consoleエラーを確認する

---

## 9-3. カメラが動かない

原因：

- `NSCameraUsageDescription` がない
- WKWebView内でカメラAPIが制限されている
- HTML側のBarcodeDetectorがWebViewで非対応
- file URL上でカメラAPIが制限されている

対応：

第一段階では、アプリが落ちないことを優先する。  
カメラ読み取りが不安定な場合は、次フェーズでSwift側のネイティブカメラ読み取りへ移行する。

---

## 9-4. 保存されない

原因：

- WKWebViewのlocalStorageが想定通り保持されていない
- アプリ再インストールでデータが消えている
- iOS側のWebViewデータがリセットされた

対応：

- まずは自動保存の動作を確認
- 重要なレイアウトはJSONバックアップで保存
- 次フェーズでSwift側のファイル保存に移行する

---

# Step 10. 次フェーズ：ネイティブQR/バーコード読み取り

WKWebView内のカメラ読み取りが不安定な場合、Swift側でネイティブカメラを実装する。

構成は以下。

```text
Swiftネイティブカメラ
↓
QR/バーコード読み取り
↓
読み取ったコードをJavaScriptへ渡す
↓
SeatFlow HTML側の scanInput に反映
↓
既存の applyScan 処理を実行
```

## 10-1. HTML側に受け口を追加する案

HTML側に以下のような関数を追加する。

```javascript
window.seatflowReceiveCode = function(code){
  const input = document.getElementById("scanInput");
  if(input){
    input.value = code;
    const ev = new KeyboardEvent("keydown", {key:"Enter"});
    input.dispatchEvent(ev);
  }
};
```

Swift側から以下のように呼ぶ。

```swift
webView.evaluateJavaScript("window.seatflowReceiveCode('\(code)')")
```

これにより、Swiftで読み取ったQR/バーコードをHTML側へ渡せる。

---

# Step 11. 次フェーズ：JSONバックアップをネイティブ保存にする

将来的には、HTMLのダウンロード処理ではなく、Swift側にJSONを渡してiPadのファイルとして保存する。

構成案：

```text
HTML
↓
現在のSeatFlowデータをJSON化
↓
SwiftへpostMessage
↓
Swift側でFiles Appへ保存
```

WKScriptMessageHandlerを使う。

---

# Step 12. 今回のゴール

今回のゴールは以下。

- Xcodeプロジェクトが作成されている
- `index.html` がアプリに同梱されている
- iPad実機でSeatFlowアプリが起動する
- 編集Studioが使える
- 操作Boardが使える
- 保存動作が確認できる
- カメラは最低限、落ちないことを確認する
- カメラが不安定な場合は、ネイティブ化の課題として切り分ける

---

# 最終チェックリスト

```text
[ ] Xcodeプロジェクト SeatFlow を作成した
[ ] Bundle Identifier を com.llld.seatflow にした
[ ] index.html をプロジェクトに追加した
[ ] Add to targets にチェックした
[ ] ContentView.swift をWKWebView版に差し替えた
[ ] Info.plist に NSCameraUsageDescription を追加した
[ ] 横画面設定にした
[ ] iPadをMacに接続した
[ ] XcodeからRunできた
[ ] iPadで開発元を信頼した
[ ] SeatFlowが表示された
[ ] 編集Studioが動いた
[ ] 操作Boardが動いた
[ ] 保存が動いた
[ ] JSONバックアップを確認した
[ ] カメラボタンでアプリが落ちないことを確認した
```

---

# Codex / 開発者への依頼文

以下の方針で、既存HTMLをiPad専用アプリとして動作確認できるXcodeプロジェクトを作成してください。

- 既存の `SeatFlow_Studio_v32_iPad安定版.html` を `index.html` としてアプリに同梱する
- SwiftUI + WKWebViewで `index.html` を表示する
- iPad横画面を基本にする
- カメラ権限 `NSCameraUsageDescription` を追加する
- 初期段階ではHTML側の機能をそのまま利用する
- カメラ読み取りが不安定な場合でもアプリ全体が落ちないようにする
- まずはXcodeからiPad実機に直接Runして動作確認できる状態をゴールにする
- App Store申請、Custom App配布、Ad Hoc配布は今回の範囲外
- 将来的にSwift側のネイティブQR/バーコード読み取りへ拡張しやすい構成にする
```
