// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 24 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Upstream's Support screen (Settings, Support) lists Cypher Stack's own
// channels: their Telegram, Discord, Reddit, X and e-mail address. Cypher Stack
// does not support this edition, so in the 4bc Wallet edition the screen shows
// the entries below and none of theirs; every other edition keeps upstream's.
// The upstream file (lib/pages/settings_views/global_settings_view/
// support_view.dart) keeps its own list and asks fourbcSupportEntries() first.
//
// Unlike upstream's rows, ours show the address itself under the label, so it
// can be read on a phone that cannot open it; in that case a tap copies it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../notifications/show_flush_bar.dart';
import '../themes/stack_colors.dart';
import '../utilities/assets.dart';
import '../utilities/constants.dart';
import '../utilities/text_styles.dart';
import '../widgets/rounded_white_container.dart';
import 'edition_notice.dart';

/// The first lines of the screen.
const kFourbcSupportIntro =
    "If you need help or want to report a bug, write to us. "
    "We will never ask for your recovery words, your PIN or a backup file.";

/// Where a letter to us goes.
const kFourbcSupportEmail = "support@4bcwallet.com";

/// Where this edition's source code is published.
const kFourbcSourceCode = "github.com/4bcwallet/4bc-wallet";

/// What the Support screen shows in the 4bc Wallet edition; null in every
/// other edition, which then shows upstream's own list.
List<Widget>? fourbcSupportEntries({required bool isDesktop}) {
  if (!isFourbcEdition) return null;
  return [
    Builder(
      builder: (context) => RoundedWhiteContainer(
        child: Text(
          kFourbcSupportIntro,
          style: STextStyles.smallMed12(context),
        ),
      ),
    ),
    SizedBox(height: isDesktop ? 24 : 12),
    _FourbcSupportEntry(
      label: "Email",
      shown: kFourbcSupportEmail,
      url: "mailto:$kFourbcSupportEmail",
      iconAsset: Assets.svg.envelope,
    ),
    const SizedBox(height: 8),
    const _FourbcSupportEntry(
      label: "Source code",
      shown: kFourbcSourceCode,
      url: "https://$kFourbcSourceCode",
      iconAsset: "assets/svg/fourbc-code.svg",
    ),
  ];
}

class _FourbcSupportEntry extends StatelessWidget {
  const _FourbcSupportEntry({
    required this.label,
    required this.shown,
    required this.url,
    required this.iconAsset,
  });

  final String label;
  final String shown;
  final String url;
  final String iconAsset;

  Future<void> _open(BuildContext context) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // No app on this device takes the address: it is copied instead.
    }
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: shown));
    if (!context.mounted) return;
    await showFloatingFlushBar(
      type: FlushBarType.info,
      message: "Could not open it here. The address is copied.",
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StackColors>()!;
    return RoundedWhiteContainer(
      padding: const EdgeInsets.all(0),
      child: RawMaterialButton(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            Constants.size.circularBorderRadius,
          ),
        ),
        onPressed: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(
                  colors.topNavIconPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: STextStyles.titleBold12(context)),
                    const SizedBox(height: 2),
                    Text(shown, style: STextStyles.itemSubtitle12(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
