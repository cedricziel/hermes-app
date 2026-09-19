//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cron_job_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CronJobUpdate {
  /// Returns a new [CronJobUpdate] instance.
  CronJobUpdate({required this.updates});

  @JsonKey(name: r'updates', required: true, includeIfNull: false)
  final Map<String, Object> updates;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CronJobUpdate && other.updates == updates;

  @override
  int get hashCode => updates.hashCode;

  factory CronJobUpdate.fromJson(Map<String, dynamic> json) =>
      _$CronJobUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$CronJobUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
