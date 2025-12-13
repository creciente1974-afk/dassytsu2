import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

// 必要なサービスとモデルのインポート
// EscapeRecord, Event, FirebaseServiceError などのクラスが必要です。
import '../models.dart'; 
import '../services/firebase_service.dart';
import '../services/firebase_service_error.dart';

// ⚠️ 注意: 以下のクラス/関数は、別途定義が必要です。
// 1. IndividualEventPage (遷移先の画面)
// 2. EscapeRecord (データモデル)
// 3. ShareManager, ViewSnapshotHelper (シェア機能のヘルパー)
//    - Flutterでは 'share_plus' パッケージや 'screenshot' パッケージ等で代用します。

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
  
  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    
    // Swiftの .task に相当: 画面表示時に自動で記録を保存
    if (!_hasAttemptedSave) {
      _hasAttemptedSave = true;
      _saveEscapeRecord();
    }
  }

  // プレイヤー名を取得する（非同期処理の代用スタブ）
  Future<void> _loadPlayerName() async {
    // 実際には shared_preferences などを使って非同期で取得する
    // ここではデモ値としてスタブを使用
    // final playerName = await SharedPreferences.getInstance().getString('playerName_${widget.eventId}');
    final playerName = 'テストプレイヤーチーム'; 

    if (mounted) {
      setState(() {
        _playerName = playerName;
      });
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
    if (_isSaving || _playerName == null) return;
    
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      // 1. EscapeRecordを作成 (UUIDはDartの 'uuid' パッケージで代用)
      final record = EscapeRecord(
        // id: Uuid().v4(), // UUIDはStringとして保持するモデルを前提
        id: const Uuid().v4(),
        playerName: _playerName!,
        escapeTime: widget.escapeTime,
        completedAt: DateTime.now(),
      );
      
      // 2. Firebaseに保存
      // ⚠️ _firebaseService.addEscapeRecord は別途実装が必要です
      // try await _firebaseService.addEscapeRecord(record, toEventId: widget.eventId);

      // 🚨 [重要] FirebaseServiceに addEscapeRecord メソッドを追加する必要があります
      // ここでは、メソッドが存在することを前提として、一時的なスタブ処理を行います。
      await Future.delayed(const Duration(milliseconds: 500)); // APIコールをシミュレート
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        // 成功時の処理: 特に画面遷移はせず、この画面に留まる
      }
    } on FirebaseServiceError catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = e.message;
          _showError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = '記録の保存中に予期せぬエラーが発生しました';
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
    // 実際には SharedPreferences を使用
    // final prefs = await SharedPreferences.getInstance();
    // prefs.setBool('clearChecked_${widget.eventId}', true);
    // prefs.setDouble('escapeTime_${widget.eventId}', widget.escapeTime);
    
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
  
  // MARK: - シェア機能（Flutterの代用スタブ）
  
  // Swiftの generateShareImage() / shareToAll() に相当
  void _shareToAll() {
    // 実際には 'screenshot' や 'share_plus' パッケージを使用

    // 1. 共有するテキストを作成
    var text = "「${widget.eventName}」をクリアしました！\n";
    text += "脱出タイム: ${_formatTime(widget.escapeTime)}\n";
    if (_playerName != null) {
      text += "プレイヤー: $_playerName\n";
    }
    
    // 2. スクリーンショットを生成し、シェアシートを開く処理をここに記述
    // 例: ScreenshotController.capture().then((Uint8List? imageBytes) {
    //   if (imageBytes != null) {
    //     // share_plusを使って画像とテキストをシェア
    //   }
    // });
    
    // デモとしてシェアテキストをデバッグ出力
    if (kDebugMode) {
      print("--- Share Content ---");
      print(text);
      print("--- Share Logic Stub ---");
    }
  }

  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Swiftの .navigationBarBackButtonHidden(true) に相当
      appBar: AppBar(
        automaticallyImplyLeading: false, 
      ),
      
      // SwiftUIの Alert に相当
      body: Builder(
        builder: (context) {
          if (_showError) {
            // エラー表示後、自動で閉じるか、OKボタンでdismiss()を呼ぶ処理を実装
            // 🚨 今回はAlertDialogとして処理
            Future.microtask(() => _showAlert(context));
          }
          
          // Swiftの VStack(spacing: 30) に相当
          return SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height - (Scaffold.of(context).appBarMaxHeight ?? 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),

                  // 脱出成功アイコン (ZStackに相当)
                  _buildClearIcon(),
                  
                  const SizedBox(height: 30),

                  // タイトル
                  const Text(
                    "脱出成功！",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  // 説明文
                  Text(
                    "${widget.eventName}を\nすべてクリアしました！",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  // 受付チェック指示
                  Text(
                    "受付スタッフにチェックボタンを押してもらってください。",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // MARK: - チェックボタン
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingEvent ? null : _loadEventAndNavigate,
                      icon: _isLoadingEvent 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                        _isLoadingEvent ? "読み込み中..." : "チェック",
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoadingEvent ? Colors.grey : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // MARK: - 脱出タイム表示
                  if (_playerName != null)
                    _buildTimeRecordCard(),
                  
                  const SizedBox(height: 30),

                  // MARK: - シェアボタンセクション
                  _buildShareSection(),
                  
                  const Spacer(),
                ],
              ),
            ),
          );
        },
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
            width: 200,
            height: 200,
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
            size: 100, 
            color: Colors.yellow,
          ),
        ],
      ),
    );
  }
  
  // プレイヤー名とタイムのカード
  Widget _buildTimeRecordCard() {
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
            Text("プレイヤー: $_playerName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
      ),
    );
  }
  
  // シェアセクション
  Widget _buildShareSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const Text("結果をシェア", style: TextStyle(fontSize: 16, color: Colors.grey)),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showError) {
        showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text("エラー"),
              content: Text(_saveError ?? "不明なエラーが発生しました"),
              actions: <Widget>[
                TextButton(
                  // OKを押したらメイン画面へ戻る（dismiss() に相当）
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // アラートを閉じる
                    widget.onDismiss(); // 画面を閉じてメインへ
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
                _saveError = null;
             });
          }
        });
      }
    });
  }
}