// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validation_error.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ValidationErrorCWProxy {
  ValidationError loc(List<Object> loc);

  ValidationError msg(String msg);

  ValidationError type(String type);

  ValidationError input(Object? input);

  ValidationError ctx(Object? ctx);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ValidationError(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ValidationError(...).copyWith(id: 12, name: "My name")
  /// ```
  ValidationError call({
    List<Object> loc,
    String msg,
    String type,
    Object? input,
    Object? ctx,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfValidationError.copyWith(...)` or call `instanceOfValidationError.copyWith.fieldName(value)` for a single field.
class _$ValidationErrorCWProxyImpl implements _$ValidationErrorCWProxy {
  const _$ValidationErrorCWProxyImpl(this._value);

  final ValidationError _value;

  @override
  ValidationError loc(List<Object> loc) => call(loc: loc);

  @override
  ValidationError msg(String msg) => call(msg: msg);

  @override
  ValidationError type(String type) => call(type: type);

  @override
  ValidationError input(Object? input) => call(input: input);

  @override
  ValidationError ctx(Object? ctx) => call(ctx: ctx);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ValidationError(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ValidationError(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ValidationError call({
    Object? loc = const $CopyWithPlaceholder(),
    Object? msg = const $CopyWithPlaceholder(),
    Object? type = const $CopyWithPlaceholder(),
    Object? input = const $CopyWithPlaceholder(),
    Object? ctx = const $CopyWithPlaceholder(),
  }) {
    return ValidationError(
      loc: loc == const $CopyWithPlaceholder() || loc == null
          ? _value.loc
          // ignore: cast_nullable_to_non_nullable
          : loc as List<Object>,
      msg: msg == const $CopyWithPlaceholder() || msg == null
          ? _value.msg
          // ignore: cast_nullable_to_non_nullable
          : msg as String,
      type: type == const $CopyWithPlaceholder() || type == null
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      input: input == const $CopyWithPlaceholder()
          ? _value.input
          // ignore: cast_nullable_to_non_nullable
          : input as Object?,
      ctx: ctx == const $CopyWithPlaceholder()
          ? _value.ctx
          // ignore: cast_nullable_to_non_nullable
          : ctx as Object?,
    );
  }
}

extension $ValidationErrorCopyWith on ValidationError {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfValidationError.copyWith(...)` or `instanceOfValidationError.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ValidationErrorCWProxy get copyWith => _$ValidationErrorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ValidationError _$ValidationErrorFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ValidationError', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['loc', 'msg', 'type']);
      final val = ValidationError(
        loc: $checkedConvert(
          'loc',
          (v) => (v as List<dynamic>).map((e) => e as Object).toList(),
        ),
        msg: $checkedConvert('msg', (v) => v as String),
        type: $checkedConvert('type', (v) => v as String),
        input: $checkedConvert('input', (v) => v),
        ctx: $checkedConvert('ctx', (v) => v),
      );
      return val;
    });

Map<String, dynamic> _$ValidationErrorToJson(ValidationError instance) =>
    <String, dynamic>{
      'loc': instance.loc,
      'msg': instance.msg,
      'type': instance.type,
      'input': ?instance.input,
      'ctx': ?instance.ctx,
    };
