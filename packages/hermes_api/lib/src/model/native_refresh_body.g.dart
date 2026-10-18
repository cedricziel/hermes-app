// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_refresh_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NativeRefreshBodyCWProxy {
  NativeRefreshBody refreshToken(String refreshToken);

  NativeRefreshBody provider(String? provider);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NativeRefreshBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NativeRefreshBody(...).copyWith(id: 12, name: "My name")
  /// ```
  NativeRefreshBody call({String refreshToken, String? provider});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfNativeRefreshBody.copyWith(...)` or call `instanceOfNativeRefreshBody.copyWith.fieldName(value)` for a single field.
class _$NativeRefreshBodyCWProxyImpl implements _$NativeRefreshBodyCWProxy {
  const _$NativeRefreshBodyCWProxyImpl(this._value);

  final NativeRefreshBody _value;

  @override
  NativeRefreshBody refreshToken(String refreshToken) =>
      call(refreshToken: refreshToken);

  @override
  NativeRefreshBody provider(String? provider) => call(provider: provider);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NativeRefreshBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NativeRefreshBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  NativeRefreshBody call({
    Object? refreshToken = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
  }) {
    return NativeRefreshBody(
      refreshToken:
          refreshToken == const $CopyWithPlaceholder() || refreshToken == null
          ? _value.refreshToken
          // ignore: cast_nullable_to_non_nullable
          : refreshToken as String,
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String?,
    );
  }
}

extension $NativeRefreshBodyCopyWith on NativeRefreshBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfNativeRefreshBody.copyWith(...)` or `instanceOfNativeRefreshBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NativeRefreshBodyCWProxy get copyWith =>
      _$NativeRefreshBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NativeRefreshBody _$NativeRefreshBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NativeRefreshBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['refresh_token']);
      final val = NativeRefreshBody(
        refreshToken: $checkedConvert('refresh_token', (v) => v as String),
        provider: $checkedConvert('provider', (v) => v as String? ?? ''),
      );
      return val;
    }, fieldKeyMap: const {'refreshToken': 'refresh_token'});

Map<String, dynamic> _$NativeRefreshBodyToJson(NativeRefreshBody instance) =>
    <String, dynamic>{
      'refresh_token': instance.refreshToken,
      'provider': ?instance.provider,
    };
