// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LinkBodyCWProxy {
  LinkBody parentId(String parentId);

  LinkBody childId(String childId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LinkBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LinkBody(...).copyWith(id: 12, name: "My name")
  /// ````
  LinkBody call({String parentId, String childId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLinkBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLinkBody.copyWith.fieldName(...)`
class _$LinkBodyCWProxyImpl implements _$LinkBodyCWProxy {
  const _$LinkBodyCWProxyImpl(this._value);

  final LinkBody _value;

  @override
  LinkBody parentId(String parentId) => this(parentId: parentId);

  @override
  LinkBody childId(String childId) => this(childId: childId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LinkBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LinkBody(...).copyWith(id: 12, name: "My name")
  /// ````
  LinkBody call({
    Object? parentId = const $CopyWithPlaceholder(),
    Object? childId = const $CopyWithPlaceholder(),
  }) {
    return LinkBody(
      parentId: parentId == const $CopyWithPlaceholder()
          ? _value.parentId
          // ignore: cast_nullable_to_non_nullable
          : parentId as String,
      childId: childId == const $CopyWithPlaceholder()
          ? _value.childId
          // ignore: cast_nullable_to_non_nullable
          : childId as String,
    );
  }
}

extension $LinkBodyCopyWith on LinkBody {
  /// Returns a callable class that can be used as follows: `instanceOfLinkBody.copyWith(...)` or like so:`instanceOfLinkBody.copyWith.fieldName(...)`.
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
