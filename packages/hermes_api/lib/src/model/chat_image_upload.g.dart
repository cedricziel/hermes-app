// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_image_upload.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ChatImageUploadCWProxy {
  ChatImageUpload dataUrl(String dataUrl);

  ChatImageUpload filename(String? filename);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ChatImageUpload(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ChatImageUpload(...).copyWith(id: 12, name: "My name")
  /// ```
  ChatImageUpload call({String dataUrl, String? filename});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfChatImageUpload.copyWith(...)` or call `instanceOfChatImageUpload.copyWith.fieldName(value)` for a single field.
class _$ChatImageUploadCWProxyImpl implements _$ChatImageUploadCWProxy {
  const _$ChatImageUploadCWProxyImpl(this._value);

  final ChatImageUpload _value;

  @override
  ChatImageUpload dataUrl(String dataUrl) => call(dataUrl: dataUrl);

  @override
  ChatImageUpload filename(String? filename) => call(filename: filename);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ChatImageUpload(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ChatImageUpload(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ChatImageUpload call({
    Object? dataUrl = const $CopyWithPlaceholder(),
    Object? filename = const $CopyWithPlaceholder(),
  }) {
    return ChatImageUpload(
      dataUrl: dataUrl == const $CopyWithPlaceholder() || dataUrl == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfChatImageUpload.copyWith(...)` or `instanceOfChatImageUpload.copyWith.fieldName(...)`.
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
