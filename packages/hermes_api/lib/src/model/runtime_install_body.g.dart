// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_install_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RuntimeInstallBodyCWProxy {
  RuntimeInstallBody backend(String? backend);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RuntimeInstallBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RuntimeInstallBody(...).copyWith(id: 12, name: "My name")
  /// ```
  RuntimeInstallBody call({String? backend});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfRuntimeInstallBody.copyWith(...)` or call `instanceOfRuntimeInstallBody.copyWith.fieldName(value)` for a single field.
class _$RuntimeInstallBodyCWProxyImpl implements _$RuntimeInstallBodyCWProxy {
  const _$RuntimeInstallBodyCWProxyImpl(this._value);

  final RuntimeInstallBody _value;

  @override
  RuntimeInstallBody backend(String? backend) => call(backend: backend);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RuntimeInstallBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RuntimeInstallBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  RuntimeInstallBody call({Object? backend = const $CopyWithPlaceholder()}) {
    return RuntimeInstallBody(
      backend: backend == const $CopyWithPlaceholder()
          ? _value.backend
          // ignore: cast_nullable_to_non_nullable
          : backend as String?,
    );
  }
}

extension $RuntimeInstallBodyCopyWith on RuntimeInstallBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfRuntimeInstallBody.copyWith(...)` or `instanceOfRuntimeInstallBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RuntimeInstallBodyCWProxy get copyWith =>
      _$RuntimeInstallBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuntimeInstallBody _$RuntimeInstallBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RuntimeInstallBody', json, ($checkedConvert) {
      final val = RuntimeInstallBody(
        backend: $checkedConvert('backend', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$RuntimeInstallBodyToJson(RuntimeInstallBody instance) =>
    <String, dynamic>{'backend': ?instance.backend};
