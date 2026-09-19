// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_speak_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TTSSpeakRequestCWProxy {
  TTSSpeakRequest text(String text);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TTSSpeakRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TTSSpeakRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TTSSpeakRequest call({String text});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTTSSpeakRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTTSSpeakRequest.copyWith.fieldName(...)`
class _$TTSSpeakRequestCWProxyImpl implements _$TTSSpeakRequestCWProxy {
  const _$TTSSpeakRequestCWProxyImpl(this._value);

  final TTSSpeakRequest _value;

  @override
  TTSSpeakRequest text(String text) => this(text: text);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TTSSpeakRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TTSSpeakRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TTSSpeakRequest call({Object? text = const $CopyWithPlaceholder()}) {
    return TTSSpeakRequest(
      text: text == const $CopyWithPlaceholder()
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as String,
    );
  }
}

extension $TTSSpeakRequestCopyWith on TTSSpeakRequest {
  /// Returns a callable class that can be used as follows: `instanceOfTTSSpeakRequest.copyWith(...)` or like so:`instanceOfTTSSpeakRequest.copyWith.fieldName(...)`.
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
