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

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `OrchestrationSettingsBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// OrchestrationSettingsBody(...).copyWith(id: 12, name: "My name")
  /// ```
  OrchestrationSettingsBody call({
    String? orchestratorProfile,
    String? defaultAssignee,
    bool? autoDecompose,
    bool? autoPromoteChildren,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfOrchestrationSettingsBody.copyWith(...)` or call `instanceOfOrchestrationSettingsBody.copyWith.fieldName(value)` for a single field.
class _$OrchestrationSettingsBodyCWProxyImpl
    implements _$OrchestrationSettingsBodyCWProxy {
  const _$OrchestrationSettingsBodyCWProxyImpl(this._value);

  final OrchestrationSettingsBody _value;

  @override
  OrchestrationSettingsBody orchestratorProfile(String? orchestratorProfile) =>
      call(orchestratorProfile: orchestratorProfile);

  @override
  OrchestrationSettingsBody defaultAssignee(String? defaultAssignee) =>
      call(defaultAssignee: defaultAssignee);

  @override
  OrchestrationSettingsBody autoDecompose(bool? autoDecompose) =>
      call(autoDecompose: autoDecompose);

  @override
  OrchestrationSettingsBody autoPromoteChildren(bool? autoPromoteChildren) =>
      call(autoPromoteChildren: autoPromoteChildren);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `OrchestrationSettingsBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// OrchestrationSettingsBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfOrchestrationSettingsBody.copyWith(...)` or `instanceOfOrchestrationSettingsBody.copyWith.fieldName(...)`.
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
