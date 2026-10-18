// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hook_delete.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HookDeleteCWProxy {
  HookDelete event(String event);

  HookDelete command(String command);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HookDelete(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HookDelete(...).copyWith(id: 12, name: "My name")
  /// ```
  HookDelete call({String event, String command});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfHookDelete.copyWith(...)` or call `instanceOfHookDelete.copyWith.fieldName(value)` for a single field.
class _$HookDeleteCWProxyImpl implements _$HookDeleteCWProxy {
  const _$HookDeleteCWProxyImpl(this._value);

  final HookDelete _value;

  @override
  HookDelete event(String event) => call(event: event);

  @override
  HookDelete command(String command) => call(command: command);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HookDelete(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HookDelete(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  HookDelete call({
    Object? event = const $CopyWithPlaceholder(),
    Object? command = const $CopyWithPlaceholder(),
  }) {
    return HookDelete(
      event: event == const $CopyWithPlaceholder() || event == null
          ? _value.event
          // ignore: cast_nullable_to_non_nullable
          : event as String,
      command: command == const $CopyWithPlaceholder() || command == null
          ? _value.command
          // ignore: cast_nullable_to_non_nullable
          : command as String,
    );
  }
}

extension $HookDeleteCopyWith on HookDelete {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfHookDelete.copyWith(...)` or `instanceOfHookDelete.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HookDeleteCWProxy get copyWith => _$HookDeleteCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HookDelete _$HookDeleteFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HookDelete', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['event', 'command']);
      final val = HookDelete(
        event: $checkedConvert('event', (v) => v as String),
        command: $checkedConvert('command', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$HookDeleteToJson(HookDelete instance) =>
    <String, dynamic>{'event': instance.event, 'command': instance.command};
