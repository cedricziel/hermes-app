// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'specify_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SpecifyBodyCWProxy {
  SpecifyBody author(String? author);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SpecifyBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SpecifyBody(...).copyWith(id: 12, name: "My name")
  /// ````
  SpecifyBody call({String? author});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSpecifyBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSpecifyBody.copyWith.fieldName(...)`
class _$SpecifyBodyCWProxyImpl implements _$SpecifyBodyCWProxy {
  const _$SpecifyBodyCWProxyImpl(this._value);

  final SpecifyBody _value;

  @override
  SpecifyBody author(String? author) => this(author: author);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SpecifyBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SpecifyBody(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfSpecifyBody.copyWith(...)` or like so:`instanceOfSpecifyBody.copyWith.fieldName(...)`.
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
