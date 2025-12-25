# テスト環境データベースURL確認

## 🔍 現在の状況

### 現在のコードで使用しているデータベースURL
- **URL**: `https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/`
- **設定場所**:
  - `lib/firebase_service.dart` (line 31)
  - `lib/main.dart` (line 30)
  - `ios/Runner/GoogleService-Info.plist` (line 30)
  - `macos/Runner/GoogleService-Info.plist` (line 30)
  - `android/app/google-services.json` (line 4)

## ⚠️ 問題の可能性

Firebase Realtime Databaseでは、**複数のデータベースインスタンス**を作成できます：
- **デフォルトインスタンス**: `https://{project-id}-default-rtdb.{region}.firebasedatabase.app/`
- **追加インスタンス**: `https://{project-id}-{instance-name}-rtdb.{region}.firebasedatabase.app/`

**テスト環境で公開**している場合、以下の可能性があります：
1. テスト環境用の別のデータベースインスタンスを使用している
2. テスト環境のデータベースURLが現在のコードと異なる

## ✅ 確認手順

### 1. Firebase Consoleでテスト環境のデータベースURLを確認

1. Firebase Console → **`dassyutsu2`** プロジェクトを選択
2. 「Realtime Database」をクリック
3. データベースインスタンスの一覧を確認
4. **テスト環境のデータベースインスタンス**を選択
5. データベースURLを確認（例：`https://dassyutsu2-test-rtdb.asia-southeast1.firebasedatabase.app/`）

### 2. テスト環境のデータベースURLが異なる場合

テスト環境のデータベースURLが現在のコードと異なる場合、以下のいずれかの対応が必要です：

#### オプションA: コードをテスト環境のURLに更新（一時的）
- `lib/firebase_service.dart` の `_databaseURL` をテスト環境のURLに変更
- `lib/main.dart` の `databaseURL` をテスト環境のURLに変更

#### オプションB: 環境変数で切り替え（推奨）
- 環境変数や設定ファイルを使って、テスト環境と本番環境を切り替えられるようにする

## 📋 確認チェックリスト

- [ ] Firebase Consoleで `dassyutsu2` プロジェクトを選択
- [ ] 「Realtime Database」でデータベースインスタンスの一覧を確認
- [ ] テスト環境のデータベースインスタンスを特定
- [ ] テスト環境のデータベースURLを確認
- [ ] 現在のコードのURLと一致しているか確認
- [ ] 一致していない場合、テスト環境のURLに更新

## 💡 次のステップ

1. **テスト環境のデータベースURLを確認**
   - Firebase Console → `dassyutsu2` プロジェクト → Realtime Database
   - テスト環境のデータベースインスタンスのURLを確認

2. **URLが異なる場合**
   - テスト環境のURLを共有してください
   - コードを更新します

3. **URLが一致している場合**
   - セキュリティルールが正しく公開されているか再確認
   - データベースインスタンスが正しく選択されているか確認




