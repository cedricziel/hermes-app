// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_speak_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TTSSpeakRequestCWProxy {
  TTSSpeakRequest text(String text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TTSSpeakRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TTSSpeakRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  TTSSpeakRequest call({String text});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTTSSpeakRequest.copyWith(...)` or call `instanceOfTTSSpeakRequest.copyWith.fieldName(value)` for a single field.
class _$TTSSpeakRequestCWProxyImpl implements _$TTSSpeakRequestCWProxy {
  const _$TTSSpeakRequestCWProxyImpl(this._value);

  final TTSSpeakRequest _value;

  @override
  TTSSpeakRequest text(String text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TTSSpeakRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TTSSpeakRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TTSSpeakRequest call({Object? text = const $CopyWithPlaceholder()}) {
    return TTSSpeakRequest(
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as String,
    );
  }
}

extension $TTSSpeakRequestCopyWith on TTSSpeakRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTTSSpeakRequest.copyWith(...)` or `instanceOfTTSSpeakRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TTSSpeakRequestCWProxy get copyWith => _$TTSSpeakRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TTSSpeakRequest _$TTSSpeakRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TTSSpeakRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['text']);
      final val = TTSSpeakRequest(
        text: $checkedConvert('text', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$TTSSpeakRequestToJson(TTSSpeakRequest instance) =>
    <String, dynamic>{'text': instance.text};
