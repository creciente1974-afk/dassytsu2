# 新しいFirebaseプロジェクト作成 - クイックガイド

## 📋 手順

### 1. Firebaseプロジェクトを作成
- Firebase Console → プロジェクトを追加
- プロジェクト名を入力（例: `dassyutsu2-new`）
- 作成完了を待つ

### 2. Realtime Databaseを作成
- Realtime Database → データベースを作成
- リージョン: `asia-southeast1`
- モード: **テストモード**
- ルール: `.read: true, .write: true` に設定して公開

### 3. Firestoreのルールを設定（エラー回避のため）
- Firestore Database → データベースを作成（まだの場合）
- ルール: `allow read, write: if true;` に設定して公開

### 4. Authenticationを設定
- Authentication → Sign-in method → 匿名認証を有効化

### 5. Storageを設定
- Storage → 始める → セキュリティルールを確認

### 6. macOSアプリを追加
- プロジェクトの設定 → アプリを追加 → macOS
- Bundle ID: `com.example.myFlutterProject`
- `GoogleService-Info.plist` をダウンロード
- `macos/Runner/GoogleService-Info.plist` に置き換え

### 7. プロジェクト情報を取得
- プロジェクトの設定 → 全般 から以下をコピー：
  - **プロジェクトID**
  - **Web APIキー**
  - **Storage Bucket**
  - **Database URL**

## ⚠️ 重要な情報

新しいプロジェクトの情報を取得したら、以下の値を共有してください：

1. **プロジェクトID**: `dassyutsu2-new`（例）
2. **Web APIキー**: `AIzaSy...`（新しいキー）
3. **Storage Bucket**: `dassyutsu2-new.firebasestorage.app`（例）
4. **Database URL**: `https://dassyutsu2-new-default-rtdb.asia-southeast1.firebasedatabase.app`（例）
5. **App ID**: macOSアプリを追加した場合の新しいApp ID（例: `1:xxxxx:macos:xxxxx`）
6. **Messaging Sender ID**: 新しいプロジェクトのSender ID

これらの情報を共有いただければ、コードを更新します。




