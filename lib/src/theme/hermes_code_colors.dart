import 'package:flutter/material.dart';

/// The colours of syntax-highlighted code, one per token class. Each stands at
/// least 5.2:1 off the page and the raised surface of its theme.
///
/// Mirrors `--h-code-*` in `design/web/src/styles/tokens.css`; change both
/// together.
@immutable
class HermesCodeColors extends ThemeExtension<HermesCodeColors> {
  const HermesCodeColors({
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.function,
    required this.typeName,
  });

  static const light = HermesCodeColors(
    keyword: Color(0xFFA626A4),
    string: Color(0xFF0B6E2F),
    comment: Color(0xFF5F6670),
    number: Color(0xFFA3480B),
    function: Color(0xFF1D4ED8),
    typeName: Color(0xFF8A5A00),
  );

  static const dark = HermesCodeColors(
    keyword: Color(0xFFE08EF0),
    string: Color(0xFF7EE2A8),
    comment: Color(0xFFA1A1AA),
    number: Color(0xFFFDBA74),
    function: Color(0xFF93C5FD),
    typeName: Color(0xFFFCD34D),
  );

  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color function;
  final Color typeName;

  @override
  HermesCodeColors copyWith({
    Color? keyword,
    Color? string,
    Color? comment,
    Color? number,
    Color? function,
    Color? typeName,
  }) => HermesCodeColors(
    keyword: keyword ?? this.keyword,
    string: string ?? this.string,
    comment: comment ?? this.comment,
    number: number ?? this.number,
    function: function ?? this.function,
    typeName: typeName ?? this.typeName,
  );

  @override
  HermesCodeColors lerp(ThemeExtension<HermesCodeColors>? other, double t) {
    if (other is! HermesCodeColors) return this;
    return HermesCodeColors(
      keyword: Color.lerp(keyword, other.keyword, t)!,
      string: Color.lerp(string, other.string, t)!,
      comment: Color.lerp(comment, other.comment, t)!,
      number: Color.lerp(number, other.number, t)!,
      function: Color.lerp(function, other.function, t)!,
      typeName: Color.lerp(typeName, other.typeName, t)!,
    );
  }
}

extension HermesCodeColorsX on BuildContext {
  /// Falls back to the palette of the theme's brightness under a theme
  /// without the extension, such as a test's plain `MaterialApp`.
  HermesCodeColors get codeColors {
    final theme = Theme.of(this);
    return theme.extension<HermesCodeColors>() ??
        (theme.brightness == Brightness.dark
            ? HermesCodeColors.dark
            : HermesCodeColors.light);
  }
}
