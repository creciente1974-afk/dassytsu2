import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'event_model.dart' as event_model; // 定義したモデル
import 'lib/models/event.dart' as lib_models; // ReceptionPage用のEventモデル
import 'lib/models/problem.dart' as lib_problem; // Problemモデル
import 'lib/models/escape_record.dart' as lib_escape; // EscapeRecordモデル
import 'lib/models/hint.dart' as lib_hint; // Hintモデル
import 'firebase_service.dart'; // 以前変換したFirebaseService
import 'lib/pages/clear_page.dart';
import 'game_view.dart' show GameView; // 必要なクラスのみインポート
import 'game_view.dart' as game_view; // Event, Problem, Hintクラス用
import 'lib/pages/reception_page.dart' show ReceptionPage;

// ⚠️ 注意: GameView, ClearView, ReceptionView はここでは定義していません。
// 適切なファイルからインポートしてください。

// SwiftUIのUUID()に相当
const Uuid _uuid = Uuid();

class IndividualEventScreen extends StatefulWidget {
  final event_model.Event event;

  const IndividualEventScreen({super.key, required this.event});

  @override
  State<IndividualEventScreen> createState() => _IndividualEventScreenState();
}

class _IndividualEventScreenState extends State<IndividualEventScreen> {
  // @State private var currentEvent: Event
  late event_model.Event _currentEvent;
  // @State private var isLoading = false
  bool _isLoading = false;

  // private let firebaseService = FirebaseService.shared に相当
  final FirebaseService _firebaseService = FirebaseService();
  
  // ランキング更新用のTimer
  Timer? _rankingUpdateTimer;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    // .onAppear { loadEvent() } に相当
    _loadEvent();
    
