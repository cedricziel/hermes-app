// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_active_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileActiveUpdateCWProxy {
  ProfileActiveUpdate name(String name);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileActiveUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileActiveUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileActiveUpdate call({String name});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileActiveUpdate.copyWith(...)` or call `instanceOfProfileActiveUpdate.copyWith.fieldName(value)` for a single field.
class _$ProfileActiveUpdateCWProxyImpl implements _$ProfileActiveUpdateCWProxy {
  const _$ProfileActiveUpdateCWProxyImpl(this._value);

  final ProfileActiveUpdate _value;

  @override
  ProfileActiveUpdate name(String name) => call(name: name);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileActiveUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileActiveUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileActiveUpdate call({Object? name = const $CopyWithPlaceholder()}) {
    return ProfileActiveUpdate(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
    );
  }
}

extension $ProfileActiveUpdateCopyWith on ProfileActiveUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileActiveUpdate.copyWith(...)` or `instanceOfProfileActiveUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileActiveUpdateCWProxy get copyWith =>
      _$ProfileActiveUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileActiveUpdate _$ProfileActiveUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileActiveUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name']);
      final val = ProfileActiveUpdate(
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ProfileActiveUpdateToJson(
  ProfileActiveUpdate instance,
) => <String, dynamic>{'name': instance.name};
