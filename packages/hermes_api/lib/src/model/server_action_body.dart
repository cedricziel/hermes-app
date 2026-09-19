//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'server_action_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ServerActionBody {
  /// Returns a new [ServerActionBody] instance.
  ServerActionBody({required this.action});

  @JsonKey(name: r'action', required: true, includeIfNull: false)
  final String action;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerActionBody && other.action == action;

  @override
  int get hashCode => action.hashCode;

  factory ServerActionBody.fromJson(Map<String, dynamic> json) =>
      _$ServerActionBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ServerActionBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
