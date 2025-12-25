# ログ表示確認方法（Cursor/VS Code）

## 問題：画面下部のログが表示されない

### 解決方法1: ターミナルパネルを表示する

1. **キーボードショートカット**
   - Mac: `Ctrl + `` (バッククォート)
   - または: `Cmd + J`

2. **メニューから**
   - 「表示」→「ターミナル」

3. **下部パネルが表示されない場合**
   - 画面下部の端をドラッグしてパネルを開く

### 解決方法2: 新しいターミナルを開く

1. メニュー: 「ターミナル」→「新しいターミナル」
2. コマンドを実行:
   ```bash
   cd /Users/tsudakazumi/dassyutsu2/my_flutter_project
   flutter run
   ```

### 解決方法3: ターミナル出力を確認

アプリが既に実行中の場合は、新しいターミナルを開いて確認:

```bash
# 新しいターミナルを開く
# プロジェクトディレクトリに移動
cd /Users/tsudakazumi/dassyutsu2/my_flutter_project

# ログを確認（既に実行中の場合は別の方法）
# macOSのConsole.appを使用するか、アプリを再起動
flutter run
```

### 解決方法4: macOSのConsole.appを使用

1. Spotlight検索で「Console」を開く
2. 左側で「system.log」またはデバイスを選択
3. 検索バーで「flutter」や「my_flutter_project」でフィルタ

### 解決方法5: ログファイルに出力

ターミナルで実行:
```bash
cd /Users/tsudakazumi/dassyutsu2/my_flutter_project
flutter run > flutter_log.txt 2>&1
```

その後、`flutter_log.txt`ファイルを確認

### 確認すべきログ

アプリ起動時に以下のログが表示されるはず:
- `🚀 [main] アプリが起動しました`
- `🚀 [main] WidgetsFlutterBinding初期化完了`
- `✅ [main] Firebase 初期化完了`

画像認証成功時に:
- `✅ [GameView] onApproved()が呼ばれました`
- `📸 [GameView] CameraCheckPage closed`
- `🎉 [GameView] 全ての問題をクリアしました！`


