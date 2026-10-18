// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'automation_blueprint_instantiate.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AutomationBlueprintInstantiateCWProxy {
  AutomationBlueprintInstantiate blueprint(String blueprint);

  AutomationBlueprintInstantiate values(Map<String, Object>? values);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AutomationBlueprintInstantiate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AutomationBlueprintInstantiate(...).copyWith(id: 12, name: "My name")
  /// ```
  AutomationBlueprintInstantiate call({
    String blueprint,
    Map<String, Object>? values,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAutomationBlueprintInstantiate.copyWith(...)` or call `instanceOfAutomationBlueprintInstantiate.copyWith.fieldName(value)` for a single field.
class _$AutomationBlueprintInstantiateCWProxyImpl
    implements _$AutomationBlueprintInstantiateCWProxy {
  const _$AutomationBlueprintInstantiateCWProxyImpl(this._value);

  final AutomationBlueprintInstantiate _value;

  @override
  AutomationBlueprintInstantiate blueprint(String blueprint) =>
      call(blueprint: blueprint);

  @override
  AutomationBlueprintInstantiate values(Map<String, Object>? values) =>
      call(values: values);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AutomationBlueprintInstantiate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AutomationBlueprintInstantiate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  AutomationBlueprintInstantiate call({
    Object? blueprint = const $CopyWithPlaceholder(),
    Object? values = const $CopyWithPlaceholder(),
  }) {
    return AutomationBlueprintInstantiate(
      blueprint: blueprint == const $CopyWithPlaceholder() || blueprint == null
          ? _value.blueprint
          // ignore: cast_nullable_to_non_nullable
          : blueprint as String,
      values: values == const $CopyWithPlaceholder()
          ? _value.values
          // ignore: cast_nullable_to_non_nullable
          : values as Map<String, Object>?,
    );
  }
}

extension $AutomationBlueprintInstantiateCopyWith
    on AutomationBlueprintInstantiate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAutomationBlueprintInstantiate.copyWith(...)` or `instanceOfAutomationBlueprintInstantiate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AutomationBlueprintInstantiateCWProxy get copyWith =>
      _$AutomationBlueprintInstantiateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AutomationBlueprintInstantiate _$AutomationBlueprintInstantiateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AutomationBlueprintInstantiate', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['blueprint']);
  final val = AutomationBlueprintInstantiate(
    blueprint: $checkedConvert('blueprint', (v) => v as String),
    values: $checkedConvert(
      'values',
      (v) =>
          (v as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as Object),
          ) ??
          {},
    ),
  );
  return val;
});

Map<String, dynamic> _$AutomationBlueprintInstantiateToJson(
  AutomationBlueprintInstantiate instance,
) => <String, dynamic>{
  'blueprint': instance.blueprint,
  'values': ?instance.values,
};
