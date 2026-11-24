#!/bin/bash

set -x -e

# Configure files for 4bc Wallet.
#
# Local file of the 4bc Wallet project (not part of upstream Stack Wallet), added
# 23 Nov 2026 beside configure_stack_duo.sh and derived from it. GPL-3.0 like the rest.
# 4bc Wallet is a modified edition of Stack Duo: the same coins, our own name, pictures
# and theme. What differs from configure_stack_duo.sh, and why:
#   - name, identifiers, package name and data folder name are our own;
#   - the feature set is Tor only: theme selection is off because the app has one look
#     (see local/fourbc_wallet/make_theme.py), and swap, buy and the two shops are off
#     because they need partner agreements and keys this edition does not have;
#   - our theme is packed, our few shared pictures and our two animations are laid over
#     Stack Duo's, and the launch screen's ground colour is set to our grey.
#
# NEVER change NEW_APP_ID or _appDataDirName once anyone holds coins in the app:
# they decide whether an installed app keeps its wallets.
#
# NEW_APP_ID is the partner's decision of 23 Nov 2026: com.4bcwallet.app, the domain
# 4bcwallet.com written backwards. It is for Apple's platforms. Android does not accept
# a part that begins with a digit: an Android build needs its own identifier, to be
# decided the day one is built.
#
# The description's line break is where the welcome screen parts its two rows
# (lib/local_fourbc/welcome_words.dart). The words are the partner's choice of 23 Nov 2026.

export NEW_NAME="4bc Wallet"
export NEW_APP_ID="com.4bcwallet.app"
export NEW_APP_ID_CAMEL="com.4bcwallet.app"
export NEW_APP_ID_SNAKE="com.4bcwallet.app"
export NEW_BASIC_NAME="fourbc_wallet"

NEW_PUBSPEC_NAME="fourbcwallet"
PUBSPEC_FILE="${APP_PROJECT_ROOT_DIR}/pubspec.yaml"

# String replacements.
sed -i.bak \
  -e "s/name: PLACEHOLDER/name: ${NEW_PUBSPEC_NAME}/g" \
  -e "s/description: PLACEHOLDER/description: ${NEW_NAME}/g" \
  "${PUBSPEC_FILE}"
rm -f "${PUBSPEC_FILE}.bak"

# The launch screen's ground: our grey, in light and dark mode alike.
sed -i.bak \
  -e 's/^  color: "F7F7F7"$/  color: "2B2D31"/' \
  -e 's/^  color_dark_ios: "2A2D34"$/  color_dark_ios: "2B2D31"/' \
  -e 's/^  color_dark_android: "2A2D34"$/  color_dark_android: "2B2D31"/' \
  -e 's/^    color: "F7F7F7"$/    color: "2B2D31"/' \
  -e 's/^    color_dark: "2A2D34"$/    color_dark: "2B2D31"/' \
  "${PUBSPEC_FILE}"
rm -f "${PUBSPEC_FILE}.bak"
if [ "$(grep -c '"2B2D31"' "${PUBSPEC_FILE}")" != "5" ]; then
  echo "configure_fourbc_wallet: the launch screen colours in the pubspec template have changed shape"
  exit 1
fi

# Our shared pictures: Stack Duo's folder with our few replacements laid over it
# (local/fourbc_wallet/svg_overrides/, same file names). The folder is rebuilt on every
# configure and is not tracked by git. Today's one replacement: plus.svg, drawn dark,
# because the "Add Wallet" button shows it uncoloured on our yellow. A file there whose
# name begins with "fourbc-" replaces nothing: it is a small sign of our own
# (fourbc-code.svg, for the Support screen's "Source code" entry).
if [ -z "${APP_PROJECT_ROOT_DIR}" ]; then
  echo "configure_fourbc_wallet: APP_PROJECT_ROOT_DIR is not set"
  exit 1
fi
OUR_SVG_DIR="${APP_PROJECT_ROOT_DIR}/asset_sources/svg/fourbc_wallet"
rm -rf "${OUR_SVG_DIR}"
cp -R "${APP_PROJECT_ROOT_DIR}/asset_sources/svg/stack_duo" "${OUR_SVG_DIR}"
cp -R "${APP_PROJECT_ROOT_DIR}/local/fourbc_wallet/svg_overrides/." "${OUR_SVG_DIR}/"

