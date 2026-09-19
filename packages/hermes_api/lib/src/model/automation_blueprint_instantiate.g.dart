// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'automation_blueprint_instantiate.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AutomationBlueprintInstantiateCWProxy {
  AutomationBlueprintInstantiate blueprint(String blueprint);

  AutomationBlueprintInstantiate values(Map<String, Object>? values);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AutomationBlueprintInstantiate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AutomationBlueprintInstantiate(...).copyWith(id: 12, name: "My name")
  /// ````
  AutomationBlueprintInstantiate call({
    String blueprint,
    Map<String, Object>? values,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAutomationBlueprintInstantiate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAutomationBlueprintInstantiate.copyWith.fieldName(...)`
class _$AutomationBlueprintInstantiateCWProxyImpl
    implements _$AutomationBlueprintInstantiateCWProxy {
  const _$AutomationBlueprintInstantiateCWProxyImpl(this._value);

  final AutomationBlueprintInstantiate _value;

  @override
  AutomationBlueprintInstantiate blueprint(String blueprint) =>
      this(blueprint: blueprint);

  @override
  AutomationBlueprintInstantiate values(Map<String, Object>? values) =>
      this(values: values);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AutomationBlueprintInstantiate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AutomationBlueprintInstantiate(...).copyWith(id: 12, name: "My name")
  /// ````
  AutomationBlueprintInstantiate call({
    Object? blueprint = const $CopyWithPlaceholder(),
    Object? values = const $CopyWithPlaceholder(),
  }) {
    return AutomationBlueprintInstantiate(
      blueprint: blueprint == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfAutomationBlueprintInstantiate.copyWith(...)` or like so:`instanceOfAutomationBlueprintInstantiate.copyWith.fieldName(...)`.
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
