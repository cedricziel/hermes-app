// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileModelUpdateCWProxy {
  ProfileModelUpdate provider(String provider);

  ProfileModelUpdate model(String model);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileModelUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileModelUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileModelUpdate call({String provider, String model});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileModelUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileModelUpdate.copyWith.fieldName(...)`
class _$ProfileModelUpdateCWProxyImpl implements _$ProfileModelUpdateCWProxy {
  const _$ProfileModelUpdateCWProxyImpl(this._value);

  final ProfileModelUpdate _value;

  @override
  ProfileModelUpdate provider(String provider) => this(provider: provider);

  @override
  ProfileModelUpdate model(String model) => this(model: model);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileModelUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileModelUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileModelUpdate call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
  }) {
    return ProfileModelUpdate(
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      model: model == const $CopyWithPlaceholder()
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String,
    );
  }
}

extension $ProfileModelUpdateCopyWith on ProfileModelUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfProfileModelUpdate.copyWith(...)` or like so:`instanceOfProfileModelUpdate.copyWith.fieldName(...)`.
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
