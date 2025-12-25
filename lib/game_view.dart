import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // debugPrint用
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'lib/pages/clear_page.dart'; // ClearPageをインポート
import 'lib/models/event.dart' as lib_models; // Eventモデル用
import 'lib/pages/camera_check_page.dart'; // CameraCheckPageをインポート
import 'lib/pages/game_over_page.dart'; // GameOverPageをインポート
import 'lib/models/problem.dart' as lib_problem; // libのProblemモデル用
import 'lib/models/hint.dart' as lib_hint; // libのHintモデル用
import 'individual_event_screen.dart'; // IndividualEventScreen用
import 'event_model.dart' as event_model; // event_model.Event用

// ===============================================
// 1. データモデルの定義 (Swiftコードで利用されている構造体)
// ===============================================

class Hint {
  final String id;
  final String content;
  final int timeOffset; // minutes

  Hint({required this.id, required this.content, required this.timeOffset});
}

class Problem {
  final String id;
  final String? text;
  final String mediaURL;
  final String answer;
  final List<Hint> hints;
  final bool requiresCheck;
  final String? checkText;
  final String? checkImageURL;

  Problem({
    required this.id,
    this.text,
    required this.mediaURL,
    required this.answer,
    required this.hints,
    this.requiresCheck = false,
    this.checkText,
    this.checkImageURL,
  });
}

class Event {
  final String id;
  final String name;
  final List<Problem> problems;
  final int duration; // minutes
  final String? targetObjectText;
  // ... 他のフィールドは省略 ...

  Event({
    required this.id,
    required this.name,
    required this.problems,
    required this.duration,
    this.targetObjectText,
  });
}

// プレースホルダークラス (FirebaseServiceの代替)
class FirebaseService {
  static final FirebaseService shared = FirebaseService._internal();
  FirebaseService._internal();
  // 実際のFirebaseロジックは実装されていません
}

// ClearViewは削除（ClearPageを使用するため）

class GameOverView extends StatelessWidget {
  final String eventName;
  const GameOverView({required this.eventName, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ゲームオーバー')),
      body: Center(
        child: Text('$eventName は時間切れです...'),
      ),
    );
  }
}



// ===============================================
// 2. GameView (メイン画面)
// ===============================================

class GameView extends StatefulWidget {
  final Event event;
  final String teamId;

  const GameView({required this.event, this.teamId = 'default-team', super.key});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  int _currentProblemIndex = 0;
  late int _remainingTime; // 秒単位（イベント全体の残り時間）
  int _problemElapsedTime = 0; // 現在の問題の経過時間（秒）
  late DateTime _startTime; // ゲーム開始時刻
  Timer? _timer;
  String _answerText = '';
  Set<String> _displayedHints = {}; // Hint ID (String) を保持
  bool _showGameOverView = false;
  bool _shouldMoveToNextProblem = false; // 認証クリア後に次の問題へ遷移するフラグ
  bool _showCameraCheck = false; // カメラチェックシートの表示状態

  final TextEditingController _answerController = TextEditingController();

  Problem? get _currentProblem {
    if (_currentProblemIndex < 0 || _currentProblemIndex >= widget.event.problems.length) {
      debugPrint('⚠️ [GameView] _currentProblem: インデックスが範囲外です: $_currentProblemIndex / ${widget.event.problems.length}');
      return null;
    }
    return widget.event.problems[_currentProblemIndex];
  }

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.event.duration * 60; // 分を秒に変換
    _startTime = DateTime.now();
    
    // デバッグ: イベントと問題の情報を出力
    print('🎮 [GameView] initState called');
    print('   - Event ID: ${widget.event.id}');
    print('   - Event Name: ${widget.event.name}');
    print('   - Problems Count: ${widget.event.problems.length}');
    for (int i = 0; i < widget.event.problems.length; i++) {
      final problem = widget.event.problems[i];
      print('   - Problem $i:');
      print('     * ID: ${problem.id}');
      print('     * requiresCheck: ${problem.requiresCheck}');
      print('     * checkText: ${problem.checkText}');
      print('     * checkImageURL: ${problem.checkImageURL}');
    }
    
    // 挑戦回数をカウント（ゲーム開始時）
    _incrementAttemptCount();
    
