# 有効なAPIとサービスの確認

## ✅ 確認済み

- APIキーの制限を解除済み（「キーを制限しない」に設定）

## 🔍 次の確認事項

### Firebase Realtime Database APIが有効か確認

1. Google Cloud Console → `dassyutsu2` プロジェクト
2. 「API とサービス」→ 「有効なAPIとサービス」をクリック
3. 検索バーで「Firebase Realtime Database API」を検索
4. 「Firebase Realtime Database API」が有効になっているか確認

### 有効になっていない場合

1. 「API とサービス」→ 「ライブラリ」をクリック
2. 検索バーで「Firebase Realtime Database API」を検索
3. 「Firebase Realtime Database API」をクリック
4. 「有効にする」ボタンをクリック
5. 有効化が完了するまで待つ（数秒かかる場合があります）

## 📋 確認チェックリスト

- [ ] 「有効なAPIとサービス」で「Firebase Realtime Database API」を検索
- [ ] 「Firebase Realtime Database API」が有効になっているか確認
- [ ] 無効な場合、「ライブラリ」から有効化
- [ ] 有効化後、アプリを再起動

## 💡 重要なポイント

- APIキーの制限を解除しても、「Firebase Realtime Database API」が有効になっていない場合、アクセスできない可能性があります
- 「Firebase Realtime Database Management API」とは異なります
- アプリがデータベースにアクセスするには「Firebase Realtime Database API」が必要です




