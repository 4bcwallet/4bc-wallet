// Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 23 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Walks the first screens of a freshly installed app in the iOS simulator and
// saves a picture of each into the app's Documents folder, from where the
// lead's script copies them. It creates NO wallet and shows NO recovery
// phrase: from the list of coins it opens "Add ... wallet" of each coin (and
// "Name your ... wallet" of the first, where it types nothing and never
// presses "Next"), then goes back and pictures the settings screens
// (settings, about, manage nodes, currency, advanced, support).
//
// With --dart-define=TEST_WALLET=true it takes another road after the empty home
// screen: it makes throwaway wallets on Bitcoin's test network and pictures
// the screens only a wallet shows (see _testWalletScreens below). The
// recovery phrase is never on the screen on that road either.
//
// The package name in the imports below is the configured app's (pubspec.yaml,
// set by scripts/app_config/configure_<app>.sh): "fourbcwallet" for 4bc Wallet.
//
// Run:
//   flutter test integration_test/local_screenshots/walk_test.dart -d <simulator id>

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fourbcwallet/main.dart' as app;
import 'package:fourbcwallet/pages/wallet_view/wallet_view.dart';
import 'package:fourbcwallet/pages/wallets_view/sub_widgets/favorite_card.dart';
import 'package:fourbcwallet/providers/global/secure_store_provider.dart';
import 'package:fourbcwallet/providers/providers.dart';
import 'package:fourbcwallet/wallets/crypto_currency/crypto_currency.dart';
import 'package:fourbcwallet/wallets/isar/models/wallet_info.dart';
import 'package:fourbcwallet/wallets/wallet/wallet.dart';
import 'package:fourbcwallet/widgets/custom_buttons/app_bar_icon_button.dart';
import 'package:fourbcwallet/widgets/custom_pin_put/pin_keyboard.dart';

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

// The app draws its own back arrow (AppBarBackButton), not the system's.
Future<void> _back(WidgetTester tester) async {
  final back = find.byType(AppBarBackButton);
  expect(await _waitFor(tester, back, seconds: 10), isTrue, reason: "no back");
  await tester.tap(back.first, warnIfMissed: false);
}

