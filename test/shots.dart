import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screen tests at phone size; with SHOTS=dir they also write PNGs.
const phone = Size(412, 892);
final shotsDir = Platform.environment['SHOTS'];

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await family('Cinzel', [
    'assets/fonts/Cinzel-400.ttf',
    'assets/fonts/Cinzel-600.ttf',
    'assets/fonts/Cinzel-700.ttf',
  ]);
  await family('Jost', [
    'assets/fonts/Jost-400.ttf',
    'assets/fonts/Jost-500.ttf',
    'assets/fonts/Jost-600.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 48, bottom: 32);
  addTearDown(tester.view.reset);
}

/// Writes the whole screen to SHOTS/[name].png (when SHOTS is set).
Future<void> shot(WidgetTester tester, String name) async {
  final dir = shotsDir;
  if (dir == null) return;
  final render = tester.binding.renderViews.first;
  final layer = render.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & (phone * 2), pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
