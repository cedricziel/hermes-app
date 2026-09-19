// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_refresh_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NativeRefreshBodyCWProxy {
  NativeRefreshBody refreshToken(String refreshToken);

  NativeRefreshBody provider(String? provider);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NativeRefreshBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NativeRefreshBody(...).copyWith(id: 12, name: "My name")
  /// ````
  NativeRefreshBody call({String refreshToken, String? provider});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNativeRefreshBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNativeRefreshBody.copyWith.fieldName(...)`
class _$NativeRefreshBodyCWProxyImpl implements _$NativeRefreshBodyCWProxy {
  const _$NativeRefreshBodyCWProxyImpl(this._value);

  final NativeRefreshBody _value;

  @override
  NativeRefreshBody refreshToken(String refreshToken) =>
      this(refreshToken: refreshToken);

  @override
  NativeRefreshBody provider(String? provider) => this(provider: provider);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NativeRefreshBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NativeRefreshBody(...).copyWith(id: 12, name: "My name")
  /// ````
  NativeRefreshBody call({
    Object? refreshToken = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
  }) {
    return NativeRefreshBody(
      refreshToken: refreshToken == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfNativeRefreshBody.copyWith(...)` or like so:`instanceOfNativeRefreshBody.copyWith.fieldName(...)`.
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
