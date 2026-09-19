// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orchestration_settings_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrchestrationSettingsBodyCWProxy {
  OrchestrationSettingsBody orchestratorProfile(String? orchestratorProfile);

  OrchestrationSettingsBody defaultAssignee(String? defaultAssignee);

  OrchestrationSettingsBody autoDecompose(bool? autoDecompose);

  OrchestrationSettingsBody autoPromoteChildren(bool? autoPromoteChildren);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrchestrationSettingsBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrchestrationSettingsBody(...).copyWith(id: 12, name: "My name")
  /// ````
  OrchestrationSettingsBody call({
    String? orchestratorProfile,
    String? defaultAssignee,
    bool? autoDecompose,
    bool? autoPromoteChildren,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrchestrationSettingsBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrchestrationSettingsBody.copyWith.fieldName(...)`
class _$OrchestrationSettingsBodyCWProxyImpl
    implements _$OrchestrationSettingsBodyCWProxy {
  const _$OrchestrationSettingsBodyCWProxyImpl(this._value);

  final OrchestrationSettingsBody _value;

  @override
  OrchestrationSettingsBody orchestratorProfile(String? orchestratorProfile) =>
      this(orchestratorProfile: orchestratorProfile);

  @override
  OrchestrationSettingsBody defaultAssignee(String? defaultAssignee) =>
      this(defaultAssignee: defaultAssignee);

  @override
  OrchestrationSettingsBody autoDecompose(bool? autoDecompose) =>
      this(autoDecompose: autoDecompose);

  @override
  OrchestrationSettingsBody autoPromoteChildren(bool? autoPromoteChildren) =>
      this(autoPromoteChildren: autoPromoteChildren);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrchestrationSettingsBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrchestrationSettingsBody(...).copyWith(id: 12, name: "My name")
  /// ````
  OrchestrationSettingsBody call({
    Object? orchestratorProfile = const $CopyWithPlaceholder(),
    Object? defaultAssignee = const $CopyWithPlaceholder(),
    Object? autoDecompose = const $CopyWithPlaceholder(),
    Object? autoPromoteChildren = const $CopyWithPlaceholder(),
  }) {
    return OrchestrationSettingsBody(
      orchestratorProfile: orchestratorProfile == const $CopyWithPlaceholder()
          ? _value.orchestratorProfile
          // ignore: cast_nullable_to_non_nullable
          : orchestratorProfile as String?,
      defaultAssignee: defaultAssignee == const $CopyWithPlaceholder()
          ? _value.defaultAssignee
          // ignore: cast_nullable_to_non_nullable
          : defaultAssignee as String?,
      autoDecompose: autoDecompose == const $CopyWithPlaceholder()
          ? _value.autoDecompose
          // ignore: cast_nullable_to_non_nullable
          : autoDecompose as bool?,
      autoPromoteChildren: autoPromoteChildren == const $CopyWithPlaceholder()
          ? _value.autoPromoteChildren
          // ignore: cast_nullable_to_non_nullable
          : autoPromoteChildren as bool?,
    );
  }
}

extension $OrchestrationSettingsBodyCopyWith on OrchestrationSettingsBody {
  /// Returns a callable class that can be used as follows: `instanceOfOrchestrationSettingsBody.copyWith(...)` or like so:`instanceOfOrchestrationSettingsBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrchestrationSettingsBodyCWProxy get copyWith =>
      _$OrchestrationSettingsBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrchestrationSettingsBody _$OrchestrationSettingsBodyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'OrchestrationSettingsBody',
  json,
  ($checkedConvert) {
    final val = OrchestrationSettingsBody(
      orchestratorProfile: $checkedConvert(
        'orchestrator_profile',
        (v) => v as String?,
      ),
      defaultAssignee: $checkedConvert('default_assignee', (v) => v as String?),
      autoDecompose: $checkedConvert('auto_decompose', (v) => v as bool?),
      autoPromoteChildren: $checkedConvert(
        'auto_promote_children',
        (v) => v as bool?,
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orchestratorProfile': 'orchestrator_profile',
    'defaultAssignee': 'default_assignee',
    'autoDecompose': 'auto_decompose',
    'autoPromoteChildren': 'auto_promote_children',
  },
);

Map<String, dynamic> _$OrchestrationSettingsBodyToJson(
  OrchestrationSettingsBody instance,
) => <String, dynamic>{
  'orchestrator_profile': ?instance.orchestratorProfile,
  'default_assignee': ?instance.defaultAssignee,
  'auto_decompose': ?instance.autoDecompose,
  'auto_promote_children': ?instance.autoPromoteChildren,
};
