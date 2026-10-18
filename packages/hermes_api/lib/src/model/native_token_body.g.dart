// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_token_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NativeTokenBodyCWProxy {
  NativeTokenBody code(String code);

  NativeTokenBody codeVerifier(String codeVerifier);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NativeTokenBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NativeTokenBody(...).copyWith(id: 12, name: "My name")
  /// ```
  NativeTokenBody call({String code, String codeVerifier});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfNativeTokenBody.copyWith(...)` or call `instanceOfNativeTokenBody.copyWith.fieldName(value)` for a single field.
class _$NativeTokenBodyCWProxyImpl implements _$NativeTokenBodyCWProxy {
  const _$NativeTokenBodyCWProxyImpl(this._value);

  final NativeTokenBody _value;

  @override
  NativeTokenBody code(String code) => call(code: code);

  @override
  NativeTokenBody codeVerifier(String codeVerifier) =>
      call(codeVerifier: codeVerifier);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NativeTokenBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NativeTokenBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  NativeTokenBody call({
    Object? code = const $CopyWithPlaceholder(),
    Object? codeVerifier = const $CopyWithPlaceholder(),
  }) {
    return NativeTokenBody(
      code: code == const $CopyWithPlaceholder() || code == null
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      codeVerifier:
          codeVerifier == const $CopyWithPlaceholder() || codeVerifier == null
          ? _value.codeVerifier
          // ignore: cast_nullable_to_non_nullable
          : codeVerifier as String,
    );
  }
}

extension $NativeTokenBodyCopyWith on NativeTokenBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfNativeTokenBody.copyWith(...)` or `instanceOfNativeTokenBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NativeTokenBodyCWProxy get copyWith => _$NativeTokenBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NativeTokenBody _$NativeTokenBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NativeTokenBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['code', 'code_verifier']);
      final val = NativeTokenBody(
        code: $checkedConvert('code', (v) => v as String),
        codeVerifier: $checkedConvert('code_verifier', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'codeVerifier': 'code_verifier'});

Map<String, dynamic> _$NativeTokenBodyToJson(NativeTokenBody instance) =>
    <String, dynamic>{
      'code': instance.code,
      'code_verifier': instance.codeVerifier,
    };
