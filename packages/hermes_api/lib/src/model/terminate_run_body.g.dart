// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminate_run_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TerminateRunBodyCWProxy {
  TerminateRunBody reason(String? reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TerminateRunBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TerminateRunBody(...).copyWith(id: 12, name: "My name")
  /// ````
  TerminateRunBody call({String? reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTerminateRunBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTerminateRunBody.copyWith.fieldName(...)`
class _$TerminateRunBodyCWProxyImpl implements _$TerminateRunBodyCWProxy {
  const _$TerminateRunBodyCWProxyImpl(this._value);

  final TerminateRunBody _value;

  @override
  TerminateRunBody reason(String? reason) => this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TerminateRunBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TerminateRunBody(...).copyWith(id: 12, name: "My name")
  /// ````
  TerminateRunBody call({Object? reason = const $CopyWithPlaceholder()}) {
    return TerminateRunBody(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String?,
    );
  }
}

extension $TerminateRunBodyCopyWith on TerminateRunBody {
  /// Returns a callable class that can be used as follows: `instanceOfTerminateRunBody.copyWith(...)` or like so:`instanceOfTerminateRunBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TerminateRunBodyCWProxy get copyWith => _$TerminateRunBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TerminateRunBody _$TerminateRunBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TerminateRunBody', json, ($checkedConvert) {
      final val = TerminateRunBody(
        reason: $checkedConvert('reason', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$TerminateRunBodyToJson(TerminateRunBody instance) =>
    <String, dynamic>{'reason': ?instance.reason};
