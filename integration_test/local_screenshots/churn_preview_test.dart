// Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 25 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Shows this edition's figure of the "Churning progress" screen by itself, on
// the app's ground: once at the size that screen draws it (200 points high)
// and once larger. That screen belongs to a Monero wallet, and a Monero wallet
// cannot be made in the simulator, so this is the widget alone and not the
// screen. It does not start the app.
//
// It saves a few stills and then keeps the figure moving on the screen for a
// while, so that the simulated phone's screen can be recorded.
//
// Run:
//   flutter test integration_test/local_screenshots/churn_preview_test.dart -d <simulator id>
//     --dart-define=PICTURES=/absolute/folder   (holds the figure's two pictures)
//     --dart-define=SHOT_DIR=/absolute/folder
//     [--dart-define=HOLD=20]     seconds on the screen after the stills

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fourbcwallet/local_fourbc/churn_figure.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _still(WidgetTester tester, String file) async {
  final RenderView view = tester.binding.renderViews.first;
  final OffsetLayer layer = view.debugLayer! as OffsetLayer;
  final double ratio = view.flutterView.devicePixelRatio;
  final ui.Image image = await layer.toImage(
    Offset.zero & (view.size * ratio),
    pixelRatio: 1.0,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(file).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  // ignore: avoid_print
  print("SHOT $file");
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets("show the Churn figure", (tester) async {
    const pictures = String.fromEnvironment("PICTURES");
    const shotDir = String.fromEnvironment("SHOT_DIR");
    const hold = int.fromEnvironment("HOLD", defaultValue: 20);
    expect(pictures, isNotEmpty, reason: "no PICTURES folder given");
    if (shotDir.isNotEmpty) Directory(shotDir).createSync(recursive: true);

    const label = TextStyle(color: Color(0xFF9DA0A6), fontSize: 13);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Color(0xFF2B2D31),
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text("as on the screen: 200 points high", style: label),
                    FourbcChurnFigure(height: 200, pictureFolder: pictures),
                    Text("larger, to see the drawing: 380 points", style: label),
                    FourbcChurnFigure(height: 380, pictureFolder: pictures),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 800));
    if (shotDir.isNotEmpty) {
      for (int i = 0; i < 6; i++) {
        await _still(tester, "$shotDir/still-$i.png");
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // ignore: avoid_print
    print("HOLD $hold seconds");
    final end = DateTime.now().add(const Duration(seconds: hold));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });
}
