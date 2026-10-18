// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'o_auth_submit_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OAuthSubmitBodyCWProxy {
  OAuthSubmitBody sessionId(String sessionId);

  OAuthSubmitBody code(String code);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `OAuthSubmitBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// OAuthSubmitBody(...).copyWith(id: 12, name: "My name")
  /// ```
  OAuthSubmitBody call({String sessionId, String code});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfOAuthSubmitBody.copyWith(...)` or call `instanceOfOAuthSubmitBody.copyWith.fieldName(value)` for a single field.
class _$OAuthSubmitBodyCWProxyImpl implements _$OAuthSubmitBodyCWProxy {
  const _$OAuthSubmitBodyCWProxyImpl(this._value);

  final OAuthSubmitBody _value;

  @override
  OAuthSubmitBody sessionId(String sessionId) => call(sessionId: sessionId);

  @override
  OAuthSubmitBody code(String code) => call(code: code);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `OAuthSubmitBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// OAuthSubmitBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  OAuthSubmitBody call({
    Object? sessionId = const $CopyWithPlaceholder(),
    Object? code = const $CopyWithPlaceholder(),
  }) {
    return OAuthSubmitBody(
      sessionId: sessionId == const $CopyWithPlaceholder() || sessionId == null
          ? _value.sessionId
          // ignore: cast_nullable_to_non_nullable
          : sessionId as String,
      code: code == const $CopyWithPlaceholder() || code == null
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
    );
  }
}

extension $OAuthSubmitBodyCopyWith on OAuthSubmitBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfOAuthSubmitBody.copyWith(...)` or `instanceOfOAuthSubmitBody.copyWith.fieldName(...)`.
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
