// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_install_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RuntimeInstallBodyCWProxy {
  RuntimeInstallBody backend(String? backend);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RuntimeInstallBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RuntimeInstallBody(...).copyWith(id: 12, name: "My name")
  /// ````
  RuntimeInstallBody call({String? backend});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRuntimeInstallBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRuntimeInstallBody.copyWith.fieldName(...)`
class _$RuntimeInstallBodyCWProxyImpl implements _$RuntimeInstallBodyCWProxy {
  const _$RuntimeInstallBodyCWProxyImpl(this._value);

  final RuntimeInstallBody _value;

  @override
  RuntimeInstallBody backend(String? backend) => this(backend: backend);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RuntimeInstallBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RuntimeInstallBody(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfRuntimeInstallBody.copyWith(...)` or like so:`instanceOfRuntimeInstallBody.copyWith.fieldName(...)`.
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
