// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 25 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Settings, "Delete account" explains in upstream's words why the screen
// exists: Apple's store asks every app for a way to delete an account, and
// would reject upstream's updates without one. Those sentences speak for
// upstream. The 4bc Wallet edition says in its own words what the button
// does; every other edition keeps upstream's words.

import 'edition_notice.dart';

/// What "Delete account" does, said to the user before they confirm.
const kFourbcDeleteAccountWords =
    "This deletes all of 4bc Wallet's data on this phone, every wallet and "
    "every setting, and takes you back to the first screen.\n\n"
    "Nothing is kept anywhere else, so nothing can bring it back. A wallet "
    "returns only from its recovery words. Make sure you have them on paper "
    "for every wallet before you go on.";

/// [upstreamWords] in every edition but ours.
String fourbcDeleteAccountWords(String upstreamWords) =>
    isFourbcEdition ? kFourbcDeleteAccountWords : upstreamWords;
