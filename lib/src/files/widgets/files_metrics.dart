import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';

/// The sizes of the Files widgets on one platform: touch rows and targets of
/// 44 pt on iOS and iPadOS and 48 dp on Android, and on a Mac 32 pt pointer
/// rows with no other target under 28 pt.
class FilesMetrics {
  const FilesMetrics._({
    required this.rowMinHeight,
    required this.target,
    required this.pointer,
    required this.previewTile,
    required this.codeSize,
  });

  static const ios = FilesMetrics._(
    rowMinHeight: 44,
    target: 44,
    pointer: false,
    previewTile: 44,
    codeSize: 13,
  );

  static const material = FilesMetrics._(
    rowMinHeight: 56,
    target: 48,
    pointer: false,
    previewTile: 44,
    codeSize: 13,
  );

  static const macos = FilesMetrics._(
    rowMinHeight: 32,
    target: 28,
    pointer: true,
    previewTile: 32,
    codeSize: 12,
  );

  static FilesMetrics of(BuildContext context) =>
      switch (platformChromeOf(context)) {
        PlatformChrome.ios => ios,
        PlatformChrome.macos => macos,
        PlatformChrome.material => material,
      };

  /// The height of a file row.
  final double rowMinHeight;

  /// The smallest size of any other tappable thing.
  final double target;

  /// Whether this is a pointer platform (the Mac).
  final bool pointer;

  /// The side of the file type tile in a preview header.
  final double previewTile;

  /// The font size of text and code, with 20 pt lines.
  final double codeSize;

  /// An icon button of exactly [target] on each side, not Material's padded 48.
  ButtonStyle iconButtonStyle() => IconButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    fixedSize: Size.square(target),
    minimumSize: Size.square(target),
    padding: EdgeInsets.zero,
  );

  /// A button style that keeps the platform's smallest target.
  ButtonStyle buttonStyle({bool fullWidth = false}) => ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(fullWidth ? double.infinity : target, target),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: pointer ? 12 : 16),
    ),
  );
}

/// How many times larger than the default the system's text size is, taken
/// from a 14 point sample.
double textScaleOf(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;

/// From this scale names wrap in full and the lock of a secret file moves
/// under its name.
const double kLargeTextScale = 1.3;

bool isLargeText(BuildContext context) =>
    textScaleOf(context) > kLargeTextScale;
