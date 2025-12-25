# 認証ベースのルール設定

## 🔍 現在の状況

- ✅ REST APIで直接アクセス可能（ルールは正しく設定されている）
- ✅ 匿名認証を追加済み
- ❌ Firebase SDKからアクセスできない（`permission-denied` エラー）
- ❌ 「Firebase Realtime Database API」が検索結果に出ない

## 💡 解決方法: 認証ベースのルールに変更

Firebase Realtime Databaseのルールを認証を要求する形に変更し、匿名認証を使用します。

### ステップ1: Firebase Consoleでルールを変更

1. **Firebase Console** → **Realtime Database** → **ルール**タブ
2. **ルールを以下のように変更**

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

3. **「公開」ボタンをクリック**

### ステップ2: アプリを再起動

```bash
flutter run
```

### ステップ3: ログを確認

- `✅ [main] 匿名認証成功: ...` が表示されるか
- `✅ [FirebaseService] ルートパスへのアクセス成功` が表示されるか
- `permission-denied` エラーが解消されたか

## 📋 確認チェックリスト

- [ ] Firebase Consoleでルールを認証ベースに変更
- [ ] 「公開」ボタンをクリック
- [ ] アプリを再起動
- [ ] ログで匿名認証が成功したか確認
- [ ] `permission-denied` エラーが解消されたか確認

## 💡 重要なポイント

- **認証ベースのルール** (`auth != null`) を使用すると、匿名認証を含むすべての認証済みユーザーがアクセスできます
- **匿名認証**を使用すると、認証トークンが自動的にFirebase Realtime Databaseに送信されます
- **REST APIで直接アクセスできた** → ルールは正しく設定されていますが、Firebase SDKが認証トークンを使用していない可能性があります