    // ランキングを定期的に更新（30秒ごと）
    _rankingUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadEvent();
      }
    });
  }
  
  @override
  void dispose() {
    _rankingUpdateTimer?.cancel();
    _rankingUpdateTimer = null;
    super.dispose();
  }

  // MARK: - Computed Properties (算出プロパティ)

  // チェック済みフラグを確認 (isClearChecked)
  Future<bool> get _isClearChecked async {
    final prefs = await SharedPreferences.getInstance();
    final key = "clearChecked_${_currentEvent.id}"; // DartではIDはString
    return prefs.getBool(key) ?? false;
  }

  // 保存されたescapeTimeを取得 (savedEscapeTime)
  Future<double?> get _savedEscapeTime async {
    final prefs = await SharedPreferences.getInstance();
    final key = "escapeTime_${_currentEvent.id}";
    final value = prefs.getDouble(key) ?? 0.0;
    return value > 0 ? value : null;
  }

  // sortedRecords に相当
  List<event_model.EscapeRecord> get _sortedRecords {
    final records = List<event_model.EscapeRecord>.from(_currentEvent.records);
    // EscapeRecordで定義したescapeTimeでソート
    records.sort((a, b) => a.escapeTime.compareTo(b.escapeTime));
    return records;
  }

  // MARK: - Utility Methods (ユーティリティメソッド)

  // private func formatTime(_ time: TimeInterval) に相当
  String _formatTime(double time) {
    final minutes = (time ~/ 60).toString();
    final seconds = (time % 60).toString().padLeft(2, '0');
    return "${minutes}分${seconds}秒";
  }

  // private func formatDate(_ date: Date) に相当
  String _formatDate(DateTime date) {
    // intlパッケージを使用
    final formatter = DateFormat.yMMMd('ja_JP').add_jm(); // Medium Date & Short Time
    return formatter.format(date);
  }

  // private func formatEventDate(_ date: Date) に相当
  String _formatEventDate(DateTime date) {
    final formatter = DateFormat.yMMMMd('ja_JP'); // Long Date
    return "開催日: ${formatter.format(date)}";
  }
  
  // private func generateTeamId() に相当
  // ログイン時に保存されたデバイスIDをランキングのIDとして使用
  Future<String> _generateTeamId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // ログイン時に保存されたデバイスIDを取得
    String? deviceId = prefs.getString('deviceId');
    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }
    
    // デバイスIDが保存されていない場合（旧バージョンからの移行など）、teamIdを確認
    String? savedTeamId = prefs.getString('teamId');
    if (savedTeamId != null && savedTeamId.isNotEmpty) {
      return savedTeamId;
    }
    
    // どちらもない場合は新規UUIDを生成（フォールバック）
    final newTeamId = "team-${_uuid.v4()}";
    await prefs.setString('teamId', newTeamId);
    await prefs.setString('deviceId', newTeamId); // デバイスIDとしても保存
    return newTeamId;
  }

  // MARK: - Data Loading & Reset (データ読み込みとリセット)
  
  // event_model.Event を lib/models/event.dart の Event に変換するヘルパー関数
  // ReceptionPageは lib/models/event.dart の Event を使用しているため
  lib_models.Event _convertEventForReception(event_model.Event event) {
    return lib_models.Event(
      id: event.id,
      name: event.name,
      problems: event.problems.map((p) {
        // hintsを変換（event_modelのhintsはList<dynamic>）
        List<lib_hint.Hint> convertedHints = [];
        if (p.hints is List) {
          for (var h in p.hints) {
            if (h is Map) {
              convertedHints.add(lib_hint.Hint.fromJson(Map<String, dynamic>.from(h)));
            }
          }
        }
        
        return lib_problem.Problem(
          id: p.id,
          text: p.text,
          mediaURL: p.mediaURL ?? '',
          answer: p.answer,
          hints: convertedHints,
          requiresCheck: p.requiresCheck,
          checkText: p.checkText,
          checkImageURL: p.checkImageURL,
        );
      }).toList(),
      duration: event.duration,
      records: event.records.map((r) {
        return lib_escape.EscapeRecord(
          id: r.id,
          playerName: r.playerName,
          escapeTime: r.escapeTime,
          completedAt: r.completedAt,
        );
      }).toList(),
      cardImageUrl: event.card_image_url,
      overview: event.overview,
      eventDate: event.eventDate,
      isVisible: event.isVisible,
      qrCodeData: event.qrCodeData, // QRコードデータを追加
    );
  }
  
  // lib_models.Event を event_model.Event に変換するヘルパー関数
  event_model.Event _convertLibEventToEventModel(lib_models.Event libEvent) {
    return event_model.Event(
      id: libEvent.id,
      name: libEvent.name,
      problems: libEvent.problems.map((p) {
        // hintsを変換（lib_modelsのhintsはList<Hint>）
        List<dynamic> convertedHints = p.hints.map((h) => h.toJson()).toList();
        
        return event_model.Problem(
          id: p.id,
          text: p.text ?? '',
          mediaURL: p.mediaURL,
          answer: p.answer,
          hints: convertedHints,
          requiresCheck: p.requiresCheck,
          checkText: p.checkText,
          checkImageURL: p.checkImageURL,
        );
      }).toList(),
      duration: libEvent.duration,
      records: libEvent.records.map((r) => event_model.EscapeRecord(
        id: r.id,
        playerName: r.playerName,
        escapeTime: r.escapeTime,
        completedAt: r.completedAt,
      )).toList(),
      card_image_url: libEvent.cardImageUrl,
      overview: libEvent.overview,
      eventDate: libEvent.eventDate,
      isVisible: libEvent.isVisible,
      qrCodeData: libEvent.qrCodeData, // QRコードデータを追加
    );
  }
  
  // event_model.Event を game_view.dart の Event に変換するヘルパー関数
  // GameViewは game_view.dart で定義された Event を使用しているため
  game_view.Event _convertEventModelToGameEvent(event_model.Event event) {
    return game_view.Event(
      id: event.id,
      name: event.name,
      problems: event.problems.map((p) {
        // hintsを変換
        List<game_view.Hint> convertedHints = [];
        if (p.hints is List) {
          for (var h in p.hints) {
            if (h is Map) {
              final hMap = Map<String, dynamic>.from(h);
              convertedHints.add(game_view.Hint(
                id: hMap['id'] as String? ?? '',
                content: hMap['content'] as String? ?? '',
                timeOffset: (hMap['timeOffset'] as num?)?.toInt() ?? 0,
              ));
            }
          }
        }
        
        return game_view.Problem(
          id: p.id,
          text: p.text,
          mediaURL: p.mediaURL ?? '',
          answer: p.answer,
          hints: convertedHints,
          requiresCheck: p.requiresCheck,
          checkText: p.checkText,
          checkImageURL: p.checkImageURL,
        );
      }).toList(),
      duration: event.duration,
      targetObjectText: null, // デフォルト値
    );
  }
  
  // private func loadEvent() に相当
  Future<void> _loadEvent() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // FirebaseServiceのgetAllEventsを使用（lib_models.Eventを返す）
      final events = await _firebaseService.getAllEvents();
      final updatedLibEvent = events.firstWhere(
        (e) => e.id == widget.event.id,
        orElse: () => _convertEventForReception(widget.event), // 見つからなかった場合は現在のイベントを維持
      );

      // lib_models.Event を event_model.Event に変換
      final updatedEvent = _convertLibEventToEventModel(updatedLibEvent);

      setState(() {
        _currentEvent = updatedEvent;
      });
    } catch (e) {
      debugPrint("イベントデータのロード中にエラー: $e");
      // エラー処理（例: SnackBar表示）
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // private func resetQRCodeAuthenticationAndNavigateToReception() に相当
  Future<void> _resetAndNavigateToReception() async {
    final prefs = await SharedPreferences.getInstance();
    final eventId = _currentEvent.id;

    // QRコード認証状態をリセット
    const authKey = "qrCodeAuthenticated"; // イベントID固有の認証キーが適切 (Swift側コードを尊重)
    final eventAuthKey = "${authKey}_$eventId";
    await prefs.remove(eventAuthKey);

    // クリアチェックフラグをリセット
    const clearCheckedKey = "clearChecked";
    final eventClearCheckedKey = "${clearCheckedKey}_$eventId";
    await prefs.remove(eventClearCheckedKey);

    // 受付ページへ遷移
    // setState(() {
    //   _navigateToReception = true;
    // });
  }

  // MARK: - Build Method (UI構築)

  @override
  Widget build(BuildContext context) {
    // SwiftUIのViewと同様にFutureBuilderを使ってisClearCheckedとsavedEscapeTimeを待つ
    return FutureBuilder(
      future: Future.wait([_isClearChecked, _savedEscapeTime]),
      builder: (context, snapshot) {
        final isClearChecked = snapshot.data?[0] as bool? ?? false;
        final savedEscapeTime = snapshot.data?[1] as double?;
        
        // NavigationStackや.navigationTitleはScaffoldとAppBarで実現
        return Scaffold(
          appBar: AppBar(
            title: const Text("イベント詳細"),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _loadEvent, // .toolbarItem(placement: .navigationBarTrailing)
              ),
            ],
          ),
          
          // .refreshable { ... } に相当
          body: RefreshIndicator(
            onRefresh: _loadEvent,
            child: SingleChildScrollView( // ScrollView に相当
              physics: const AlwaysScrollableScrollPhysics(), // Pull-to-refreshのために常にスクロール可能にする
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // VStack(alignment: .leading)と.frame(maxWidth: .infinity)を統合
                children: [
                  // 1. イベント情報
                  _buildEventInfo(context),
                  const SizedBox(height: 20),

                  // 1.5. イベント一覧へ戻るボタン
                  _buildBackToEventListButton(context),
                  const SizedBox(height: 20),

                  // 2. イベントカード画像表示
                  if (_currentEvent.card_image_url != null && _currentEvent.card_image_url!.isNotEmpty)
                    _buildCardImage(),
                  
                  if (_currentEvent.card_image_url != null && _currentEvent.card_image_url!.isNotEmpty)
                    const SizedBox(height: 20),

                  // 3. イベント概要表示
                  if (_currentEvent.overview != null && _currentEvent.overview!.isNotEmpty)
                    _buildOverview(),
                  
                  if (_currentEvent.overview != null && _currentEvent.overview!.isNotEmpty)
                    const SizedBox(height: 20),

                  // 4. クリアページに戻るボタン
                  if (isClearChecked && savedEscapeTime != null)
                    _buildClearPageButton(context, savedEscapeTime),
                  
                  if (isClearChecked)
                    const SizedBox(height: 20),

                  // 5. 開始/再挑戦ボタン
                  _buildStartButton(context, isClearChecked),
                  
                  const SizedBox(height: 30),

                  // 6. ランキング表示
                  if (_currentEvent.records.isNotEmpty)
                    _buildRanking(),
                ],
              ),
            ),
          ),
          
          // .alert に相当
          // FlutterではAlertDialogはButtonや他のロジック内で表示する
          // ここではsetStateで_showClearAlertがtrueになったときにshowDialogを呼び出す

          // .navigationDestination(isPresented: $navigateToReception) に相当
          // 画面がビルドされた直後のチェックと画面遷移
          // この方法ではなく、_resetAndNavigateToReception内でNavigator.pushReplacementを使う方が一般的だが
          // SwiftUIコードの $navigateToReception ロジックを尊重する
          // (ただし、このFutureBuilder内でpushを呼ぶのはアンチパターン。onSaveなどで使うのがベスト)
          // シンプルにAlert内で直接pushReplacementを呼び出すのがFlutter流。
        );
      },
    );
  }

  // MARK: - Component Builders

  Widget _buildEventInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200], // Color(.systemGray6) に相当
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentEvent.name,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          if (_currentEvent.eventDate != null)
            Text(
              _formatEventDate(_currentEvent.eventDate!),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey), // .secondary
            ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              _buildInfoLabel(context, "問題数: ${_currentEvent.problems.length}", Icons.list),
              const Spacer(),
              _buildInfoLabel(context, "制限時間: ${_currentEvent.duration}分", Icons.watch_later_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLabel(BuildContext context, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  // イベント一覧へ戻るボタン
  Widget _buildBackToEventListButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        // イベント一覧ページ（最初のページ）に戻る
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      style: TextButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_back, color: Colors.white),
          SizedBox(width: 8),
          Text(
            "イベント一覧へ戻る",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage() {
    // SwiftUIのAsyncImageに相当
    return CachedNetworkImage(
      imageUrl: _currentEvent.card_image_url!,
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.fitWidth, // .aspectRatio(contentMode: .fit) に近い
          ),
        ),
        // 画像の高さを確保するため、AspectRatioを使用
        width: double.infinity,
        height: MediaQuery.of(context).size.width * 9 / 16, // 16:9比率を概算
      ),
      placeholder: (context, url) => Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: MediaQuery.of(context).size.width * 9 / 16,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: MediaQuery.of(context).size.width * 9 / 16,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "イベント概要",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _currentEvent.overview!,
            textAlign: TextAlign.left, // .frame(maxWidth: .infinity, alignment: .leading)
          ),
        ),
      ],
    );
  }

  Widget _buildClearPageButton(BuildContext context, double escapeTime) {
    return TextButton(
      // NavigationLinkに相当
      onPressed: () {
        // ClearPageを使用
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ClearPage(
            eventName: _currentEvent.name,
            eventId: _currentEvent.id,
            escapeTime: escapeTime,
            onNavigateToEventDetail: (lib_models.Event event) {
              // lib_models.Event を event_model.Event に変換
              final convertedEvent = _convertLibEventToEventModel(event);
              return IndividualEventScreen(event: convertedEvent);
            },
            onDismiss: () {
              // メイン画面（イベント一覧）に戻る
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ));
      },
      style: TextButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, color: Colors.white),
          SizedBox(width: 8),
          Text(
            "クリアページに戻る",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  // 開始/再挑戦ボタン
  Widget _buildStartButton(BuildContext context, bool isClearChecked) {
    final buttonColor = isClearChecked ? Colors.orange : Colors.blue;
    final buttonText = isClearChecked ? "もう一度挑戦する" : "ゲーム開始";
    
    // アクションを非同期関数として定義
    Future<void> action() async {
      if (isClearChecked) {
        // クリア後の場合はアラートを表示
        await _showRestartAlert(context);
      } else {
        // 未クリアの場合はゲーム開始
        // 挑戦回数のカウントはGameViewのinitStateで行う
        final teamId = await _generateTeamId();
        if (mounted) {
          // event_model.Event を game_view.dart の Event に変換
          final gameEvent = _convertEventModelToGameEvent(_currentEvent);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => GameView(event: gameEvent, teamId: teamId),
          ));
        }
      }
    }
    
    return TextButton(
      onPressed: action,
      style: TextButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_arrow, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            buttonText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Swiftの.alertに相当するウィジェット
  Future<void> _showRestartAlert(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('もう一度受付してください。'),
          content: const Text('受付へ戻りますか？'),
          actions: <Widget>[
            TextButton(
              child: const Text('いいえ', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('はい'),
              onPressed: () async {
                Navigator.of(context).pop(); // アラートを閉じる
                await _resetAndNavigateToReception(); // リセットと遷移
                // ⚠️ _navigateToReceptionがtrueになった後の遷移ロジックは
                // 状態が更新されてから画面をpopし、親ウィジェットでpushReplacementを実行する方がクリーンです。
                // 簡略化のため、ここでは直接ReceptionViewにpushReplacementします。
                if (mounted) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => ReceptionPage(event: _convertEventForReception(_currentEvent)), // ReceptionPageを使用
                    ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRanking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            "ランキング",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true, // Column内でListViewを使うため必須
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _sortedRecords.take(3).length, // prefix(3)に相当
          itemBuilder: (context, index) {
            final record = _sortedRecords[index];
            final rank = index + 1;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200], // Color(.systemGray6)
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!, width: 1.0), // .border(Color(.systemGray4))
              ),
              child: Row(
                children: [
                  Text(
                    "${rank}位",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.playerName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _formatTime(record.escapeTime),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                        Text(
                          _formatDate(record.completedAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}