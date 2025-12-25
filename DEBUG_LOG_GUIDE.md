# デバッグログ確認方法

## ログ出力方法

重要なログは`debugPrint()`に変更しました。以下の方法で確認できます。

## 確認方法

### 1. VS Code / Cursorのターミナル
- アプリを実行: `flutter run`
- ターミナル（下部）にログが表示されます

### 2. macOSターミナル
```bash
cd /Users/tsudakazumi/dassyutsu2/my_flutter_project
flutter run
```

### 3. ログのフィルタリング
特定のログだけを確認する場合：
```bash
flutter run | grep "GameView\|CameraCheckPage\|ClearPage"
```

## 確認すべきログ（順番）

1. `✅ [GameView] onApproved()が呼ばれました`
2. `📸 [GameView] CameraCheckPage closed`
3. `✅ [GameView] 次の問題へ遷移します`
4. `🔄 [GameView] _moveToNextProblem called`
5. `🎉 [GameView] 全ての問題をクリアしました！`
6. `✅ [ClearPage] build: クリアページを構築します`

## トラブルシューティング

### ログが表示されない場合
- アプリがデバッグモードで実行されているか確認
- `flutter run`を実行しているか確認（リリースモードでは表示されない場合あり）

### 特定のログだけ表示されない場合
- その処理が実行されていない可能性
- エラーで停止している可能性
- ログの前後にエラーメッセージを確認


