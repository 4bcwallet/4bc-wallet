// Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 23 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Walks the first screens of a freshly installed app in the iOS simulator and
// saves a picture of each into the app's Documents folder, from where the
// lead's script copies them. It creates NO wallet and shows NO recovery
// phrase: it stops at the list of coins.
//
// Run:
//   flutter test integration_test/local_screenshots/walk_test.dart -d <simulator id>

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stackduo/main.dart' as app;
import 'package:stackduo/widgets/custom_pin_put/pin_keyboard.dart';

late Directory _outDir;
int _counter = 0;

Future<void> _wait(WidgetTester tester, [int tenths = 20]) async {
  for (int i = 0; i < tenths; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
}) async {
  for (int i = 0; i < seconds * 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _wait(tester, 15);
  final RenderView view = tester.binding.renderViews.first;
  final OffsetLayer layer = view.debugLayer! as OffsetLayer;
  final double ratio = view.flutterView.devicePixelRatio;
  // The root layer already applies the device pixel ratio, so the bounds are
  // given in physical pixels and no further scaling is asked for.
  final ui.Image image = await layer.toImage(
    Offset.zero & (view.size * ratio),
    pixelRatio: 1.0,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  _counter++;
  final file = File(
    "${_outDir.path}/${_counter.toString().padLeft(2, '0')}-$name.png",
  );
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  // ignore: avoid_print
  print("SHOT ${file.path}");
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(await _waitFor(tester, finder), isTrue, reason: 'no "$text"');
  await tester.ensureVisible(finder.first);
  await _wait(tester, 3);
  await tester.tap(finder.first, warnIfMissed: false);
  await _wait(tester, 10);
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final digit in pin.split("")) {
    final key = find.byWidgetPredicate(
      (w) => w is NumberKey && w.number == digit,
    );
    expect(await _waitFor(tester, key, seconds: 10), isTrue);
    await tester.tap(key.first, warnIfMissed: false);
    await _wait(tester, 3);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("walk the first screens and save pictures", (tester) async {
    // The test app is removed from the simulator when the test ends, and its
    // Documents folder with it. A simulator app can write to the Mac's own
    // disk, so the pictures go straight to the folder given with
    // --dart-define=SHOT_DIR=/absolute/folder (kept if it is given).
    const shotDir = String.fromEnvironment("SHOT_DIR");
    if (shotDir.isNotEmpty) {
      _outDir = Directory(shotDir);
    } else {
      final docs = await getApplicationDocumentsDirectory();
      _outDir = Directory("${docs.path}/local_screenshots");
    }
    _outDir.createSync(recursive: true);

    final errors = <Object>[];
    runZonedGuarded(() => app.main(const []), (e, s) => errors.add(e));

    // 1. Welcome.
    expect(
      await _waitFor(tester, find.text("Get started"), seconds: 60),
      isTrue,
    );
    await _shot(tester, "welcome");

    // 2. Privacy choice. "Incognito" preloads no exchange data.
    await _tapText(tester, "Get started");
    expect(await _waitFor(tester, find.text("Incognito")), isTrue);
    await _shot(tester, "privacy-choice");
    await _tapText(tester, "Incognito");
    await _shot(tester, "privacy-choice-incognito");
    await _tapText(tester, "Continue");

    // 3. PIN. A throwaway PIN for a throwaway install.
    expect(await _waitFor(tester, find.text("Create a PIN")), isTrue);
    await _shot(tester, "create-pin");
    await _typePin(tester, "1379");
    final submit = find.byType(SubmitKey);
    if (submit.evaluate().isNotEmpty) {
      await tester.tap(submit.first, warnIfMissed: false);
    }
    await _wait(tester, 15);
    if (await _waitFor(tester, find.text("Confirm PIN"), seconds: 10)) {
      await _shot(tester, "confirm-pin");
      await _typePin(tester, "1379");
      final submit2 = find.byType(SubmitKey);
      if (submit2.evaluate().isNotEmpty) {
        await tester.tap(submit2.first, warnIfMissed: false);
      }
    }
    await _wait(tester, 20);
    if (find.text("SKIP").evaluate().isNotEmpty) {
      await _shot(tester, "biometrics-question");
      await _tapText(tester, "SKIP");
    }

    // 4. Home, no wallets yet.
    final addWallet = find.text("Add Wallet");
    final reachedHome = await _waitFor(tester, addWallet, seconds: 40);
    await _shot(tester, reachedHome ? "home-empty" : "after-pin");
    if (!reachedHome) return;

    // 5. The list of coins this edition offers. The walk ends here.
    await _tapText(tester, "Add Wallet");
    await _waitFor(tester, find.text("Coins"), seconds: 20);
    await _shot(tester, "add-wallet-coins");
    final testnet = find.text("Testnet");
    if (testnet.evaluate().isNotEmpty) {
      await tester.ensureVisible(testnet.first);
      await _shot(tester, "add-wallet-testnet-coins");
    }
  });
}
