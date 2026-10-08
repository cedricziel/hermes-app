//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'consent_answer.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ConsentAnswer {
  /// Returns a new [ConsentAnswer] instance.
  ConsentAnswer({required this.enabled, this.send = false});

  @JsonKey(name: r'enabled', required: true, includeIfNull: false)
  final bool enabled;

  @JsonKey(
    defaultValue: false,
    name: r'send',
    required: false,
    includeIfNull: false,
  )
  final bool? send;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentAnswer && other.enabled == enabled && other.send == send;

  @override
  int get hashCode => enabled.hashCode + send.hashCode;

  factory ConsentAnswer.fromJson(Map<String, dynamic> json) =>
      _$ConsentAnswerFromJson(json);

  Map<String, dynamic> toJson() => _$ConsentAnswerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
