# SeatFlow iPadアプリ専用版

2026年6月13日時点では、PC版HTMLとiPadアプリ版を分離して管理します。

## 現在の役割分担

- PC版: `../SeatFlow_Studio_v32_iPad安定版(1).html`
- iPad画面: `SeatFlow_iPad.html`
- iPadネイティブ処理: `Xcodeソース/ContentView.swift`
- 実際にXcodeで開くプロジェクト: `/Users/tetsuya/Desktop/SeatFlow/SeatFlow.xcodeproj`

PC版の元HTMLは今回変更していません。

## iPad版の設計

- 座席表示、編集Studio、操作Board、JSONデータ管理はHTML/JavaScriptが担当
- QR・バーコード読取はSwiftのAVFoundationだけが担当
- ファイル書き出しと共有画面はSwiftが担当
- HTMLからSwiftへの連絡は `window.webkit.messageHandlers.seatflow` に限定
- Webカメラ、外部カメラ画面、複数のQRライブラリは使用しない
- カメラの `startRunning()` と `stopRunning()` は専用キューで実行し、画面を固めない
- 二本指拡大はHTMLとWKWebViewの両方で無効化

## カメラの動作

1. 操作Boardで「カメラ開始」を押す
2. HTML画面の上にアプリ内カメラ画面が直接開く
3. iPadの内カメラでQR・バーコードを読む
4. 読取結果をHTMLへ返し、座席操作欄へ反映する

カメラはシミュレータでは確認できないため、実機iPadで最終確認します。

## 今後の統合方針

PC版とiPad版をすぐ同じHTMLへ戻すのではなく、まず安定動作を優先します。
将来は座席データ、JSON形式、状態更新ロジックだけを共通モジュール化し、
PC固有処理とiPad固有処理をそれぞれのアダプターに分ける構成が安全です。

## 実機確認項目

- 編集Studioと操作Boardを連続で切り替えても固まらない
- カメラ開始で黒いアプリ内カメラ画面と準備状況がすぐ表示される
- 内カメラの映像が表示される
- QR読取後に読取パネルが閉じ、値が入力される
- カメラを閉じた後もStudio・Boardを操作できる
- レイアウトとJSONを書き出せる
- アプリ再起動後も座席データが残る
