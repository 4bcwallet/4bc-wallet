// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 23 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// The notice the licence asks a modified edition to show (GPL-3.0, sections 5a and 5d):
// that this app is a modified version of Stack Wallet, who changed it and when, and
// under which licence it is passed on. Shown on the About screen of the 4bc Wallet
// edition only; the other editions built from this repository are unchanged.

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../utilities/text_styles.dart';
import '../widgets/rounded_white_container.dart';

/// The upstream release this edition is built from.
const kUpstreamRelease = "Stack Wallet v2.7.5 (build 325)";

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
            "${AppConfig.appName} is a modified version of $kUpstreamRelease "
            "by Cypher Stack, changed by the ${AppConfig.appName} project on "
            "$kEditionChangedOn. It is free software under the GNU General "
            "Public License, version 3, and comes with no warranty. "
            "Cypher Stack does not make, endorse or support this edition.",
            style: STextStyles.itemSubtitle(context),
          ),
        ],
      ),
    );
  }
}
