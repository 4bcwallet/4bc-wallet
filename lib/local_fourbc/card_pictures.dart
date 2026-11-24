// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 24 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Upstream gives every wallet of a coin the same card: the coin's colour with
// two circles, or one picture a coin when the theme names one. The 4bc Wallet
// edition lays a drawn picture on the card and has several for each coin, so
// that two wallets of one coin (one for spending, one for keeping) are told
// apart at a glance.
//
// The pictures are files of the installed theme, beside each other in
// assets/png/cards/ (local/fourbc_wallet/theme/): "<coin>-<n>.png" for the
// balance card on a wallet's own screen and "<coin>-<n>-favorite.png" for the
// smaller card on the home screen, n from 1 upwards. A wallet's picture is
// decided by its place among the wallets of its coin, in the order in which
// they were made on this device: the first takes picture 1, the second
// picture 2, and after the last picture the first comes again. (When a wallet
// is deleted, the ones made after it move up by one picture.)
//
// A theme without these files, and every other edition, draws the card as
// before: this file only chooses a picture, it reads nothing of a wallet but
// its id and its coin.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../themes/theme_providers.dart';
import '../utilities/stack_file_system.dart';
import '../wallets/crypto_currency/crypto_currency.dart';
import '../wallets/isar/providers/all_wallets_info_provider.dart';
import 'edition_notice.dart';

/// How many pictures a coin has in a theme's folder, remembered once counted.
final Map<String, int> _counted = {};

int _count(String folder, String coinId) => _counted.putIfAbsent(
  "$folder/$coinId",
  () {
    int n = 0;
    while (File("$folder/$coinId-${n + 1}.png").existsSync()) {
      n++;
    }
    return n;
  },
);

/// The file of the picture for the card of wallet [walletId], or null when
/// the card is to be drawn upstream's way.
String? fourbcCardPicture(
  WidgetRef ref,
  String walletId,
  CryptoCurrency coin, {
  required bool isFavorite,
}) {
  if (!isFourbcEdition) return null;
  final themes = StackFileSystem.themesDir;
  if (themes == null) return null;
  final themeId = ref.watch(themeProvider.select((value) => value.themeId));
  final folder = "${themes.path}/$themeId/assets/png/cards";
  final count = _count(folder, coin.mainNetId);
  if (count == 0) return null;

  // The wallets of this coin (its test networks with it), oldest first.
  final sameCoin =
      ref
          .watch(pAllWalletsInfo)
          .where((info) => info.coin.mainNetId == coin.mainNetId)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final place = sameCoin.indexWhere((info) => info.walletId == walletId);
  final n = (place < 0 ? 0 : place) % count + 1;

  final own = File(
    "$folder/${coin.mainNetId}-$n${isFavorite ? "-favorite" : ""}.png",
  );
  return own.existsSync() ? own.path : null;
}
