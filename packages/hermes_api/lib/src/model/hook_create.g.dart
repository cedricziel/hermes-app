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

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HookCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HookCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  HookCreate call({
    String event,
    String command,
    String? matcher,
    int? timeout,
    bool? approve,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfHookCreate.copyWith(...)` or call `instanceOfHookCreate.copyWith.fieldName(value)` for a single field.
class _$HookCreateCWProxyImpl implements _$HookCreateCWProxy {
  const _$HookCreateCWProxyImpl(this._value);

  final HookCreate _value;

  @override
  HookCreate event(String event) => call(event: event);

  @override
  HookCreate command(String command) => call(command: command);

  @override
  HookCreate matcher(String? matcher) => call(matcher: matcher);

  @override
  HookCreate timeout(int? timeout) => call(timeout: timeout);

  @override
  HookCreate approve(bool? approve) => call(approve: approve);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HookCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HookCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  HookCreate call({
    Object? event = const $CopyWithPlaceholder(),
    Object? command = const $CopyWithPlaceholder(),
    Object? matcher = const $CopyWithPlaceholder(),
    Object? timeout = const $CopyWithPlaceholder(),
    Object? approve = const $CopyWithPlaceholder(),
  }) {
    return HookCreate(
      event: event == const $CopyWithPlaceholder() || event == null
          ? _value.event
          // ignore: cast_nullable_to_non_nullable
          : event as String,
      command: command == const $CopyWithPlaceholder() || command == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfHookCreate.copyWith(...)` or `instanceOfHookCreate.copyWith.fieldName(...)`.
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
