# Google API Key セキュリティアラート対応

## 問題
GitHubリポジトリにGoogle API Keyが公開されています。

## 公開されているAPIキー
- Android: `AIzaSyBrtv60brsEepfPcDNttTmMVZWVv0-6rkc` (google-services.json)
- iOS: `AIzaSyAiu1LnKFkDLroxfLJLXxjWEY3lvwZ8-as` (GoogleService-Info.plist)

## 対応手順

### 1. Firebase ConsoleでAPIキーを制限する（最重要）

Firebase ConsoleでAPIキーに適切な制限を設定してください：

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクト「dassyutsu2」を選択
3. 「APIとサービス」>「認証情報」に移動
4. 各APIキーをクリックして編集
5. 「アプリケーションの制限」で以下を設定：
   - **Android**: パッケージ名「com.dassyutsu2.dassyutsu_app」とSHA-1証明書フィンガープリントを追加
   - **iOS**: バンドルID「com.dassyutsu2.dassyutsu_app」（または適切なバンドルID）を追加
6. 「APIの制限」で「Firebase用にキーを制限」を選択
7. 変更を保存

### 2. Git履歴からAPIキーを削除（推奨）

既にコミットされているAPIキーを履歴から削除するには：

```bash
# git filter-branchを使用（注意: この操作は履歴を書き換えます）
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch android/app/google-services.json ios/Runner/GoogleService-Info.plist" \
  --prune-empty --tag-name-filter cat -- --all

# 強制プッシュ（注意: チームメンバーに通知が必要）
git push origin --force --all
git push origin --force --tags
```

または、より安全な方法として：

```bash
# BFG Repo-Cleanerを使用（推奨）
# 1. BFGをダウンロード: https://rtyley.github.io/bfg-repo-cleaner/
# 2. 以下のコマンドを実行:
java -jar bfg.jar --delete-files google-services.json
java -jar bfg.jar --delete-files GoogleService-Info.plist
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --force
```

### 3. .gitignoreの確認

`.gitignore`に以下が含まれていることを確認（既に設定済み）：
```
**/GoogleService-Info.plist
**/google-services.json
```

### 4. 新しいAPIキーを生成（必要に応じて）

制限を設定しても不安な場合は、新しいAPIキーを生成して置き換えることを検討してください：

1. Firebase Consoleで新しいAPIキーを生成
2. 古いAPIキーを削除または無効化
3. 新しいAPIキーを設定ファイルに反映

### 5. セキュリティルールの確認

Firebase Realtime DatabaseとStorageのセキュリティルールが適切に設定されていることを確認してください。

## 注意事項

- **Firebase設定ファイルは通常、Gitリポジトリに含めることが推奨されています**
- しかし、セキュリティのため、APIキーには必ず適切な制限を設定してください
- クライアント側のAPIキーは完全に隠すことはできませんが、制限を設定することで悪用を防げます

## 参考リンク

- [Firebase APIキーの制限](https://firebase.google.com/docs/projects/api-keys#restrict_api_key)
- [Git履歴から機密情報を削除する方法](https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

