// lib/widgets/pro_feature_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/revenuecat_service.dart';
import '../pages/subscription_page.dart';

/// Pro機能へのアクセスを制御するウィジェット
/// Proエンタイトルメントがない場合、Paywallを表示するオプションを提供
class ProFeatureGate extends StatefulWidget {
  /// 子ウィジェット（Pro機能）
  final Widget child;
  
  /// Proエンタイトルメントがない場合に表示するウィジェット
  /// nullの場合は、Paywallを表示するボタンを表示
  final Widget? fallback;
  
  /// Pro機能の説明テキスト
  final String? featureDescription;

  const ProFeatureGate({
    super.key,
    required this.child,
    this.fallback,
    this.featureDescription,
  });

  @override
  State<ProFeatureGate> createState() => _ProFeatureGateState();
}

class _ProFeatureGateState extends State<ProFeatureGate> {
  final RevenueCatService _revenueCatService = RevenueCatService();
  bool _hasPro = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
    _setupCustomerInfoListener();
  }

  Future<void> _checkProStatus() async {
    try {
      await _revenueCatService.refreshCustomerInfo();
      if (mounted) {
        setState(() {
          _hasPro = _revenueCatService.hasProEntitlement();
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ProFeatureGate] Error checking Pro status: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _setupCustomerInfoListener() {
    _revenueCatService.customerInfoStream.listen((customerInfo) {
      if (mounted) {
        setState(() {
          _hasPro = _revenueCatService.hasProEntitlement();
        });
      }
    });
  }

  Future<void> _showPaywall() async {
    try {
      await _revenueCatService.presentPaywall(context);
      await _checkProStatus();
    } catch (e) {
      debugPrint('❌ [ProFeatureGate] Error showing paywall: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasPro) {
      return widget.child;
    }

    // Proエンタイトルメントがない場合
    if (widget.fallback != null) {
      return widget.fallback!;
    }

    // デフォルトのフォールバックUI
    return _buildDefaultFallback();
  }

  Widget _buildDefaultFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'この機能は脱出くん２ Proが必要です',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.featureDescription != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.featureDescription!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showPaywall,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('脱出くん２ Pro を始める'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionPage(),
                  ),
                );
              },
              child: const Text('サブスクリプションを管理'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Proエンタイトルメントの状態を監視するWidget
/// 状態が変更されたときにコールバックを呼び出す
class ProEntitlementWatcher extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool>? onEntitlementChanged;

  const ProEntitlementWatcher({
    super.key,
    required this.child,
    this.onEntitlementChanged,
  });

  @override
  State<ProEntitlementWatcher> createState() => _ProEntitlementWatcherState();
}

class _ProEntitlementWatcherState extends State<ProEntitlementWatcher> {
  final RevenueCatService _revenueCatService = RevenueCatService();
  bool? _previousHasPro;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _setupListener();
  }

  Future<void> _checkInitialStatus() async {
    try {
      await _revenueCatService.refreshCustomerInfo();
      final hasPro = _revenueCatService.hasProEntitlement();
      _previousHasPro = hasPro;
      widget.onEntitlementChanged?.call(hasPro);
    } catch (e) {
      debugPrint('❌ [ProEntitlementWatcher] Error checking status: $e');
    }
  }

  void _setupListener() {
    _revenueCatService.customerInfoStream.listen((customerInfo) {
      final hasPro = _revenueCatService.hasProEntitlement();
      
      // 状態が変更された場合のみコールバックを呼び出す
      if (_previousHasPro != hasPro) {
        _previousHasPro = hasPro;
        widget.onEntitlementChanged?.call(hasPro);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

