// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_set_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FontSetBodyCWProxy {
  FontSetBody font(String font);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FontSetBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FontSetBody(...).copyWith(id: 12, name: "My name")
  /// ````
  FontSetBody call({String font});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFontSetBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFontSetBody.copyWith.fieldName(...)`
class _$FontSetBodyCWProxyImpl implements _$FontSetBodyCWProxy {
  const _$FontSetBodyCWProxyImpl(this._value);

  final FontSetBody _value;

  @override
  FontSetBody font(String font) => this(font: font);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FontSetBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FontSetBody(...).copyWith(id: 12, name: "My name")
  /// ````
  FontSetBody call({Object? font = const $CopyWithPlaceholder()}) {
    return FontSetBody(
      font: font == const $CopyWithPlaceholder()
          ? _value.font
          // ignore: cast_nullable_to_non_nullable
          : font as String,
    );
  }
}

extension $FontSetBodyCopyWith on FontSetBody {
  /// Returns a callable class that can be used as follows: `instanceOfFontSetBody.copyWith(...)` or like so:`instanceOfFontSetBody.copyWith.fieldName(...)`.
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
