// lib/models/user_device_info.dart

class UserDeviceInfo {
  // 端末を一意に識別するためのID (iOSの identifierForVendor や Androidの ID)
  final String deviceId;
  // 端末の名称 (例: iPhone 15, Galaxy S23)
  final String deviceName;
  // OSのバージョン (例: iOS 17.1, Android 14)
  final String osVersion;
  // ユーザーがログインしたタイムスタンプ (保存時に自動生成)
  final DateTime timestamp;

  UserDeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.osVersion,
    // タイムスタンプは生成時に指定がない場合、現在時刻をデフォルト値とする
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();


  // MARK: - Firebaseへの変換（toJson）
  
  // Flutterの login() 関数で jsonEncode() を使って SharedPreferences に保存するためにも使用
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'osVersion': osVersion,
      // Firebaseで比較可能な文字列形式で保存
      'timestamp': timestamp.toIso8601String(), 
    };
  }

  // MARK: - Firebaseからの変換（fromJson）
  // (今回は未使用ですが、管理画面などで必要になるため定義)

  factory UserDeviceInfo.fromJson(Map<String, dynamic> json) {
    return UserDeviceInfo(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      osVersion: json['osVersion'] as String? ?? '',
      // 文字列からDateTimeオブジェクトに変換
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}