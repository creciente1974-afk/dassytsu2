# RevenueCat 統合ガイド

このドキュメントでは、脱出くん２アプリに統合されたRevenueCat SDKの使用方法を説明します。

## 概要

RevenueCat SDKを使用して、サブスクリプション管理機能を実装しています。主な機能：

- **エンタイトルメント管理**: 「脱出くん２ Pro」エンタイトルメントのチェック
- **Paywall UI**: RevenueCat Paywall UIを使用した購入画面
- **Customer Center**: サブスクリプション管理画面
- **顧客情報管理**: 購入履歴とサブスクリプション状態の管理

## 設定

### API キー

API キーは `lib/services/revenuecat_service.dart` で設定されています：
```dart
static const String _apiKey = 'test_DspXSdOjTMHYXXvUKGFRNYBdaAn';
```

### エンタイトルメント ID

エンタイトルメント ID: `脱出くん２ Pro`

## 使用方法

### 1. 基本的なエンタイトルメントチェック

```dart
import 'package:my_flutter_project/services/revenuecat_service.dart';

final revenueCatService = RevenueCatService();

// Proエンタイトルメントが有効かチェック
bool hasPro = revenueCatService.hasProEntitlement();

if (hasPro) {
  // Pro機能を使用
} else {
  // 無料版の機能のみ
}
```

### 2. ProFeatureGateウィジェットを使用

Pro機能を簡単に保護するには、`ProFeatureGate`ウィジェットを使用します：

```dart
import 'package:my_flutter_project/widgets/pro_feature_gate.dart';

ProFeatureGate(
  featureDescription: 'この機能はProプランでのみ利用可能です',
  child: YourProFeatureWidget(),
)
```

### 3. SubscriptionHelperを使用

同期・非同期でエンタイトルメントをチェック：

```dart
import 'package:my_flutter_project/utils/subscription_helper.dart';

// 非同期で最新の状態を取得
bool hasPro = await SubscriptionHelper.checkProEntitlement();

// 同期でキャッシュされた状態を取得
bool hasProSync = SubscriptionHelper.hasProEntitlementSync();

// 有効期限を確認
DateTime? expirationDate = SubscriptionHelper.getProExpirationDate();
bool isExpired = SubscriptionHelper.isProExpired();
bool isExpiringSoon = SubscriptionHelper.isExpiringSoon(daysBeforeExpiration: 7);
```

### 4. Paywallを表示

```dart
import 'package:my_flutter_project/services/revenuecat_service.dart';

final revenueCatService = RevenueCatService();
await revenueCatService.presentPaywall(context);
```

### 5. Customer Centerを表示

```dart
await revenueCatService.presentCustomerCenter(context);
```

### 6. サブスクリプションページを表示

```dart
import 'package:my_flutter_project/pages/subscription_page.dart';

Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const SubscriptionPage(),
  ),
);
```

### 7. エンタイトルメント状態の監視

`ProEntitlementWatcher`を使用して、エンタイトルメント状態の変更を監視：

```dart
ProEntitlementWatcher(
  onEntitlementChanged: (hasPro) {
    print('Pro status changed: $hasPro');
    // 状態が変更されたときの処理
  },
  child: YourWidget(),
)
```

### 8. Firebase Authと連携

Firebase Authを使用している場合、RevenueCatにユーザーIDを設定：

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_project/services/revenuecat_service.dart';

// ユーザーがログインしたとき
FirebaseAuth.instance.authStateChanges().listen((user) {
  if (user != null) {
    RevenueCatService().setUserId(user.uid);
  } else {
    RevenueCatService().logout();
  }
});
```

## プロダクト設定

### RevenueCat Dashboardでの設定

1. **Products (プロダクト)**
   - Identifier: `yearly`
   - Type: `Annual Subscription`

2. **Entitlements (エンタイトルメント)**
   - Identifier: `脱出くん２ Pro`
   - Attach products: `yearly`

3. **Offerings (オファリング)**
   - Identifier: `default` (またはカスタム)
   - Packages: `yearly` パッケージを含める

## ベストプラクティス

1. **エラーハンドリング**: すべてのRevenueCat操作で適切なエラーハンドリングを実装してください。

2. **状態の更新**: PaywallやCustomer Centerが閉じられた後、必ず顧客情報をリフレッシュしてください。

3. **UIフィードバック**: 非同期操作中は、ユーザーにローディング状態を表示してください。

4. **テスト**: Sandbox環境で十分にテストしてからリリースしてください。

5. **顧客情報のキャッシュ**: パフォーマンス向上のために、顧客情報は適切にキャッシュされていますが、重要な操作の前には最新の状態を取得してください。

## トラブルシューティング

### エンタイトルメントが認識されない

1. RevenueCat Dashboardでエンタイトルメントが正しく設定されているか確認
2. プロダクトがエンタイトルメントにアタッチされているか確認
3. 顧客情報をリフレッシュ: `await revenueCatService.refreshCustomerInfo()`

### Paywallが表示されない

1. オファリングがRevenueCat Dashboardで設定されているか確認
2. プロダクトがApp Store Connect / Google Play Consoleで設定されているか確認
3. デバイスがSandbox/Test環境で正しく設定されているか確認

### 購入が完了しない

1. テストアカウントでSandbox環境を使用しているか確認
2. ネットワーク接続を確認
3. App Store / Google Play の設定を確認

## 参考資料

- [RevenueCat Flutter Documentation](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [RevenueCat Paywalls](https://www.revenuecat.com/docs/tools/paywalls)
- [RevenueCat Customer Center](https://www.revenuecat.com/docs/tools/customer-center)

