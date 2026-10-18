// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'specify_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SpecifyBodyCWProxy {
  SpecifyBody author(String? author);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SpecifyBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SpecifyBody(...).copyWith(id: 12, name: "My name")
  /// ```
  SpecifyBody call({String? author});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSpecifyBody.copyWith(...)` or call `instanceOfSpecifyBody.copyWith.fieldName(value)` for a single field.
class _$SpecifyBodyCWProxyImpl implements _$SpecifyBodyCWProxy {
  const _$SpecifyBodyCWProxyImpl(this._value);

  final SpecifyBody _value;

  @override
  SpecifyBody author(String? author) => call(author: author);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SpecifyBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SpecifyBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SpecifyBody call({Object? author = const $CopyWithPlaceholder()}) {
    return SpecifyBody(
      author: author == const $CopyWithPlaceholder()
          ? _value.author
          // ignore: cast_nullable_to_non_nullable
          : author as String?,
    );
  }
}

extension $SpecifyBodyCopyWith on SpecifyBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSpecifyBody.copyWith(...)` or `instanceOfSpecifyBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SpecifyBodyCWProxy get copyWith => _$SpecifyBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpecifyBody _$SpecifyBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SpecifyBody', json, ($checkedConvert) {
      final val = SpecifyBody(
        author: $checkedConvert('author', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SpecifyBodyToJson(SpecifyBody instance) =>
    <String, dynamic>{'author': ?instance.author};
