// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_backend_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TerminalBackendSelectCWProxy {
  TerminalBackendSelect backend(String backend);

  TerminalBackendSelect profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TerminalBackendSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TerminalBackendSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  TerminalBackendSelect call({String backend, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTerminalBackendSelect.copyWith(...)` or call `instanceOfTerminalBackendSelect.copyWith.fieldName(value)` for a single field.
class _$TerminalBackendSelectCWProxyImpl
    implements _$TerminalBackendSelectCWProxy {
  const _$TerminalBackendSelectCWProxyImpl(this._value);

  final TerminalBackendSelect _value;

  @override
  TerminalBackendSelect backend(String backend) => call(backend: backend);

  @override
  TerminalBackendSelect profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TerminalBackendSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TerminalBackendSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TerminalBackendSelect call({
    Object? backend = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return TerminalBackendSelect(
      backend: backend == const $CopyWithPlaceholder() || backend == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTerminalBackendSelect.copyWith(...)` or `instanceOfTerminalBackendSelect.copyWith.fieldName(...)`.
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
