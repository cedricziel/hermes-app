// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webhook_enabled_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebhookEnabledToggleCWProxy {
  WebhookEnabledToggle enabled(bool enabled);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebhookEnabledToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebhookEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  WebhookEnabledToggle call({bool enabled});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebhookEnabledToggle.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebhookEnabledToggle.copyWith.fieldName(...)`
class _$WebhookEnabledToggleCWProxyImpl
    implements _$WebhookEnabledToggleCWProxy {
  const _$WebhookEnabledToggleCWProxyImpl(this._value);

  final WebhookEnabledToggle _value;

  @override
  WebhookEnabledToggle enabled(bool enabled) => this(enabled: enabled);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebhookEnabledToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebhookEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  WebhookEnabledToggle call({Object? enabled = const $CopyWithPlaceholder()}) {
    return WebhookEnabledToggle(
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool,
    );
  }
}

extension $WebhookEnabledToggleCopyWith on WebhookEnabledToggle {
  /// Returns a callable class that can be used as follows: `instanceOfWebhookEnabledToggle.copyWith(...)` or like so:`instanceOfWebhookEnabledToggle.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebhookEnabledToggleCWProxy get copyWith =>
      _$WebhookEnabledToggleCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebhookEnabledToggle _$WebhookEnabledToggleFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WebhookEnabledToggle', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['enabled']);
  final val = WebhookEnabledToggle(
    enabled: $checkedConvert('enabled', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$WebhookEnabledToggleToJson(
  WebhookEnabledToggle instance,
) => <String, dynamic>{'enabled': instance.enabled};
