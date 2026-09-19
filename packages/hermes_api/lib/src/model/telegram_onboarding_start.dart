//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'telegram_onboarding_start.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TelegramOnboardingStart {
  /// Returns a new [TelegramOnboardingStart] instance.
  TelegramOnboardingStart({this.botName});

  @JsonKey(name: r'bot_name', required: false, includeIfNull: false)
  final String? botName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelegramOnboardingStart && other.botName == botName;

  @override
  int get hashCode => (botName == null ? 0 : botName.hashCode);

  factory TelegramOnboardingStart.fromJson(Map<String, dynamic> json) =>
      _$TelegramOnboardingStartFromJson(json);

  Map<String, dynamic> toJson() => _$TelegramOnboardingStartToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
