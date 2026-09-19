//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'memory_reset.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemoryReset {
  /// Returns a new [MemoryReset] instance.
  MemoryReset({this.target = 'all'});

  @JsonKey(
    defaultValue: 'all',
    name: r'target',
    required: false,
    includeIfNull: false,
  )
  final String? target;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MemoryReset && other.target == target;

  @override
  int get hashCode => target.hashCode;

  factory MemoryReset.fromJson(Map<String, dynamic> json) =>
      _$MemoryResetFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryResetToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
