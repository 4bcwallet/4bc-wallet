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
// With --dart-define=SWEEP=true as well (and TEST_WALLET=true, best with
// TEST_WALLETS=2) it continues after the wallet screens with a third road,
// _sweepScreens below: it pictures the other screens a user can reach without
// any coins. The road never opens a screen that shows a recovery phrase or a
// key, and never presses a button that sends, signs, deletes, creates or
// restores anything (the comments in _sweepScreens say which ones it leaves).
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
import 'package:fourbcwallet/pages/home_view/home_view.dart';
import 'package:fourbcwallet/pages/manage_favorites_view/manage_favorites_view.dart';
import 'package:fourbcwallet/pages/pinpad_views/lock_screen_view.dart';
import 'package:fourbcwallet/pages/settings_views/global_settings_view/global_settings_view.dart';
import 'package:fourbcwallet/pages/settings_views/global_settings_view/security_views/auto_lock_timeout_settings_view.dart';
import 'package:fourbcwallet/pages/settings_views/global_settings_view/syncing_preferences_views/syncing_options_view.dart';
import 'package:fourbcwallet/pages/wallet_view/wallet_view.dart';
import 'package:fourbcwallet/pages/wallets_view/wallets_overview.dart';
import 'package:fourbcwallet/pages/wallets_view/sub_widgets/favorite_card.dart';
import 'package:fourbcwallet/providers/global/secure_store_provider.dart';
import 'package:fourbcwallet/providers/providers.dart';
import 'package:fourbcwallet/wallets/crypto_currency/crypto_currency.dart';
import 'package:fourbcwallet/wallets/isar/models/wallet_info.dart';
import 'package:fourbcwallet/wallets/wallet/wallet.dart';
import 'package:fourbcwallet/widgets/custom_buttons/app_bar_icon_button.dart';
import 'package:fourbcwallet/widgets/custom_pin_put/pin_keyboard.dart';
import 'package:fourbcwallet/widgets/node_card.dart';

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

  if (const bool.fromEnvironment("SWEEP")) {
    await _sweepScreens(tester, navigator, container, ids, coin);
  }
}

// ---------------------------------------------------------------------------
// The third road (--dart-define=SWEEP=true): every other screen a user can
// reach without coins. Each group of pictures is one "step": if something in
// a step cannot be found or opened, the step is reported in the log with
// "SWEEP step failed", the app is taken back to the screen the step started
// from, and the walk goes on with the next step.
// ---------------------------------------------------------------------------

// Goes back, screen by screen, to the screen with this route name.
Future<void> _popTo(
  WidgetTester tester,
  NavigatorState navigator,
  String routeName,
) async {
  navigator.popUntil((r) => r.isFirst || r.settings.name == routeName);
  await _wait(tester, 10);
}

// Runs one group of pictures. Whatever happens, the app ends on the screen
// named by [returnTo].
Future<void> _step(
  WidgetTester tester,
  NavigatorState navigator,
  String what,
  String returnTo,
  Future<void> Function() body,
) async {
  try {
    await body();
  } catch (e) {
    final text = e.toString().replaceAll("\n", " ");
    // ignore: avoid_print
    print("SWEEP step failed: $what: ${text.length > 160 ? text.substring(0, 160) : text}");
  }
  await _popTo(tester, navigator, returnTo);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  expect(await _waitFor(tester, finder, seconds: 10), isTrue, reason: 'no key "$key"');
  await tester.tap(finder.first, warnIfMissed: false);
  await _wait(tester, 10);
}

// Goes back one screen.
Future<void> _backOne(WidgetTester tester, NavigatorState navigator) async {
  navigator.pop();
  await _wait(tester, 10);
}

// Finds a text drawn by Text or by RichText (the app's blue text buttons are
// drawn as RichText, which find.text alone does not see).
Finder _anyText(String text) => find.text(text, findRichText: true);

Future<void> _tapAny(WidgetTester tester, String text) async {
  final finder = _anyText(text);
  expect(await _waitFor(tester, finder, seconds: 15), isTrue, reason: 'no "$text"');
  await tester.ensureVisible(finder.first);
  await _wait(tester, 3);
  await tester.tap(finder.first, warnIfMissed: false);
  await _wait(tester, 10);
}

