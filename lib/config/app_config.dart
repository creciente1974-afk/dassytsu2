// lib/config/app_config.dart

/// アプリケーションの設定を管理するクラス
class AppConfig {
  // シングルトンパターン
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  /// RevenueCatを使用するかどうか
  /// true: RevenueCatを使用する
  /// false: RevenueCatを使用しない
  static const bool useRevenueCat = true;
}

