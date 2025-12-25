# Firebase Realtime Database セキュリティルール設定

## ⚠️ 重要: このエラーを解決するには、Firebase Consoleでセキュリティルールを設定する必要があります

## 問題
現在、Firebase Realtime Databaseへのアクセスが`permission-denied`エラーで拒否されています。
これは、Firebase Realtime Databaseのセキュリティルールがデフォルトで「すべて拒否」に設定されているためです。

## 解決方法（ステップバイステップ）

### ステップ1: Firebase Consoleにアクセス
1. ブラウザで [Firebase Console](https://console.firebase.google.com/) を開く
2. Googleアカウントでログイン（プロジェクト `dassyutsu2` の所有者アカウント）
3. プロジェクト一覧から **`dassyutsu2`** を選択

### ステップ2: Realtime Databaseに移動
1. 左側のメニューから **「Realtime Database」** をクリック
   - もし「Realtime Database」が見つからない場合：
     - 左メニューの「構築」セクションを展開
     - 「Realtime Database」を探す
2. データベースが作成されていない場合は「データベースの作成」をクリック
   - リージョン: `asia-southeast1` (Asia Pacific (Singapore)) を選択
   - モード: 「本番モード」または「テストモード」を選択（テストモードは一時的にすべて許可）

### ステップ3: セキュリティルールを設定
1. Realtime Databaseの画面で、上部のタブから **「ルール」** をクリック
2. エディタに以下のルールをコピー＆ペースト（開発用）

```json
{
  "rules": {
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

**または、このファイルをコピー**: `firebase-database-rules.json` の内容をそのまま使用できます。

### ステップ4: ルールを公開
1. ルールを入力したら、エディタの下部にある **「公開」** ボタンをクリック
2. 確認ダイアログが表示されたら **「公開」** をクリック
3. 「ルールが正常に公開されました」というメッセージが表示されるのを確認

### ステップ5: アプリを再起動
1. Flutterアプリを再起動（Hot Restart: `R` キーを押す、またはアプリを完全に再起動）
2. イベント一覧が表示されることを確認

## トラブルシューティング

### ルールを設定してもエラーが続く場合
1. Firebase Consoleでルールが正しく保存されているか確認
2. ブラウザのキャッシュをクリアして再度確認
3. Firebase Consoleの「ルール」タブで、現在のルール内容を確認

### データベースが見つからない場合
- データベースが作成されていない可能性があります
- 「Realtime Database」画面で「データベースの作成」をクリック
- リージョンは `asia-southeast1` を選択（既存のデータベースURLと一致させる）

## 本番環境用のセキュリティルール（推奨）

本番環境では、より厳格なルールを設定することを推奨します：

```json
{
  "rules": {
    "events": {
      ".read": true,
      ".write": "auth != null"
    },
    "team_progress": {
      "$teamId": {
        "$eventId": {
          ".read": true,
          ".write": true
        }
      }
    },
    "teams": {
      "$eventId": {
        ".read": true,
        ".write": true
      }
    },
    "escape_records": {
      "$eventId": {
        ".read": true,
        ".write": true
      }
    },
    "passcodes": {
      ".read": false,
      ".write": false
    }
  }
}
```

### 4. ルールを公開
1. 「公開」ボタンをクリック
2. 確認ダイアログで「公開」を選択

## 注意事項
- 開発用のルール（`.read: true, .write: true`）は、すべてのユーザーが読み書きできるため、本番環境では使用しないでください
- 本番環境では、認証（Authentication）を有効にして、適切な権限管理を行うことを推奨します

