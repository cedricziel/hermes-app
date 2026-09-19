// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_set_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ThemeSetBodyCWProxy {
  ThemeSetBody name(String name);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ThemeSetBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ThemeSetBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ThemeSetBody call({String name});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfThemeSetBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfThemeSetBody.copyWith.fieldName(...)`
class _$ThemeSetBodyCWProxyImpl implements _$ThemeSetBodyCWProxy {
  const _$ThemeSetBodyCWProxyImpl(this._value);

  final ThemeSetBody _value;

  @override
  ThemeSetBody name(String name) => this(name: name);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ThemeSetBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ThemeSetBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ThemeSetBody call({Object? name = const $CopyWithPlaceholder()}) {
    return ThemeSetBody(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
    );
  }
}

extension $ThemeSetBodyCopyWith on ThemeSetBody {
  /// Returns a callable class that can be used as follows: `instanceOfThemeSetBody.copyWith(...)` or like so:`instanceOfThemeSetBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ThemeSetBodyCWProxy get copyWith => _$ThemeSetBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeSetBody _$ThemeSetBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ThemeSetBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name']);
      final val = ThemeSetBody(
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ThemeSetBodyToJson(ThemeSetBody instance) =>
    <String, dynamic>{'name': instance.name};
