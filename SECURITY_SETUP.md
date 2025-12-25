# セキュリティ設定ガイド

## 現在の対策状況

### ✅ 実施済み
1. **`.gitignore`にAPIキーを含むファイルを追加**
   - `.env` ファイル
   - `GoogleService-Info.plist` ファイル
   - `google-services.json` ファイル

### ⚠️ 推奨される追加対策

## 1. 環境変数の使用（推奨）

現在、`lib/main.dart`にAPIキーがハードコードされています。環境変数を使用することを強く推奨します。

### 手順

#### ステップ1: `flutter_dotenv`パッケージを追加

```yaml
# pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

#### ステップ2: `.env`ファイルを作成

```bash
# .env
FIREBASE_API_KEY=AIzaSyAiu1LnKFkDLroxfLJLXxjWEY3lvwZ8-as
FIREBASE_APP_ID=1:245139907628:ios:e187581a13a65a02eddd89
FIREBASE_MESSAGING_SENDER_ID=245139907628
FIREBASE_PROJECT_ID=dassyutsu2
FIREBASE_STORAGE_BUCKET=dassyutsu2.firebasestorage.app
FIREBASE_DATABASE_URL=https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app
```

#### ステップ3: `.env.example`ファイルを作成（テンプレート）

```bash
# .env.example
FIREBASE_API_KEY=your_api_key_here
FIREBASE_APP_ID=your_app_id_here
FIREBASE_MESSAGING_SENDER_ID=your_sender_id_here
FIREBASE_PROJECT_ID=your_project_id_here
FIREBASE_STORAGE_BUCKET=your_storage_bucket_here
FIREBASE_DATABASE_URL=your_database_url_here
```

#### ステップ4: `pubspec.yaml`に`.env`ファイルを追加

```yaml
flutter:
  assets:
    - .env
```

#### ステップ5: `lib/main.dart`を更新

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // .envファイルを読み込む
  await dotenv.load(fileName: ".env");
  
  // Firebase初期化
  if (Platform.isMacOS) {
    final options = FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
      databaseURL: dotenv.env['FIREBASE_DATABASE_URL']!,
    );
    await Firebase.initializeApp(options: options);
  }
  // ...
}
```

## 2. Firebase設定ファイルの扱い

### オプションA: Gitに含める（一般的な方法）

Firebaseの公式ドキュメントでは、`GoogleService-Info.plist`と`google-services.json`をGitに含めることを推奨しています。これらのファイルはプロジェクト固有の設定であり、APIキーは公開されても問題ないとされています（ただし、適切なセキュリティルールの設定が必要）。

**`.gitignore`から除外する場合**:
```bash
# .gitignoreから以下を削除
# **/GoogleService-Info.plist
# **/google-services.json
```

### オプションB: Gitから除外する（より安全な方法）

セキュリティを重視する場合は、これらのファイルを`.gitignore`に含めて、`.env.example`のようなテンプレートファイルを共有します。

## 3. 現在の`.gitignore`設定

以下のファイルがGitから除外されています：

```
.env
.env.local
.env.*.local
**/GoogleService-Info.plist
**/google-services.json
```

## 4. チーム開発時の注意事項

1. **`.env.example`ファイルをGitに含める**
   - 実際の値は含めず、テンプレートとして共有
   
2. **README.mdにセットアップ手順を記載**
   ```markdown
   ## セットアップ
   1. `.env.example`をコピーして`.env`を作成
   2. `.env`に実際のFirebase設定値を入力
   ```

3. **Firebase設定ファイルの共有方法**
   - プライベートリポジトリ: 直接共有可能
   - パブリックリポジトリ: `.gitignore`に追加し、別途共有

## 5. セキュリティチェックリスト

- [x] `.gitignore`に`.env`を追加
- [x] `.gitignore`に`GoogleService-Info.plist`を追加
- [x] `.gitignore`に`google-services.json`を追加
- [ ] 環境変数を使用するようにコードを更新（推奨）
- [ ] `.env.example`ファイルを作成
- [ ] README.mdにセットアップ手順を記載

## 6. 緊急時の対応

もしAPIキーがGitにコミットされてしまった場合：

1. **Git履歴から削除**
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/file" \
     --prune-empty --tag-name-filter cat -- --all
   ```

2. **Firebase ConsoleでAPIキーを再生成**
   - Firebase Console → プロジェクト設定 → 全般
   - 新しいAPIキーを生成
   - 古いAPIキーを削除または制限

3. **`.env`ファイルを更新**
   - 新しいAPIキーで`.env`を更新

## 参考リンク

- [Flutter環境変数の管理](https://pub.dev/packages/flutter_dotenv)
- [Firebaseセキュリティガイド](https://firebase.google.com/docs/projects/learn-more#best-practices)
- [Gitから機密情報を削除](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)




