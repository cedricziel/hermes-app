// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_pr_scan_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionPrScanBodyCWProxy {
  SessionPrScanBody ids(List<String>? ids);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionPrScanBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionPrScanBody(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionPrScanBody call({List<String>? ids});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionPrScanBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionPrScanBody.copyWith.fieldName(...)`
class _$SessionPrScanBodyCWProxyImpl implements _$SessionPrScanBodyCWProxy {
  const _$SessionPrScanBodyCWProxyImpl(this._value);

  final SessionPrScanBody _value;

  @override
  SessionPrScanBody ids(List<String>? ids) => this(ids: ids);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionPrScanBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionPrScanBody(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionPrScanBody call({Object? ids = const $CopyWithPlaceholder()}) {
    return SessionPrScanBody(
      ids: ids == const $CopyWithPlaceholder()
          ? _value.ids
          // ignore: cast_nullable_to_non_nullable
          : ids as List<String>?,
    );
  }
}

extension $SessionPrScanBodyCopyWith on SessionPrScanBody {
  /// Returns a callable class that can be used as follows: `instanceOfSessionPrScanBody.copyWith(...)` or like so:`instanceOfSessionPrScanBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionPrScanBodyCWProxy get copyWith =>
      _$SessionPrScanBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionPrScanBody _$SessionPrScanBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SessionPrScanBody', json, ($checkedConvert) {
      final val = SessionPrScanBody(
        ids: $checkedConvert(
          'ids',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        ),
      );
      return val;
    });

Map<String, dynamic> _$SessionPrScanBodyToJson(SessionPrScanBody instance) =>
    <String, dynamic>{'ids': ?instance.ids};
