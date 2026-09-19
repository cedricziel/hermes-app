// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'o_auth_submit_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OAuthSubmitBodyCWProxy {
  OAuthSubmitBody sessionId(String sessionId);

  OAuthSubmitBody code(String code);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OAuthSubmitBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OAuthSubmitBody(...).copyWith(id: 12, name: "My name")
  /// ````
  OAuthSubmitBody call({String sessionId, String code});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOAuthSubmitBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOAuthSubmitBody.copyWith.fieldName(...)`
class _$OAuthSubmitBodyCWProxyImpl implements _$OAuthSubmitBodyCWProxy {
  const _$OAuthSubmitBodyCWProxyImpl(this._value);

  final OAuthSubmitBody _value;

  @override
  OAuthSubmitBody sessionId(String sessionId) => this(sessionId: sessionId);

  @override
  OAuthSubmitBody code(String code) => this(code: code);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OAuthSubmitBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OAuthSubmitBody(...).copyWith(id: 12, name: "My name")
  /// ````
  OAuthSubmitBody call({
    Object? sessionId = const $CopyWithPlaceholder(),
    Object? code = const $CopyWithPlaceholder(),
  }) {
    return OAuthSubmitBody(
      sessionId: sessionId == const $CopyWithPlaceholder()
          ? _value.sessionId
          // ignore: cast_nullable_to_non_nullable
          : sessionId as String,
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
    );
  }
}

extension $OAuthSubmitBodyCopyWith on OAuthSubmitBody {
  /// Returns a callable class that can be used as follows: `instanceOfOAuthSubmitBody.copyWith(...)` or like so:`instanceOfOAuthSubmitBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OAuthSubmitBodyCWProxy get copyWith => _$OAuthSubmitBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OAuthSubmitBody _$OAuthSubmitBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OAuthSubmitBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['session_id', 'code']);
      final val = OAuthSubmitBody(
        sessionId: $checkedConvert('session_id', (v) => v as String),
        code: $checkedConvert('code', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'sessionId': 'session_id'});

Map<String, dynamic> _$OAuthSubmitBodyToJson(OAuthSubmitBody instance) =>
    <String, dynamic>{'session_id': instance.sessionId, 'code': instance.code};
