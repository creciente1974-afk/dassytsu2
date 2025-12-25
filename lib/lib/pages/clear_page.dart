import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 必要なサービスとモデルのインポート
// EscapeRecord, Event, FirebaseServiceError などのクラスが必要です。
import '../../lib/models/event.dart'; // 正規のEventモデル
import '../../lib/models/escape_record.dart'; // EscapeRecordモデル
import '../../firebase_service.dart';
import '../services/firebase_service_error.dart';

// ⚠️ 注意: 以下のクラス/関数は、別途定義が必要です。
// 1. IndividualEventPage (遷移先の画面)
// 2. EscapeRecord (データモデル)
// 3. ShareManager, ViewSnapshotHelper (シェア機能のヘルパー)
//    - Flutterでは 'share_plus' パッケージや 'screenshot' パッケージ等で代用します。

// シェア機能のインポート
import '../utils/share_manager.dart';
import '../utils/view_snapshot_helper.dart';

class ClearPage extends StatefulWidget {
  final String eventName;
  final String eventId;
  final double escapeTime; // TimeIntervalはDartではdoubleで表現
  
  // 遷移先ページ（ここでは仮にWidget型で定義）
  final Widget Function(Event event) onNavigateToEventDetail;
  final VoidCallback onDismiss; // メイン画面へ戻る処理

  const ClearPage({
    required this.eventName,
    required this.eventId,
    required this.escapeTime,
    required this.onNavigateToEventDetail,
    required this.onDismiss,
    super.key,
  });

  @override
  State<ClearPage> createState() => _ClearPageState();
}

class _ClearPageState extends State<ClearPage> {
  
  // MARK: - Properties (Swiftの @State / private let に相当)
  final FirebaseService _firebaseService = FirebaseService();
  // final ShareManager _shareManager = ShareManager(); // 実際にはパッケージで代用
  
  bool _isSaving = false;
  bool _hasAttemptedSave = false;
  String? _saveError;
  bool _showError = false;
  Event? _event; // Firebaseから取得したイベント情報
  bool _isLoadingEvent = false;
  bool _navigateToEventDetail = false; // 遷移トリガー
  
  // プレイヤー名 (Swiftの UserDefaults.standard.string(forKey: key) に相当)
  // 実際には shared_preferences パッケージなどを使って非同期で取得する
  String? _playerName;
  
  // 画面キャプチャ用のGlobalKey
  final GlobalKey _captureKey = GlobalKey(); 
  
  @override
  void initState() {
    super.initState();
    debugPrint('✅ [ClearPage] initState: クリアページが初期化されました');
    
    // 初期値を設定（非同期読み込みが完了するまでのフォールバック）
    _playerName = 'テストプレイヤーチーム';
    
    // プレイヤー名を読み込んでから記録を保存
    _loadPlayerName().then((_) {
      // プレイヤー名が読み込まれた後に記録を保存
      if (!_hasAttemptedSave && mounted) {
        _hasAttemptedSave = true;
        _saveEscapeRecord();
      }
    }).catchError((error) {
      debugPrint('⚠️ [ClearPage] プレイヤー名の読み込みエラー: $error');
      // エラーが発生した場合でも記録保存を試みる
      if (!_hasAttemptedSave && mounted) {
        _hasAttemptedSave = true;
        _saveEscapeRecord();
      }
    });
  }

  // プレイヤー名を取得する（非同期処理の代用スタブ）
  Future<void> _loadPlayerName() async {
    try {
      // 実際には shared_preferences などを使って非同期で取得する
      final prefs = await SharedPreferences.getInstance();
      final playerNameKey = 'playerName_${widget.eventId}';
      final playerName = prefs.getString(playerNameKey) ?? 'テストプレイヤーチーム';

      if (mounted) {
        setState(() {
          _playerName = playerName;
        });
      }
    } catch (e) {
      // エラーが発生した場合はデフォルト値を使用
      if (mounted) {
        setState(() {
          _playerName = 'テストプレイヤーチーム';
        });
      }
    }
  }

  // MARK: - Logic (Swiftの private func に相当)

  // Swiftの formatTime(_:) に相当
  String _formatTime(double time) {
    final minutes = (time / 60).truncate();
    final seconds = (time % 60).truncate();
    return '${minutes}分${seconds}秒';
  }

