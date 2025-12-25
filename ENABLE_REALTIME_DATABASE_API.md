# Firebase Realtime Database API の有効化

## 🔍 問題

「Firebase Realtime Database API」を検索しても結果が見つからない場合、このAPIが有効になっていない可能性があります。

## ✅ 解決方法: Firebase Realtime Database API を有効化

### ステップ1: 有効なAPIとサービスを確認

1. Google Cloud Console → `dassyutsu2` プロジェクト
2. 「API とサービス」→ 「有効なAPIとサービス」をクリック
3. 「Firebase Realtime Database API」が有効になっているか確認

### ステップ2: Firebase Realtime Database API を有効化

「Firebase Realtime Database API」が有効になっていない場合：

1. Google Cloud Console → `dassyutsu2` プロジェクト
2. 「API とサービス」→ 「ライブラリ」をクリック
3. 検索バーで「Firebase Realtime Database API」を検索
4. 「Firebase Realtime Database API」をクリック
5. 「有効にする」ボタンをクリック
6. 有効化が完了するまで待つ（数秒かかる場合があります）

### ステップ3: APIキーの制限を更新

APIを有効化した後、APIキーの制限を更新：

1. 「API とサービス」→ 「認証情報」をクリック
2. 使用しているAPIキーをクリック
3. 「API の制限」セクションで「キーを制限」が選択されていることを確認
4. 「API を選択」またはドロップダウンをクリック
5. 「Firebase Realtime Database API」を検索して追加
6. 「保存」をクリック

### ステップ4: 一時的に制限を解除してテスト（代替方法）

APIを有効化する前に、問題を切り分けるため、一時的にAPIキーの制限を解除してテスト：

1. APIキーの編集ページで「API の制限」セクションを開く
2. 「キーを制限しない」を選択
3. 「保存」をクリック
4. アプリを再起動してテスト

**注意**: 本番環境では、必要最小限のAPIのみを許可する制限を設定してください。

## 📋 チェックリスト

- [ ] 「有効なAPIとサービス」で「Firebase Realtime Database API」が有効か確認
- [ ] 無効な場合、「ライブラリ」から「Firebase Realtime Database API」を有効化
- [ ] APIキーの制限に「Firebase Realtime Database API」を追加
- [ ] または、一時的に「キーを制限しない」に設定してテスト
- [ ] アプリを再起動して動作を確認

## 💡 重要なポイント

- 「Firebase Realtime Database Management API」は管理用のAPIです
- アプリがデータベースにアクセスするには「Firebase Realtime Database API」が必要です
- このAPIが有効になっていない場合、APIキーの制限リストに表示されません




