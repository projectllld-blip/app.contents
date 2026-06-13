# SeatFlow Studio - PWA版

座席配置の編集、QR/バーコード登録、名簿管理ができるシステムです。

## 特徴

- **PWA (Progressive Web App)**: インストール不要で、ホーム画面に追加してアプリのように使用できます
- **オフライン対応**: インターネットに接続していなくても基本機能が使用できます
- **キャッシュ自動管理**: 自動更新チェック機能で常に最新版を利用できます
- **相対パス対応**: GitHub Pages のサブパスでも動作します

---

## GitHub Pages への公開手順

### 1. リポジトリ設定

1. GitHub リポジトリのルートディレクトリに `座席管理` フォルダをコミット・プッシュします
2. リポジトリの **Settings** → **Pages** を開きます
3. **Build and deployment** セクションで以下を設定します:
   - **Source**: `Deploy from a branch`
   - **Branch**: `main` → `/ (root)` を選択して **Save**

### 2. フォルダ構成

GitHub Pages 公開時は、以下の構成をリポジトリルートに配置してください:

```
your-repo/
├── 座席管理/          ← このフォルダ全体が公開対象
│   ├── index.html
│   ├── manifest.webmanifest
│   ├── service-worker.js
│   ├── .nojekyll
│   ├── icons/
│   │   ├── icon-192.png
│   │   ├── icon-256.png
│   │   ├── icon-384.png
│   │   ├── icon-512.png
│   │   └── screenshot-540x720.png
│   ├── SeatFlow/
│   └── SeatFlow_iPadアプリ専用/
└── (その他のファイル)
```

### 3. 公開 URL

リポジトリ名が `repo-name` の場合:

```
https://ユーザー名.github.io/repo-name/座席管理/
```

---

## iPad Safari でホーム画面に追加する手順

### 1. Safari を開く

iPad の Safari で以下の URL にアクセスします:

```
https://ユーザー名.github.io/repo-name/座席管理/
```

### 2. 共有ボタンをタップ

画面下の共有ボタン（矢印が上向き）をタップします

### 3. 「ホーム画面に追加」を選択

スクロールして「ホーム画面に追加」を探し、タップします

### 4. 名前を確認して追加

ポップアップに「SeatFlow」と表示されます。「追加」をタップします

### 5. ホーム画面から起動

iPad のホーム画面に「SeatFlow」アイコンが追加されます。
タップするとアプリのようにフルスクリーンで起動します。

---

## アップデート手順

### バージョンを更新する場合

#### 1. index.html を編集

`index.html` 内の以下の箇所でバージョン番号を変更します:

```javascript
const APP_VERSION = '1.0.5';  // ← このバージョン番号を更新
```

#### 2. service-worker.js を編集

`service-worker.js` 内の以下の箇所でキャッシュバージョンを変更します:

```javascript
const CACHE_VERSION = 'seatflow-pwa-v6';  // ← vの後ろの数字を更新
```

#### 3. 変更をコミット・プッシュ

```bash
git add .
git commit -m "Update SeatFlow to v1.0.1"
git push origin main
```

#### 4. GitHub Pages が自動更新

GitHub Pages は 1～2 分で自動的に新しいバージョンをデプロイします。

---

## iPad Safari で「更新確認」ボタンを表示

ユーザーが新しいバージョンが利用可能であることに気づくように、以下の手順を実施します:

### 1. 新しいバージョンをデプロイした場合

アプリを開いている状態で、新しいバージョンが利用可能になると、右下に「アプリの新しいバージョンが利用可能です」という通知が表示されます。

### 2. 手動で更新を確認したい場合

ブラウザのコンソール（F12 → Console）で以下を実行:

```javascript
navigator.serviceWorker.getRegistrations().then(regs => {
  regs.forEach(reg => reg.update());
});
```

---

## キャッシュが古い時の対処法

### キャッシュをリセットする方法

#### 方法 1: ブラウザ設定から

1. Safari を開き、設定を確認します（iPad の設定アプリ → Safari）
2. 「履歴とサイトデータを消去」をタップしてキャッシュをクリアします
3. アプリを再度開きます

#### 方法 2: JavaScript コンソールから

ブラウザのコンソール（F12 → Console）で以下を実行:

```javascript
window.clearSeatFlowCache();
```

#### 方法 3: アプリを再インストール

1. ホーム画面から SeatFlow アイコンを長押しして削除します
2. Safari でもう一度ホーム画面に追加します

---

## ローカルでの起動確認手順

### 1. Python の簡易サーバーを起動

```bash
cd '/Users/tetsuya/川岡哲也専用　AI軍団/03_塾事業/座席管理'
python3 -m http.server 8000
```

### 2. ブラウザで確認

```
http://localhost:8000/
```

### 3. Service Worker を確認

1. ブラウザの F12 キーを押して開発者ツールを開きます
2. **Application** タブ → **Service Workers** を確認
3. `service-worker.js` が登録されていることを確認

---

## トラブルシューティング

### アプリが起動しない場合

1. **キャッシュをクリア**: 上記の「キャッシュが古い時の対処法」を参照
2. **HTTPS を確認**: GitHub Pages は HTTPS で配信されているため、HTTP では PWA 機能が動作しません
3. **ブラウザのコンソールを確認**: F12 → Console で エラーメッセージを確認

### QR/バーコード読み込みが動作しない場合

1. **カメラの許可**: ブラウザがカメラアクセスを許可しているか確認
2. **HTTPS 接続**: PWA のカメラ機能は HTTPS でのみ動作します
3. **html5-qrcode ライブラリ**: CDN からの読み込みが失敗していないか確認

---

## ファイル説明

| ファイル | 説明 |
|---------|------|
| `index.html` | メインアプリケーション（PWA 対応版） |
| `manifest.webmanifest` | PWA メタデータ（アプリ名、アイコン等） |
| `service-worker.js` | オフライン対応とキャッシュ管理 |
| `.nojekyll` | GitHub Pages でのJekyllビルドをスキップ |
| `icons/` | PWA アイコンとスクリーンショット格納フォルダ |
| `SeatFlow/` | 座席表設定・レイアウト管理フォルダ |
| `SeatFlow_iPadアプリ専用/` | iPad ネイティブアプリ関連ファイル |

---

## バージョン情報

- **SeatFlow Studio v31**: 基本機能
- **PWA対応**: v1.0.5
- **最終更新**: 2026年6月13日

---

## 技術スタック

- **HTML5 / CSS3 / JavaScript**
- **Service Worker**: オフライン対応
- **Web App Manifest**: PWA メタデータ
- **html5-qrcode**: QR/バーコード読み込み
- **GitHub Pages**: ホスティング

---

## サポート

問題が発生した場合は、コンソールのエラーメッセージを確認し、上記の「トラブルシューティング」を参照してください。