  // Swiftの saveEscapeRecord() に相当
  Future<void> _saveEscapeRecord() async {
    if (_isSaving) return;
    
    // プレイヤー名がまだ読み込まれていない場合は待つ
    if (_playerName == null) {
      // 少し待ってから再試行
      await Future.delayed(const Duration(milliseconds: 100));
      if (_playerName == null && mounted) {
        // デフォルト値を使用
        setState(() {
          _playerName = 'テストプレイヤーチーム';
        });
      }
    }
    
    // 最終的にプレイヤー名がnullの場合はデフォルト値を使用
    final playerName = _playerName ?? 'テストプレイヤーチーム';
    
    if (!mounted) return;
    
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      // 1. EscapeRecordを作成 (UUIDはDartの 'uuid' パッケージで代用)
      final record = EscapeRecord(
        id: const Uuid().v4(),
        playerName: playerName,
        escapeTime: widget.escapeTime,
        completedAt: DateTime.now(),
      );
      
      // 2. Firebaseに保存
      await _firebaseService.addEscapeRecord(record, eventId: widget.eventId);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        // 成功時の処理: 特に画面遷移はせず、この画面に留まる
        debugPrint('✅ [ClearPage] 脱出記録を保存しました');
      }
    } on FirebaseServiceError catch (e) {
      debugPrint('❌ [ClearPage] FirebaseServiceError: ${e.message}');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = e.message;
          _showError = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [ClearPage] 予期せぬエラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = '記録の保存中に予期せぬエラーが発生しました: ${e.toString()}';
          _showError = true;
        });
      }
    }
  }

  // Swiftの loadEventAndNavigate() に相当
  Future<void> _loadEventAndNavigate() async {
    if (_isLoadingEvent) return;
    
    setState(() {
      _isLoadingEvent = true;
    });
    
    // 1. UserDefaultsにチェック済みフラグと時間を保存 (shared_preferencesで代用)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clearChecked_${widget.eventId}', true);
    await prefs.setDouble('escapeTime_${widget.eventId}', widget.escapeTime);
    
    try {
      // 2. イベント情報を取得 (getAllEventsは既にFirebaseServiceにある前提)
      final events = await _firebaseService.getAllEvents();
      final loadedEvent = events.firstWhere(
        (e) => e.id == widget.eventId, // ⚠️ イベントモデルのIDはString型と仮定
        orElse: () => throw Exception('イベントが見つかりませんでした'),
      );
      
      if (mounted) {
        setState(() {
          _event = loadedEvent;
          _isLoadingEvent = false;
          _navigateToEventDetail = true; // 遷移トリガーをON
        });
        
        // 遷移実行
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => widget.onNavigateToEventDetail(loadedEvent),
          ),
        ).then((_) {
          // 遷移先の画面から戻ってきたときの処理 (必要に応じて)
          setState(() {
            _navigateToEventDetail = false;
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEvent = false;
          _saveError = 'イベント情報の取得に失敗しました';
          _showError = true;
        });
      }
    }
  }
  
  // MARK: - シェア機能
  
  // Swiftの generateShareImage() / shareToAll() に相当
  Future<void> _shareToAll() async {
    if (!mounted) return;
    
    try {
      // 1. 共有するテキストを作成
      final playerName = _playerName ?? 'テストプレイヤーチーム';
      var text = "「${widget.eventName}」をクリアしました！\n";
      text += "脱出タイム: ${_formatTime(widget.escapeTime)}\n";
      text += "プレイヤー: $playerName\n";
      
      // 2. 画面をキャプチャして画像を取得
      if (mounted) {
        try {
          final imageBytes = await ViewSnapshotHelper.snapshotWidget(
            key: _captureKey,
            pixelRatio: 3.0,
          );
          
          if (imageBytes != null && imageBytes.isNotEmpty) {
            // 3. 画像とテキストを同時にシェア
            await ShareManager.shared.shareContent(
              imageBytes: imageBytes,
              text: text,
              context: context,
              onComplete: (completed) {
                if (kDebugMode) {
                  print("シェア完了: $completed");
                }
              },
            );
          } else {
            // 画像キャプチャに失敗した場合はテキストのみシェア
            if (kDebugMode) {
              print("画像キャプチャに失敗したため、テキストのみシェアします");
            }
            await ShareManager.shared.shareText(
              text: text,
              context: context,
            );
          }
        } catch (e) {
          // 画像キャプチャエラーの場合はテキストのみシェア
          debugPrint('⚠️ [ClearPage] 画像キャプチャエラー: $e');
          if (mounted) {
            await ShareManager.shared.shareText(
              text: text,
              context: context,
            );
          }
        }
      }
    } catch (e, stackTrace) {
      // エラーが発生した場合はユーザーに通知
      debugPrint('❌ [ClearPage] シェアエラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('シェアに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print("シェアエラー: $e");
      }
    }
  }

  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    debugPrint('✅ [ClearPage] build: クリアページを構築します');
    
    // エラー表示をbuild後に処理
    if (_showError && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showError) {
          _showAlert(context);
        }
      });
    }
    
    // エラーハンドリング: ビルド中にエラーが発生した場合のフォールバック
    try {
      return _buildScaffold(context);
    } catch (e, stackTrace) {
      debugPrint('❌ [ClearPage] buildエラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      // エラーが発生した場合はシンプルなエラー画面を表示
      return Scaffold(
        appBar: AppBar(
          title: const Text('エラー'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'ページの表示中にエラーが発生しました',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.onDismiss,
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  Widget _buildScaffold(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final availableHeight = screenSize.height - MediaQuery.of(context).padding.top - kToolbarHeight;
    
    return Scaffold(
      // Swiftの .navigationBarBackButtonHidden(true) に相当
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent, // 背景画像を見せるため透明に
        elevation: 0, // 影を削除
      ),
      
      // SwiftUIの Alert に相当
      // RepaintBoundaryで画面全体を囲んでキャプチャ可能にする
      body: RepaintBoundary(
        key: _captureKey,
        child: Stack(
          children: [
            // 背景画像
            Positioned.fill(
              child: Image.asset(
                'assets/images/clear_bg.jpg',
                fit: BoxFit.cover, // 画面全体をカバー
                errorBuilder: (context, error, stackTrace) {
                  // 画像が見つからない場合のフォールバック
                  return Container(
                    color: Colors.white,
                  );
                },
              ),
            ),
            // 半透明のオーバーレイ（テキストの可読性向上）
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.3), // 30%の白いオーバーレイ
              ),
            ),
            // コンテンツ
            LayoutBuilder(
              builder: (context, constraints) {
                // シェア時に全体が表示される固定サイズを計算
                // 画面の高さに合わせて、すべてのコンテンツが収まるサイズを設定
                final fixedHeight = availableHeight;
                
                return SingleChildScrollView(
                  child: Container(
                    width: screenSize.width,
                    constraints: BoxConstraints(
                      minHeight: fixedHeight,
                    ),
                    child: Container(
                      height: fixedHeight,
                      padding: const EdgeInsets.only(top: 40, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 上部ブロック: 画面上部に配置
                          // 脱出成功アイコン (ZStackに相当)
                          _buildClearIcon(),
                          
                          const SizedBox(height: 20),

                          // タイトル（白い枠線エフェクト付き）
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 白い枠線（ストローク）用のテキスト
                                Text(
                                  "脱出成功！",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 3
                                      ..color = Colors.white,
                                  ),
                                ),
                                // メインのテキスト（緑）
                                const Text(
                                  "脱出成功！",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // スペーサー: 下部ブロックを中央付近に配置
                          const Spacer(),

                          // 下部ブロック: 現在の位置を維持（中央付近）
                          // MARK: - 脱出タイム表示
                          // _playerNameはinitStateで初期化されるため、常に表示可能
                          _buildTimeRecordCard(),
                          
                          const SizedBox(height: 20),

                          // MARK: - チェックボタン
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: ElevatedButton(
                              onPressed: _isLoadingEvent ? null : _loadEventAndNavigate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isLoadingEvent ? Colors.grey : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 受付チェック指示テキスト
                                  Text(
                                    "受付スタッフにチェックボタンを押してもらってください。",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // アイコンとラベル
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isLoadingEvent)
                                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      else
                                        const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isLoadingEvent ? "読み込み中..." : "チェック",
                                        style: const TextStyle(color: Colors.white, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // MARK: - シェアボタンセクション
                          _buildShareSection(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - UI Components

  // 脱出成功アイコン
  Widget _buildClearIcon() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // SwiftUIの LinearGradient に近い表現
              gradient: LinearGradient(
                colors: [Colors.green.withOpacity(0.2), Colors.lightGreenAccent.withOpacity(0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const Icon(
            Icons.emoji_events, // trophy.fill に相当
            size: 80, 
            color: Colors.yellow,
          ),
        ],
      ),
    );
  }
  
  // プレイヤー名とタイムのカード
  Widget _buildTimeRecordCard() {
    // 念のためnullチェックを追加
    final playerName = _playerName ?? 'テストプレイヤーチーム';
    
    return FutureBuilder<int>(
      future: _getAttemptCount(),
      builder: (context, snapshot) {
        final attemptCount = snapshot.data ?? 1;
        final playerNameWithAttempt = "$playerName ($attemptCount回目)";
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 白い枠線エフェクト付きの脱出タイム表示
                Stack(
                  children: [
                    // 白い枠線（ストローク）用のテキスト
                    Text(
                      "脱出タイム: ${_formatTime(widget.escapeTime)}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.white,
                      ),
                    ),
                    // メインのテキスト（青）
                    Text(
                      "脱出タイム: ${_formatTime(widget.escapeTime)}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("プレイヤー: $playerNameWithAttempt", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // 挑戦回数を取得
  Future<int> _getAttemptCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptCountKey = "attemptCount_${widget.eventId}";
      return prefs.getInt(attemptCountKey) ?? 1;
    } catch (e) {
      return 1;
    }
  }
  
  // シェアセクション
  Widget _buildShareSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _shareToAll,
            icon: const Icon(Icons.share, color: Colors.white), // square.and.arrow.up
            label: const Text(
              "脱出タイムをシェア",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
  
  // エラーアラート表示 (Swiftの .alert に相当)
  void _showAlert(BuildContext context) {
    if (!mounted || !_showError) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("エラー"),
          content: Text(_saveError ?? "不明なエラーが発生しました"),
          actions: <Widget>[
            TextButton(
              // OKを押したらメイン画面へ戻る（dismiss() に相当）
              onPressed: () {
                Navigator.of(dialogContext).pop(); // アラートを閉じる
                if (mounted) {
                  setState(() {
                    _showError = false;
                    _saveError = null;
                  });
                  widget.onDismiss(); // 画面を閉じてメインへ
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}