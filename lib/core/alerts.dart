import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'session.dart';

/// "Phase over" notifications, scheduled ahead for every phase end so they
/// arrive while the app is closed. Rescheduled whenever the session changes.
class Alerts {
  Alerts._();
  static final instance = Alerts._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _exact = false;

  static const _icon = 'ic_stat_sisyphus';
  static const _terracotta = Color(0xFFB0502F);

  /// Phase changes that should be heard (sound, heads-up).
  static AndroidNotificationDetails _alerting({bool live = false, DateTime? endsAt}) =>
      AndroidNotificationDetails(
        'phases',
        'Phase changes',
        channelDescription: 'When an ascent or a rest ends.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        icon: _icon,
        color: _terracotta,
        ongoing: live,
        autoCancel: !live,
        usesChronometer: endsAt != null,
        chronometerCountDown: endsAt != null,
        when: endsAt?.millisecondsSinceEpoch,
        showWhen: endsAt != null,
      );

  /// The quiet live countdown that sits in the shade during a session.
  static AndroidNotificationDetails _quiet({DateTime? endsAt}) => AndroidNotificationDetails(
    'session',
    'Session countdown',
    channelDescription: 'The time left in the current ascent or rest.',
    importance: Importance.low,
    priority: Priority.low,
    icon: _icon,
    color: _terracotta,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    silent: true,
    usesChronometer: endsAt != null,
    chronometerCountDown: endsAt != null,
    when: endsAt?.millisecondsSinceEpoch,
    showWhen: endsAt != null,
  );

  static const _ios = DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive);

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_sisyphus'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Asks for permission the first time a session starts.
  Future<void> ask() async {
    if (!_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
        _exact = await android.canScheduleExactNotifications() ?? false;
      }
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    } catch (_) {}
  }

  /// Android 14+: exact alarms are off by default; this opens the switch.
  Future<bool> askExact() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      await android.requestExactAlarmsPermission();
      _exact = await android.canScheduleExactNotifications() ?? false;
    } catch (_) {}
    return _exact;
  }

  Future<bool> exactAllowed() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      return _exact = await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Lines up every notification for [s]: on Android with [countdown], a
  /// live countdown now and, at each phase end, the next phase's countdown
  /// (alerting when [alerts]); otherwise plain alerts at each phase end.
  Future<void> schedule(Session? s, {required bool alerts, required bool countdown}) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (s == null || s.finished) return;
      final android = defaultTargetPlatform == TargetPlatform.android;
      final live = android && countdown;
      if (!alerts && !live) return;
      final now = DateTime.now();
      final mode = _exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      if (live) {
        final (title, body) = _now(s, now);
        await _plugin.show(
          id: _liveId,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(android: _quiet(endsAt: s.running ? s.endsAt : null)),
        );
      }
      var id = 1;
      for (final u in s.upcoming()) {
        if (!u.at.isAfter(now)) continue;
        final last = u.index >= s.phaseCount - 1;
        final next = u.index + 1;
        final continues = !last && s.autoContinue;
        final (title, body) = _text(s, u.index);
        NotificationDetails details;
        if (live) {
          final endsAt = continues ? u.at.add(s.phaseLength(next)) : null;
          details = NotificationDetails(
            android: alerts
                ? _alerting(live: continues, endsAt: endsAt)
                : (continues ? _quiet(endsAt: endsAt) : _alerting()),
          );
        } else {
          details = NotificationDetails(android: _alerting(), iOS: _ios);
        }
        await _plugin.zonedSchedule(
          id: live ? _liveId : id++,
          scheduledDate: tz.TZDateTime.from(u.at, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: mode,
          title: title,
          body: body,
        );
      }
    } catch (_) {
      // Alerts are a nicety; the timer itself never depends on them.
    }
  }

  static const _liveId = 100;

  /// The live notification's text right now.
  (String, String) _now(Session s, DateTime now) {
    final climb = 'climb ${s.climb} of ${s.climbs}';
    if (s.waiting) {
      return (s.phase == Phase.rest ? 'Ready to rest' : 'The stone waits', 'Open Sisyphus to carry on.');
    }
    final name = s.phase == Phase.ascent ? 'Ascending' : (s.isLongRest() ? 'Long rest' : 'Resting');
    if (s.paused) {
      return ('Paused · $name', '${_mmss(s.remaining(now))} left · $climb');
    }
    return (name, '$climb${s.label != null ? ' · ${s.label}' : ''}');
  }

  static String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  (String, String) _text(Session s, int endingIndex) {
    final last = endingIndex >= s.phaseCount - 1;
    if (last) return ('The summit', 'The boulder rests at the top. So can you.');
    if (endingIndex.isEven) {
      final long = s.isLongRest(endingIndex + 1);
      final mins = (s.phaseLength(endingIndex + 1) * s.speed).inMinutes;
      return (
        long ? 'Long rest' : 'Rest',
        'The boulder rolls back down. ${long ? 'A long rest' : 'Rest'} in the valley for $mins min.',
      );
    }
    return ('Ascend', 'Back to the stone: climb ${endingIndex ~/ 2 + 2} of ${s.climbs}.');
  }
}
