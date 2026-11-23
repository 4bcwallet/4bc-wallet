// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 24 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Upstream names the home screen, and the address book's entry for the user's
// own wallets, "My <short name of the edition>": "My Stack" in Stack Wallet.
// With our short name that reads "My 4bc", which says nothing. The 4bc Wallet
// edition writes the words below in those two places (the partner's choice of
// 24 Nov 2026); every other edition keeps upstream's words.

import 'edition_notice.dart';

/// The title of the home screen and the name of the user's own entry in the address book.
const kFourbcHomeTitle = "My vault";

/// [upstreamTitle] in every edition but ours.
String fourbcHomeTitle(String upstreamTitle) =>
    isFourbcEdition ? kFourbcHomeTitle : upstreamTitle;
