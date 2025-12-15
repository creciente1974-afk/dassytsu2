import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // JSONEncoderの代わり

// 必要なパッケージ
import 'package:shared_preferences/shared_preferences.dart'; // UserDefaultsの代替
import 'package:device_info_plus/device_info_plus.dart'; // 端末情報取得の代替 (pubspec.yamlに追加が必要)

// 必要なサービスとモデルのインポート
import '../../firebase_service.dart';
import '../../models.dart'; // UserDeviceInfo, FirebaseServiceError などが含まれることを想定
import '../services/firebase_service_error.dart'; 

// 🚨 必要なダミーモデル/ページ (別途定義が必要)
// import 'content_page.dart'; // 遷移先の画面 (Swiftの ContentView())

// ⚠️ FlutterではJSONEncoder/Decoderを直接使う代わりに、
// モデルに toJson/fromJson メソッドを定義し、dart:convert の jsonEncode/jsonDecode を使います。

class LoginPage extends StatefulWidget {
  final Widget Function() onLoginSuccess; // ログイン成功時の遷移先ページを返す関数

  const LoginPage({
    required this.onLoginSuccess,
    super.key,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // MARK: - Properties (Swiftの @State / private let に相当)
  bool _isLoggingIn = false;
  String? _errorMessage;
  bool _showError = false;
  
  // ログイン状態は、遷移ロジック（widget.onLoginSuccess）が担うため、
  // この画面のStateとしては直接管理しません。
  
  final FirebaseService _firebaseService = FirebaseService();

  // MARK: - Logic (Swiftの private func login() に相当)
  
  // 端末情報を取得する関数 (Swiftの UserDeviceInfo.current() に相当)
  Future<UserDeviceInfo> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    // プラットフォームごとに情報を取得 (ここではAndroid/iOSの例)
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return UserDeviceInfo(
        deviceId: androidInfo.id,
        deviceName: androidInfo.model,
        osVersion: 'Android ${androidInfo.version.release}',
      );
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return UserDeviceInfo(
        deviceId: iosInfo.identifierForVendor ?? 'unknown',
        deviceName: iosInfo.name,
        osVersion: iosInfo.systemVersion,
      );
    } else {
      // その他のプラットフォーム (Web, Desktopなど)
      return UserDeviceInfo(
        deviceId: 'web_desktop_device_id',
        deviceName: 'Generic Device',
        osVersion: 'Unknown OS',
      );
    }
  }

  void _login() async {
    if (_isLoggingIn) return;

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    try {
      // 1. 端末情報を取得
      final deviceInfo = await _getDeviceInfo();
      
      // 2. Firebaseに保存 (saveUserDeviceInfoはFirebaseServiceに定義が必要です)
      // ⚠️ _firebaseService.saveUserDeviceInfo は別途実装が必要です
      // await _firebaseService.saveUserDeviceInfo(deviceInfo); // コメントアウト（未実装のため） 
      
      // 3. UserDefaultsにも保存 (shared_preferencesで代替)
      final prefs = await SharedPreferences.getInstance();
      
      // Dartでは JSONEncoder().encode(deviceInfo) の代わりに jsonEncode(deviceInfo.toJson()) を使用
      final encoded = jsonEncode(deviceInfo.toJson());
      await prefs.setString("userDeviceInfo", encoded);
      
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        
        // 4. ログイン成功後の遷移 (Swiftの isLoggedIn = true に相当)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.onLoginSuccess()),
        );
      }
    } on FirebaseServiceError catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError(e.toString());
    }
  }
  
  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoggingIn = false;
        _errorMessage = message;
        _showError = true;
      });
      // Swiftの .alert に相当
      Future.microtask(() => _showAlert(context));
    }
  }
  
  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    // Swiftの ZStack に相当
    return Scaffold(
      body: Stack(
        children: [
          // MARK: - 背景画像とオーバーレイ
          // Swiftの Image("Top").resizable()... に相当
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  // ⚠️ Image("Top") は、assetsフォルダに画像ファイルを配置し、
                  // pubspec.yamlで設定する必要があります。
                  image: AssetImage('assets/images/Top.png'), 
                  fit: BoxFit.cover,
                ),
              ),
              // オーバーレイで暗くする
              child: Container(
                color: Colors.black.withOpacity(0.3), // Color.black.opacity(0.3)
              ),
            ),
          ),
          
          // MARK: - コンテンツ (VStackに相当)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end, // ボタンを下に寄せる
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(), // Spacer() (上部の余白)
                  
                  // タイトルなど（必要に応じて追加する部分）
                  // 例: Text("脱出ゲームアプリ", style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                  
                  const Spacer(), // Spacer()
                  
                  // MARK: - ログインボタン
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60), // padding(.bottom, 60)
                    child: _buildLoginButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    // Swiftの Button { ... } に相当
    return InkWell(
      onTap: _isLoggingIn ? null : _login,
      child: Container(
        width: 280, // frame(maxWidth: 280)
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          // Swiftの LinearGradient に相当
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.blue.withOpacity(0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12), // cornerRadius(12)
          boxShadow: [ // shadow に相当
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoggingIn)
              // ProgressView() に相当
              const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  color: Colors.white, 
                  strokeWidth: 2
                )
              )
            else
              // Image(systemName: "person.crop.circle.fill.badge.checkmark") に相当
              const Icon(
                Icons.person_pin_circle_rounded, 
                color: Colors.white, 
                size: 24
              ),
              
            const SizedBox(width: 8),

            // Text(isLoggingIn ? "ログイン中..." : "始める") に相当
            Text(
              _isLoggingIn ? "ログイン中..." : "始める",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18, // headline
                fontWeight: FontWeight.w600, // semibold
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // エラーアラート表示 (Swiftの .alert に相当)
  void _showAlert(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showError) {
        showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text("エラー"),
              content: Text(_errorMessage ?? "不明なエラーが発生しました"),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // アラートを閉じる
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        ).then((_) {
          // アラートが閉じられたら状態をリセット
          if(mounted) {
             setState(() {
                _showError = false;
                _errorMessage = null;
             });
          }
        });
      }
    });
  }
}

// ----------------------------------------------------------------------
// 🚨 必要なモデルとサービスメソッドのスタブ (別途定義が必要です)
// ----------------------------------------------------------------------

// 端末情報モデルのダミー (lib/models/user_device_info.dart に定義が必要)
class UserDeviceInfo {
  final String deviceId;
  final String deviceName;
  final String osVersion;

  UserDeviceInfo({required this.deviceId, required this.deviceName, required this.osVersion});

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'osVersion': osVersion,
    'timestamp': DateTime.now().toIso8601String(),
  };
}

// FirebaseService に実装が必要なメソッドの定義 (lib/services/firebase_service.dart に追記が必要)
/*
extension FirebaseServiceExtension on FirebaseService {
  Future<void> saveUserDeviceInfo(UserDeviceInfo info) async {
    // Realtime Databaseへの書き込みロジック
    // await _database.ref().child('device_info/${info.deviceId}').set(info.toJson());
  }
}
*/