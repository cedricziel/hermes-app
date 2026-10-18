// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileModelUpdateCWProxy {
  ProfileModelUpdate provider(String provider);

  ProfileModelUpdate model(String model);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileModelUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileModelUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileModelUpdate call({String provider, String model});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileModelUpdate.copyWith(...)` or call `instanceOfProfileModelUpdate.copyWith.fieldName(value)` for a single field.
class _$ProfileModelUpdateCWProxyImpl implements _$ProfileModelUpdateCWProxy {
  const _$ProfileModelUpdateCWProxyImpl(this._value);

  final ProfileModelUpdate _value;

  @override
  ProfileModelUpdate provider(String provider) => call(provider: provider);

  @override
  ProfileModelUpdate model(String model) => call(model: model);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileModelUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileModelUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileModelUpdate call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
  }) {
    return ProfileModelUpdate(
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      model: model == const $CopyWithPlaceholder() || model == null
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String,
    );
  }
}

extension $ProfileModelUpdateCopyWith on ProfileModelUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileModelUpdate.copyWith(...)` or `instanceOfProfileModelUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileModelUpdateCWProxy get copyWith =>
      _$ProfileModelUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileModelUpdate _$ProfileModelUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileModelUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['provider', 'model']);
      final val = ProfileModelUpdate(
        provider: $checkedConvert('provider', (v) => v as String),
        model: $checkedConvert('model', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ProfileModelUpdateToJson(ProfileModelUpdate instance) =>
    <String, dynamic>{'provider': instance.provider, 'model': instance.model};
