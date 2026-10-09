import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central "the world may have changed" tick.
///
/// Pages listen to [liveSyncProvider] and re-fetch their data on every
/// tick so a long-running app session picks up new articles, deleted
/// rows, and bookmark changes without the user having to pull-to-
/// refresh or navigate away and back.
///
/// Why not WebSockets / SSE?
/// -------------------------
/// The backend's RSS ingest + Puku processing cron runs every 5
/// minutes. Polling at 60s catches every new article within a minute
/// of arrival, which is well under the source's natural cadence.
/// Adding an SSE channel would mean new backend infra (auth, fan-out,
/// reconnection logic) for a UX gain the user can't perceive. The
/// 60-second tick is the right trade-off.
///
/// Lifecycle integration
/// ---------------------
/// The timer only runs while the app is in the foreground. When the
/// app is paused (user backgrounded it), [pause] is called and the
/// timer stops so we don't waste battery or hammer the API. When
/// the app resumes, [resume] restarts the timer and fires one
/// immediate tick so the user sees fresh data the moment they come
/// back to the app — not 60 seconds later.
class LiveSync extends ChangeNotifier {
  LiveSync({this.interval = const Duration(seconds: 60)});

  /// Polling cadence. 60s is the sweet spot: well under the 5-minute
  /// backend ingest cadence, light enough that the average phone
  /// won't notice the network chatter.
  final Duration interval;

  Timer? _timer;
  bool _running = false;

  /// True while the timer is active. Read by widgets (e.g. the feed's
  /// "LIVE" indicator) if they want to show a sync state.
  bool get isRunning => _running;

  /// Start the periodic tick. Idempotent — calling while already
  /// running is a no-op.
  void start() {
    if (_running) return;
    _running = true;
    _scheduleNext();
    notifyListeners();
  }

  /// Stop the periodic tick without firing any more updates.
  /// Idempotent.
  void pause() {
    _timer?.cancel();
    _timer = null;
    if (_running) {
      _running = false;
      notifyListeners();
    }
  }

  /// Resume the tick and fire one immediate notification so the UI
  /// picks up whatever changed while the app was backgrounded. If we
  /// were already running this just re-syncs the timer.
  void resume() {
    final wasRunning = _running;
    _timer?.cancel();
    _timer = null;
    _running = true;
    _scheduleNext();
    if (!wasRunning) {
      // First time since pause — fire listeners so the feed/page
      // refreshes immediately instead of waiting up to [interval] for
      // the next scheduled tick.
      notifyListeners();
    }
  }

  void _scheduleNext() {
    _timer = Timer.periodic(interval, (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Riverpod surface. Pages do ``ref.listen(liveSyncProvider, (_, __) {
/// ref.invalidate(_myProvider); })`` to be notified on every tick.
final liveSyncProvider = ChangeNotifierProvider<LiveSync>((ref) {
  final sync = LiveSync();
  ref.onDispose(sync.dispose);
  return sync;
});
