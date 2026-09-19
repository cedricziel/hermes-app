// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'estimate_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EstimateBodyCWProxy {
  EstimateBody title(String? title);

  EstimateBody body(String? body);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EstimateBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EstimateBody(...).copyWith(id: 12, name: "My name")
  /// ````
  EstimateBody call({String? title, String? body});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEstimateBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEstimateBody.copyWith.fieldName(...)`
class _$EstimateBodyCWProxyImpl implements _$EstimateBodyCWProxy {
  const _$EstimateBodyCWProxyImpl(this._value);

  final EstimateBody _value;

  @override
  EstimateBody title(String? title) => this(title: title);

  @override
  EstimateBody body(String? body) => this(body: body);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EstimateBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EstimateBody(...).copyWith(id: 12, name: "My name")
  /// ````
  EstimateBody call({
    Object? title = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
  }) {
    return EstimateBody(
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String?,
    );
  }
}

extension $EstimateBodyCopyWith on EstimateBody {
  /// Returns a callable class that can be used as follows: `instanceOfEstimateBody.copyWith(...)` or like so:`instanceOfEstimateBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EstimateBodyCWProxy get copyWith => _$EstimateBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EstimateBody _$EstimateBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EstimateBody', json, ($checkedConvert) {
      final val = EstimateBody(
        title: $checkedConvert('title', (v) => v as String? ?? ''),
        body: $checkedConvert('body', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$EstimateBodyToJson(EstimateBody instance) =>
    <String, dynamic>{'title': ?instance.title, 'body': ?instance.body};
