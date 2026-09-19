// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hook_delete.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HookDeleteCWProxy {
  HookDelete event(String event);

  HookDelete command(String command);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HookDelete(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HookDelete(...).copyWith(id: 12, name: "My name")
  /// ````
  HookDelete call({String event, String command});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHookDelete.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHookDelete.copyWith.fieldName(...)`
class _$HookDeleteCWProxyImpl implements _$HookDeleteCWProxy {
  const _$HookDeleteCWProxyImpl(this._value);

  final HookDelete _value;

  @override
  HookDelete event(String event) => this(event: event);

  @override
  HookDelete command(String command) => this(command: command);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HookDelete(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HookDelete(...).copyWith(id: 12, name: "My name")
  /// ````
  HookDelete call({
    Object? event = const $CopyWithPlaceholder(),
    Object? command = const $CopyWithPlaceholder(),
  }) {
    return HookDelete(
      event: event == const $CopyWithPlaceholder()
          ? _value.event
          // ignore: cast_nullable_to_non_nullable
          : event as String,
      command: command == const $CopyWithPlaceholder()
          ? _value.command
          // ignore: cast_nullable_to_non_nullable
          : command as String,
    );
  }
}

extension $HookDeleteCopyWith on HookDelete {
  /// Returns a callable class that can be used as follows: `instanceOfHookDelete.copyWith(...)` or like so:`instanceOfHookDelete.copyWith.fieldName(...)`.
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
