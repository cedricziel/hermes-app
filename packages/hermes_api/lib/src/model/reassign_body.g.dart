// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reassign_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReassignBodyCWProxy {
  ReassignBody profile(String? profile);

  ReassignBody reclaimFirst(bool? reclaimFirst);

  ReassignBody reason(String? reason);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ReassignBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ReassignBody(...).copyWith(id: 12, name: "My name")
  /// ```
  ReassignBody call({String? profile, bool? reclaimFirst, String? reason});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfReassignBody.copyWith(...)` or call `instanceOfReassignBody.copyWith.fieldName(value)` for a single field.
class _$ReassignBodyCWProxyImpl implements _$ReassignBodyCWProxy {
  const _$ReassignBodyCWProxyImpl(this._value);

  final ReassignBody _value;

  @override
  ReassignBody profile(String? profile) => call(profile: profile);

  @override
  ReassignBody reclaimFirst(bool? reclaimFirst) =>
      call(reclaimFirst: reclaimFirst);

  @override
  ReassignBody reason(String? reason) => call(reason: reason);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ReassignBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ReassignBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfReassignBody.copyWith(...)` or `instanceOfReassignBody.copyWith.fieldName(...)`.
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
