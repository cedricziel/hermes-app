// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decompose_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DecomposeBodyCWProxy {
  DecomposeBody author(String? author);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DecomposeBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DecomposeBody(...).copyWith(id: 12, name: "My name")
  /// ```
  DecomposeBody call({String? author});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDecomposeBody.copyWith(...)` or call `instanceOfDecomposeBody.copyWith.fieldName(value)` for a single field.
class _$DecomposeBodyCWProxyImpl implements _$DecomposeBodyCWProxy {
  const _$DecomposeBodyCWProxyImpl(this._value);

  final DecomposeBody _value;

  @override
  DecomposeBody author(String? author) => call(author: author);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DecomposeBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DecomposeBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DecomposeBody call({Object? author = const $CopyWithPlaceholder()}) {
    return DecomposeBody(
      author: author == const $CopyWithPlaceholder()
          ? _value.author
          // ignore: cast_nullable_to_non_nullable
          : author as String?,
    );
  }
}

extension $DecomposeBodyCopyWith on DecomposeBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDecomposeBody.copyWith(...)` or `instanceOfDecomposeBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DecomposeBodyCWProxy get copyWith => _$DecomposeBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DecomposeBody _$DecomposeBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DecomposeBody', json, ($checkedConvert) {
      final val = DecomposeBody(
        author: $checkedConvert('author', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$DecomposeBodyToJson(DecomposeBody instance) =>
    <String, dynamic>{'author': ?instance.author};
