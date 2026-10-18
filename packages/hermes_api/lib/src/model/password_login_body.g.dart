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

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PasswordLoginBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PasswordLoginBody(...).copyWith(id: 12, name: "My name")
  /// ```
  PasswordLoginBody call({
    String provider,
    String username,
    String password,
    String? next,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPasswordLoginBody.copyWith(...)` or call `instanceOfPasswordLoginBody.copyWith.fieldName(value)` for a single field.
class _$PasswordLoginBodyCWProxyImpl implements _$PasswordLoginBodyCWProxy {
  const _$PasswordLoginBodyCWProxyImpl(this._value);

  final PasswordLoginBody _value;

  @override
  PasswordLoginBody provider(String provider) => call(provider: provider);

  @override
  PasswordLoginBody username(String username) => call(username: username);

  @override
  PasswordLoginBody password(String password) => call(password: password);

  @override
  PasswordLoginBody next(String? next) => call(next: next);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PasswordLoginBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PasswordLoginBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PasswordLoginBody call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? username = const $CopyWithPlaceholder(),
    Object? password = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
  }) {
    return PasswordLoginBody(
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      username: username == const $CopyWithPlaceholder() || username == null
          ? _value.username
          // ignore: cast_nullable_to_non_nullable
          : username as String,
      password: password == const $CopyWithPlaceholder() || password == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPasswordLoginBody.copyWith(...)` or `instanceOfPasswordLoginBody.copyWith.fieldName(...)`.
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
