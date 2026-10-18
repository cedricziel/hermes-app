// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_post_setup.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetPostSetupCWProxy {
  ToolsetPostSetup key(String key);

  ToolsetPostSetup profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetPostSetup(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetPostSetup(...).copyWith(id: 12, name: "My name")
  /// ```
  ToolsetPostSetup call({String key, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfToolsetPostSetup.copyWith(...)` or call `instanceOfToolsetPostSetup.copyWith.fieldName(value)` for a single field.
class _$ToolsetPostSetupCWProxyImpl implements _$ToolsetPostSetupCWProxy {
  const _$ToolsetPostSetupCWProxyImpl(this._value);

  final ToolsetPostSetup _value;

  @override
  ToolsetPostSetup key(String key) => call(key: key);

  @override
  ToolsetPostSetup profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetPostSetup(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetPostSetup(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ToolsetPostSetup call({
    Object? key = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetPostSetup(
      key: key == const $CopyWithPlaceholder() || key == null
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $ToolsetPostSetupCopyWith on ToolsetPostSetup {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfToolsetPostSetup.copyWith(...)` or `instanceOfToolsetPostSetup.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ToolsetPostSetupCWProxy get copyWith => _$ToolsetPostSetupCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolsetPostSetup _$ToolsetPostSetupFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ToolsetPostSetup', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key']);
      final val = ToolsetPostSetup(
        key: $checkedConvert('key', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ToolsetPostSetupToJson(ToolsetPostSetup instance) =>
    <String, dynamic>{'key': instance.key, 'profile': ?instance.profile};
