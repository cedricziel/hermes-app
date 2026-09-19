// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_backend_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TerminalBackendSelectCWProxy {
  TerminalBackendSelect backend(String backend);

  TerminalBackendSelect profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TerminalBackendSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TerminalBackendSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  TerminalBackendSelect call({String backend, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTerminalBackendSelect.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTerminalBackendSelect.copyWith.fieldName(...)`
class _$TerminalBackendSelectCWProxyImpl
    implements _$TerminalBackendSelectCWProxy {
  const _$TerminalBackendSelectCWProxyImpl(this._value);

  final TerminalBackendSelect _value;

  @override
  TerminalBackendSelect backend(String backend) => this(backend: backend);

  @override
  TerminalBackendSelect profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TerminalBackendSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TerminalBackendSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  TerminalBackendSelect call({
    Object? backend = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return TerminalBackendSelect(
      backend: backend == const $CopyWithPlaceholder()
          ? _value.backend
          // ignore: cast_nullable_to_non_nullable
          : backend as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $TerminalBackendSelectCopyWith on TerminalBackendSelect {
  /// Returns a callable class that can be used as follows: `instanceOfTerminalBackendSelect.copyWith(...)` or like so:`instanceOfTerminalBackendSelect.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TerminalBackendSelectCWProxy get copyWith =>
      _$TerminalBackendSelectCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TerminalBackendSelect _$TerminalBackendSelectFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TerminalBackendSelect', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['backend']);
  final val = TerminalBackendSelect(
    backend: $checkedConvert('backend', (v) => v as String),
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$TerminalBackendSelectToJson(
  TerminalBackendSelect instance,
) => <String, dynamic>{
  'backend': instance.backend,
  'profile': ?instance.profile,
};
