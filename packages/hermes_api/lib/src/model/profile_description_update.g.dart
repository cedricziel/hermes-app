// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_description_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileDescriptionUpdateCWProxy {
  ProfileDescriptionUpdate description(String? description);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileDescriptionUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileDescriptionUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileDescriptionUpdate call({String? description});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileDescriptionUpdate.copyWith(...)` or call `instanceOfProfileDescriptionUpdate.copyWith.fieldName(value)` for a single field.
class _$ProfileDescriptionUpdateCWProxyImpl
    implements _$ProfileDescriptionUpdateCWProxy {
  const _$ProfileDescriptionUpdateCWProxyImpl(this._value);

  final ProfileDescriptionUpdate _value;

  @override
  ProfileDescriptionUpdate description(String? description) =>
      call(description: description);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileDescriptionUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileDescriptionUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileDescriptionUpdate call({
    Object? description = const $CopyWithPlaceholder(),
  }) {
    return ProfileDescriptionUpdate(
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String?,
    );
  }
}

extension $ProfileDescriptionUpdateCopyWith on ProfileDescriptionUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileDescriptionUpdate.copyWith(...)` or `instanceOfProfileDescriptionUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileDescriptionUpdateCWProxy get copyWith =>
      _$ProfileDescriptionUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileDescriptionUpdate _$ProfileDescriptionUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ProfileDescriptionUpdate', json, ($checkedConvert) {
  final val = ProfileDescriptionUpdate(
    description: $checkedConvert('description', (v) => v as String? ?? ''),
  );
  return val;
});

Map<String, dynamic> _$ProfileDescriptionUpdateToJson(
  ProfileDescriptionUpdate instance,
) => <String, dynamic>{'description': ?instance.description};
