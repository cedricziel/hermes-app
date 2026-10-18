// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_pr_scan_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionPrScanBodyCWProxy {
  SessionPrScanBody ids(List<String>? ids);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SessionPrScanBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SessionPrScanBody(...).copyWith(id: 12, name: "My name")
  /// ```
  SessionPrScanBody call({List<String>? ids});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSessionPrScanBody.copyWith(...)` or call `instanceOfSessionPrScanBody.copyWith.fieldName(value)` for a single field.
class _$SessionPrScanBodyCWProxyImpl implements _$SessionPrScanBodyCWProxy {
  const _$SessionPrScanBodyCWProxyImpl(this._value);

  final SessionPrScanBody _value;

  @override
  SessionPrScanBody ids(List<String>? ids) => call(ids: ids);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SessionPrScanBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SessionPrScanBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSessionPrScanBody.copyWith(...)` or `instanceOfSessionPrScanBody.copyWith.fieldName(...)`.
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
