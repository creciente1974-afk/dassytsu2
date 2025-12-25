// lib/services/revenuecat_service.dart

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCatサービスクラス
/// サブスクリプション管理とエンタイトルメントチェックを担当
class RevenueCatService {
  // プラットフォームごとのAPI Key
  static const String _apiKeyAndroid = 'goog_TyoPzvFesFYfPZKjNNdnSFcSOJr'; // Google Play用
  static const String _apiKeyIOS = 'appl_LjKgykRryEnhxJlcVNZFwFPXXBF'; // App Store用
  
  /// プラットフォームに応じたAPI Keyを取得
  static String get _apiKey {
    if (Platform.isAndroid) {
      return _apiKeyAndroid;
    } else if (Platform.isIOS) {
      return _apiKeyIOS;
    } else {
      // その他のプラットフォーム（Web、Desktopなど）はAndroid用を使用
      return _apiKeyAndroid;
    }
  }
  
  static const String _entitlementId = '脱出くん２ Pro';
  
  // シングルトンパターン
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;
  CustomerInfo? _customerInfo;
  StreamController<CustomerInfo>? _customerInfoController;
  
  /// RevenueCatの初期化
  /// main.dartでアプリ起動時に呼び出す
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ [RevenueCat] Already initialized');
      return;
    }

    try {
      // デバッグモードの設定（リリースビルドでは false に変更）
      PurchasesConfiguration configuration = PurchasesConfiguration(_apiKey)
        ..appUserID = null; // 匿名ユーザーとして開始（Firebase Authと連携する場合は後で設定）

      await Purchases.configure(configuration);
      _isInitialized = true;
      
      debugPrint('✅ [RevenueCat] Initialized successfully');
      
      // ストリームコントローラーを初期化
      _customerInfoController = StreamController<CustomerInfo>.broadcast();
      
      // 初期化後に顧客情報を取得
      final customerInfo = await refreshCustomerInfo();
      // 初期値をストリームに送信
      _customerInfoController?.add(customerInfo);
    } catch (e, stackTrace) {
      debugPrint('❌ [RevenueCat] Initialization error: $e');
      debugPrint('📚 [RevenueCat] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// ユーザーIDを設定（Firebase Authと連携する場合）
  Future<void> setUserId(String userId) async {
    try {
      await Purchases.logIn(userId);
      debugPrint('✅ [RevenueCat] User ID set: $userId');
      // refreshCustomerInfo内でストリームに通知されるため、ここでは呼び出すだけ
      await refreshCustomerInfo();
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error setting user ID: $e');
      rethrow;
    }
  }

  /// ログアウト
  Future<void> logout() async {
    try {
      await Purchases.logOut();
      _customerInfo = null;
      debugPrint('✅ [RevenueCat] Logged out');
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error logging out: $e');
      rethrow;
    }
  }

  /// 顧客情報をリフレッシュ
  Future<CustomerInfo> refreshCustomerInfo() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      debugPrint('✅ [RevenueCat] Customer info refreshed');
      debugPrint('📊 [RevenueCat] Active entitlements: ${_customerInfo?.entitlements.active.keys}');
      // ストリームに更新を通知
      _customerInfoController?.add(_customerInfo!);
      return _customerInfo!;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error refreshing customer info: $e');
      rethrow;
    }
  }

  /// 現在の顧客情報を取得（キャッシュされた値）
  CustomerInfo? get customerInfo => _customerInfo;

  /// エンタイトルメント「脱出くん２ Pro」が有効かチェック
  bool hasProEntitlement() {
    if (_customerInfo == null) {
      debugPrint('⚠️ [RevenueCat] Customer info is null, returning false');
      return false;
    }
    
    final entitlement = _customerInfo!.entitlements.active[_entitlementId];
    final hasAccess = entitlement != null;
    
    debugPrint('🔍 [RevenueCat] Pro entitlement check: $hasAccess');
    return hasAccess;
  }

  /// エンタイトルメントの詳細情報を取得
  EntitlementInfo? getProEntitlementInfo() {
    if (_customerInfo == null) return null;
    return _customerInfo!.entitlements.active[_entitlementId];
  }

  /// 利用可能なオファリングを取得
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('✅ [RevenueCat] Offerings retrieved: ${offerings.current?.identifier}');
      return offerings;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error getting offerings: $e');
      rethrow;
    }
  }

  /// Paywallを表示
  /// RevenueCat Paywall UIを使用
  Future<void> presentPaywall(BuildContext context) async {
    try {
      final offerings = await getOfferings();
      
      if (offerings?.current == null) {
        debugPrint('⚠️ [RevenueCat] No current offering available');
        // オファリングがない場合はエラーを表示
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('サブスクリプション情報の取得に失敗しました。しばらく待ってから再度お試しください。'),
            ),
          );
        }
        return;
      }

      // RevenueCat Paywall UIを表示
      if (context.mounted) {
        await RevenueCatUI.presentPaywall(
          offering: offerings!.current!,
        );
        
        // Paywallが閉じられた後に顧客情報をリフレッシュ
        await refreshCustomerInfo();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [RevenueCat] Error presenting paywall: $e');
      debugPrint('📚 [RevenueCat] Stack trace: $stackTrace');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 特定のパッケージを購入
  Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      debugPrint('🛒 [RevenueCat] Purchasing package: ${package.identifier}');
      final customerInfo = await Purchases.purchasePackage(package);
      
      // 購入成功後に顧客情報を更新
      _customerInfo = customerInfo;
      // ストリームに更新を通知
      _customerInfoController?.add(customerInfo);
      
      debugPrint('✅ [RevenueCat] Purchase successful');
      return customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('⚠️ [RevenueCat] Purchase cancelled by user');
        throw Exception('購入がキャンセルされました');
      } else if (errorCode == PurchasesErrorCode.productNotAvailableForPurchaseError) {
        debugPrint('❌ [RevenueCat] Product not available');
        throw Exception('商品が利用できません');
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        debugPrint('❌ [RevenueCat] Purchase not allowed');
        throw Exception('購入が許可されていません');
      } else if (errorCode == PurchasesErrorCode.purchaseInvalidError) {
        debugPrint('❌ [RevenueCat] Purchase invalid');
        throw Exception('無効な購入です');
      } else {
        debugPrint('❌ [RevenueCat] Purchase error: ${e.message}');
        throw Exception('購入エラー: ${e.message}');
      }
    } catch (e) {
      debugPrint('❌ [RevenueCat] Unexpected purchase error: $e');
      rethrow;
    }
  }

  /// Customer Centerを表示
  Future<void> presentCustomerCenter(BuildContext context) async {
    try {
      if (context.mounted) {
        await RevenueCatUI.presentCustomerCenter();
        
        // Customer Centerが閉じられた後に顧客情報をリフレッシュ
        await refreshCustomerInfo();
      }
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error presenting customer center: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 購入の復元
  Future<CustomerInfo> restorePurchases() async {
    try {
      debugPrint('♻️ [RevenueCat] Restoring purchases');
      final customerInfo = await Purchases.restorePurchases();
      _customerInfo = customerInfo;
      // ストリームに更新を通知
      _customerInfoController?.add(customerInfo);
      debugPrint('✅ [RevenueCat] Purchases restored');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error restoring purchases: $e');
      rethrow;
    }
  }

  /// エンタイトルメント状態の変更を監視するストリーム
  Stream<CustomerInfo> get customerInfoStream {
    if (_customerInfoController == null) {
      _customerInfoController = StreamController<CustomerInfo>.broadcast();
      
      // 初期値を送信
      if (_customerInfo != null) {
        _customerInfoController!.add(_customerInfo!);
      }
    }
    
    return _customerInfoController!.stream;
  }
}

