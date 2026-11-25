import 'package:flutter/material.dart';

import '../local_fourbc/churn_figure.dart';
import '../utilities/assets.dart';

class MoneroChanDance extends StatelessWidget {
  const MoneroChanDance({super.key, this.height = 200});

  final double height;
  @override
  Widget build(BuildContext context) {
    return fourbcChurnFigure(height) ?? Image(
      height: height,
      image: AssetImage(
        Assets.gif.moneroChanDance,
      ),
    );
  }
}
