// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_transcription_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AudioTranscriptionRequestCWProxy {
  AudioTranscriptionRequest dataUrl(String dataUrl);

  AudioTranscriptionRequest mimeType(String? mimeType);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AudioTranscriptionRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AudioTranscriptionRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  AudioTranscriptionRequest call({String dataUrl, String? mimeType});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAudioTranscriptionRequest.copyWith(...)` or call `instanceOfAudioTranscriptionRequest.copyWith.fieldName(value)` for a single field.
class _$AudioTranscriptionRequestCWProxyImpl
    implements _$AudioTranscriptionRequestCWProxy {
  const _$AudioTranscriptionRequestCWProxyImpl(this._value);

  final AudioTranscriptionRequest _value;

  @override
  AudioTranscriptionRequest dataUrl(String dataUrl) => call(dataUrl: dataUrl);

  @override
  AudioTranscriptionRequest mimeType(String? mimeType) =>
      call(mimeType: mimeType);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AudioTranscriptionRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AudioTranscriptionRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  AudioTranscriptionRequest call({
    Object? dataUrl = const $CopyWithPlaceholder(),
    Object? mimeType = const $CopyWithPlaceholder(),
  }) {
    return AudioTranscriptionRequest(
      dataUrl: dataUrl == const $CopyWithPlaceholder() || dataUrl == null
          ? _value.dataUrl
          // ignore: cast_nullable_to_non_nullable
          : dataUrl as String,
      mimeType: mimeType == const $CopyWithPlaceholder()
          ? _value.mimeType
          // ignore: cast_nullable_to_non_nullable
          : mimeType as String?,
    );
  }
}

extension $AudioTranscriptionRequestCopyWith on AudioTranscriptionRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAudioTranscriptionRequest.copyWith(...)` or `instanceOfAudioTranscriptionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AudioTranscriptionRequestCWProxy get copyWith =>
      _$AudioTranscriptionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioTranscriptionRequest _$AudioTranscriptionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AudioTranscriptionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data_url']);
  final val = AudioTranscriptionRequest(
    dataUrl: $checkedConvert('data_url', (v) => v as String),
    mimeType: $checkedConvert('mime_type', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'dataUrl': 'data_url', 'mimeType': 'mime_type'});

Map<String, dynamic> _$AudioTranscriptionRequestToJson(
  AudioTranscriptionRequest instance,
) => <String, dynamic>{
  'data_url': instance.dataUrl,
  'mime_type': ?instance.mimeType,
};
