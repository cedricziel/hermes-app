import 'package:flutter/material.dart';

/// The colours of syntax-highlighted code, one per token class, the canvas
/// palette: keys and functions blue, strings teal, numbers (and `true`,
/// `false`, `null`, semibold) purple, keywords pink; comments and punctuation
/// take the muted text colour. Red and green are never syntax colours: they
/// mean status and diff. Each stands at least 4.5:1 off the page, the card
/// and the raised surface of its theme (`test/theme/code_palette_test.dart`).
///
/// Mirrors `--h-code-*` in `design/web/src/styles/tokens.css`; change both
/// together.
@immutable
class HermesCodeColors extends ThemeExtension<HermesCodeColors> {
  const HermesCodeColors({
    required this.key,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.function,
    required this.typeName,
  });

  static const light = HermesCodeColors(
    key: Color(0xFF1D4ED8),
    keyword: Color(0xFFBE185D),
    string: Color(0xFF0F766E),
    comment: Color(0xFF6B6B74),
    number: Color(0xFF7E22CE),
    function: Color(0xFF1D4ED8),
    typeName: Color(0xFF8A5A00),
  );

  static const dark = HermesCodeColors(
    key: Color(0xFF93C5FD),
    keyword: Color(0xFFF9A8D4),
    string: Color(0xFF5EEAD4),
    comment: Color(0xFFA1A1AA),
    number: Color(0xFFD8B4FE),
    function: Color(0xFF93C5FD),
    typeName: Color(0xFFFCD34D),
  );

  /// An object key (JSON, YAML).
  final Color key;
  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color function;
  final Color typeName;

  @override
  HermesCodeColors copyWith({
    Color? key,
    Color? keyword,
    Color? string,
    Color? comment,
    Color? number,
    Color? function,
    Color? typeName,
  }) => HermesCodeColors(
    key: key ?? this.key,
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
      key: Color.lerp(key, other.key, t)!,
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
