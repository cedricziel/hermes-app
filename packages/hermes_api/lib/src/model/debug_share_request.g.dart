// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debug_share_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DebugShareRequestCWProxy {
  DebugShareRequest redact(bool? redact);

  DebugShareRequest lines(int? lines);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DebugShareRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DebugShareRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DebugShareRequest call({bool? redact, int? lines});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDebugShareRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDebugShareRequest.copyWith.fieldName(...)`
class _$DebugShareRequestCWProxyImpl implements _$DebugShareRequestCWProxy {
  const _$DebugShareRequestCWProxyImpl(this._value);

  final DebugShareRequest _value;

  @override
  DebugShareRequest redact(bool? redact) => this(redact: redact);

  @override
  DebugShareRequest lines(int? lines) => this(lines: lines);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DebugShareRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DebugShareRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DebugShareRequest call({
    Object? redact = const $CopyWithPlaceholder(),
    Object? lines = const $CopyWithPlaceholder(),
  }) {
    return DebugShareRequest(
      redact: redact == const $CopyWithPlaceholder()
          ? _value.redact
          // ignore: cast_nullable_to_non_nullable
          : redact as bool?,
      lines: lines == const $CopyWithPlaceholder()
          ? _value.lines
          // ignore: cast_nullable_to_non_nullable
          : lines as int?,
    );
  }
}

extension $DebugShareRequestCopyWith on DebugShareRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDebugShareRequest.copyWith(...)` or like so:`instanceOfDebugShareRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DebugShareRequestCWProxy get copyWith =>
      _$DebugShareRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DebugShareRequest _$DebugShareRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DebugShareRequest', json, ($checkedConvert) {
      final val = DebugShareRequest(
        redact: $checkedConvert('redact', (v) => v as bool? ?? true),
        lines: $checkedConvert('lines', (v) => (v as num?)?.toInt() ?? 200),
      );
      return val;
    });

Map<String, dynamic> _$DebugShareRequestToJson(DebugShareRequest instance) =>
    <String, dynamic>{'redact': ?instance.redact, 'lines': ?instance.lines};
