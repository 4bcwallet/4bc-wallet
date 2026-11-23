// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 23 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// How the 4bc Wallet edition sets the two texts of the welcome screen on a phone:
// the name as a small spaced label, and the line under it large and light, its first
// row in the main text colour and the rest dimmer. The words themselves come from
// AppConfig (scripts/app_config/configure_fourbc_wallet.sh); a line break in the
// description is where the rows part. The other editions are unchanged.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_config.dart';
import '../themes/stack_colors.dart';

class FourbcWelcomeName extends StatelessWidget {
  const FourbcWelcomeName({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StackColors>()!;
    return Padding(
      // The spacing pushes the last letter left of centre by half a gap.
      padding: const EdgeInsets.only(left: 3.1, bottom: 10),
      child: Text(
        AppConfig.appName.toUpperCase(),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: colors.textSubtitle1,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 3.1,
        ),
      ),
    );
  }
}

class FourbcWelcomeLine extends StatelessWidget {
  const FourbcWelcomeLine({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StackColors>()!;
    final rows = AppConfig.shortDescriptionText.split("\n");
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: rows.first),
          if (rows.length > 1)
            TextSpan(
              text: "\n${rows.skip(1).join("\n")}",
              style: TextStyle(color: colors.textSubtitle1),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: colors.textDark,
        fontWeight: FontWeight.w300,
        fontSize: 27,
        height: 36 / 27,
        letterSpacing: -0.27,
      ),
    );
  }
}
