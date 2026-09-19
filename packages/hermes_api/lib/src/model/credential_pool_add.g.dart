// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credential_pool_add.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CredentialPoolAddCWProxy {
  CredentialPoolAdd provider(String provider);

  CredentialPoolAdd apiKey(String apiKey);

  CredentialPoolAdd label(String? label);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CredentialPoolAdd(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CredentialPoolAdd(...).copyWith(id: 12, name: "My name")
  /// ````
  CredentialPoolAdd call({String provider, String apiKey, String? label});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCredentialPoolAdd.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCredentialPoolAdd.copyWith.fieldName(...)`
class _$CredentialPoolAddCWProxyImpl implements _$CredentialPoolAddCWProxy {
  const _$CredentialPoolAddCWProxyImpl(this._value);

  final CredentialPoolAdd _value;

  @override
  CredentialPoolAdd provider(String provider) => this(provider: provider);

  @override
  CredentialPoolAdd apiKey(String apiKey) => this(apiKey: apiKey);

  @override
  CredentialPoolAdd label(String? label) => this(label: label);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CredentialPoolAdd(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CredentialPoolAdd(...).copyWith(id: 12, name: "My name")
  /// ````
  CredentialPoolAdd call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? apiKey = const $CopyWithPlaceholder(),
    Object? label = const $CopyWithPlaceholder(),
  }) {
    return CredentialPoolAdd(
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      apiKey: apiKey == const $CopyWithPlaceholder()
          ? _value.apiKey
          // ignore: cast_nullable_to_non_nullable
          : apiKey as String,
      label: label == const $CopyWithPlaceholder()
          ? _value.label
          // ignore: cast_nullable_to_non_nullable
          : label as String?,
    );
  }
}

extension $CredentialPoolAddCopyWith on CredentialPoolAdd {
  /// Returns a callable class that can be used as follows: `instanceOfCredentialPoolAdd.copyWith(...)` or like so:`instanceOfCredentialPoolAdd.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CredentialPoolAddCWProxy get copyWith =>
      _$CredentialPoolAddCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CredentialPoolAdd _$CredentialPoolAddFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CredentialPoolAdd', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['provider', 'api_key']);
      final val = CredentialPoolAdd(
        provider: $checkedConvert('provider', (v) => v as String),
        apiKey: $checkedConvert('api_key', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'apiKey': 'api_key'});

Map<String, dynamic> _$CredentialPoolAddToJson(CredentialPoolAdd instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'api_key': instance.apiKey,
      'label': ?instance.label,
    };
