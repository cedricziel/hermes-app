// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_live_session_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$VoiceLiveSessionRequestCWProxy {
  VoiceLiveSessionRequest sdp(String sdp);

  VoiceLiveSessionRequest history(List<Map<String, Object>>? history);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VoiceLiveSessionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VoiceLiveSessionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  VoiceLiveSessionRequest call({
    String sdp,
    List<Map<String, Object>>? history,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfVoiceLiveSessionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfVoiceLiveSessionRequest.copyWith.fieldName(...)`
class _$VoiceLiveSessionRequestCWProxyImpl
    implements _$VoiceLiveSessionRequestCWProxy {
  const _$VoiceLiveSessionRequestCWProxyImpl(this._value);

  final VoiceLiveSessionRequest _value;

  @override
  VoiceLiveSessionRequest sdp(String sdp) => this(sdp: sdp);

  @override
  VoiceLiveSessionRequest history(List<Map<String, Object>>? history) =>
      this(history: history);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VoiceLiveSessionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VoiceLiveSessionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  VoiceLiveSessionRequest call({
    Object? sdp = const $CopyWithPlaceholder(),
    Object? history = const $CopyWithPlaceholder(),
  }) {
    return VoiceLiveSessionRequest(
      sdp: sdp == const $CopyWithPlaceholder()
          ? _value.sdp
          // ignore: cast_nullable_to_non_nullable
          : sdp as String,
      history: history == const $CopyWithPlaceholder()
          ? _value.history
          // ignore: cast_nullable_to_non_nullable
          : history as List<Map<String, Object>>?,
    );
  }
}

extension $VoiceLiveSessionRequestCopyWith on VoiceLiveSessionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfVoiceLiveSessionRequest.copyWith(...)` or like so:`instanceOfVoiceLiveSessionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$VoiceLiveSessionRequestCWProxy get copyWith =>
      _$VoiceLiveSessionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VoiceLiveSessionRequest _$VoiceLiveSessionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('VoiceLiveSessionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['sdp']);
  final val = VoiceLiveSessionRequest(
    sdp: $checkedConvert('sdp', (v) => v as String),
    history: $checkedConvert(
      'history',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) => (e as Map<String, dynamic>).map(
              (k, e) => MapEntry(k, e as Object),
            ),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$VoiceLiveSessionRequestToJson(
  VoiceLiveSessionRequest instance,
) => <String, dynamic>{'sdp': instance.sdp, 'history': ?instance.history};
