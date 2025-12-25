// lib/pages/subscription_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import '../firebase_service.dart';
import '../event_list_page.dart';

/// サブスクリプション管理ページ
/// RevenueCat PaywallとCustomer Centerへのアクセスを提供
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final RevenueCatService _revenueCatService = RevenueCatService();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  bool _hasPro = false;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
    _setupCustomerInfoListener();
  }

  /// Proエンタイトルメントの状態をチェック
  Future<void> _checkProStatus() async {
    try {
      await _revenueCatService.refreshCustomerInfo();
      if (mounted) {
        setState(() {
          _hasPro = _revenueCatService.hasProEntitlement();
        });
      }
    } catch (e) {
      debugPrint('❌ [SubscriptionPage] Error checking Pro status: $e');
    }
  }

  /// 顧客情報の変更を監視
  void _setupCustomerInfoListener() {
    _revenueCatService.customerInfoStream.listen((customerInfo) {
      if (mounted) {
        setState(() {
          _hasPro = _revenueCatService.hasProEntitlement();
        });
      }
      debugPrint('📊 [SubscriptionPage] Customer info updated');
    });
  }

  /// Paywallを表示
  Future<void> _presentPaywall() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _revenueCatService.presentPaywall(context);
      
      // Paywallが閉じられた後に状態を更新
      await _checkProStatus();
    } catch (e) {
      debugPrint('❌ [SubscriptionPage] Error presenting paywall: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Customer Centerを表示
  Future<void> _presentCustomerCenter() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _revenueCatService.presentCustomerCenter(context);
      
      // Customer Centerが閉じられた後に状態を更新
      await _checkProStatus();
    } catch (e) {
      debugPrint('❌ [SubscriptionPage] Error presenting customer center: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 管理者ページに遷移
  Future<void> _navigateToAdminPage() async {
    if (!_firebaseService.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firebaseが初期化されていません'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // イベント一覧を取得
      final events = await _firebaseService.getAllEvents();
      
      if (mounted) {
        // 管理者ページをモーダルシートで表示
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return AdminPage(
              events: events,
              onSave: () {
                // 管理者ページで保存された場合のコールバック
                // 必要に応じて実装
              },
            );
          },
        );
      }
    } catch (e) {
      debugPrint('❌ [SubscriptionPage] Error navigating to admin page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('管理者ページの読み込みに失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 購入を復元
  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _revenueCatService.restorePurchases();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('購入を復元しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _checkProStatus();
    } catch (e) {
      debugPrint('❌ [SubscriptionPage] Error restoring purchases: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元に失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// エンタイトルメント情報を表示
  Widget _buildEntitlementInfo() {
    final entitlementInfo = _revenueCatService.getProEntitlementInfo();
    
    if (entitlementInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '脱出くん２ 主催者用',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '現在、主催者用プランに加入していません',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  '脱出くん２ 主催者用',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entitlementInfo.willRenew != null)
              Text(
                '自動更新: ${entitlementInfo.willRenew! ? "有効" : "無効"}',
                style: const TextStyle(fontSize: 14),
              ),
            if (entitlementInfo.periodType != null)
              Text(
                '期間タイプ: ${_getPeriodTypeString(entitlementInfo.periodType!)}',
                style: const TextStyle(fontSize: 14),
              ),
            if (entitlementInfo.latestPurchaseDate != null)
              Text(
                '最新購入日: ${_formatDate(_parseDate(entitlementInfo.latestPurchaseDate!))}',
                style: const TextStyle(fontSize: 14),
              ),
            if (entitlementInfo.expirationDate != null)
              Text(
                '有効期限: ${_formatDate(_parseDate(entitlementInfo.expirationDate!))}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getPeriodTypeString(PeriodType periodType) {
    switch (periodType) {
      case PeriodType.intro:
        return '紹介期間';
      case PeriodType.trial:
        return 'トライアル期間';
      case PeriodType.normal:
        return '通常期間';
      case PeriodType.prepaid:
        return 'プリペイド期間';
      case PeriodType.unknown:
        return '不明';
    }
  }

  /// 日付文字列またはDateTimeをDateTimeに変換
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      final parsed = DateTime.tryParse(dateValue);
      if (parsed != null) {
        return parsed;
      }
    }
    // フォールバック: 現在の日時を返す
    return DateTime.now();
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サブスクリプション'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // エンタイトルメント情報
            _buildEntitlementInfo(),
            const SizedBox(height: 24),
            
            // Pro機能の説明
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '脱出くん２ 主催者用の特典',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem('✓ すべての機能にアクセス'),
                    _buildFeatureItem('✓ イベント管理機能'),
                    _buildFeatureItem('✓ イベント進行機能'),
                    _buildFeatureItem('✓ 新機能への早期アクセス'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // アクションボタン
            if (!_hasPro) ...[
              // Proに加入していない場合: Paywallを表示
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _presentPaywall,
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  '脱出くん２ 主催者用 を始める',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Proに加入している場合: 管理者ページへのボタン
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _navigateToAdminPage,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text(
                  '管理者ページを開く',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Customer Center ボタン
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _presentCustomerCenter,
              icon: const Icon(Icons.settings),
              label: const Text('サブスクリプションを管理'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            // 購入を復元ボタン
            TextButton.icon(
              onPressed: _isLoading ? null : _restorePurchases,
              icon: const Icon(Icons.restore),
              label: const Text('購入を復元'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

