# 新しいFirebaseプロジェクトを作成する手順

## ⚠️ 注意事項

プロジェクトを作成し直すと、既存のデータが失われる可能性があります。重要なデータがある場合は、必ずバックアップを取ってください。

## 📋 手順

### ステップ1: 新しいFirebaseプロジェクトを作成

1. **Firebase Console** → **プロジェクトを追加**
2. **プロジェクト名を入力**（例: `dassyutsu2-new`）
3. **Google Analyticsの設定**（必要に応じて）
4. **「プロジェクトを作成」** をクリック

### ステップ2: Realtime Databaseを作成

1. **Firebase Console** → **Realtime Database**
2. **「データベースを作成」** をクリック
3. **設定を選択**
   - リージョン: `asia-southeast1`
   - モード: **テストモード**（開発用）
4. **「有効にする」** をクリック

### ステップ3: ルールを設定

1. **「ルール」タブをクリック**
2. **ルールを以下のように設定**

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

3. **「公開」ボタンをクリック**

### ステップ4: Authenticationを設定

1. **Firebase Console** → **Authentication** → **Sign-in method**
2. **「匿名」を有効にする**

### ステップ5: Storageを設定

1. **Firebase Console** → **Storage**
2. **「始める」** をクリック
3. **セキュリティルールを確認**（開発用は許可的な設定）

### ステップ6: アプリの設定ファイルを更新

1. **Firebase Console** → **プロジェクトの設定** → **全般**
2. **「アプリを追加」** → **macOS** を選択
3. **Bundle IDを入力**（既存のBundle IDを使用）
4. **`GoogleService-Info.plist`をダウンロード**
5. **`macos/Runner/GoogleService-Info.plist`を置き換え**

### ステップ7: アプリのコードを更新

`lib/main.dart`と`lib/firebase_service.dart`の以下の値を更新：

- `projectId`
- `apiKey`
- `appId`
- `messagingSenderId`
- `storageBucket`
- `databaseURL`

### ステップ8: アプリを再起動

```bash
flutter clean
flutter pub get
flutter run
```

## ⚠️ 重要な注意事項

- **既存のデータが失われる可能性があります**
- **既存のユーザーデータやイベントデータをバックアップしてください**
- **本番環境で使用している場合は、慎重に検討してください**




