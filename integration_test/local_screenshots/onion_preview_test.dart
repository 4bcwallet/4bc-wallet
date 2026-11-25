// Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 25 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Plays an animation for the Tor settings screen the way that screen plays it,
// with the app's own Lottie player, on the app's dark grey ground: the file's
// markers say where each part lies (see _TorAnimatedButton in
// lib/pages/settings_views/global_settings_view/tor_settings/tor_settings_view.dart).
// The order: rest for a second, the plug (frame 0 to "connecting-start"), the
// connecting loop twice, the passage into "connected", the connected loop three
// times, the disconnect, rest for a second, and then the failed part once.
//
// The picture is drawn 293 points wide (two thirds of the screen, as on the
// screen) with a small copy of 100 points under it, and the name of the state
// that plays is written under the big one. The name is the preview's own text,
// not the file's. A still is saved at the middle of each state, named by the
// state. It does not start the app.
//
// Run:
//   flutter test integration_test/local_screenshots/onion_preview_test.dart -d <simulator id>
//     --dart-define=LOTTIE_FILE=/absolute/onion_animation.json
//     --dart-define=SHOT_DIR=/absolute/folder
//     [--dart-define=FRAMES=0,40,75]  only stills of these frames (no playing), saved as frame-<n>.png
//     [--dart-define=DENSE=true]      four stills in each state, at a fifth, two, three, four fifths
//     [--dart-define=GROUND=0xFF2B2D31]
// A simulator app reads and writes the Mac's own disk, so the file need not be packed.

import 'dart:async';
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

class _Player extends StatefulWidget {
  const _Player({super.key, required this.file});

  final String file;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  final Completer<LottieComposition> _loaded = Completer();
  String label = "";

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _name(String text) => setState(() => label = text);

  /// Plays from marker (or frame number) [from] to [to], as the screen does.
  Future<void> _play(
    String state, {
    required String from,
    required String to,
    required bool repeat,
    int count = 1,
    Future<void> Function(String state, Duration length)? onStart,
  }) async {
    final composition = await _loaded.future;
    final start = double.tryParse(from) ?? composition.getMarker(from)!.start;
    final end = composition.getMarker(to)!.start;
    final length = composition.duration * (end - start);
    _name(state);
    controller.value = start;
    if (onStart != null) unawaited(onStart(state, length * count));
    if (repeat) {
      await controller.repeat(
        min: start,
        max: end,
        period: length,
        count: count,
      );
    } else {
      await controller.animateTo(end, duration: length);
    }
  }

  /// The whole sequence of the Tor screen, in order.
  Future<void> sequence(Future<void> Function(String state, Duration length) onStart) async {
    final composition = await _loaded.future;
    controller.value = 0;
    _name("rest");
    unawaited(onStart("rest", const Duration(seconds: 1)));
    await Future<void>.delayed(const Duration(seconds: 1));
    await _play("plug", from: "0.0", to: "connecting-start", repeat: false, onStart: onStart);
    await _play("connecting", from: "connecting-start", to: "connecting-end", repeat: true, count: 2, onStart: onStart);
    // the passage starts where the loop stands: here at its end
    final here = controller.value;
    _name("passage");
    final end = composition.getMarker("connected-start")!.start;
    unawaited(onStart("passage", composition.duration * (end - here)));
    await controller.animateTo(end, duration: composition.duration * (end - here));
    await _play("connected", from: "connected-start", to: "connected-end", repeat: true, count: 3, onStart: onStart);
    await _play("disconnecting", from: "disconnection-start", to: "disconnection-end", repeat: false, onStart: onStart);
    controller.reset();
    _name("rest");
    unawaited(onStart("rest-again", const Duration(seconds: 1)));
    await Future<void>.delayed(const Duration(seconds: 1));
    await _play("failed", from: "failed-start", to: "failed-end", repeat: false, onStart: onStart);
    controller.reset();
    _name("rest");
  }

  Future<void> goTo(int frame) async {
    final composition = await _loaded.future;
    controller.value = (frame - composition.startFrame) / (composition.endFrame - composition.startFrame);
    _name("frame $frame");
  }

  @override
  Widget build(BuildContext context) {
    final big = MediaQuery.of(context).size.width / 1.5;
    Widget lottie(double size, {bool report = false}) => SizedBox(
          width: size,
          height: size,
          child: Lottie.file(
            File(widget.file),
            controller: controller,
            width: size,
            onLoaded: (c) {
              if (report && !_loaded.isCompleted) {
                controller.duration = c.duration;
                _loaded.complete(c);
              }
            },
          ),
        );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        lottie(big, report: true),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9DA0A6),
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 18),
        lottie(100),
      ],
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets("play an animation as the Tor screen does", (tester) async {
    const file = String.fromEnvironment("LOTTIE_FILE");
    const shotDir = String.fromEnvironment("SHOT_DIR");
    const frames = String.fromEnvironment("FRAMES");
    const dense = bool.fromEnvironment("DENSE");
    const ground = int.fromEnvironment("GROUND", defaultValue: 0xFF2B2D31);
    expect(file, isNotEmpty, reason: "no LOTTIE_FILE given");
    if (shotDir.isNotEmpty) Directory(shotDir).createSync(recursive: true);

    final key = GlobalKey<_PlayerState>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(ground),
          body: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: _Player(key: key, file: file),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    final player = key.currentState!;

    if (frames.isNotEmpty) {
      // Only stills of the given frames: exact moments, nothing plays.
      for (final f in frames.split(",").where((s) => s.isNotEmpty)) {
        await player.goTo(int.parse(f));
        await tester.pump(const Duration(milliseconds: 250));
        await _still(tester, "$shotDir/frame-${f.padLeft(3, '0')}.png");
      }
      return;
    }

    // Stills in the middle of each state (or four in each, when DENSE).
    final shots = <Future<void>>[];
    Future<void> onStart(String state, Duration length) async {
      final fractions = dense ? [0.2, 0.4, 0.6, 0.8] : [0.5];
      var at = 0.0;
      for (var n = 0; n < fractions.length; n++) {
        await Future<void>.delayed(length * (fractions[n] - at));
        at = fractions[n];
        final name = dense ? "$state-${n + 1}" : state;
        if (shotDir.isNotEmpty) {
          await _still(tester, "$shotDir/$name.png");
        }
      }
    }

    // ignore: avoid_print
    print("PLAY");
    var done = false;
    unawaited(player.sequence((s, l) {
      final f = onStart(s, l);
      shots.add(f);
      return f;
    }).whenComplete(() => done = true));
    while (!done) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await Future.wait(shots);
    await tester.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print("DONE");
    await tester.pump(const Duration(seconds: 2));
  });
}