# Our animations: Stack Duo's folder with three files of our own laid over it
# (local/fourbc_wallet/lottie/make_loader.py writes them; its header says what they are).
# The folder is rebuilt on every configure and is not tracked by git.
#   loader.json                the app's loading animation: our own, the "c" of our sign
#   loader_and_checkmark.json  Stack Duo's, its two near-black circles in our silver
#   onion_animation.json       Stack Duo's Tor onion, its plain colours changed to ours
OUR_LOTTIE_DIR="${APP_PROJECT_ROOT_DIR}/asset_sources/lottie/fourbc_wallet"
rm -rf "${OUR_LOTTIE_DIR}"
cp -R "${APP_PROJECT_ROOT_DIR}/asset_sources/lottie/stack_duo" "${OUR_LOTTIE_DIR}"
python3 "${APP_PROJECT_ROOT_DIR}/local/fourbc_wallet/lottie/make_loader.py" ring "${OUR_LOTTIE_DIR}/loader.json"
python3 "${APP_PROJECT_ROOT_DIR}/local/fourbc_wallet/lottie/make_loader.py" send-dialog \
  "${APP_PROJECT_ROOT_DIR}/asset_sources/lottie/stack_duo/loader_and_checkmark.json" \
  "${OUR_LOTTIE_DIR}/loader_and_checkmark.json"
python3 "${APP_PROJECT_ROOT_DIR}/local/fourbc_wallet/lottie/make_loader.py" tor-onion \
  "${APP_PROJECT_ROOT_DIR}/asset_sources/lottie/stack_duo/onion_animation.json" \
  "${OUR_LOTTIE_DIR}/onion_animation.json"

# Pack our theme into asset_sources/default_themes/fourbc_wallet/light.zip.
python3 "${APP_PROJECT_ROOT_DIR}/local/fourbc_wallet/make_theme.py"

dart "${APP_PROJECT_ROOT_DIR}/tool/process_pubspec_deps.dart" \
      "${PUBSPEC_FILE}" \
      XMR \
      TOR \
      FROST

dart "${APP_PROJECT_ROOT_DIR}/tool/gen_interfaces.dart" \
      "${APP_PROJECT_ROOT_DIR}/tool/wl_templates" \
      "${APP_PROJECT_ROOT_DIR}/lib/wl_gen/generated" \
      XMR \
      TOR \
      FROST


pushd "${APP_PROJECT_ROOT_DIR}"
BUILT_COMMIT_HASH=$(git log -1 --pretty=format:"%H")
popd

APP_CONFIG_DART_FILE="${APP_PROJECT_ROOT_DIR}/lib/app_config.g.dart"
rm -f "$APP_CONFIG_DART_FILE"
cat << EOF > "$APP_CONFIG_DART_FILE"
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

const _prefix = "4bc";
const _separator = " ";
const _suffix = "Wallet";
const _emptyWalletsMessage =
    "You do not have any wallets yet. Add your first one.";
const _appDataDirName = "fourbcwallet";
const _shortDescriptionText = "Your keys. Your coins.\\nNobody else's.";
const _commitHash = "$BUILT_COMMIT_HASH";

const _mwebdExeHash = "";

const Set<AppFeature> _features = {
  AppFeature.tor,
};

const ({String light, String dark})? _appIconAsset = (
  light: "assets/in_app_logo_icons/4bc-icon_light.svg",
  dark: "assets/in_app_logo_icons/4bc-icon_dark.svg",
);

final List<CryptoCurrency> _supportedCoins = List.unmodifiable([
  Bitcoin(CryptoCurrencyNetwork.main),
  Monero(CryptoCurrencyNetwork.main),
  BitcoinFrost(CryptoCurrencyNetwork.main),
  Bitcoin(CryptoCurrencyNetwork.test),
  Bitcoin(CryptoCurrencyNetwork.test4),
  BitcoinFrost(CryptoCurrencyNetwork.test),
  BitcoinFrost(CryptoCurrencyNetwork.test4),
]);

const List<EthContract> _defaultEthTokens = [];

final ({String from, String fromFuzzyNet, String to, String toFuzzyNet})
_swapDefaults = (
  from: "BTC",
  fromFuzzyNet: "btc",
  to: "XMR",
  toFuzzyNet: "xmr",
);

EOF
