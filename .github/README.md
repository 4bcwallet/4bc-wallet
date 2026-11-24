# 4bc Wallet

A wallet for Bitcoin and Monero on iPhone. Your keys stay on your phone.

4bc Wallet is a **modified version of [Stack Wallet](https://github.com/cypherstack/stack_wallet) v2.7.5 (build 325) by Cypher Stack**, changed by the 4bc Wallet project, first on 23 November 2026. It is free software under the GNU General Public License, version 3, and comes with no warranty.

**Cypher Stack does not make, endorse or support this edition.** Please do not ask them for help with it. The file `README.md` in the root of this repository is theirs, kept as they wrote it; it describes Stack Wallet, not this edition.

## What is different from Stack Wallet

- **The name and the look:** our own name, icon, launch picture, colours, drawn pictures and welcome words.
- **Fewer features:** Bitcoin, Monero and Bitcoin Frost only. Swapping, buying, the in-app shops and theme downloads are switched off.
- **Our own links:** the app names `4bcwallet.com` and its own terms and privacy pages instead of Stack Wallet's.
- **Nothing else.** No line of the code that handles keys, signing, storage or the network is changed. The default nodes are the ones Stack Wallet ships with.

## Where the changes are

Everything is on top of upstream's release tag `build_325`:

```
git diff build_325..main --stat
```

Our own files:

- `scripts/app_config/configure_fourbc_wallet.sh`: the edition's configuration (derived from Stack Duo's; its header lists every difference)
- `local/fourbc_wallet/`: the theme's sources and the script that packs it
- `lib/local_fourbc/`: the edition notice of the About screen, our links and words
- `asset_sources/*/fourbc_wallet/`: icon, launch picture, logo
- `integration_test/local_screenshots/`: a test that walks the first screens and saves pictures

Upstream files edited, each by a few lines: `scripts/build_app.sh`, and under `lib/pages/`: `intro_view.dart`, `home_view/home_view.dart`, `address_book_views/address_book_view.dart`, `settings_views/global_settings_view/about_view.dart`, `settings_views/global_settings_view/stack_backup_views/auto_backup_view.dart`.

## Building

Follow upstream's `docs/building.md` at this tag for the tools (Flutter 3.47.2, Rust, CocoaPods). We build on an Apple-chip Mac with Xcode 27.2. Then, for iOS:

```
cd scripts
./prebuild.sh
echo yes | ./build_app.sh -a fourbc_wallet -p ios -v 2.7.5 -b 325 -d
cd ..
flutter pub get
flutter build ios --release --no-codesign
```

Signing and installing on a phone need your own Apple developer team and your own bundle identifier.

## Status

Early. 4bc Wallet is not in the App Store. It is kept by a very small independent project, not by a company. Your recovery words are your only backup: nobody, we included, can restore your coins.

## Contact

`support@4bcwallet.com`. We will never ask for your recovery words.

## Licence

GNU General Public License, version 3: see `LICENSE`. You may use, study, change and share this software under the same licence. Stack Wallet is copyright Cypher Stack; their notices in the source files are kept.
