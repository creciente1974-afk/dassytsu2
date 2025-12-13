class Hint {
  final String id;
  String content;
  int timeOffset; // 分単位

  Hint({
    required this.id,
    required this.content,
    required this.timeOffset,
  });

  // Flutterでは、SwiftのUUIDの代わりに通常StringでIDを扱います。
  // UUID生成には 'uuid' パッケージを使用します。
}