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
#   - our theme is packed and the launch screen's ground colour is set to our grey.
#
# NEVER change NEW_APP_ID or _appDataDirName once anyone holds coins in the app:
# they decide whether an installed app keeps its wallets.

export NEW_NAME="4bc Wallet"
export NEW_APP_ID="com.fourbc.wallet"
export NEW_APP_ID_CAMEL="com.fourbc.wallet"
export NEW_APP_ID_SNAKE="com.fourbc.wallet"
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
const _shortDescriptionText = "An open-source wallet for Bitcoin and Monero";
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
