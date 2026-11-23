// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 24 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Upstream draws one and the same theme picture ("stack") on the welcome screen
// and on the empty home screen. The 4bc Wallet edition shows a picture of its
// own on the welcome screen: the file named below, when the installed theme
// carries one beside its "stack" picture (local/fourbc_wallet/theme/assets/png/).
// A theme without that file, and every other edition, shows the theme's picture
// as before.

import 'dart:io';

import 'edition_notice.dart';

/// The file name of the welcome screen's own picture inside the theme.
const kFourbcWelcomePictureName = "fourbc-welcome.png";

/// The picture the welcome screen draws, given the theme's "stack" picture.
String fourbcWelcomePicture(String themePicture) {
  if (!isFourbcEdition) return themePicture;
  final own = File(
    "${File(themePicture).parent.path}/$kFourbcWelcomePictureName",
  );
  return own.existsSync() ? own.path : themePicture;
}