    _startTimer();
  }
  
  // 挑戦回数をカウント
  Future<void> _incrementAttemptCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptCountKey = "attemptCount_${widget.event.id}";
      final currentAttemptCount = prefs.getInt(attemptCountKey) ?? 0;
      await prefs.setInt(attemptCountKey, currentAttemptCount + 1);
      print('💾 [GameView] 挑戦回数を更新しました: $attemptCountKey = ${currentAttemptCount + 1}');
    } catch (e) {
      print('❌ [GameView] 挑戦回数の更新エラー: $e');
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _answerController.dispose();
    super.dispose();
  }

  // プレイヤー名を取得 (SwiftのUserDefaultsの代替)
  // Future<String?> _getPlayerName() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final key = 'playerName_${widget.event.id}';
  //   return prefs.getString(key);
  // }

  // タイムカウントをHH:MM:SS形式に変換
  String _timeString(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // タイマー開始
  void _startTimer() {
    _stopTimer(); // 既存のタイマーを停止してから新しいタイマーを開始
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime -= 1;
          _problemElapsedTime += 1;
          _checkHints();
        } else {
          _handleTimeOver();
        }
      });
    });
  }

  // タイマー停止
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ヒント表示チェック
  void _checkHints() {
    final problem = _currentProblem;
    if (problem == null) return;
    
    for (final hint in problem.hints) {
      // timeOffsetは分単位なので、秒に変換して比較
      if ((hint.timeOffset * 60) <= _problemElapsedTime &&
          !_displayedHints.contains(hint.id)) {
        setState(() {
          _displayedHints.add(hint.id);
        });
      }
    }
  }

  // 回答チェック
  void _checkAnswer() {
    // マウント状態とコンテキストの確認
    if (!mounted) {
      debugPrint('⚠️ [GameView] _checkAnswer: Widget is not mounted');
      return;
    }
    
    // 問題の範囲チェック
    if (_currentProblemIndex < 0 || _currentProblemIndex >= widget.event.problems.length) {
      debugPrint('❌ [GameView] _checkAnswer: 問題インデックスが範囲外です: $_currentProblemIndex / ${widget.event.problems.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の読み込みにエラーが発生しました。')),
      );
      return;
    }
    
    try {
      _dismissKeyboard();

      final trimmedAnswer = _answerText.trim().toLowerCase();
      
      // 現在の問題の取得とnullチェック
      final problem = _currentProblem;
      if (problem == null) {
        debugPrint('❌ [GameView] _checkAnswer: 現在の問題が取得できません');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題の読み込みにエラーが発生しました。')),
        );
        return;
      }
      
      // 正解の取得とnullチェック
      final problemAnswer = problem.answer;
      if (problemAnswer.isEmpty) {
        debugPrint('❌ [GameView] _checkAnswer: 正解が設定されていません');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この問題には正解が設定されていません。')),
        );
        return;
      }
      
      final correctAnswer = problemAnswer.toLowerCase();
      
      // デバッグ: 現在の問題情報を出力
      print('🔍 [GameView] _checkAnswer called');
      print('   - 問題インデックス: $_currentProblemIndex');
      print('   - 問題ID: ${problem.id}');
      print('   - requiresCheck: ${problem.requiresCheck}');
      print('   - checkText: ${problem.checkText}');
      print('   - checkImageURL: ${problem.checkImageURL}');
      print('   - 入力された回答: "$trimmedAnswer"');
      print('   - 正解: "$correctAnswer"');

      if (trimmedAnswer == correctAnswer) {
        // 正解
        print('✅ [GameView] 問題 ${_currentProblemIndex + 1} の回答が正解でした');
        // 画像認証ページ滞在時もタイマーを継続するため、タイマーを停止しない
        
        // キーボードを閉じる
        _dismissKeyboard();
        
        // 画像認証が必要かどうかをチェック
        final lastProblemIndex = widget.event.problems.length - 1;
        final isLastProblem = _currentProblemIndex == lastProblemIndex;
        
        debugPrint('📸 [GameView] requiresCheck=${problem.requiresCheck}');
        debugPrint('📸 [GameView] isLastProblem=$isLastProblem');
        
        if (problem.requiresCheck) {
          // 画像認証が必要な場合: 画像認証ページへ遷移（タイマーは継続）
          debugPrint('📸 [GameView] 問題 ${_currentProblemIndex + 1} の画像認証ページへ遷移します（タイマー継続）');
          debugPrint('📸 [GameView] checkText=${problem.checkText}');
          debugPrint('📸 [GameView] checkImageURL=${problem.checkImageURL}');
          
          // キーボードが完全に閉じられ、UIが安定してから遷移する
          // SchedulerBindingを使用して、次のフレームで確実に実行
          SchedulerBinding.instance.addPostFrameCallback((_) {
            // さらに少し遅延を入れて、キーボードのアニメーションが完了してから遷移
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted || !context.mounted) {
                debugPrint('⚠️ [GameView] Widget or context is not mounted, cannot show camera check sheet');
                return;
              }
              
              try {
                debugPrint('📸 [GameView] _showCameraCheckSheetを呼び出します');
                _showCameraCheckSheet(context);
              } catch (e, stackTrace) {
                debugPrint('❌ [GameView] _showCameraCheckSheet呼び出しエラー: $e');
                debugPrint('スタックトレース: $stackTrace');
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('画面遷移に失敗しました: $e')),
                  );
                }
              }
            });
          });
        } else {
          // 画像認証が不要な場合: 画像認証ページをスキップ
          debugPrint('⏭️ [GameView] 画像認証がOFFのため、画像認証ページをスキップします');
          
          // キーボードが完全に閉じられ、UIが安定してから遷移する
          SchedulerBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted || !context.mounted) {
                debugPrint('⚠️ [GameView] Widget or context is not mounted');
                return;
              }
              
              try {
                if (isLastProblem) {
                  // 最後の問題の場合: クリアページへ遷移
                  debugPrint('🎉 [GameView] 最後の問題をクリアしました - クリアページへ遷移します');
                  _showClearScreen();
                } else {
                  // 次の問題がある場合: 次の問題へ遷移
                  debugPrint('➡️ [GameView] 次の問題へ遷移します');
                  _moveToNextProblem();
                }
              } catch (e, stackTrace) {
                debugPrint('❌ [GameView] 画面遷移エラー: $e');
                debugPrint('スタックトレース: $stackTrace');
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('画面遷移に失敗しました: $e')),
                  );
                }
              }
            });
          });
        }
      } else {
        // 不正解
        print('❌ [GameView] 回答が不正解でした');
        if (mounted) {
          setState(() {
            _answerText = '';
            _answerController.clear();
          });
          // 必要に応じてユーザーにフィードバックを表示 (e.g., SnackBar)
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('不正解です。もう一度お試しください。')),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [GameView] _checkAnswer エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回答チェック中にエラーが発生しました: $e')),
        );
      }
    }
  }

  // キーボードを閉じる (SwiftのdismissKeyboardの代替)
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // game_view.Problem を lib/models/problem.dart の Problem に変換
  lib_problem.Problem _convertProblemToLibProblem(Problem problem) {
    // デバッグ: 変換前の値を確認
    print('🔄 [GameView] _convertProblemToLibProblem');
    print('   - problem.id: ${problem.id}');
    print('   - problem.checkText: ${problem.checkText}');
    print('   - problem.checkImageURL: ${problem.checkImageURL}');
    print('   - problem.requiresCheck: ${problem.requiresCheck}');
    
    final converted = lib_problem.Problem(
      id: problem.id,
      text: problem.text,
      mediaURL: problem.mediaURL,
      answer: problem.answer,
      hints: problem.hints.map((h) => lib_hint.Hint(
        id: h.id,
        content: h.content,
        timeOffset: h.timeOffset,
      )).toList(),
      checkText: problem.checkText,
      checkImageURL: problem.checkImageURL,
      requiresCheck: problem.requiresCheck,
    );
    
    // デバッグ: 変換後の値を確認
    print('   - converted.checkImageURL: ${converted.checkImageURL}');
    
    return converted;
  }

  // カメラチェックページを表示
  void _showCameraCheckSheet(BuildContext context) {
    final problem = _currentProblem;
    if (problem == null) {
      print('❌ [GameView] _showCameraCheckSheet: 現在の問題が取得できません');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題の読み込みにエラーが発生しました。')),
        );
      }
      // 画像認証ページ滞在時もタイマーを継続するため、タイマーを停止しない
      return;
    }
    
    debugPrint('📸 [GameView] _showCameraCheckSheet called');
    debugPrint('   - context: $context');
    debugPrint('   - mounted: $mounted');
    debugPrint('   - problem: ${problem.id}');
    debugPrint('   - requiresCheck: ${problem.requiresCheck}');
    debugPrint('   - checkText: ${problem.checkText}');
    debugPrint('   - checkImageURL: ${problem.checkImageURL}');
    
    if (!mounted) {
      debugPrint('❌ [GameView] Widget is not mounted, cannot show camera check page');
      // 画像認証ページ滞在時もタイマーを継続するため、タイマーを停止しない
      return;
    }
    
    // BuildContextが有効か確認
    if (!context.mounted) {
      debugPrint('❌ [GameView] Context is not mounted, cannot show camera check page');
      // 画像認証ページ滞在時もタイマーを継続するため、タイマーを停止しない
      return;
    }
    
    // 次のフレームで確実に実行されるようにする
    // 呼び出し元でもaddPostFrameCallbackを使っているため、ここでは直接実行する
    // ただし、念のため少し遅延を入れて実行
    Future.delayed(const Duration(milliseconds: 100), () {
      // 再度チェック
      if (!mounted || !context.mounted) {
        debugPrint('❌ [GameView] Widget or context is not mounted after delay');
        // 画像認証ページ滞在時もタイマーを継続するため、タイマーを停止しない
        return;
      }
      
      try {
        // game_view.Problem を lib/models/problem.dart の Problem に変換
        final libProblem = _convertProblemToLibProblem(problem);
        
        debugPrint('📸 [GameView] Calling Navigator.push to CameraCheckPage...');
        final route = MaterialPageRoute(
          fullscreenDialog: true,
          builder: (BuildContext sheetContext) {
            debugPrint('📸 [GameView] Building CameraCheckPage');
            try {
              debugPrint('   - problem.id: ${libProblem.id}');
              debugPrint('   - problem.requiresCheck: ${libProblem.requiresCheck}');
              debugPrint('   - problem.checkText: ${libProblem.checkText}');
              debugPrint('   - problem.checkImageURL: ${libProblem.checkImageURL}');
              final lastProblemIndex = widget.event.problems.length - 1;
              final isLastProblem = _currentProblemIndex == lastProblemIndex;
              
              return CameraCheckPage(
                problem: libProblem,
                eventId: widget.event.id,
                problemIndex: _currentProblemIndex,
                teamId: widget.teamId,
                isLastProblem: isLastProblem,
                onApproved: () {
                  // 認証クリア: CameraCheckPageを閉じて、次の処理を行う
                  debugPrint('✅ [GameView] onApproved()が呼ばれました - 問題 ${_currentProblemIndex + 1} の画像認証がクリアされました');
                  debugPrint('🔍 [GameView] onApproved: 現在の問題インデックス=${_currentProblemIndex}, 全問題数=${widget.event.problems.length}');
                  debugPrint('🔍 [GameView] onApproved: 最後の問題か=${isLastProblem}');
                  
                  // 次のフレームで画面を閉じて次の処理を行う
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || !context.mounted) {
                      debugPrint('⚠️ [GameView] Widget or context is not mounted in onApproved callback');
                      return;
                    }
                    
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (!mounted || !context.mounted) {
                        debugPrint('⚠️ [GameView] Widget or context is not mounted after delay in onApproved');
                        return;
                      }
                      
                      // CameraCheckPageを閉じる
                      if (Navigator.of(context).canPop()) {
                        debugPrint('✅ [GameView] CameraCheckPageを閉じます');
                        Navigator.of(context).pop();
                      } else {
                        debugPrint('⚠️ [GameView] Cannot pop CameraCheckPage - Navigator stack is empty or invalid');
                      }
                      
                      // 画面が閉じられた後に次の処理を行う
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (!mounted || !context.mounted) {
                          debugPrint('⚠️ [GameView] Widget or context is not mounted after pop in onApproved');
                          return;
                        }
                        
                        if (isLastProblem) {
                          // 最後の問題の場合: タイマーを停止してクリアページへ遷移
                          debugPrint('🎉 [GameView] 最後の問題をクリアしました - クリアページへ遷移します');
                          _stopTimer();
                          _showClearScreen();
                        } else {
                          // 最後の問題でない場合: 次の問題へ遷移
                          debugPrint('➡️ [GameView] 次の問題へ遷移します');
                          _moveToNextProblem();
                        }
                      });
                    });
                  });
                },
                onRejected: () {
                  // 認証失敗: チェックページに留まる（CameraCheckPage内で処理）
                  debugPrint('❌ [GameView] 画像認証が拒否されました');
                },
                onNavigateToClearPage: null, // onApproved()内で処理するため不要
              );
            } catch (e, stackTrace) {
              debugPrint('❌ [GameView] CameraCheckPage構築エラー: $e');
              debugPrint('スタックトレース: $stackTrace');
              // エラーが発生した場合は、エラー表示画面を返す
              return Scaffold(
                appBar: AppBar(title: const Text('エラー')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('画像認証ページの読み込みに失敗しました'),
                      const SizedBox(height: 8),
                      Text('${e.toString()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }
          },
        );
        
        // Navigator.pushを実行する前に、もう一度コンテキストをチェック
        if (!mounted || !context.mounted) {
          debugPrint('❌ [GameView] Context became invalid just before Navigator.push');
          _startTimer();
          return;
        }
        
        Navigator.of(context).push(route).then((result) {
          // 画面が閉じられたときに実行される（ユーザーが手動で閉じた場合など）
          debugPrint('📸 [GameView] CameraCheckPage closed (manually or error)');
          debugPrint('📸 [GameView] mounted = $mounted');
          
          if (!mounted) {
            debugPrint('⚠️ [GameView] Widget is not mounted after CameraCheckPage closed');
            return;
          }
          
          _dismissKeyboard();
          // onApproved()が呼ばれていない場合（手動で閉じられた場合など）は何もしない
          debugPrint('⚠️ [GameView] CameraCheckPageが手動で閉じられた可能性があります');
        }).catchError((error, stackTrace) {
          debugPrint('❌ [GameView] Error showing camera check page: $error');
          debugPrint('❌ [GameView] Stack trace: $stackTrace');
          // 画像認証ページ滞在時もタイマーを継続しているため、再開不要
        });
      } catch (e, stackTrace) {
        debugPrint('❌ [GameView] Exception in _showCameraCheckSheet: $e');
        debugPrint('❌ [GameView] Stack trace: $stackTrace');
        // 画像認証ページ滞在時もタイマーを継続しているため、再開不要
      }
    });
  }

  // 次の問題へ遷移
  void _moveToNextProblem() {
    debugPrint('🔄 [GameView] _moveToNextProblem called');
    if (!mounted) {
      debugPrint('⚠️ [GameView] _moveToNextProblem: Widget is not mounted');
      return;
    }
    
    // 現在の問題が最後の問題かどうかをチェック
    // 注意: _currentProblemIndexは0ベースなので、最後の問題はlength - 1
    // 画像認証が完了した時点で、現在の問題が最後の問題かどうかを判定する
    // 例: 問題が3つある場合（インデックス0,1,2）、最後の問題はインデックス2
    // インデックス2をクリアした後、_currentProblemIndexは2のままなので、isLastProblemはtrueになる
    final lastProblemIndex = widget.event.problems.length - 1;
    final isLastProblem = _currentProblemIndex == lastProblemIndex;
    debugPrint('🔍 [GameView] _moveToNextProblem: 現在の問題インデックス=${_currentProblemIndex}, 全問題数=${widget.event.problems.length}');
    debugPrint('🔍 [GameView] _moveToNextProblem: 最後の問題のインデックス=${lastProblemIndex}');
    debugPrint('🔍 [GameView] _moveToNextProblem: 最後の問題か=${isLastProblem} (条件: $_currentProblemIndex == ${lastProblemIndex})');

    // この関数は「次の問題がある場合」のみ呼ばれるため、常に次の問題へ遷移する
    // 最後の問題の場合は、呼び出し元（Navigator.push().then()コールバック）で既に_showClearScreen()が呼ばれている
    final nextProblemIndex = _currentProblemIndex + 1;
    debugPrint('➡️ [GameView] 次の問題（インデックス: $nextProblemIndex）へ遷移します');
    
    if (mounted) {
      debugPrint('🔄 [GameView] Updating state for next problem');
      setState(() {
        _currentProblemIndex = nextProblemIndex;
        _answerText = '';
        _answerController.clear();
        _displayedHints.clear();
        _problemElapsedTime = 0; // 問題ごとのタイマーをリセット
      });
      _startTimer(); // タイマーを再開
      debugPrint('✅ [GameView] 問題 ${_currentProblemIndex + 1} へ遷移しました');
    } else {
      debugPrint('⚠️ [GameView] Widget became unmounted during _moveToNextProblem');
    }
  }

  // タイムオーバー処理
  void _handleTimeOver() {
    _stopTimer();
    Vibration.vibrate(duration: 500); // バイブレーション

    _showGameOverScreen();
  }

  // 脱出タイムを計算
  double _calculateEscapeTime() {
    return DateTime.now().difference(_startTime).inSeconds.toDouble();
  }

  // クリア画面への遷移
  void _showClearScreen() {
    debugPrint('🎉 [GameView] _showClearScreen() called');
    
    if (!mounted) {
      debugPrint('⚠️ [GameView] _showClearScreen: Widget is not mounted');
      return;
    }
    
    if (!context.mounted) {
      debugPrint('⚠️ [GameView] _showClearScreen: Context is not mounted');
      return;
    }
    
    final escapeTime = _calculateEscapeTime();
    debugPrint('🎉 [GameView] クリア画面へ遷移します。脱出時間: $escapeTime秒');
    debugPrint('🎉 [GameView] Navigator.pushReplacement()を呼び出します');
    
    try {
      // クリアページを表示（GameView以前のルートを全て削除し、最初のルートだけを残す）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) {
            debugPrint('✅ [GameView] ClearPageを構築します');
            try {
              return ClearPage(
                eventName: widget.event.name,
                eventId: widget.event.id,
                escapeTime: escapeTime,
                onNavigateToEventDetail: (lib_models.Event event) {
                  // lib_models.Event を event_model.Event に変換
                  try {
                    final convertedEvent = _convertLibEventToEventModel(event);
                    return IndividualEventScreen(event: convertedEvent);
                  } catch (e, stackTrace) {
                    debugPrint('⚠️ [GameView] イベント変換エラー: $e');
                    debugPrint('スタックトレース: $stackTrace');
                    // エラーが発生した場合は、元のイベント情報を使用してエラー画面を表示
                    return Scaffold(
                      appBar: AppBar(title: const Text('エラー')),
                      body: Center(
                        child: Text('イベント情報の読み込みに失敗しました: $e'),
                      ),
                    );
                  }
                },
                onDismiss: () {
                  // メイン画面（イベント一覧）に戻る
                  if (mounted && context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              );
            } catch (e, stackTrace) {
              debugPrint('❌ [GameView] ClearPage構築エラー: $e');
              debugPrint('スタックトレース: $stackTrace');
              // エラーが発生した場合は、シンプルなクリア画面を表示
              return Scaffold(
                appBar: AppBar(title: const Text('クリア！')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎉 脱出成功！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text('${widget.event.name}をクリアしました'),
                      const SizedBox(height: 10),
                      Text('脱出時間: ${escapeTime.toStringAsFixed(2)}秒'),
                    ],
                  ),
                ),
              );
            }
          },
        ),
        (Route<dynamic> route) => route.isFirst, // 最初のルートのみ残す
      );
      debugPrint('✅ [GameView] Navigator.pushAndRemoveUntil()実行完了');
    } catch (navError, navStackTrace) {
      debugPrint('❌ [GameView] Navigator.pushAndRemoveUntilエラー: $navError');
      debugPrint('スタックトレース: $navStackTrace');
      // Navigator.pushAndRemoveUntilが失敗した場合、通常のpushを試みる
      if (mounted && context.mounted) {
        try {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('クリア！')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎉 脱出成功！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text('${widget.event.name}をクリアしました'),
                      const SizedBox(height: 10),
                      Text('脱出時間: ${escapeTime.toStringAsFixed(2)}秒'),
                    ],
                  ),
                ),
              ),
            ),
          );
        } catch (fallbackError, fallbackStackTrace) {
          debugPrint('❌ [GameView] フォールバック画面遷移もエラー: $fallbackError');
          debugPrint('スタックトレース: $fallbackStackTrace');
        }
      }
    }
  }
  
  // lib_models.Event を event_model.Event に変換するヘルパー関数
  event_model.Event _convertLibEventToEventModel(lib_models.Event libEvent) {
    return event_model.Event(
      id: libEvent.id,
      name: libEvent.name,
      problems: libEvent.problems.map((p) {
        // hintsを変換
        List<dynamic> convertedHints = [];
        for (var h in p.hints) {
          if (h is Map) {
            convertedHints.add(h);
          } else {
            // Hintオブジェクトの場合はtoJson()を使用
            try {
              convertedHints.add((h as dynamic).toJson());
            } catch (e) {
              // toJson()が使えない場合は空のMapを使用
              convertedHints.add({'id': '', 'content': '', 'timeOffset': 0});
            }
          }
        }
        
        return event_model.Problem(
          id: p.id,
          text: p.text ?? '',
          mediaURL: p.mediaURL,
          answer: p.answer,
          hints: convertedHints,
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
    );
  }

  // ゲームオーバー画面への遷移
  void _showGameOverScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => GameOverPage(
          eventName: widget.event.name,
          eventId: widget.event.id,
        ),
      ),
      (Route<dynamic> route) => false, // スタックを全てクリア
    );
  }

  @override
  Widget build(BuildContext context) {
    // ゲームオーバー画面が表示される場合は、メインのUIを構築しない
    if (_showGameOverView) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // 戻るボタンを非表示
        title: const Text('ゲーム進行中'),
      ),
      body: Column(
        children: [
          // タイムカウント表示
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.watch_later_outlined,
                  color: _remainingTime <= 60 ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  _timeString(_remainingTime),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: _remainingTime <= 60 ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // スクロール可能な問題コンテンツ
          Expanded(
            child: _currentProblem == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          '問題の読み込みにエラーが発生しました',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 問題番号表示
                          Text(
                            '問題 ${_currentProblemIndex + 1} / ${widget.event.problems.length}',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // 問題テキスト
                          if (_currentProblem!.text != null)
                            Text(
                              _currentProblem!.text!,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 20),

                          // メディア表示（動画または画像）
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth > 0 
                                        ? constraints.maxWidth 
                                        : MediaQuery.of(context).size.width - 40,
                                    maxHeight: 300,
                                    minHeight: 100,
                                  ),
                                  child: MediaView(mediaURL: _currentProblem!.mediaURL),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 表示されたヒント
                          if (_displayedHints.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "ヒント",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange),
                                ),
                                const SizedBox(height: 8),
                                ..._currentProblem!.hints
                                    .where((h) => _displayedHints.contains(h.id))
                                    .map((hint) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              hint.content,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        )),
                              ],
                            ),
                          const SizedBox(height: 20),

                    // 回答入力フィールド
                    const Text(
                      "回答",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _answerController,
                      onChanged: (text) => _answerText = text,
                      decoration: InputDecoration(
                        hintText: '答えを入力してください',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      // onSubmittedを削除: Enterキーでは送信しない。回答するボタンのみで送信
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "回答する",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================================
// 3. MediaView (メディア表示)
// ===============================================

class MediaView extends StatefulWidget {
  final String mediaURL;

  const MediaView({required this.mediaURL, super.key});

  @override
  State<MediaView> createState() => _MediaViewState();
}

enum MediaType { video, image, youtube, unknown }

class _MediaViewState extends State<MediaView> {
  MediaType _mediaType = MediaType.unknown;
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _determineMediaType(widget.mediaURL);
    _setupMedia();
  }

  @override
  void didUpdateWidget(covariant MediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaURL != widget.mediaURL) {
      _disposeControllers();
      _determineMediaType(widget.mediaURL);
      _setupMedia();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    _videoController = null;
    _youtubeController = null;
  }

  void _determineMediaType(String url) {
    _mediaType = MediaType.unknown;
    if (url.isEmpty) return;

    final lowercased = url.toLowerCase();

    // YouTubeのURLを最初にチェック
    if (lowercased.contains("youtube.com") || lowercased.contains("youtu.be")) {
      _mediaType = MediaType.youtube;
    }
    // 動画ファイル形式をチェック
    else if (lowercased.contains(".mp4") ||
        lowercased.contains(".mov") ||
        lowercased.contains(".m4v") ||
        lowercased.contains(".avi") ||
        lowercased.contains(".webm") ||
        lowercased.contains("video")) {
      _mediaType = MediaType.video;
    }
    // 画像ファイル形式をチェック
    else if (lowercased.contains(".jpg") ||
        lowercased.contains(".jpeg") ||
        lowercased.contains(".png") ||
        lowercased.contains(".gif") ||
        lowercased.contains(".webp") ||
        lowercased.contains(".svg") ||
        lowercased.contains("image")) {
      _mediaType = MediaType.image;
    }
    // HTTP/HTTPSで始まるURLはデフォルトで画像として扱う（Swiftのロジックに倣う）
    else if (url.startsWith("http://") || url.startsWith("https://")) {
       _mediaType = MediaType.image;
    }
  }

  String? _getYoutubeVideoId(String urlString) {
    return YoutubePlayer.convertUrlToId(urlString);
  }

  void _setupMedia() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    switch (_mediaType) {
      case MediaType.video:
        try {
          final url = Uri.parse(widget.mediaURL);
          _videoController = VideoPlayerController.networkUrl(url);
          await _videoController!.initialize();
          _videoController!.setLooping(true);
          _videoController!.play();
          setState(() {
            _isLoading = false;
          });
          print('✅ [MediaView] 動画の準備が完了しました: ${widget.mediaURL}');
        } catch (e) {
          print('❌ [MediaView] 動画の読み込みに失敗: $e');
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        break;

      case MediaType.youtube:
        final videoId = _getYoutubeVideoId(widget.mediaURL);
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
              disableDragSeek: false,
              loop: true,
              isLive: false,
              forceHD: false,
              enableCaption: false,
            ),
          );
          _youtubeController!.addListener(() {
            if (_youtubeController!.value.hasError) {
              setState(() => _hasError = true);
              print('❌ [MediaView] YouTube Player Error: ${_youtubeController!.value}'); // error field not available
            }
          });
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        break;

      case MediaType.image:
        // Image.networkは自動で読み込みを行うため、特別なセットアップは不要
        setState(() {
          _isLoading = false;
        });
        break;

      case MediaType.unknown:
        setState(() {
          _isLoading = false;
        });
        break;
    }
  }

  Widget _placeholderView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo,
            size: 50,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            _hasError ? "メディアの読み込みに失敗しました" : "メディアなし",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 制約が有界でない場合はプレースホルダーを返す
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight ||
            constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return Container(
            constraints: const BoxConstraints(
              minHeight: 100,
              maxHeight: 300,
            ),
            child: _placeholderView(),
          );
        }
        
        final maxWidth = constraints.maxWidth > 0 
            ? constraints.maxWidth 
            : double.infinity;
        final maxHeight = constraints.maxHeight > 0 
            ? constraints.maxHeight 
            : 300.0;
        final minHeight = constraints.minHeight > 0 
            ? constraints.minHeight 
            : 100.0;

        if (_isLoading) {
          return Container(
            constraints: BoxConstraints(
              minHeight: minHeight,
              maxHeight: maxHeight,
            ),
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    _mediaType == MediaType.video ? "動画を読み込み中..." : "メディアを読み込み中...",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        if (_hasError || _mediaType == MediaType.unknown) {
          return Container(
            constraints: BoxConstraints(
              minHeight: minHeight,
              maxHeight: maxHeight,
            ),
            child: _placeholderView(),
          );
        }

        switch (_mediaType) {
          case MediaType.video:
            if (_videoController == null || !_videoController!.value.isInitialized) {
              return Container(
                constraints: BoxConstraints(
                  minHeight: minHeight,
                  maxHeight: maxHeight,
                ),
                child: _placeholderView(),
              );
            }
            final aspectRatio = _videoController!.value.aspectRatio;
            double width = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 400.0;
            double height = width / aspectRatio;
            
            if (height > maxHeight) {
              height = maxHeight;
              width = height * aspectRatio;
            }
            
            // 最小サイズを確保
            if (height < minHeight) {
              height = minHeight;
              width = height * aspectRatio;
            }
            
            // widthが無効な場合はデフォルト値を使用
            final finalWidth = width.isFinite && width > 0 ? width : 400.0;
            final finalHeight = height.isFinite && height > 0 ? height : 225.0;
            
            return RepaintBoundary(
              child: SizedBox(
                width: finalWidth,
                height: finalHeight,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            );

          case MediaType.youtube:
            // YouTubeの標準的なアスペクト比は16:9
            final aspectRatio = 16.0 / 9.0;
            double width = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 400.0;
            double height = width / aspectRatio;
            
            if (height > maxHeight) {
              height = maxHeight;
              width = height * aspectRatio;
            }
            
            // 最小サイズを確保
            if (height < minHeight) {
              height = minHeight;
              width = height * aspectRatio;
            }
            
            // 有効なサイズを確保
            final finalWidth = width.isFinite && width > 0 ? width : 400.0;
            final finalHeight = height.isFinite && height > 0 ? height : 225.0;
            
            return RepaintBoundary(
              child: SizedBox(
                width: finalWidth,
                height: finalHeight,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: YoutubePlayer(
                    controller: _youtubeController!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Colors.blueAccent,
                    onReady: () {
                      print('✅ [MediaView] YouTubeプレイヤーの準備が完了');
                    },
                    onEnded: (metaData) {
                      _youtubeController!.load(_youtubeController!.initialVideoId); // ループ再生
                    },
                  ),
                ),
              ),
            );

          case MediaType.image:
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minHeight,
                maxHeight: maxHeight,
              ),
              child: Image.network(
                widget.mediaURL,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return _placeholderView();
                },
              ),
            );

          case MediaType.unknown:
            return Container(
              constraints: BoxConstraints(
                minHeight: minHeight,
                maxHeight: maxHeight,
              ),
              child: _placeholderView(),
            );
        }
      },
    );
  }
}

