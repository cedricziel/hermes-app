// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_transcription_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AudioTranscriptionRequestCWProxy {
  AudioTranscriptionRequest dataUrl(String dataUrl);

  AudioTranscriptionRequest mimeType(String? mimeType);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AudioTranscriptionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AudioTranscriptionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  AudioTranscriptionRequest call({String dataUrl, String? mimeType});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAudioTranscriptionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAudioTranscriptionRequest.copyWith.fieldName(...)`
class _$AudioTranscriptionRequestCWProxyImpl
    implements _$AudioTranscriptionRequestCWProxy {
  const _$AudioTranscriptionRequestCWProxyImpl(this._value);

  final AudioTranscriptionRequest _value;

  @override
  AudioTranscriptionRequest dataUrl(String dataUrl) => this(dataUrl: dataUrl);

  @override
  AudioTranscriptionRequest mimeType(String? mimeType) =>
      this(mimeType: mimeType);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AudioTranscriptionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AudioTranscriptionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  AudioTranscriptionRequest call({
    Object? dataUrl = const $CopyWithPlaceholder(),
    Object? mimeType = const $CopyWithPlaceholder(),
  }) {
    return AudioTranscriptionRequest(
      dataUrl: dataUrl == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfAudioTranscriptionRequest.copyWith(...)` or like so:`instanceOfAudioTranscriptionRequest.copyWith.fieldName(...)`.
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
