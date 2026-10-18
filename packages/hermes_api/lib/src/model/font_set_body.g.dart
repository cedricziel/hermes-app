// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_set_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FontSetBodyCWProxy {
  FontSetBody font(String font);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FontSetBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FontSetBody(...).copyWith(id: 12, name: "My name")
  /// ```
  FontSetBody call({String font});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfFontSetBody.copyWith(...)` or call `instanceOfFontSetBody.copyWith.fieldName(value)` for a single field.
class _$FontSetBodyCWProxyImpl implements _$FontSetBodyCWProxy {
  const _$FontSetBodyCWProxyImpl(this._value);

  final FontSetBody _value;

  @override
  FontSetBody font(String font) => call(font: font);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FontSetBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FontSetBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  FontSetBody call({Object? font = const $CopyWithPlaceholder()}) {
    return FontSetBody(
      font: font == const $CopyWithPlaceholder() || font == null
          ? _value.font
          // ignore: cast_nullable_to_non_nullable
          : font as String,
    );
  }
}

extension $FontSetBodyCopyWith on FontSetBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfFontSetBody.copyWith(...)` or `instanceOfFontSetBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FontSetBodyCWProxy get copyWith => _$FontSetBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FontSetBody _$FontSetBodyFromJson(Map<String, dynamic> json) => $checkedCreate(
  'FontSetBody',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['font']);
    final val = FontSetBody(font: $checkedConvert('font', (v) => v as String));
    return val;
  },
);

Map<String, dynamic> _$FontSetBodyToJson(FontSetBody instance) =>
    <String, dynamic>{'font': instance.font};
