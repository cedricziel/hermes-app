// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curator_pause.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CuratorPauseCWProxy {
  CuratorPause paused(bool paused);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CuratorPause(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CuratorPause(...).copyWith(id: 12, name: "My name")
  /// ```
  CuratorPause call({bool paused});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCuratorPause.copyWith(...)` or call `instanceOfCuratorPause.copyWith.fieldName(value)` for a single field.
class _$CuratorPauseCWProxyImpl implements _$CuratorPauseCWProxy {
  const _$CuratorPauseCWProxyImpl(this._value);

  final CuratorPause _value;

  @override
  CuratorPause paused(bool paused) => call(paused: paused);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CuratorPause(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CuratorPause(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CuratorPause call({Object? paused = const $CopyWithPlaceholder()}) {
    return CuratorPause(
      paused: paused == const $CopyWithPlaceholder() || paused == null
          ? _value.paused
          // ignore: cast_nullable_to_non_nullable
          : paused as bool,
    );
  }
}

extension $CuratorPauseCopyWith on CuratorPause {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCuratorPause.copyWith(...)` or `instanceOfCuratorPause.copyWith.fieldName(...)`.
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
