// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_login_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PasswordLoginBodyCWProxy {
  PasswordLoginBody provider(String provider);

  PasswordLoginBody username(String username);

  PasswordLoginBody password(String password);

  PasswordLoginBody next(String? next);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PasswordLoginBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PasswordLoginBody(...).copyWith(id: 12, name: "My name")
  /// ````
  PasswordLoginBody call({
    String provider,
    String username,
    String password,
    String? next,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPasswordLoginBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPasswordLoginBody.copyWith.fieldName(...)`
class _$PasswordLoginBodyCWProxyImpl implements _$PasswordLoginBodyCWProxy {
  const _$PasswordLoginBodyCWProxyImpl(this._value);

  final PasswordLoginBody _value;

  @override
  PasswordLoginBody provider(String provider) => this(provider: provider);

  @override
  PasswordLoginBody username(String username) => this(username: username);

  @override
  PasswordLoginBody password(String password) => this(password: password);

  @override
  PasswordLoginBody next(String? next) => this(next: next);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PasswordLoginBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PasswordLoginBody(...).copyWith(id: 12, name: "My name")
  /// ````
  PasswordLoginBody call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? username = const $CopyWithPlaceholder(),
    Object? password = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
  }) {
    return PasswordLoginBody(
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      username: username == const $CopyWithPlaceholder()
          ? _value.username
          // ignore: cast_nullable_to_non_nullable
          : username as String,
      password: password == const $CopyWithPlaceholder()
          ? _value.password
          // ignore: cast_nullable_to_non_nullable
          : password as String,
      next: next == const $CopyWithPlaceholder()
          ? _value.next
          // ignore: cast_nullable_to_non_nullable
          : next as String?,
    );
  }
}

extension $PasswordLoginBodyCopyWith on PasswordLoginBody {
  /// Returns a callable class that can be used as follows: `instanceOfPasswordLoginBody.copyWith(...)` or like so:`instanceOfPasswordLoginBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PasswordLoginBodyCWProxy get copyWith =>
      _$PasswordLoginBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PasswordLoginBody _$PasswordLoginBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PasswordLoginBody', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['provider', 'username', 'password'],
      );
      final val = PasswordLoginBody(
        provider: $checkedConvert('provider', (v) => v as String),
        username: $checkedConvert('username', (v) => v as String),
        password: $checkedConvert('password', (v) => v as String),
        next: $checkedConvert('next', (v) => v as String? ?? ''),
      );
      return val;
    });

Map<String, dynamic> _$PasswordLoginBodyToJson(PasswordLoginBody instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'username': instance.username,
      'password': instance.password,
      'next': ?instance.next,
    };
