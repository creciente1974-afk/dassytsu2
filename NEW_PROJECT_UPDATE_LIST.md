# 新しいFirebaseプロジェクト作成後の更新ファイル一覧

## 📋 更新が必要なファイル

新しいFirebaseプロジェクトを作成した後、以下のファイルを更新する必要があります：

### 1. `lib/main.dart`
- **更新箇所**: `FirebaseOptions` の各パラメータ
  - `apiKey`: 新しいWeb APIキー
  - `projectId`: 新しいプロジェクトID
  - `storageBucket`: 新しいStorage Bucket
  - `databaseURL`: 新しいDatabase URL

### 2. `lib/firebase_service.dart`
- **更新箇所**: クラスの定数
  - `_storageBucketURL`: 新しいStorage Bucket（`gs://` プレフィックス付き）
  - `_databaseURL`: 新しいDatabase URL

### 3. `macos/Runner/GoogleService-Info.plist`
- **更新方法**: Firebase Consoleから新しいファイルをダウンロードして置き換え
- **または手動更新**: `DATABASE_URL` キーの値を更新

### 4. `ios/Runner/GoogleService-Info.plist`（iOSアプリも使用する場合）
- **更新方法**: Firebase Consoleから新しいファイルをダウンロードして置き換え
- **または手動更新**: `DATABASE_URL` キーの値を更新

## 🔧 更新手順

### ステップ1: 新しいFirebaseプロジェクトの情報を取得

1. **Firebase Console** → **プロジェクトの設定** → **全般**
2. **以下の情報をコピー**:
   - **プロジェクトID**: 例 `dassyutsu2-new`
   - **Web APIキー**: 例 `AIzaSy...`
   - **Storage Bucket**: 例 `dassyutsu2-new.firebasestorage.app`
   - **Database URL**: 例 `https://dassyutsu2-new-default-rtdb.asia-southeast1.firebasedatabase.app`

### ステップ2: `lib/main.dart` を更新

```dart
final options = FirebaseOptions(
  apiKey: '新しいWeb APIキー', // ステップ1で取得
  appId: '1:245139907628:ios:e187581a13a65a02eddd89', // 既存のApp ID（新しいプロジェクトでmacOSアプリを追加した場合は新しいID）
  messagingSenderId: '245139907628', // 既存のSender ID（新しいプロジェクトでmacOSアプリを追加した場合は新しいID）
  projectId: '新しいプロジェクトID', // ステップ1で取得
  storageBucket: '新しいStorage Bucket', // ステップ1で取得
  databaseURL: '新しいDatabase URL', // ステップ1で取得
);
```

### ステップ3: `lib/firebase_service.dart` を更新

```dart
final String _storageBucketURL = "gs://新しいStorage Bucket"; // ステップ1で取得（gs://プレフィックス付き）
final String _databaseURL = "新しいDatabase URL"; // ステップ1で取得
```

### ステップ4: `macos/Runner/GoogleService-Info.plist` を更新

**方法A: 新しいファイルをダウンロード（推奨）**
1. **Firebase Console** → **プロジェクトの設定** → **全般**
2. **macOSアプリを追加**（まだ追加していない場合）
3. **`GoogleService-Info.plist`をダウンロード**
4. **`macos/Runner/GoogleService-Info.plist`に置き換え**

**方法B: 手動更新**
1. `macos/Runner/GoogleService-Info.plist` を開く
2. `DATABASE_URL` キーの値を新しいDatabase URLに更新

### ステップ5: アプリを再起動

```bash
flutter clean
flutter pub get
flutter run
```

## ⚠️ 重要な注意事項

- **新しいプロジェクトでmacOSアプリを追加した場合**: `appId` と `messagingSenderId` も新しい値に更新する必要があります
- **URLの末尾にスラッシュ（`/`）を付けない**: `https://...firebasedatabase.app`（正しい）
- **Storage Bucketには `gs://` プレフィックスを付ける**: `gs://dassyutsu2-new.firebasestorage.app`

## 📝 チェックリスト

新しいプロジェクトを作成した後：

- [ ] プロジェクトIDをメモ
- [ ] Web APIキーをメモ
- [ ] Storage Bucketをメモ
- [ ] Database URLをメモ
- [ ] macOSアプリを追加して `GoogleService-Info.plist` をダウンロード
- [ ] `lib/main.dart` を更新
- [ ] `lib/firebase_service.dart` を更新
- [ ] `macos/Runner/GoogleService-Info.plist` を更新
- [ ] `flutter clean && flutter pub get && flutter run` を実行
- [ ] 動作確認




