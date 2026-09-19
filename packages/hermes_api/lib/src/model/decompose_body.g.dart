// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decompose_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DecomposeBodyCWProxy {
  DecomposeBody author(String? author);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DecomposeBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DecomposeBody(...).copyWith(id: 12, name: "My name")
  /// ````
  DecomposeBody call({String? author});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDecomposeBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDecomposeBody.copyWith.fieldName(...)`
class _$DecomposeBodyCWProxyImpl implements _$DecomposeBodyCWProxy {
  const _$DecomposeBodyCWProxyImpl(this._value);

  final DecomposeBody _value;

  @override
  DecomposeBody author(String? author) => this(author: author);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DecomposeBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DecomposeBody(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfDecomposeBody.copyWith(...)` or like so:`instanceOfDecomposeBody.copyWith.fieldName(...)`.
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
