// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 25 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// The figure of a Monero wallet's "Churning progress" screen. Upstream shows
// an animated picture of a dancing character there. The 4bc Wallet edition
// shows a figure of its own: it stands and balances a coin on its fingertip,
// and the coin spins. The figure and the coin are two pictures of the
// installed theme (local/fourbc_wallet/theme/assets/png/); the motion is
// written here: the coin turns about its upright axis, and the figure
// breathes a little.
//
// A theme without those two pictures shows upstream's picture, and every
// other edition never comes here (fourbcChurnFigure answers nothing).

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../themes/theme_providers.dart';
import '../utilities/assets.dart';
import 'edition_notice.dart';

/// The two pictures, beside the theme's "stack" picture.
const kFourbcChurnFigureName = "fourbc-churn-figure.png";
const kFourbcChurnCoinName = "fourbc-churn-coin.png";

/// The figure for this edition; nothing for every other edition, which then
/// draws its own picture.
Widget? fourbcChurnFigure(double height) =>
    isFourbcEdition ? FourbcChurnFigure(height: height) : null;

class FourbcChurnFigure extends ConsumerStatefulWidget {
  const FourbcChurnFigure({super.key, required this.height, this.pictureFolder});

  final double height;

  /// The folder that holds the two pictures. Left out, it is the installed
  /// theme's; a preview gives its own.
  final String? pictureFolder;

  @override
  ConsumerState<FourbcChurnFigure> createState() => _FourbcChurnFigureState();
}

class _FourbcChurnFigureState extends ConsumerState<FourbcChurnFigure>
    with SingleTickerProviderStateMixin {
  // Measured in the figure's picture: its width for a height of one, and how
  // far from its left edge the raised fingertip is (the fingertip is the
  // picture's top).
  static const _figureWidth = 0.4545;
  static const _fingertip = 0.1797;
  // The coin's width as a share of the whole height.
  static const _coin = 0.27;

  // One turn of the clock holds a whole number of every motion below, so the
  // loop has no seam: 15 turns of the coin, 10 breaths, 5 sways.
  static const _seconds = 36.0;
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 36),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folder =
        widget.pictureFolder ??
        File(
          ref.watch(themeProvider.select((value) => value.assets.stack)),
        ).parent.path;
    final figure = File("$folder/$kFourbcChurnFigureName");
    final coin = File("$folder/$kFourbcChurnCoinName");
    if (!figure.existsSync() || !coin.existsSync()) {
      return Image(
        height: widget.height,
        image: AssetImage(Assets.gif.moneroChanDance),
      );
    }

    final height = widget.height;
    final coinSize = height * _coin;
    final figureHeight = height - coinSize;
    final figureWidth = figureHeight * _figureWidth;
    // The coin stands over the fingertip and reaches past the figure's left
    // edge; the same room is left at the right, so the figure stays centred.
    final side = math.max(0.0, coinSize / 2 - figureWidth * _fingertip);

    return SizedBox(
      width: figureWidth + side * 2,
      height: height,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value * _seconds;
          final turn = 2 * math.pi * t / 2.4;
          final breath = math.sin(2 * math.pi * t / 3.6);
          final sway = math.sin(2 * math.pi * t / 7.2);
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..rotateZ(0.010 * sway)
              ..scaleByDouble(1.0, 1.0 + 0.012 * breath, 1.0, 1.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: side,
                  bottom: 0,
                  width: figureWidth,
                  height: figureHeight,
                  child: Image.file(
                    figure,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned(
                  left: side + figureWidth * _fingertip - coinSize / 2,
                  top: 0,
                  width: coinSize,
                  height: coinSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The coin's edge, seen while its face is turned away.
                      Container(
                        width: coinSize * 0.10 * math.sin(turn).abs() + 2,
                        height: coinSize * 0.97,
                        decoration: BoxDecoration(
                          color: const Color(0xFF9DA0A6),
                          borderRadius: BorderRadius.circular(coinSize),
                          border: Border.all(
                            color: const Color(0xFF1F2023),
                            width: 1.2,
                          ),
                        ),
                      ),
                      // Its face. The sign reads the same from both sides.
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          math.cos(turn),
                          1.0,
                          1.0,
                        ),
                        child: Image.file(
                          coin,
                          width: coinSize,
                          height: coinSize,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
