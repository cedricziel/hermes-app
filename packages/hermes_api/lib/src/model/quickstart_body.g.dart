// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quickstart_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$QuickstartBodyCWProxy {
  QuickstartBody modelId(String? modelId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `QuickstartBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// QuickstartBody(...).copyWith(id: 12, name: "My name")
  /// ````
  QuickstartBody call({String? modelId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfQuickstartBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfQuickstartBody.copyWith.fieldName(...)`
class _$QuickstartBodyCWProxyImpl implements _$QuickstartBodyCWProxy {
  const _$QuickstartBodyCWProxyImpl(this._value);

  final QuickstartBody _value;

  @override
  QuickstartBody modelId(String? modelId) => this(modelId: modelId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `QuickstartBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// QuickstartBody(...).copyWith(id: 12, name: "My name")
  /// ````
  QuickstartBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return QuickstartBody(
      modelId: modelId == const $CopyWithPlaceholder()
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String?,
    );
  }
}

extension $QuickstartBodyCopyWith on QuickstartBody {
  /// Returns a callable class that can be used as follows: `instanceOfQuickstartBody.copyWith(...)` or like so:`instanceOfQuickstartBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$QuickstartBodyCWProxy get copyWith => _$QuickstartBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuickstartBody _$QuickstartBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('QuickstartBody', json, ($checkedConvert) {
      final val = QuickstartBody(
        modelId: $checkedConvert('model_id', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'modelId': 'model_id'});

Map<String, dynamic> _$QuickstartBodyToJson(QuickstartBody instance) =>
    <String, dynamic>{'model_id': ?instance.modelId};
