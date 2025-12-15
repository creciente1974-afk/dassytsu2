// lib/login_view.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'lib/models/user_device_info.dart';
import 'firebase_service.dart';

class LoginView extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  
  const LoginView({super.key, this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  String? _errorMessage;

  /// 端末情報を取得する関数
  Future<UserDeviceInfo> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return UserDeviceInfo(
        deviceId: androidInfo.id,
        deviceModel: androidInfo.model,
        systemVersion: 'Android ${androidInfo.version.release}',
        deviceName: androidInfo.model,
      );
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return UserDeviceInfo(
        deviceId: iosInfo.identifierForVendor ?? 'unknown',
        deviceModel: iosInfo.model ?? 'Unknown',
        systemVersion: iosInfo.systemVersion,
        deviceName: iosInfo.name,
      );
    } else {
      return UserDeviceInfo(
        deviceId: 'web_desktop_device_id',
        deviceModel: 'Generic Device',
        systemVersion: 'Unknown OS',
        deviceName: 'Generic Device',
      );
    }
  }

  /// ログイン処理を実行
  Future<void> _handleLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // デバイス情報を取得
      final deviceInfo = await _getDeviceInfo();
      
      // Firebaseにデバイス情報を保存（ランキングに反映させるため）
      try {
        await _firebaseService.saveUserDeviceInfo(deviceInfo);
        debugPrint('✅ [LoginView] デバイス情報をFirebaseに保存しました');
      } catch (e) {
        debugPrint('⚠️ [LoginView] Firebaseへの保存に失敗しましたが、ログインは続行します: $e');
        // Firebaseへの保存に失敗しても、ローカルには保存してログインを続行
      }
      
      // ローカルにもデバイス情報を保存
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(deviceInfo.toJson());
      await prefs.setString('userDeviceInfo', encoded);

      if (mounted) {
        // ログイン成功後、コールバックを呼び出してRootScreenDeciderの状態を更新
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ログインに失敗しました: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アイコン表示
            Icon(
              Icons.login,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            
            // 説明テキスト
            const Text(
              'ログインボタンを押して\nログインしてください',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            
            // エラーメッセージ
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // ログインボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'ログイン',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}