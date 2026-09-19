// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_image_upload.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ChatImageUploadCWProxy {
  ChatImageUpload dataUrl(String dataUrl);

  ChatImageUpload filename(String? filename);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ChatImageUpload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ChatImageUpload(...).copyWith(id: 12, name: "My name")
  /// ````
  ChatImageUpload call({String dataUrl, String? filename});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfChatImageUpload.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfChatImageUpload.copyWith.fieldName(...)`
class _$ChatImageUploadCWProxyImpl implements _$ChatImageUploadCWProxy {
  const _$ChatImageUploadCWProxyImpl(this._value);

  final ChatImageUpload _value;

  @override
  ChatImageUpload dataUrl(String dataUrl) => this(dataUrl: dataUrl);

  @override
  ChatImageUpload filename(String? filename) => this(filename: filename);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ChatImageUpload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ChatImageUpload(...).copyWith(id: 12, name: "My name")
  /// ````
  ChatImageUpload call({
    Object? dataUrl = const $CopyWithPlaceholder(),
    Object? filename = const $CopyWithPlaceholder(),
  }) {
    return ChatImageUpload(
      dataUrl: dataUrl == const $CopyWithPlaceholder()
          ? _value.dataUrl
          // ignore: cast_nullable_to_non_nullable
          : dataUrl as String,
      filename: filename == const $CopyWithPlaceholder()
          ? _value.filename
          // ignore: cast_nullable_to_non_nullable
          : filename as String?,
    );
  }
}

extension $ChatImageUploadCopyWith on ChatImageUpload {
  /// Returns a callable class that can be used as follows: `instanceOfChatImageUpload.copyWith(...)` or like so:`instanceOfChatImageUpload.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ChatImageUploadCWProxy get copyWith => _$ChatImageUploadCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatImageUpload _$ChatImageUploadFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ChatImageUpload', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data_url']);
      final val = ChatImageUpload(
        dataUrl: $checkedConvert('data_url', (v) => v as String),
        filename: $checkedConvert('filename', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'dataUrl': 'data_url'});

Map<String, dynamic> _$ChatImageUploadToJson(ChatImageUpload instance) =>
    <String, dynamic>{
      'data_url': instance.dataUrl,
      'filename': ?instance.filename,
    };
