import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../core/alerts.dart';
import '../core/app_info.dart';
import '../core/debug.dart';
import '../core/scope.dart';
import '../core/settings.dart';
import '../core/stats.dart';
import '../core/theme.dart';
import 'summit_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _versionTaps = 0;

  Future<void> _unlock() async {
    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DEBUG'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Password'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('OPEN'))],
      ),
    );
    if (!mounted || pw == null) return;
    if (DebugGate.check(pw)) {
      AppScope.of(context).settings.debugOpen = true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The gods say no.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.settings;
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
          children: [
            const _Header('Look'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Day'),
                    icon: Icon(Icons.wb_sunny_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Night'),
                    icon: Icon(Icons.nightlight_outlined),
                  ),
                ],
                selected: {s.theme},
                onSelectionChanged: (v) => s.theme = v.first,
                showSelectedIcon: false,
              ),
            ),
            ListTile(
              title: const Text('Frame rate'),
              subtitle: const Text('30 fps uses less battery.'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 60, label: Text('60')),
                  ButtonSegment(value: 30, label: Text('30')),
                ],
                selected: {s.fps},
                onSelectionChanged: (v) => s.fps = v.first,
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            SwitchListTile(
              title: const Text('Still scenes'),
              subtitle: const Text('Saves battery: the mountain stops moving.'),
              value: s.stillScenes,
              onChanged: (v) => s.stillScenes = v,
            ),
            const _Header('The climb'),
            SwitchListTile(
              title: const Text('Keep going'),
              subtitle: const Text('Start the next rest or ascent on its own.'),
              value: s.autoContinue,
              onChanged: (v) => s.autoContinue = v,
            ),
            SwitchListTile(
              title: const Text('Alerts'),
              subtitle: const Text('A notification when a phase ends and the app is closed.'),
              value: s.alerts,
              onChanged: (v) {
                s.alerts = v;
                if (v) Alerts.instance.ask();
              },
            ),
            if (Platform.isAndroid && s.alerts)
              FutureBuilder<bool>(
                future: Alerts.instance.exactAllowed(),
                builder: (context, snap) => snap.data == false
                    ? ListTile(
                        title: const Text('On-time alerts'),
                        subtitle: const Text(
                          'Android may delay alerts by a few minutes unless you allow alarms.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Alerts.instance.askExact();
                          setState(() {});
                        },
                      )
                    : const SizedBox(),
              ),
            if (Platform.isAndroid)
              SwitchListTile(
                title: const Text('Countdown in notifications'),
                subtitle: const Text('The time left, live in the notification shade.'),
                value: s.countdown,
                onChanged: (v) {
                  s.countdown = v;
                  if (v) Alerts.instance.ask();
                },
              ),
            SwitchListTile(
              title: const Text('Vibrate'),
              subtitle: const Text('A thud when a phase changes.'),
              value: s.vibrate,
              onChanged: (v) => s.vibrate = v,
            ),
            SwitchListTile(
              title: const Text('Keep the screen on'),
              subtitle: const Text('While a session is open. Uses more battery.'),
              value: s.keepAwake,
              onChanged: (v) => s.keepAwake = v,
            ),
            const _Header('Long rest'),
            SwitchListTile(
              title: const Text('Take a long rest'),
              subtitle: Text('A longer rest after every ${s.longEvery} climbs.'),
              value: s.longRest,
              onChanged: (v) => s.longRest = v,
            ),
            if (s.longRest) ...[
              _NumberTile(
                title: 'Long rest',
                value: s.longMinutes,
                unit: 'min',
                onChanged: (v) => s.longMinutes = v,
                step: 5,
                min: Settings.minLong,
                max: Settings.maxLong,
              ),
              _NumberTile(
                title: 'After every',
                value: s.longEvery,
                unit: 'climbs',
                onChanged: (v) => s.longEvery = v,
                step: 1,
                min: 2,
                max: 6,
              ),
            ],
            const _Header('Sound'),
            SwitchListTile(
              title: const Text('Ambient sound'),
              subtitle: const Text('A soft wind, up the mountain and down. Mixes with your music.'),
              value: s.sound,
              onChanged: (v) => s.sound = v,
            ),
            if (s.debugOpen) ..._debug(context),
            const _Header('About'),
            ListTile(
              title: const Text('Version'),
              trailing: Text(AppInfo.version, style: Type.number(p.muted, size: 15)),
              onTap: () {
                if (++_versionTaps >= 7) {
                  _versionTaps = 0;
                  if (!s.debugOpen) _unlock();
                }
              },
            ),
            const ListTile(
              title: Text('No accounts, no ads, no tracking.'),
              subtitle: Text('Everything stays on this phone.'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _debug(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.settings;
    return [
      const _Header('Debug'),
      ListTile(
        title: const Text('Time speed (new sessions)'),
        trailing: DropdownButton<int>(
          value: [1, 10, 60, 300].contains(s.speed) ? s.speed : 1,
          items: [
            for (final v in [1, 10, 60, 300]) DropdownMenuItem(value: v, child: Text('${v}x')),
          ],
          onChanged: (v) => s.speed = v ?? 1,
        ),
      ),
      ListTile(
        title: const Text('Preview the summit'),
        onTap: () {
          final now = DateTime.now();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SummitScreen(
                record: SessionRecord(
                  start: now.subtract(const Duration(hours: 2)),
                  end: now,
                  focus: const Duration(minutes: 100),
                  climbsDone: 4,
                  climbsPlanned: 4,
                  skips: 0,
                  shoves: 7,
                  summited: true,
                ),
              ),
            ),
          );
        },
      ),
      ListTile(title: const Text('Reset stats'), onTap: () => scope.stats.reset()),
      ListTile(title: const Text('Close Debug'), onTap: () => s.debugOpen = false),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
    child: Text(text.toUpperCase(), style: Type.label(Palette.of(context).terracotta, size: 11.5)),
  );
}

/// A setting with - / + buttons.
class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.onChanged,
    required this.step,
    required this.min,
    required this.max,
  });
  final String title, unit;
  final int value, step, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 70,
            child: Text('$value $unit', textAlign: TextAlign.center, style: Type.number(p.ink, size: 15)),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
