# 4bc Wallet

A wallet for Bitcoin and Monero on iPhone. Your keys stay on your phone.

4bc Wallet is free software under the GNU General Public License, version 3, and comes with no warranty.

## Status

Early. 4bc Wallet is not in the App Store. It is kept by a very small independent project, not by a company. Your recovery words are your only backup: nobody, we included, can restore your coins.

## Contact

`support@4bcwallet.com`. We will never ask for your recovery words.

## Building

The tools are those of `docs/building.md` (Flutter 3.47.2, Rust, CocoaPods). We build on an Apple-chip Mac with Xcode 27.2. Then, for iOS:

```
cd scripts
./prebuild.sh
echo yes | ./build_app.sh -a fourbc_wallet -p ios -v 2.7.5 -b 325 -d
cd ..
flutter pub get
flutter build ios --release --no-codesign
```

Signing and installing on a phone need your own Apple developer team and your own bundle identifier.

## Licence

GNU General Public License, version 3: see `LICENSE`. You may use, study, change and share this software under the same licence.

## Origin, and what is changed

4bc Wallet is a **modified version of [Stack Wallet](https://github.com/cypherstack/stack_wallet) v2.7.5 (build 325) by Cypher Stack**, changed by the 4bc Wallet project, first on 23 November 2026. Stack Wallet is copyright Cypher Stack; their notices in the source files are kept.

**Cypher Stack does not make, endorse or support this edition.** Please do not ask them for help with it. The file `README.md` in the root of this repository is theirs, kept as they wrote it; it describes Stack Wallet, not this edition.

What is different from Stack Wallet:

- **The name and the look:** our own name, icon, launch picture, colours, drawn pictures, small signs, loading animation and welcome words. Each wallet's card carries a small drawing, and the wallets of one coin get different ones, so that two of them are told apart at a glance. The progress screen of a Monero wallet's "Churn" shows a figure of our own, moved by a few lines of code, in place of the animated picture.
- **Fewer features:** Bitcoin, Monero and Bitcoin Frost only. Swapping, buying, the in-app shops and theme downloads are switched off.
- **Our own links:** the app names `4bcwallet.com` and its own terms and privacy pages instead of Stack Wallet's, and its Support screen shows our own address and this repository instead of Cypher Stack's channels. Settings, "Delete account" says in our own words what the button does.
- **Nothing else.** No line of the code that handles keys, signing, storage or the network is changed. The default nodes are the ones Stack Wallet ships with.

Where the changes are: everything is on top of upstream's release tag `build_325`:

```
git diff build_325..main --stat
```

Our own files:

- `scripts/app_config/configure_fourbc_wallet.sh`: the edition's configuration (derived from Stack Duo's; its header lists every difference)
- `local/fourbc_wallet/`: the theme's sources and the script that packs it; the script that writes our loading animation and gives the Tor settings' animation this edition's colours
- `lib/local_fourbc/`: the edition notice of the About screen, our links, words and contact, the choice of a wallet's card picture, and the figure of the "Churn" progress screen
- `asset_sources/*/fourbc_wallet/`: icon, launch picture, logo
- `integration_test/local_screenshots/`: a test that walks the first screens and saves pictures (it can also make a throwaway test-network wallet, to picture a wallet's screens, and go on through every screen that can be reached without coins), one that shows an animation file with the app's own player, and one that shows the "Churn" figure by itself

Upstream files edited, each by a few lines: `scripts/build_app.sh`, `lib/widgets/coin_card.dart`, `lib/widgets/monero_chan_dance.dart`, and under `lib/pages/`: `intro_view.dart`, `home_view/home_view.dart`, `address_book_views/address_book_view.dart`, `settings_views/global_settings_view/about_view.dart`, `settings_views/global_settings_view/support_view.dart`, `settings_views/global_settings_view/stack_backup_views/auto_backup_view.dart`, `settings_views/global_settings_view/delete_account_view.dart`.
