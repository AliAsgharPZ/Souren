// Vendored Phosphor icon code points (MIT, Phosphor Icons).
// phosphor_flutter 2.1.0 cannot compile on current Flutter stable:
// its PhosphorIconData extends IconData, which is now a final class.
// The Phosphor TTFs are vendored in assets/fonts/phosphor/ and these
// plain IconData constants point at them, so no package import is
// needed. Code points copied from phosphor_flutter 2.1.0.
import 'package:flutter/widgets.dart';

/// Regular-weight Phosphor icons (unselected state).
class PhosphorIconsRegular {
  const PhosphorIconsRegular();
  static const airplaneTilt = IconData(
    0xe5d6,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const arrowClockwise = IconData(0xe036, fontFamily: 'PhosphorRegular');
  static const arrowLeft = IconData(
    0xe058,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const arrowsLeftRight = IconData(
    0xe0a0,
    fontFamily: 'PhosphorRegular',
  );
  static const bank = IconData(0xe0b4, fontFamily: 'PhosphorRegular');
  static const bookOpen = IconData(0xe0e6, fontFamily: 'PhosphorRegular');
  static const bookmark = IconData(0xe0e8, fontFamily: 'PhosphorRegular');
  static const books = IconData(0xe758, fontFamily: 'PhosphorRegular');
  static const brain = IconData(0xe74e, fontFamily: 'PhosphorRegular');
  static const briefcase = IconData(0xe0ee, fontFamily: 'PhosphorRegular');
  static const caretLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const chatsCircle = IconData(0xe17e, fontFamily: 'PhosphorRegular');
  static const clock = IconData(0xe19a, fontFamily: 'PhosphorRegular');
  static const cloudArrowDown = IconData(0xe1ac, fontFamily: 'PhosphorRegular');
  static const copy = IconData(0xe1ca, fontFamily: 'PhosphorRegular');
  static const export = IconData(0xeaf0, fontFamily: 'PhosphorRegular');
  static const firstAidKit = IconData(0xe570, fontFamily: 'PhosphorRegular');
  static const flowerLotus = IconData(0xe6cc, fontFamily: 'PhosphorRegular');
  static const gear = IconData(0xe270, fontFamily: 'PhosphorRegular');
  static const globe = IconData(0xe288, fontFamily: 'PhosphorRegular');
  static const graduationCap = IconData(0xe62c, fontFamily: 'PhosphorRegular');
  static const gridFour = IconData(0xe296, fontFamily: 'PhosphorRegular');
  static const heart = IconData(0xe2a8, fontFamily: 'PhosphorRegular');
  static const house = IconData(0xe2c2, fontFamily: 'PhosphorRegular');
  static const keyboard = IconData(0xe2d8, fontFamily: 'PhosphorRegular');
  static const lock = IconData(0xe2fa, fontFamily: 'PhosphorRegular');
  static const magnifyingGlass = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
  );
  static const quotes = IconData(0xe660, fontFamily: 'PhosphorRegular');
  static const sealCheck = IconData(0xe606, fontFamily: 'PhosphorRegular');
  static const sparkle = IconData(0xe6a2, fontFamily: 'PhosphorRegular');
  static const squaresFour = IconData(0xe464, fontFamily: 'PhosphorRegular');
  static const star = IconData(0xe46a, fontFamily: 'PhosphorRegular');
  static const storefront = IconData(0xe470, fontFamily: 'PhosphorRegular');
  static const textAa = IconData(0xe6ee, fontFamily: 'PhosphorRegular');
  static const textH = IconData(0xe6ba, fontFamily: 'PhosphorRegular');
  static const tree = IconData(0xe6da, fontFamily: 'PhosphorRegular');
  static const treeStructure = IconData(0xe67c, fontFamily: 'PhosphorRegular');
  static const user = IconData(0xe4c2, fontFamily: 'PhosphorRegular');
}

/// Fill-weight Phosphor icons (selected state).
class PhosphorIconsFill {
  const PhosphorIconsFill();
  static const bookmark = IconData(0xe0e8, fontFamily: 'PhosphorFill');
  static const gear = IconData(0xe270, fontFamily: 'PhosphorFill');
  static const heart = IconData(0xe2a8, fontFamily: 'PhosphorFill');
  static const house = IconData(0xe2c2, fontFamily: 'PhosphorFill');
  static const squaresFour = IconData(0xe464, fontFamily: 'PhosphorFill');
  static const user = IconData(0xe4c2, fontFamily: 'PhosphorFill');
}