// Makes throwaway wallets on Bitcoin's test network (testnet4), so that the
// screens only a wallet shows can be pictured: the home screen with its
// favourite cards, and each wallet's own screen with its balance card. One
// wallet is made, or as many as --dart-define=TEST_WALLETS=<number> says (up
// to five): this edition gives each wallet of a coin its own card picture.
//
// A wallet is made by the app's own code, as "Create new wallet" makes it,
// but without the screens that show and verify the recovery phrase: the phrase
// is generated in memory, handed to the wallet, and never shown, read back,
// printed or logged here. The wallets live in the test app, which is removed
// from the simulator when the test ends; they are empty and nothing is sent
// to them.
//
// On this road the test is reported as failed after its last picture: when the
// test's app is taken down, the app's own code disposes two of its watchers a
// second time ("A Watcher<WalletInfo> was used after being disposed"). The
// pictures are taken before that and are whole.
Future<void> _testWalletScreens(WidgetTester tester, Finder onHome) async {
  const names = ["Spending", "Savings", "Holding", "Travel", "Gifts"];
  const asked = int.fromEnvironment("TEST_WALLETS", defaultValue: 1);
  final count = asked.clamp(1, names.length);

  final container = ProviderScope.containerOf(
    tester.element(onHome.first),
    listen: false,
  );
  final coin = Bitcoin(CryptoCurrencyNetwork.test4);
  final prefs = container.read(prefsChangeNotifierProvider);
  final nodes = container.read(nodeServiceChangeNotifierProvider);
  final isar = container.read(mainDBProvider).isar;

  prefs.showTestNetCoins = true;
  if (nodes.getPrimaryNodeFor(currency: coin) == null) {
    await nodes.save(coin.defaultNode(isPrimary: true), null, false);
  }

  final ids = <String>[];
  for (int i = 0; i < count; i++) {
    final info = WalletInfo.createNew(
      coin: coin,
      name: count == 1 ? "Test wallet" : names[i],
    );
    final wallet = await Wallet.create(
      walletInfo: info,
      mainDB: container.read(mainDBProvider),
      secureStorageInterface: container.read(secureStoreProvider),
      nodeService: nodes,
      prefs: prefs,
      mnemonicPassphrase: "",
      mnemonic: bip39.generateMnemonic(strength: 128),
    );
    await wallet.init();
    await wallet.info.setMnemonicVerified(isar: isar);
    container.read(pWallets).addWallet(wallet);
    await wallet.info.updateIsFavourite(true, isar: isar);
    ids.add(info.walletId);
  }

  // The home screen: the favourite cards lie side by side; each is brought to
  // the front in turn.
  expect(
    await _waitFor(tester, find.byType(FavoriteCard), seconds: 30),
    isTrue,
    reason: "no favourite card on the home screen",
  );
  await _wait(tester, 20);
  await _shot(tester, "home-test-wallet");
  final row = tester.getCenter(find.byType(FavoriteCard).first).dy;
  for (int i = 1; i < count; i++) {
    // One card's width to the left, from the middle of the row of cards.
    await tester.dragFrom(Offset(260, row), const Offset(-225, 0));
    await _wait(tester, 10);
    await _shot(tester, "home-test-wallet-card-${i + 1}");
  }

  // Each wallet's own screen, opened as a tap on its card opens it.
  final navigator = Navigator.of(tester.element(find.byType(FavoriteCard).first));
  for (int i = 0; i < count; i++) {
    unawaited(navigator.pushNamed(WalletView.routeName, arguments: ids[i]));
    expect(
      await _waitFor(tester, find.text("Transactions"), seconds: 60),
      isTrue,
      reason: "the wallet's screen did not open",
    );
    await _wait(tester, 30);
    await _shot(
      tester,
      count == 1 ? "wallet-screen-test-wallet" : "wallet-screen-${i + 1}",
    );
    await _back(tester);
    await _waitFor(tester, find.byType(FavoriteCard), seconds: 20);
    await _wait(tester, 10);
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

    // Optional: draw the app at another screen's size, for pictures of how
    // it lays out there (for example a folding phone's outer screen), with
    //   --dart-define=VIEW_W=1398 --dart-define=VIEW_H=2034
    //   --dart-define=VIEW_RATIO=3 --dart-define=VIEW_TOP=54 --dart-define=VIEW_BOTTOM=34
    // W and H are physical pixels, RATIO the pixels per point, TOP and BOTTOM
    // the safe-area insets in points. This is the app's own drawing at that
    // size on the simulated phone at hand, not a run on that other device.
    const viewW = int.fromEnvironment("VIEW_W");
    const viewH = int.fromEnvironment("VIEW_H");
    if (viewW > 0 && viewH > 0) {
      const ratio = int.fromEnvironment("VIEW_RATIO", defaultValue: 3);
      const top = int.fromEnvironment("VIEW_TOP");
      const bottom = int.fromEnvironment("VIEW_BOTTOM");
      tester.view.devicePixelRatio = ratio.toDouble();
      tester.view.physicalSize = Size(viewW.toDouble(), viewH.toDouble());
      final insets = FakeViewPadding(
        top: top.toDouble() * ratio,
        bottom: bottom.toDouble() * ratio,
      );
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      addTearDown(tester.view.reset);
    }

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

    // 4b. The other road: a throwaway test-network wallet and its two screens.
    if (const bool.fromEnvironment("TEST_WALLET")) {
      await _testWalletScreens(tester, addWallet);
      return;
    }

    // 5. The list of coins this edition offers. The walk ends here.
    await _tapText(tester, "Add Wallet");
    await _waitFor(tester, find.text("Coins"), seconds: 20);
    await _shot(tester, "add-wallet-coins");
    final testnet = find.text("Testnet");
    if (testnet.evaluate().isNotEmpty) {
      await tester.ensureVisible(testnet.first);
      await _shot(tester, "add-wallet-testnet-coins");
    }

    // 5b. "Add ... wallet" of each coin: the screen that shows the coin's big
    // picture. For the first coin also "Name your ... wallet", which shows the
    // same picture small. No name is typed and "Next" is never pressed there,
    // so no wallet is made and no recovery phrase is ever on the screen.
    bool first = true;
    for (final coin in ["Bitcoin", "Monero", "Bitcoin Frost"]) {
      // A row of the list reads "Bitcoin (BTC)".
      final entry = find.textContaining("$coin (");
      if (entry.evaluate().isEmpty) continue;
      await tester.ensureVisible(entry.first);
      await _wait(tester, 3);
      await tester.tap(entry.first, warnIfMissed: false);
      await _wait(tester, 5);
      await _tapText(tester, "Next");
      if (!await _waitFor(tester, find.text("Add $coin wallet"), seconds: 15)) {
        return;
      }
      final slug = coin.toLowerCase().replaceAll(" ", "-");
      await _shot(tester, "add-$slug-wallet");
      if (first) {
        first = false;
        await _tapText(tester, "Create new wallet");
        if (await _waitFor(tester, find.textContaining("Name your"), seconds: 10)) {
          await _shot(tester, "name-your-$slug-wallet");
          await _back(tester);
          await _wait(tester, 10);
        }
      }
      await _back(tester);
      await _wait(tester, 10);
      if (!await _waitFor(tester, find.text("Coins"), seconds: 10)) return;
    }

    // 6. Back home, then the settings screens. Nothing is changed in them.
    await _back(tester);
    await _wait(tester, 10);
    final settings = find.byKey(const Key("walletsViewSettingsButton"));
    if (!await _waitFor(tester, settings, seconds: 10)) return;
    await tester.tap(settings.first, warnIfMissed: false);
    if (!await _waitFor(tester, find.text("About"), seconds: 10)) return;
    await _shot(tester, "settings");
    for (final title in [
      "About",
      "Manage nodes",
      "Currency",
      "Advanced",
      "Support",
    ]) {
      final item = find.text(title);
      if (item.evaluate().isEmpty) continue;
      await tester.ensureVisible(item.first);
      await _wait(tester, 3);
      await tester.tap(item.first, warnIfMissed: false);
      await _wait(tester, 20);
      await _shot(tester, "settings-${title.toLowerCase().replaceAll(" ", "-")}");
      await _back(tester);
      await _wait(tester, 10);
      if (!await _waitFor(tester, find.text("About"), seconds: 10)) return;
    }
  });
}
