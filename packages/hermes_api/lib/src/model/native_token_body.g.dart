// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'native_token_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NativeTokenBodyCWProxy {
  NativeTokenBody code(String code);

  NativeTokenBody codeVerifier(String codeVerifier);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NativeTokenBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NativeTokenBody(...).copyWith(id: 12, name: "My name")
  /// ````
  NativeTokenBody call({String code, String codeVerifier});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNativeTokenBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNativeTokenBody.copyWith.fieldName(...)`
class _$NativeTokenBodyCWProxyImpl implements _$NativeTokenBodyCWProxy {
  const _$NativeTokenBodyCWProxyImpl(this._value);

  final NativeTokenBody _value;

  @override
  NativeTokenBody code(String code) => this(code: code);

  @override
  NativeTokenBody codeVerifier(String codeVerifier) =>
      this(codeVerifier: codeVerifier);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NativeTokenBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NativeTokenBody(...).copyWith(id: 12, name: "My name")
  /// ````
  NativeTokenBody call({
    Object? code = const $CopyWithPlaceholder(),
    Object? codeVerifier = const $CopyWithPlaceholder(),
  }) {
    return NativeTokenBody(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      codeVerifier: codeVerifier == const $CopyWithPlaceholder()
          ? _value.codeVerifier
          // ignore: cast_nullable_to_non_nullable
          : codeVerifier as String,
    );
  }
}

extension $NativeTokenBodyCopyWith on NativeTokenBody {
  /// Returns a callable class that can be used as follows: `instanceOfNativeTokenBody.copyWith(...)` or like so:`instanceOfNativeTokenBody.copyWith.fieldName(...)`.
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
