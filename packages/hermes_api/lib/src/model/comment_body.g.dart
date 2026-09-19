// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CommentBodyCWProxy {
  CommentBody body(String body);

  CommentBody author(String? author);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommentBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommentBody(...).copyWith(id: 12, name: "My name")
  /// ````
  CommentBody call({String body, String? author});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCommentBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCommentBody.copyWith.fieldName(...)`
class _$CommentBodyCWProxyImpl implements _$CommentBodyCWProxy {
  const _$CommentBodyCWProxyImpl(this._value);

  final CommentBody _value;

  @override
  CommentBody body(String body) => this(body: body);

  @override
  CommentBody author(String? author) => this(author: author);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommentBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommentBody(...).copyWith(id: 12, name: "My name")
  /// ````
  CommentBody call({
    Object? body = const $CopyWithPlaceholder(),
    Object? author = const $CopyWithPlaceholder(),
  }) {
    return CommentBody(
      body: body == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfCommentBody.copyWith(...)` or like so:`instanceOfCommentBody.copyWith.fieldName(...)`.
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
