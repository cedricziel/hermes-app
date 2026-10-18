// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credential_pool_add.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CredentialPoolAddCWProxy {
  CredentialPoolAdd provider(String provider);

  CredentialPoolAdd apiKey(String apiKey);

  CredentialPoolAdd label(String? label);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CredentialPoolAdd(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CredentialPoolAdd(...).copyWith(id: 12, name: "My name")
  /// ```
  CredentialPoolAdd call({String provider, String apiKey, String? label});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCredentialPoolAdd.copyWith(...)` or call `instanceOfCredentialPoolAdd.copyWith.fieldName(value)` for a single field.
class _$CredentialPoolAddCWProxyImpl implements _$CredentialPoolAddCWProxy {
  const _$CredentialPoolAddCWProxyImpl(this._value);

  final CredentialPoolAdd _value;

  @override
  CredentialPoolAdd provider(String provider) => call(provider: provider);

  @override
  CredentialPoolAdd apiKey(String apiKey) => call(apiKey: apiKey);

  @override
  CredentialPoolAdd label(String? label) => call(label: label);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CredentialPoolAdd(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CredentialPoolAdd(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CredentialPoolAdd call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? apiKey = const $CopyWithPlaceholder(),
    Object? label = const $CopyWithPlaceholder(),
  }) {
    return CredentialPoolAdd(
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      apiKey: apiKey == const $CopyWithPlaceholder() || apiKey == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCredentialPoolAdd.copyWith(...)` or `instanceOfCredentialPoolAdd.copyWith.fieldName(...)`.
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
