//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'curator_pause.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CuratorPause {
  /// Returns a new [CuratorPause] instance.
  CuratorPause({required this.paused});

  @JsonKey(name: r'paused', required: true, includeIfNull: false)
  final bool paused;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CuratorPause && other.paused == paused;

  @override
  int get hashCode => paused.hashCode;

  factory CuratorPause.fromJson(Map<String, dynamic> json) =>
      _$CuratorPauseFromJson(json);

  Map<String, dynamic> toJson() => _$CuratorPauseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
