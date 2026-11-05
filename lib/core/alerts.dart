import 'package:flutter/foundation.dart';
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

  static const _channel = AndroidNotificationDetails(
    'phases',
    'Phase changes',
    channelDescription: 'When an ascent or a rest ends.',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    icon: 'ic_stat_sisyphus',
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
  );

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

  Future<void> schedule(Session? s) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (s == null || s.finished) return;
      final now = DateTime.now();
      var id = 1;
      for (final u in s.upcoming()) {
        if (!u.at.isAfter(now)) continue;
        final (title, body) = _text(s, u.index);
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(u.at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: _exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      }
    } catch (_) {
      // Alerts are a nicety; the timer itself never depends on them.
    }
  }

  (String, String) _text(Session s, int endingIndex) {
    final last = endingIndex >= s.phaseCount - 1;
    if (last) return ('The summit', 'The boulder rests at the top. So can you.');
    if (endingIndex.isEven) {
      return ('Rest', 'The boulder rolls back down. Come down to the valley for ${s.restMinutes} min.');
    }
    return ('Ascend', 'Back to the stone: climb ${endingIndex ~/ 2 + 2} of ${s.climbs}.');
  }
}
