// lib/login_view.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'lib/models/user_device_info.dart';
import 'content_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _isLoggingIn = false;

  // 端末情報を取得する関数
  Future<UserDeviceInfo> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return UserDeviceInfo(
        deviceId: androidInfo.id,
        deviceModel: androidInfo.model,
        systemVersion: 'Android ${androidInfo.version.release}',
        deviceName: androidInfo.device,
      );
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return UserDeviceInfo(
        deviceId: iosInfo.identifierForVendor ?? 'unknown',
        deviceModel: iosInfo.model ?? 'Unknown',
        systemVersion: iosInfo.systemVersion,
        deviceName: iosInfo.name,
      );
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfoPlugin.macOsInfo;
      return UserDeviceInfo(
        deviceId: macInfo.systemGUID ?? 'macos-${DateTime.now().millisecondsSinceEpoch}',
        deviceModel: macInfo.model ?? 'Mac',
        systemVersion: 'macOS ${macInfo.kernelVersion}',
        deviceName: macInfo.computerName,
      );
    } else {
      // その他のプラットフォーム
      return UserDeviceInfo(
        deviceId: 'device-${DateTime.now().millisecondsSinceEpoch}',
        deviceModel: 'Generic Device',
        systemVersion: 'Unknown OS',
        deviceName: 'Generic Device',
      );
    }
  }

  Future<void> _login(BuildContext context) async {
    if (_isLoggingIn) return;

    setState(() {
      _isLoggingIn = true;
    });

    try {
      // 1. 端末情報を取得
      final deviceInfo = await _getDeviceInfo();
      
      // 2. SharedPreferencesに保存
      final prefs = await SharedPreferences.getInstance();
      
      // デバイス情報をJSON形式で保存
      final encoded = jsonEncode(deviceInfo.toJson());
      await prefs.setString('userDeviceInfo', encoded);
      
      // デバイスIDをランキングのIDとして使用できるように別途保存
      await prefs.setString('deviceId', deviceInfo.deviceId);
      await prefs.setString('teamId', deviceInfo.deviceId); // teamIdとしても保存
      
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        
        // 3. ログイン後にContentViewに遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ContentView()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ログインに失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景画像
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/clear_bg.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              // オーバーレイで暗くする
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          // コンテンツ（下部に配置）
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isLoggingIn ? null : () => _login(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ログイン'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ログインボタンを押して \n 開始してください',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}