// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webhook_enabled_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebhookEnabledToggleCWProxy {
  WebhookEnabledToggle enabled(bool enabled);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `WebhookEnabledToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// WebhookEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  WebhookEnabledToggle call({bool enabled});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfWebhookEnabledToggle.copyWith(...)` or call `instanceOfWebhookEnabledToggle.copyWith.fieldName(value)` for a single field.
class _$WebhookEnabledToggleCWProxyImpl
    implements _$WebhookEnabledToggleCWProxy {
  const _$WebhookEnabledToggleCWProxyImpl(this._value);

  final WebhookEnabledToggle _value;

  @override
  WebhookEnabledToggle enabled(bool enabled) => call(enabled: enabled);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `WebhookEnabledToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// WebhookEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  WebhookEnabledToggle call({Object? enabled = const $CopyWithPlaceholder()}) {
    return WebhookEnabledToggle(
      enabled: enabled == const $CopyWithPlaceholder() || enabled == null
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool,
    );
  }
}

extension $WebhookEnabledToggleCopyWith on WebhookEnabledToggle {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfWebhookEnabledToggle.copyWith(...)` or `instanceOfWebhookEnabledToggle.copyWith.fieldName(...)`.
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
