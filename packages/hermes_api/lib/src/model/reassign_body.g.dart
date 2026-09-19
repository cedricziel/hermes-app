// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reassign_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReassignBodyCWProxy {
  ReassignBody profile(String? profile);

  ReassignBody reclaimFirst(bool? reclaimFirst);

  ReassignBody reason(String? reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReassignBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReassignBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ReassignBody call({String? profile, bool? reclaimFirst, String? reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReassignBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReassignBody.copyWith.fieldName(...)`
class _$ReassignBodyCWProxyImpl implements _$ReassignBodyCWProxy {
  const _$ReassignBodyCWProxyImpl(this._value);

  final ReassignBody _value;

  @override
  ReassignBody profile(String? profile) => this(profile: profile);

  @override
  ReassignBody reclaimFirst(bool? reclaimFirst) =>
      this(reclaimFirst: reclaimFirst);

  @override
  ReassignBody reason(String? reason) => this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReassignBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReassignBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ReassignBody call({
    Object? profile = const $CopyWithPlaceholder(),
    Object? reclaimFirst = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return ReassignBody(
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
      reclaimFirst: reclaimFirst == const $CopyWithPlaceholder()
          ? _value.reclaimFirst
          // ignore: cast_nullable_to_non_nullable
          : reclaimFirst as bool?,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String?,
    );
  }
}

extension $ReassignBodyCopyWith on ReassignBody {
  /// Returns a callable class that can be used as follows: `instanceOfReassignBody.copyWith(...)` or like so:`instanceOfReassignBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReassignBodyCWProxy get copyWith => _$ReassignBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReassignBody _$ReassignBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReassignBody', json, ($checkedConvert) {
      final val = ReassignBody(
        profile: $checkedConvert('profile', (v) => v as String?),
        reclaimFirst: $checkedConvert(
          'reclaim_first',
          (v) => v as bool? ?? false,
        ),
        reason: $checkedConvert('reason', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'reclaimFirst': 'reclaim_first'});

Map<String, dynamic> _$ReassignBodyToJson(ReassignBody instance) =>
    <String, dynamic>{
      'profile': ?instance.profile,
      'reclaim_first': ?instance.reclaimFirst,
      'reason': ?instance.reason,
    };
