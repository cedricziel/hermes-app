// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curator_pause.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CuratorPauseCWProxy {
  CuratorPause paused(bool paused);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CuratorPause(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CuratorPause(...).copyWith(id: 12, name: "My name")
  /// ````
  CuratorPause call({bool paused});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCuratorPause.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCuratorPause.copyWith.fieldName(...)`
class _$CuratorPauseCWProxyImpl implements _$CuratorPauseCWProxy {
  const _$CuratorPauseCWProxyImpl(this._value);

  final CuratorPause _value;

  @override
  CuratorPause paused(bool paused) => this(paused: paused);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CuratorPause(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CuratorPause(...).copyWith(id: 12, name: "My name")
  /// ````
  CuratorPause call({Object? paused = const $CopyWithPlaceholder()}) {
    return CuratorPause(
      paused: paused == const $CopyWithPlaceholder()
          ? _value.paused
          // ignore: cast_nullable_to_non_nullable
          : paused as bool,
    );
  }
}

extension $CuratorPauseCopyWith on CuratorPause {
  /// Returns a callable class that can be used as follows: `instanceOfCuratorPause.copyWith(...)` or like so:`instanceOfCuratorPause.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CuratorPauseCWProxy get copyWith => _$CuratorPauseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CuratorPause _$CuratorPauseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CuratorPause', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['paused']);
      final val = CuratorPause(
        paused: $checkedConvert('paused', (v) => v as bool),
      );
      return val;
    });

Map<String, dynamic> _$CuratorPauseToJson(CuratorPause instance) =>
    <String, dynamic>{'paused': instance.paused};
