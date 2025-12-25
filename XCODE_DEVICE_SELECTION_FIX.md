# Xcodeで実機が選択できない問題の解決方法

## 実施した修正

✅ **CODE_SIGN_STYLEの追加**
- RunnerターゲットのDebug、Release、Profile設定に`CODE_SIGN_STYLE = Automatic`を追加しました
- これにより、Xcodeが自動的にプロビジョニングプロファイルを管理できるようになります

## 追加で確認すべき項目

### 1. デバイスの接続確認
- [ ] iPhone/iPadがUSBケーブルでMacに接続されているか確認
- [ ] デバイスがロック解除されているか確認
- [ ] デバイスで「このコンピュータを信頼しますか？」のダイアログが表示された場合、「信頼」を選択

### 2. Xcodeでの確認
- [ ] Xcodeを再起動
- [ ] デバイスを接続した状態で、Xcodeの上部ツールバーでデバイス選択ドロップダウンを確認
- [ ] Window > Devices and Simulators でデバイスが認識されているか確認

### 3. 開発者アカウントの確認
- [ ] Xcode > Settings > Accounts でApple IDが追加されているか確認
- [ ] 開発者アカウントが有効か確認（無料アカウントでも可）
- [ ] デバイスが開発者アカウントに登録されているか確認

### 4. プロビジョニングプロファイルの確認
- [ ] Xcodeでプロジェクトを開く
- [ ] Runnerターゲットを選択
- [ ] Signing & Capabilitiesタブを開く
- [ ] "Automatically manage signing"がチェックされているか確認
- [ ] Teamが正しく選択されているか確認（732QQC889P）

### 5. Bundle Identifierの確認
- [ ] Bundle Identifierが`com.example.myFlutterProject`で正しいか確認
- [ ] 他のアプリと重複していないか確認

### 6. デバイスの信頼設定
デバイス側で以下を確認：
- [ ] 設定 > 一般 > VPNとデバイス管理（または「プロファイルとデバイス管理」）
- [ ] 開発者アプリが信頼されているか確認
- [ ] 必要に応じて「信頼」をタップ

### 7. その他のトラブルシューティング

#### Xcodeのクリーンアップ
```bash
# XcodeのDerivedDataをクリア
rm -rf ~/Library/Developer/Xcode/DerivedData

# Flutterのクリーンビルド
cd /Users/tsudakazumi/dassyutsu2/my_flutter_project
flutter clean
flutter pub get
cd ios
pod install
```

#### デバイスの再認識
1. デバイスをMacから取り外す
2. Macを再起動（必要に応じて）
3. デバイスを再接続
4. Xcodeを再起動

#### プロビジョニングプロファイルの再生成
1. Xcode > Settings > Accounts
2. Apple IDを選択
3. "Download Manual Profiles"をクリック
4. プロジェクトに戻り、Signing & Capabilitiesで"Automatically manage signing"を一度外して再度チェック

## よくあるエラーメッセージと対処法

### "No devices found"
- デバイスが接続されていない、または認識されていない
- USBケーブルを確認、別のUSBポートを試す
- デバイスを再起動

### "This device is not registered"
- デバイスを開発者アカウントに登録する必要がある
- Xcode > Window > Devices and Simulators でデバイスを追加

### "Code signing is required"
- CODE_SIGN_STYLEが設定されていない（今回修正済み）
- 開発者アカウントが正しく設定されていない

### "Provisioning profile doesn't match"
- Bundle Identifierが一致していない
- プロビジョニングプロファイルを再生成

## 確認手順

1. **Xcodeでプロジェクトを開く**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **デバイスを選択**
   - Xcodeの上部ツールバーで、デバイス選択ドロップダウンをクリック
   - 接続された実機が表示されることを確認

3. **ビルドして実行**
   - ⌘ + R でビルド＆実行
   - 初回実行時は、デバイス側で「信頼」を選択する必要がある場合があります

## 参考情報

- [Apple Developer Documentation - Code Signing](https://developer.apple.com/documentation/xcode/code-signing)
- [Flutter - iOS Setup](https://docs.flutter.dev/deployment/ios)