// ===============================================
// 4. Preview (テスト用のデータ)
// ===============================================

void main() {
  // アプリケーションのエントリーポイント
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // プレビュー用のダミーデータ (Swiftの#Previewに対応)
    final dummyEvent = Event(
      id: 'preview-event-id',
      name: 'サンプルイベント',
      duration: 60, // 60分
      problems: [
        Problem(
          id: 'problem-1-id',
          text: "問題1: この動画に隠されたメッセージを解読せよ。",
          mediaURL:
              "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_10mb.mp4", // ダミーの動画URL
          answer: "答え1",
          requiresCheck: true,
          checkText: "赤いベンチを撮影してください",
          hints: [
            Hint(id: 'hint-1-1', content: "ヒント1: 動画の最初の方に注意深く目を凝らして。", timeOffset: 1), // 1分後
            Hint(id: 'hint-1-2', content: "ヒント2: メッセージは逆さまになっている。", timeOffset: 3), // 3分後
          ],
        ),
        Problem(
          id: 'problem-2-id',
          text: "問題2: 謎の画像に隠された数字を見つけ出せ。",
          mediaURL:
              "https://picsum.photos/id/237/800/600", // ダミーの画像URL
          answer: "答え2",
          requiresCheck: false,
          hints: [],
        ),
      ],
    );

    return MaterialApp(
      title: 'Dassyutsu Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: NavigationWrapper(event: dummyEvent),
    );
  }
}

// NavigationStackの代わりとして、GameViewを直接表示するラッパー
class NavigationWrapper extends StatelessWidget {
  final Event event;
  const NavigationWrapper({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    return GameView(event: event, teamId: 'preview-team');
  }
}

// Widgetの制約を簡略化するエクステンション (SwiftUIの.frame().cornerRadius()に対応)
extension WidgetExtensions on Widget {
  Widget constraints(BoxConstraints constraints) {
    return Container(constraints: constraints, child: this);
  }

  Widget clipRRect(BorderRadius borderRadius) {
    return ClipRRect(borderRadius: borderRadius, child: this);
  }
}