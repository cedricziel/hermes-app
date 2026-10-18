// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LinkBodyCWProxy {
  LinkBody parentId(String parentId);

  LinkBody childId(String childId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LinkBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LinkBody(...).copyWith(id: 12, name: "My name")
  /// ```
  LinkBody call({String parentId, String childId});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLinkBody.copyWith(...)` or call `instanceOfLinkBody.copyWith.fieldName(value)` for a single field.
class _$LinkBodyCWProxyImpl implements _$LinkBodyCWProxy {
  const _$LinkBodyCWProxyImpl(this._value);

  final LinkBody _value;

  @override
  LinkBody parentId(String parentId) => call(parentId: parentId);

  @override
  LinkBody childId(String childId) => call(childId: childId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LinkBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LinkBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LinkBody call({
    Object? parentId = const $CopyWithPlaceholder(),
    Object? childId = const $CopyWithPlaceholder(),
  }) {
    return LinkBody(
      parentId: parentId == const $CopyWithPlaceholder() || parentId == null
          ? _value.parentId
          // ignore: cast_nullable_to_non_nullable
          : parentId as String,
      childId: childId == const $CopyWithPlaceholder() || childId == null
          ? _value.childId
          // ignore: cast_nullable_to_non_nullable
          : childId as String,
    );
  }
}

extension $LinkBodyCopyWith on LinkBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLinkBody.copyWith(...)` or `instanceOfLinkBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LinkBodyCWProxy get copyWith => _$LinkBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinkBody _$LinkBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LinkBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['parent_id', 'child_id']);
      final val = LinkBody(
        parentId: $checkedConvert('parent_id', (v) => v as String),
        childId: $checkedConvert('child_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'parentId': 'parent_id', 'childId': 'child_id'});

Map<String, dynamic> _$LinkBodyToJson(LinkBody instance) => <String, dynamic>{
  'parent_id': instance.parentId,
  'child_id': instance.childId,
};
