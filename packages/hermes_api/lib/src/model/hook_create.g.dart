// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hook_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HookCreateCWProxy {
  HookCreate event(String event);

  HookCreate command(String command);

  HookCreate matcher(String? matcher);

  HookCreate timeout(int? timeout);

  HookCreate approve(bool? approve);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HookCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HookCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  HookCreate call({
    String event,
    String command,
    String? matcher,
    int? timeout,
    bool? approve,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHookCreate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHookCreate.copyWith.fieldName(...)`
class _$HookCreateCWProxyImpl implements _$HookCreateCWProxy {
  const _$HookCreateCWProxyImpl(this._value);

  final HookCreate _value;

  @override
  HookCreate event(String event) => this(event: event);

  @override
  HookCreate command(String command) => this(command: command);

  @override
  HookCreate matcher(String? matcher) => this(matcher: matcher);

  @override
  HookCreate timeout(int? timeout) => this(timeout: timeout);

  @override
  HookCreate approve(bool? approve) => this(approve: approve);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HookCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HookCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  HookCreate call({
    Object? event = const $CopyWithPlaceholder(),
    Object? command = const $CopyWithPlaceholder(),
    Object? matcher = const $CopyWithPlaceholder(),
    Object? timeout = const $CopyWithPlaceholder(),
    Object? approve = const $CopyWithPlaceholder(),
  }) {
    return HookCreate(
      event: event == const $CopyWithPlaceholder()
          ? _value.event
          // ignore: cast_nullable_to_non_nullable
          : event as String,
      command: command == const $CopyWithPlaceholder()
          ? _value.command
          // ignore: cast_nullable_to_non_nullable
          : command as String,
      matcher: matcher == const $CopyWithPlaceholder()
          ? _value.matcher
          // ignore: cast_nullable_to_non_nullable
          : matcher as String?,
      timeout: timeout == const $CopyWithPlaceholder()
          ? _value.timeout
          // ignore: cast_nullable_to_non_nullable
          : timeout as int?,
      approve: approve == const $CopyWithPlaceholder()
          ? _value.approve
          // ignore: cast_nullable_to_non_nullable
          : approve as bool?,
    );
  }
}

extension $HookCreateCopyWith on HookCreate {
  /// Returns a callable class that can be used as follows: `instanceOfHookCreate.copyWith(...)` or like so:`instanceOfHookCreate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HookCreateCWProxy get copyWith => _$HookCreateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HookCreate _$HookCreateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HookCreate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['event', 'command']);
      final val = HookCreate(
        event: $checkedConvert('event', (v) => v as String),
        command: $checkedConvert('command', (v) => v as String),
        matcher: $checkedConvert('matcher', (v) => v as String?),
        timeout: $checkedConvert('timeout', (v) => (v as num?)?.toInt()),
        approve: $checkedConvert('approve', (v) => v as bool? ?? true),
      );
      return val;
    });

Map<String, dynamic> _$HookCreateToJson(HookCreate instance) =>
    <String, dynamic>{
      'event': instance.event,
      'command': instance.command,
      'matcher': ?instance.matcher,
      'timeout': ?instance.timeout,
      'approve': ?instance.approve,
    };