// Taps the row [title] and pictures the screen it opens. A picture is taken
// only after [settle] tenths of a second, for screens that load something.
Future<void> _rowShot(
  WidgetTester tester,
  String title,
  String shotName, {
  int settle = 15,
}) async {
  await _tapAny(tester, title);
  await _wait(tester, settle);
  await _shot(tester, shotName);
}

Future<void> _sweepScreens(
  WidgetTester tester,
  NavigatorState navigator,
  ProviderContainer container,
  List<String> ids,
  Bitcoin coin,
) async {
  final walletId = ids.first;
  const wallet = WalletView.routeName;
  const home = HomeView.routeName;
  const settings = GlobalSettingsView.routeName;

  // ---- A wallet's own screens (the first wallet) ----
  unawaited(navigator.pushNamed(WalletView.routeName, arguments: walletId));
  expect(await _waitFor(tester, find.text("Transactions"), seconds: 60), isTrue);
  await _wait(tester, 30);

  // The row-of-bars sign: network status. "Rescan" there is never pressed.
  await _step(tester, navigator, "network status", wallet, () async {
    await _tapKey(tester, "walletViewRadioButton");
    await _wait(tester, 20);
    await _shot(tester, "wallet-network-status");
  });

  // The bell of a wallet.
  await _step(tester, navigator, "wallet alerts", wallet, () async {
    await _tapKey(tester, "walletViewAlertsButton");
    await _shot(tester, "wallet-alerts");
  });

  // "See all" above the transaction list (the list is empty).
  await _step(tester, navigator, "all transactions", wallet, () async {
    await _rowShot(tester, "See all", "wallet-all-transactions");
  });

  // "More": the sheet, then the plain view behind "Sign/Verify" (the form is
  // only looked at: "Sign" and "Verify" are never pressed). "PayNym" is never
  // pressed: it asks a server for the wallet's nym and can offer to claim one.
  await _step(tester, navigator, "more menu", wallet, () async {
    await _tapText(tester, "More");
    await _wait(tester, 10);
    await _shot(tester, "wallet-more-menu");
    await _rowShot(tester, "Sign/Verify", "wallet-sign-verify");
  });
  // Close the sheet again: a tap on the dark cover above it.
  await _step(tester, navigator, "close more menu", wallet, () async {
    await tester.tapAt(const Offset(200, 500));
    await _wait(tester, 10);
  });

  // Receive: the screen, the "Address type" choice opened, the three-dots
  // menu and the address list behind it, and "Advanced options". "Generate new
  // address" and "Copy address" are never pressed.
  await _step(tester, navigator, "receive", wallet, () async {
    await _tapAny(tester, "Receive");
    await _wait(tester, 30);
    await _shot(tester, "receive");
    try {
      final dropdown = find.byWidgetPredicate(
        (w) => w.runtimeType.toString().startsWith("DropdownButton2"),
      );
      if (dropdown.evaluate().isNotEmpty) {
        await tester.tap(dropdown.first, warnIfMissed: false);
        await _wait(tester, 10);
        await _shot(tester, "receive-address-type-choice");
        navigator.pop();
        await _wait(tester, 10);
      }
    } catch (e) {
      // ignore: avoid_print
      print("SWEEP address type choice failed: ${e.runtimeType}");
    }
    await tester.tap(find.byType(AppBarIconButton).last, warnIfMissed: false);
    await _wait(tester, 10);
    await _shot(tester, "receive-menu");
    await _rowShot(tester, "Address list", "receive-address-list");
    await _backOne(tester, navigator);
    await _rowShot(tester, "Advanced options", "receive-advanced-options");
  });

  // Send, empty. The fee choice and the address-book picker are opened and
  // closed again; nothing is typed, "Send" and "Review" are never pressed, and
  // the camera button is never pressed.
  await _step(tester, navigator, "send", wallet, () async {
    await _tapAny(tester, "Send");
    await _wait(tester, 30);
    await _shot(tester, "send-empty");
    await _tapKey(tester, "sendViewAddressBookButtonKey");
    await _wait(tester, 15);
    await _shot(tester, "send-address-book-picker");
    await _backOne(tester, navigator);
    // The fee choice: the button is the first one below the "Transaction fee"
    // label.
    final label = find.textContaining("Transaction fee");
    expect(await _waitFor(tester, label, seconds: 5), isTrue);
    await tester.ensureVisible(label.first);
    await _wait(tester, 5);
    final labelY = tester.getCenter(label.first).dy;
    final buttons = find.byType(RawMaterialButton).evaluate().where((e) {
      final box = e.renderObject as RenderBox;
      return box.localToGlobal(box.size.center(Offset.zero)).dy > labelY;
    }).toList();
    expect(buttons, isNotEmpty);
    buttons.sort((a, b) {
      double y(Element e) {
        final box = e.renderObject as RenderBox;
        return box.localToGlobal(box.size.center(Offset.zero)).dy;
      }

      return y(a).compareTo(y(b));
    });
    await tester.tap(find.byWidget(buttons.first.widget), warnIfMissed: false);
    await _wait(tester, 30);
    await _shot(tester, "send-fee-choice");
  });

  // The wallet's settings (the three-lines sign). Not opened: "Wallet backup"
  // and "Wallet xPub" (they show the recovery phrase and an extended key).
  await _step(tester, navigator, "wallet settings", wallet, () async {
    await _tapKey(tester, "walletViewSettingsButton");
    await _wait(tester, 10);
    await _shot(tester, "wallet-settings");

    await _rowShot(tester, "Address book", "wallet-settings-address-book");
    await _backOne(tester, navigator);

    await _rowShot(tester, "Network", "wallet-settings-network", settle: 20);
    await _backOne(tester, navigator);

    await _rowShot(tester, "Syncing preferences", "wallet-settings-syncing");
    await _backOne(tester, navigator);

    // "Wallet settings" and its plain rows. The switches there are not
    // touched.
    await _rowShot(tester, "Wallet settings", "wallet-settings-wallet-settings");
    await _rowShot(tester, "Rename wallet", "wallet-settings-rename");
    await _backOne(tester, navigator);
    if (_anyText("RBF settings").evaluate().isNotEmpty) {
      await _rowShot(tester, "RBF settings", "wallet-settings-rbf");
      await _backOne(tester, navigator);
    }
    // "Delete wallet": only the first question is pictured, then "Cancel".
    await _rowShot(tester, "Delete wallet", "wallet-settings-delete-question");
    await _tapAny(tester, "Cancel");
  });

  // ---- The home screen ----
  await _popTo(tester, navigator, home);
  await _waitFor(tester, find.byType(FavoriteCard), seconds: 20);

  await _step(tester, navigator, "notifications", home, () async {
    await _tapKey(tester, "walletsViewAlertsButton");
    await _wait(tester, 10);
    await _shot(tester, "notifications");
  });

  // "Manage favourites" is the three-dots button above the favourite cards.
  await _step(tester, navigator, "manage favourites", home, () async {
    unawaited(navigator.pushNamed(ManageFavoritesView.routeName));
    await _wait(tester, 20);
    await _shot(tester, "manage-favourites");
  });

  // The wallets of one coin.
  await _step(tester, navigator, "wallets of a coin", home, () async {
    unawaited(navigator.pushNamed(WalletsOverview.routeName, arguments: coin));
    await _wait(tester, 20);
    await _shot(tester, "wallets-of-a-coin");
  });

  // "Add new" (list of coins), Bitcoin, "Restore wallet", the name page, the
  // restore options, and the empty word-entry page. Nothing is typed into the
  // word entry and "Restore" is never pressed there; "Next" is pressed only
  // on pages that make no wallet.
  await _step(tester, navigator, "add wallet restore", home, () async {
    await _tapAny(tester, "Add new");
    await _waitFor(tester, find.text("Coins"), seconds: 20);
    await _wait(tester, 10);
    await _shot(tester, "add-wallet-coins");
    final entry = find.textContaining("Bitcoin (");
    expect(entry.evaluate(), isNotEmpty);
    await tester.ensureVisible(entry.first);
    await _wait(tester, 3);
    await tester.tap(entry.first, warnIfMissed: false);
    await _wait(tester, 5);
    await _tapText(tester, "Next");
    expect(await _waitFor(tester, find.text("Restore wallet"), seconds: 15), isTrue);
    await _shot(tester, "add-bitcoin-wallet-options");
    await _rowShot(tester, "Restore wallet", "restore-name-your-wallet");
    // "Next" stays dark until the wallet has a name; an ordinary label is
    // typed (no wallet is made by this page).
    await tester.enterText(find.byType(TextField).first, "Restore test");
    await _wait(tester, 10);
    await _tapText(tester, "Next");
    await _wait(tester, 10);
    await _shot(tester, "restore-options");
    await _tapText(tester, "Next");
    await _wait(tester, 15);
    await _shot(tester, "restore-word-entry-empty");
  });

  // ---- Settings ----
  await _tapKey(tester, "walletsViewSettingsButton");
  expect(await _waitFor(tester, find.text("About"), seconds: 10), isTrue);
  await _shot(tester, "settings-all-rows");

  // The address book, the "My vault" entry and its detail, "add contact".
  await _step(tester, navigator, "address book", settings, () async {
    await _rowShot(tester, "Address book", "address-book", settle: 20);
    final vault = _anyText("My vault");
    if (vault.evaluate().isNotEmpty) {
      await tester.tap(vault.first, warnIfMissed: false);
      await _wait(tester, 20);
      await _shot(tester, "address-book-my-vault");
      await _backOne(tester, navigator);
    }
    await _tapKey(tester, "addressBookAddNewContactViewButton");
    await _wait(tester, 10);
    await _shot(tester, "address-book-add-contact");
    await _backOne(tester, navigator);
    await _tapKey(tester, "addressBookFilterViewButton");
    await _wait(tester, 10);
    await _shot(tester, "address-book-filter");
  });

  // Backup and restore. The row asks for the PIN first, so the lock screen is
  // pictured; the throwaway PIN opens the page. Only the first page of each
  // choice is pictured: "Create backup", "Restore" and the file chooser are
  // never pressed, nothing is typed, and no backup file is made.
  await _step(tester, navigator, "backup pages", settings, () async {
    final row = find.textContaining("backup & restore");
    expect(await _waitFor(tester, row, seconds: 10), isTrue);
    await tester.ensureVisible(row.first);
    await _wait(tester, 3);
    await tester.tap(row.first, warnIfMissed: false);
    await _wait(tester, 20);
    await _shot(tester, "backup-lock-screen");
    await _typePin(tester, "1379");
    final unlock = find.byType(SubmitKey);
    if (unlock.evaluate().isNotEmpty) {
      await tester.tap(unlock.first, warnIfMissed: false);
    }
    expect(await _waitFor(tester, _anyText("Auto Backup"), seconds: 20), isTrue);
    await _wait(tester, 10);
    await _shot(tester, "backup-and-restore");
    await _rowShot(tester, "Auto Backup", "backup-auto-backup");
    await _backOne(tester, navigator);
    await _rowShot(tester, "Create manual backup", "backup-create");
    await _backOne(tester, navigator);
    await _rowShot(tester, "Restore backup", "backup-restore");
  });

  // Security: the first page only (every row on it asks for the PIN or
  // changes a setting). The auto-lock page is opened directly.
  await _step(tester, navigator, "security", settings, () async {
    await _rowShot(tester, "Security", "settings-security");
    unawaited(navigator.pushNamed(AutoLockTimeoutSettingsView.routeName));
    await _wait(tester, 20);
    await _shot(tester, "settings-security-auto-lock");
  });

  await _step(tester, navigator, "currency", settings, () async {
    await _rowShot(tester, "Currency", "settings-currency");
  });
  await _step(tester, navigator, "language", settings, () async {
    await _rowShot(tester, "Language", "settings-language");
  });

  // Tor settings: only looked at. "Connect" is never pressed.
  await _step(tester, navigator, "tor", settings, () async {
    await _rowShot(tester, "Tor Settings", "settings-tor", settle: 20);
  });

  // Manage nodes: the list, one coin's nodes, one node's detail page. "Connect"
  // and "Test connection" are never pressed and no node is added or changed.
  await _step(tester, navigator, "nodes", settings, () async {
    await _rowShot(tester, "Manage nodes", "settings-manage-nodes");
    final coinRow = find.textContaining(" nodes");
    expect(await _waitFor(tester, coinRow, seconds: 10), isTrue);
    await tester.tap(coinRow.first, warnIfMissed: false);
    await _wait(tester, 20);
    await _shot(tester, "settings-coin-nodes");
    final card = find.byType(NodeCard);
    expect(await _waitFor(tester, card, seconds: 10), isTrue);
    await tester.tap(card.first, warnIfMissed: false);
    await _wait(tester, 10);
    await _shot(tester, "settings-node-sheet");
    await _tapAny(tester, "Details");
    await _wait(tester, 15);
    await _shot(tester, "settings-node-details");
  });

  await _step(tester, navigator, "syncing", settings, () async {
    await _rowShot(tester, "Syncing preferences", "settings-syncing");
    unawaited(navigator.pushNamed(SyncingOptionsView.routeName));
    await _wait(tester, 20);
    await _shot(tester, "settings-syncing-options");
  });
  await _step(tester, navigator, "startup", settings, () async {
    await _rowShot(tester, "Startup", "settings-startup");
  });
  // Appearance: "Add more themes" is never pressed (it asks a server for the
  // list of themes).
  await _step(tester, navigator, "appearance", settings, () async {
    await _rowShot(tester, "Appearance", "settings-appearance");
  });

  await _step(tester, navigator, "about", settings, () async {
    await _rowShot(tester, "About", "settings-about");
  });
  await _step(tester, navigator, "support", settings, () async {
    await _rowShot(tester, "Support", "settings-support");
  });

  // Advanced and its plain sub-pages. The switches there are not touched.
  await _step(tester, navigator, "advanced", settings, () async {
    await _rowShot(tester, "Advanced", "settings-advanced");
    await _rowShot(tester, "Logging", "settings-advanced-logging");
    await _backOne(tester, navigator);
    await _rowShot(tester, "Change block explorer", "settings-advanced-explorer-coins");
    await _backOne(tester, navigator);
    await _rowShot(tester, "Units", "settings-advanced-units");
  });
  await _step(tester, navigator, "advanced privacy", settings, () async {
    await _rowShot(tester, "Advanced", "settings-advanced-again");
    final privacy = find.textContaining("rivacy");
    if (privacy.evaluate().isNotEmpty) {
      await tester.ensureVisible(privacy.first);
      await _wait(tester, 3);
      await tester.tap(privacy.first, warnIfMissed: false);
      await _wait(tester, 15);
      await _shot(tester, "settings-advanced-privacy");
    }
  });

  // "Delete account": only the first warning; "Confirm" is never pressed.
  await _step(tester, navigator, "delete account", settings, () async {
    await _rowShot(tester, "Delete account", "settings-delete-account");
  });

  // ---- The lock screen ----
  // The app does not lock when it comes back from the background: its
  // lifecycle handler only switches the blurred privacy cover on and off, and
  // the lock-on-resume code is commented out. The app locks after a period
  // without any touch (the "auto lock" setting; the shortest is one minute).
  // So: the paused/resumed pair is sent to show that nothing locks, then the
  // auto lock is switched on for one minute and the walk waits without touching.
  await _popTo(tester, navigator, home);
  // Both are sent at once: while the app is "paused" the test binding draws
  // no frames, so a pause with a wait inside it never comes back.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await _wait(tester, 10);
  await _shot(tester, "home-after-pause-and-resume");
  container.read(prefsChangeNotifierProvider).autoLockInfo = (
    enabled: true,
    minutes: 1,
  );
  final locked = await _waitFor(
    tester,
    find.byType(LockscreenView),
    seconds: 100,
  );
  if (locked) {
    await _wait(tester, 10);
    await _shot(tester, "lock-screen-after-idle");
  } else {
    // ignore: avoid_print
    print("SWEEP lock screen did not appear within 100 seconds");
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
