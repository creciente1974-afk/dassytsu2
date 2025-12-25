# データベースURLの修正

## ✅ 修正内容

データベースURLの末尾のスラッシュを削除しました。

### 修正前
```dart
final String _databaseURL = "https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/";
```

### 修正後
```dart
final String _databaseURL = "https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app";
```

## 🔍 確認結果

REST APIで直接アクセスした結果、データが正常に返ってきました。これは、ルールが正しく設定されていることを意味します。

```bash
curl -X GET "https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/.json"
# ✅ データが正常に返ってきました
```

## 📋 次のステップ

1. **アプリを再起動**
   ```bash
   flutter run
   ```

2. **ログを確認**
   - `permission-denied` エラーが解消されたか確認
   - イベントリストが表示されるか確認

3. **まだエラーが発生する場合**
   - Firebase Consoleでルールを再確認
   - アプリを完全に再起動（flutter clean → flutter pub get → flutter run）




