// lib/models/user_device_info.dart

class UserDeviceInfo {
  final String deviceId;
  final String deviceModel; // Swiftの deviceModel に対応 (旧: deviceName)
  final String systemVersion; // Swiftの systemVersion に対応 (旧: osVersion)
  final String deviceName; // Swiftの deviceName に対応
  final DateTime registeredAt; // Swiftの registeredAt に対応

  UserDeviceInfo({
    required this.deviceId,
    required this.deviceModel,
    required this.systemVersion,
    required this.deviceName,
    DateTime? registeredAt,
  }) : registeredAt = registeredAt ?? DateTime.now();

  // MARK: - Firebaseとの相互変換

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceModel': deviceModel,
      'systemVersion': systemVersion,
      'deviceName': deviceName,
      // Swift互換のため、秒単位のタイムスタンプで保存
      'registeredAt': registeredAt.millisecondsSinceEpoch / 1000.0, 
    };
  }

  factory UserDeviceInfo.fromJson(Map<String, dynamic> json) {
    // registeredAt のデコード (秒単位のタイムスタンプ)
    DateTime registeredAtDate = DateTime.now();
    final registeredAtValue = json['registeredAt'];
    if (registeredAtValue is num) {
      registeredAtDate = DateTime.fromMillisecondsSinceEpoch((registeredAtValue * 1000).toInt());
    } else if (registeredAtValue is String) {
      registeredAtDate = DateTime.tryParse(registeredAtValue) ?? DateTime.now();
    }
    
    return UserDeviceInfo(
      deviceId: json['deviceId'] as String? ?? '',
      deviceModel: json['deviceModel'] as String? ?? '',
      systemVersion: json['systemVersion'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      registeredAt: registeredAtDate,
    );
  }
}