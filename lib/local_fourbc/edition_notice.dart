// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 23 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// The notice the licence asks a modified edition to show (GPL-3.0, sections 5a and 5d):
// that this app is a modified version of Stack Wallet, when it was changed, and
// under which licence and with what warranty it is passed on. Shown as the last
// box of the About screen of the 4bc Wallet edition only; the other editions built
// from this repository are unchanged. Who changed it is the app's own name, in the
// sentence's first words. That Cypher Stack does not make or support this edition
// is said in the Terms (https://4bcwallet.com/terms) and in the README's last part.

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../utilities/text_styles.dart';
import '../widgets/rounded_white_container.dart';

/// The upstream release this edition is built from.
const kUpstreamRelease = "Stack Wallet 2.7.5";

/// The day our changes to that release were last made.
const kEditionChangedOn = "24 November 2026";

/// True only in the 4bc Wallet edition (see scripts/app_config/configure_fourbc_wallet.sh).
bool get isFourbcEdition => AppConfig.prefix == "4bc";

class EditionNotice extends StatelessWidget {
  const EditionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return RoundedWhiteContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("About this edition", style: STextStyles.titleBold12(context)),
          const SizedBox(height: 4),
          SelectableText(
            "${AppConfig.appName} is free software under the GNU GPL v3, with "
            "no warranty. It is a modified version of $kUpstreamRelease "
            "\u00A9 Cypher Stack, changed on $kEditionChangedOn.",
            style: STextStyles.itemSubtitle(context),
          ),
        ],
      ),
    );
  }
}
