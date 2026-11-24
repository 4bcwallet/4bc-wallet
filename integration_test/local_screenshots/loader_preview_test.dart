// Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 24 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Shows Lottie animations with the app's own Lottie player, at the sizes the
// app shows its loader (half the screen's width at start, 100 and 50 points
// elsewhere), on the app's ground. It does not start the app.
//
// It saves still pictures at set moments and then keeps the animations
// running on the screen for a while, so that the simulated phone's screen can
// be recorded: stills cannot show whether a motion is smooth.
//
// Run:
//   flutter test integration_test/local_screenshots/loader_preview_test.dart -d <simulator id>
//     --dart-define=LOTTIE_FILES=/absolute/a.json,/absolute/b.json
//     --dart-define=SHOT_DIR=/absolute/folder
//     [--dart-define=HOLD=20]     seconds on the screen after the stills
//     [--dart-define=GROUND=0xFF2B2D31]
// A simulator app reads and writes the Mac's own disk, so the files need not
// be packed into the app.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lottie/lottie.dart';

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

  testWidgets("show the given Lottie files", (tester) async {
    const files = String.fromEnvironment("LOTTIE_FILES");
    const shotDir = String.fromEnvironment("SHOT_DIR");
    const hold = int.fromEnvironment("HOLD", defaultValue: 20);
    const ground = int.fromEnvironment("GROUND", defaultValue: 0xFF2B2D31);
    final paths = files.split(",").where((p) => p.isNotEmpty).toList();
    expect(paths, isNotEmpty, reason: "no LOTTIE_FILES given");
    if (shotDir.isNotEmpty) Directory(shotDir).createSync(recursive: true);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            final half = MediaQuery.of(context).size.width * 0.5;
            return Scaffold(
              backgroundColor: const Color(ground),
              body: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final path in paths)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (final size in [half, 100.0, 50.0])
                            SizedBox(
                              width: size,
                              height: size,
                              child: Lottie.file(
                                File(path),
                                animate: true,
                                repeat: true,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    // Stills: twelve moments, a fifth of a second apart.
    await tester.pump(const Duration(milliseconds: 600));
    if (shotDir.isNotEmpty) {
      for (int i = 0; i < 12; i++) {
        await _still(tester, "$shotDir/still-${i.toString().padLeft(2, '0')}.png");
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    // On the screen, moving, for the recording.
    // ignore: avoid_print
    print("HOLD $hold seconds");
    final end = DateTime.now().add(const Duration(seconds: hold));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });
}
