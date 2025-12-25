// lib/utils/subscription_helper.dart

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

/// サブスクリプション関連のヘルパー関数
class SubscriptionHelper {
  static final RevenueCatService _revenueCatService = RevenueCatService();

  /// Proエンタイトルメントが有効かどうかをチェック
  /// 非同期で最新の状態を取得
  static Future<bool> checkProEntitlement() async {
    try {
      await _revenueCatService.refreshCustomerInfo();
      return _revenueCatService.hasProEntitlement();
    } catch (e) {
      debugPrint('❌ [SubscriptionHelper] Error checking entitlement: $e');
      return false;
    }
  }

  /// Proエンタイトルメントが有効かどうかをチェック（同期）
  /// キャッシュされた顧客情報を使用
  static bool hasProEntitlementSync() {
    return _revenueCatService.hasProEntitlement();
  }

  /// エンタイトルメント情報を取得
  static EntitlementInfo? getProEntitlementInfo() {
    return _revenueCatService.getProEntitlementInfo();
  }

  /// エンタイトルメントの有効期限を取得
  static DateTime? getProExpirationDate() {
    final entitlementInfo = getProEntitlementInfo();
    return entitlementInfo?.expirationDate;
  }

  /// エンタイトルメントが有効期限切れかどうかをチェック
  static bool isProExpired() {
    final expirationDate = getProExpirationDate();
    if (expirationDate == null) return true;
    return DateTime.now().isAfter(expirationDate);
  }

  /// エンタイトルメントがまもなく期限切れになるかどうかをチェック
  /// [daysBeforeExpiration] 日以内に期限切れになる場合に true を返す
  static bool isProExpiringSoon({int daysBeforeExpiration = 7}) {
    final expirationDate = getProExpirationDate();
    if (expirationDate == null) return false;
    
    final now = DateTime.now();
    final daysUntilExpiration = expirationDate.difference(now).inDays;
    return daysUntilExpiration > 0 && daysUntilExpiration <= daysBeforeExpiration;
  }
}

