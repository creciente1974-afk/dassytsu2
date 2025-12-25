# Firebase Realtime Database セキュリティルール テスト手順

## 🚨 現在の状況

ログを見ると、依然として `permission-denied` エラーが発生しています。

```
❌ [FirebaseService] Firebase読み込みエラー: [firebase_database/permission-denied] Client doesn't have permission to access the desired data.
```

## ✅ 最もシンプルなルールでテスト

まず、**すべての読み書きを許可する最もシンプルなルール**でテストしてください。

### ステップ1: Firebase Consoleでルールを設定

1. Firebase Console → **`dassyutsu2`** プロジェクトを選択
2. 「Realtime Database」をクリック
3. データベースインスタンスの一覧を確認
4. **`dassyutsu2-default-rtdb` (asia-southeast1)** のインスタンスを選択
5. 「ルール」タブをクリック
6. 以下の**最もシンプルなルール**をコピー＆ペースト：

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

7. 「公開」ボタンをクリック
8. 「公開済み」と表示されるまで待つ（数秒かかる場合があります）

### ステップ2: アプリを再起動

1. アプリを完全に終了
2. `flutter clean` を実行（オプション）
3. `flutter run` で再起動

### ステップ3: ログを確認

アプリを実行して、以下のログを確認してください：

```
✅ [FirebaseService] ルートパスへのアクセス成功
```

このログが表示されれば、ルールが正しく設定されています。

## 🔍 トラブルシューティング

### 問題1: ルールを公開してもエラーが続く

**確認事項**:
1. 正しいデータベースインスタンスのルールを設定しているか
   - URL: `https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/`
   - インスタンス名: `dassyutsu2-default-rtdb`
   - リージョン: `asia-southeast1`

2. ルールの構文が正しいか
   - JSON構文エラーがないか
   - カンマや括弧が正しく閉じられているか

3. ルールが「公開済み」になっているか
   - 「未公開の変更があります」と表示されていないか
   - 「公開」ボタンを再度クリック

### 問題2: 複数のデータベースインスタンスがある

Firebase Realtime Databaseでは、複数のデータベースインスタンスを作成できます。

**確認手順**:
1. Firebase Console → `dassyutsu2` プロジェクト
2. 「Realtime Database」をクリック
3. データベースインスタンスの一覧を確認
4. **すべてのインスタンス**のルールを確認
5. アプリが接続しているインスタンス（`dassyutsu2-default-rtdb`）のルールを設定

### 問題3: ルールの反映に時間がかかる

セキュリティルールの変更は、**数秒から数分**かかって反映される場合があります。

**対処法**:
1. ルールを公開
2. 1-2分待つ
3. アプリを再起動
4. 再度試す

## 📋 チェックリスト

- [ ] Firebase Consoleで **`dassyutsu2`** プロジェクトを選択
- [ ] 「Realtime Database」→ **`dassyutsu2-default-rtdb` (asia-southeast1)** のインスタンスを選択
- [ ] 「ルール」タブで最もシンプルなルール（`.read: true, .write: true`）を設定
- [ ] 「公開」ボタンをクリック
- [ ] 「公開済み」と表示されるまで待つ
- [ ] アプリを完全に再起動
- [ ] ログで「✅ [FirebaseService] ルートパスへのアクセス成功」が表示されるか確認

## 💡 次のステップ

最もシンプルなルールで動作することを確認したら、必要なパスごとにルールを追加：

```json
{
  "rules": {
    ".read": true,
    ".write": true,
    "events": {
      ".read": true,
      ".write": true
    },
    "team_progress": {
      ".read": true,
      ".write": true
    },
    "teams": {
      ".read": true,
      ".write": true
    },
    "escape_records": {
      ".read": true,
      ".write": true
    },
    "passcodes": {
      ".read": false,
      ".write": false
    }
  }
}
```




