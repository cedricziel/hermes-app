// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CommentBodyCWProxy {
  CommentBody body(String body);

  CommentBody author(String? author);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CommentBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CommentBody(...).copyWith(id: 12, name: "My name")
  /// ```
  CommentBody call({String body, String? author});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCommentBody.copyWith(...)` or call `instanceOfCommentBody.copyWith.fieldName(value)` for a single field.
class _$CommentBodyCWProxyImpl implements _$CommentBodyCWProxy {
  const _$CommentBodyCWProxyImpl(this._value);

  final CommentBody _value;

  @override
  CommentBody body(String body) => call(body: body);

  @override
  CommentBody author(String? author) => call(author: author);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CommentBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CommentBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CommentBody call({
    Object? body = const $CopyWithPlaceholder(),
    Object? author = const $CopyWithPlaceholder(),
  }) {
    return CommentBody(
      body: body == const $CopyWithPlaceholder() || body == null
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      author: author == const $CopyWithPlaceholder()
          ? _value.author
          // ignore: cast_nullable_to_non_nullable
          : author as String?,
    );
  }
}

extension $CommentBodyCopyWith on CommentBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCommentBody.copyWith(...)` or `instanceOfCommentBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CommentBodyCWProxy get copyWith => _$CommentBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommentBody _$CommentBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CommentBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['body']);
      final val = CommentBody(
        body: $checkedConvert('body', (v) => v as String),
        author: $checkedConvert('author', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$CommentBodyToJson(CommentBody instance) =>
    <String, dynamic>{'body': instance.body, 'author': ?instance.author};
