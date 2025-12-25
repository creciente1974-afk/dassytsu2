# Firebase Console セキュリティルール設定ガイド

## ⚠️ 重要
Firebase Realtime DatabaseのURL（`https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/`）に直接アクセスしても、セキュリティルールは設定できません。
**Firebase Console**から設定する必要があります。

## 正しい手順

### ステップ1: Firebase Consoleにアクセス
1. ブラウザで [Firebase Console](https://console.firebase.google.com/) を開く
2. Googleアカウントでログイン（プロジェクト `dassyutsu2` の所有者アカウント）
3. プロジェクト一覧から **`dassyutsu2`** を選択

### ステップ2: Realtime Databaseに移動
1. 左側のメニューから **「構築」** セクションを展開
2. **「Realtime Database」** をクリック
   - もし「Realtime Database」が見つからない場合：
     - 「データベースの作成」をクリック
     - リージョン: `asia-southeast1` (Asia Pacific (Singapore)) を選択
     - モード: 「本番モード」を選択

### ステップ3: セキュリティルールタブを開く
1. Realtime Databaseの画面で、上部にタブが表示されます：
   - **データ**
   - **ルール** ← これをクリック
   - **使用量**
   - **バックアップ**

### ステップ4: ルールを設定
1. 「ルール」タブをクリック
2. エディタに以下のルールをコピー＆ペースト：

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

**または、プロジェクト内の `firebase-database-rules.json` ファイルの内容をコピー**

### ステップ5: ルールを公開
1. ルールを入力したら、エディタの下部にある **「公開」** ボタンをクリック
2. 確認ダイアログが表示されたら **「公開」** をクリック
3. 「ルールが正常に公開されました」というメッセージが表示されるのを確認

### ステップ6: ルールの確認
1. エディタに設定したルールが表示されているか確認
2. エラーメッセージが表示されていないか確認（エディタ下部）
3. ルールが正しく保存されているか確認

## トラブルシューティング

### ルールを設定してもエラーが続く場合

1. **ルールが正しく公開されているか確認**
   - 「ルール」タブで現在のルール内容を確認
   - 「公開」ボタンを再度クリック

2. **データベースのリージョンを確認**
   - データベースURL: `https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/`
   - リージョンが `asia-southeast1` であることを確認

3. **一時的にすべて許可するルールでテスト**
   ```json
   {
     "rules": {
       ".read": true,
       ".write": true
     }
   }
   ```
   このルールで動作するか確認してください。

4. **ブラウザのキャッシュをクリア**
   - Firebase Consoleのページをリロード
   - ブラウザのキャッシュをクリアして再度確認

## 確認方法

ルールが正しく設定されているか確認するには：

1. Firebase Console → Realtime Database → ルールタブ
2. エディタに設定したルールが表示されているか確認
3. エラーメッセージがないか確認

## 次のステップ

ルールを設定した後：
1. 数秒待つ（ルールの反映に時間がかかる場合があります）
2. Flutterアプリを再起動（Hot Restart: `R` キー）
3. イベント一覧が表示されるか確認




