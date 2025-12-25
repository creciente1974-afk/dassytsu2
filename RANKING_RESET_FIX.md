# ランキングリセット機能の修正

## 問題の概要

問題編集ページ（`ProblemManagementPage`）でランキングリセットボタンを押下しても、リセットが反映されない問題がありました。

## 原因

`EventTitleEditView`の`_resetRanking()`メソッドは以下の処理を行っていました：

1. ✅ Firebaseに`records: []`を保存
2. ✅ `widget.onUpdate?.call(updatedEvent)`を呼び出して親に通知

しかし、`ProblemManagementPage`の`_navigateToEventTitleEdit`メソッドでは：

- `onUpdate`コールバック内でローカルの`_currentEvent`を更新しているだけ
- 画面から戻ってきた後、Firebaseから最新データを再読み込みしていない

そのため、ランキングがリセットされても、画面に反映されない問題が発生していました。

## 修正内容

### `lib/lib/pages/problem_management_page.dart`

1. **`_reloadEventFromFirebase()`メソッドを追加**
   - Firebaseから最新のイベントデータを取得
   - ローカル状態を更新
   - 親ウィジェットに更新を通知

2. **`_navigateToEventTitleEdit()`メソッドを修正**
   - 画面から戻ってきた後、既存イベント編集の場合は`_reloadEventFromFirebase()`を呼び出す
   - これにより、ランキングリセットなどの変更が確実に反映される

## 修正後の動作

1. ランキングリセットボタンを押下
2. `EventTitleEditView`の`_resetRanking()`が実行される
3. Firebaseに`records: []`が保存される
4. `onUpdate`コールバックが呼び出される
5. 画面から戻る
6. `_reloadEventFromFirebase()`が実行される
7. Firebaseから最新データを取得して画面を更新
8. ✅ ランキングがリセットされた状態が表示される

## 確認事項

- [x] `ProblemManagementPage`でランキングリセットが反映される
- [x] `EventListPage`は既に`_loadEvents()`で再読み込みしているため問題なし
- [x] `IndividualEventScreen`は`_loadEvent()`メソッドを持っており、必要に応じて再読み込み可能

## 関連ファイル

- `lib/lib/pages/problem_management_page.dart` - 修正済み
- `lib/event_title_edit_view.dart` - ランキングリセット機能の実装
- `lib/event_list_page.dart` - 問題なし（既に再読み込み実装済み）




