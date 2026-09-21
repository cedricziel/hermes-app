import 'package:hermes_api/src/model/agent_plugin_install_body.dart';
import 'package:hermes_api/src/model/audio_transcription_request.dart';
import 'package:hermes_api/src/model/automation_blueprint_instantiate.dart';
import 'package:hermes_api/src/model/backup_request.dart';
import 'package:hermes_api/src/model/browsed_download_body.dart';
import 'package:hermes_api/src/model/bulk_delete_sessions.dart';
import 'package:hermes_api/src/model/bulk_task_body.dart';
import 'package:hermes_api/src/model/chat_image_upload.dart';
import 'package:hermes_api/src/model/comment_body.dart';
import 'package:hermes_api/src/model/config_update.dart';
import 'package:hermes_api/src/model/create_board_body.dart';
import 'package:hermes_api/src/model/create_task_body.dart';
import 'package:hermes_api/src/model/credential_pool_add.dart';
import 'package:hermes_api/src/model/cron_job_create.dart';
import 'package:hermes_api/src/model/cron_job_update.dart';
import 'package:hermes_api/src/model/curator_pause.dart';
import 'package:hermes_api/src/model/custom_endpoint_update.dart';
import 'package:hermes_api/src/model/debug_share_request.dart';
import 'package:hermes_api/src/model/decompose_body.dart';
import 'package:hermes_api/src/model/describe_auto_body.dart';
import 'package:hermes_api/src/model/describe_body.dart';
import 'package:hermes_api/src/model/env_var_delete.dart';
import 'package:hermes_api/src/model/env_var_reveal.dart';
import 'package:hermes_api/src/model/env_var_update.dart';
import 'package:hermes_api/src/model/estimate_body.dart';
import 'package:hermes_api/src/model/export_board_body.dart';
import 'package:hermes_api/src/model/font_set_body.dart';
import 'package:hermes_api/src/model/fs_write_text.dart';
import 'package:hermes_api/src/model/git_branch_switch_body.dart';
import 'package:hermes_api/src/model/git_commit_body.dart';
import 'package:hermes_api/src/model/git_file_body.dart';
import 'package:hermes_api/src/model/git_path_body.dart';
import 'package:hermes_api/src/model/git_pr_list_body.dart';
import 'package:hermes_api/src/model/git_worktree_add_body.dart';
import 'package:hermes_api/src/model/git_worktree_remove_body.dart';
import 'package:hermes_api/src/model/http_validation_error.dart';
import 'package:hermes_api/src/model/hook_create.dart';
import 'package:hermes_api/src/model/hook_delete.dart';
import 'package:hermes_api/src/model/import_board_body.dart';
import 'package:hermes_api/src/model/import_request.dart';
import 'package:hermes_api/src/model/learning_node_edit.dart';
import 'package:hermes_api/src/model/learning_node_ref.dart';
import 'package:hermes_api/src/model/link_body.dart';
import 'package:hermes_api/src/model/mcp_catalog_install.dart';
import 'package:hermes_api/src/model/mcp_enabled_toggle.dart';
import 'package:hermes_api/src/model/mcp_server_create.dart';
import 'package:hermes_api/src/model/mcp_servers_replace.dart';
import 'package:hermes_api/src/model/managed_directory_create.dart';
import 'package:hermes_api/src/model/managed_file_delete.dart';
import 'package:hermes_api/src/model/managed_file_upload.dart';
import 'package:hermes_api/src/model/memory_provider_config_update.dart';
import 'package:hermes_api/src/model/memory_provider_select.dart';
import 'package:hermes_api/src/model/memory_provider_setup_request.dart';
import 'package:hermes_api/src/model/memory_reset.dart';
import 'package:hermes_api/src/model/messaging_platform_update.dart';
import 'package:hermes_api/src/model/moa_config_payload.dart';
import 'package:hermes_api/src/model/moa_model_slot.dart';
import 'package:hermes_api/src/model/moa_preset_payload.dart';
import 'package:hermes_api/src/model/model_activate_body.dart';
import 'package:hermes_api/src/model/model_assignment.dart';
import 'package:hermes_api/src/model/model_download_body.dart';
import 'package:hermes_api/src/model/model_eject_body.dart';
import 'package:hermes_api/src/model/native_refresh_body.dart';
import 'package:hermes_api/src/model/native_token_body.dart';
import 'package:hermes_api/src/model/o_auth_submit_body.dart';
import 'package:hermes_api/src/model/orchestration_settings_body.dart';
import 'package:hermes_api/src/model/pairing_approve.dart';
import 'package:hermes_api/src/model/pairing_revoke.dart';
import 'package:hermes_api/src/model/password_login_body.dart';
import 'package:hermes_api/src/model/plugin_providers_put_body.dart';
import 'package:hermes_api/src/model/plugin_visibility_body.dart';
import 'package:hermes_api/src/model/profile_active_update.dart';
import 'package:hermes_api/src/model/profile_create.dart';
import 'package:hermes_api/src/model/profile_describe_auto.dart';
import 'package:hermes_api/src/model/profile_description_update.dart';
import 'package:hermes_api/src/model/profile_export.dart';
import 'package:hermes_api/src/model/profile_import.dart';
import 'package:hermes_api/src/model/profile_model_update.dart';
import 'package:hermes_api/src/model/profile_rename.dart';
import 'package:hermes_api/src/model/profile_soul_update.dart';
import 'package:hermes_api/src/model/quickstart_body.dart';
import 'package:hermes_api/src/model/raw_config_update.dart';
import 'package:hermes_api/src/model/reassign_body.dart';
import 'package:hermes_api/src/model/reclaim_body.dart';
import 'package:hermes_api/src/model/rename_board_body.dart';
import 'package:hermes_api/src/model/runtime_install_body.dart';
import 'package:hermes_api/src/model/server_action_body.dart';
import 'package:hermes_api/src/model/session_owner_backfill.dart';
import 'package:hermes_api/src/model/session_pr_scan_body.dart';
import 'package:hermes_api/src/model/session_prune.dart';
import 'package:hermes_api/src/model/session_rename.dart';
import 'package:hermes_api/src/model/sideload_body.dart';
import 'package:hermes_api/src/model/skill_content_update.dart';
import 'package:hermes_api/src/model/skill_create.dart';
import 'package:hermes_api/src/model/skill_install_request.dart';
import 'package:hermes_api/src/model/skill_toggle.dart';
import 'package:hermes_api/src/model/skill_uninstall_request.dart';
import 'package:hermes_api/src/model/skills_update_request.dart';
import 'package:hermes_api/src/model/specify_body.dart';
import 'package:hermes_api/src/model/tts_lease_request.dart';
import 'package:hermes_api/src/model/tts_speak_request.dart';
import 'package:hermes_api/src/model/telegram_onboarding_apply.dart';
import 'package:hermes_api/src/model/telegram_onboarding_start.dart';
import 'package:hermes_api/src/model/terminal_backend_select.dart';
import 'package:hermes_api/src/model/terminate_run_body.dart';
import 'package:hermes_api/src/model/theme_set_body.dart';
import 'package:hermes_api/src/model/toolset_env_update.dart';
import 'package:hermes_api/src/model/toolset_model_select.dart';
import 'package:hermes_api/src/model/toolset_post_setup.dart';
import 'package:hermes_api/src/model/toolset_provider_select.dart';
import 'package:hermes_api/src/model/toolset_toggle.dart';
import 'package:hermes_api/src/model/update_task_body.dart';
import 'package:hermes_api/src/model/validation_error.dart';
import 'package:hermes_api/src/model/voice_live_session_request.dart';
import 'package:hermes_api/src/model/webhook_create.dart';
import 'package:hermes_api/src/model/webhook_enabled_toggle.dart';
import 'package:hermes_api/src/model/whats_app_onboarding_apply.dart';
import 'package:hermes_api/src/model/whats_app_onboarding_start.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

ReturnType deserialize<ReturnType, BaseType>(
  dynamic value,
  String targetType, {
  bool growable = true,
}) {
  switch (targetType) {
    case 'String':
      return '$value' as ReturnType;
    case 'int':
      return (value is int ? value : int.parse('$value')) as ReturnType;
    case 'bool':
      if (value is bool) {
        return value as ReturnType;
      }
      final valueString = '$value'.toLowerCase();
      return (valueString == 'true' || valueString == '1') as ReturnType;
    case 'double':
      return (value is double ? value : double.parse('$value')) as ReturnType;
    case 'AgentPluginInstallBody':
      return AgentPluginInstallBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AudioTranscriptionRequest':
      return AudioTranscriptionRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AutomationBlueprintInstantiate':
      return AutomationBlueprintInstantiate.fromJson(
        value as Map<String, dynamic>,
      ) as ReturnType;
    case 'BackupRequest':
      return BackupRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrowsedDownloadBody':
      return BrowsedDownloadBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BulkDeleteSessions':
      return BulkDeleteSessions.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BulkTaskBody':
      return BulkTaskBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ChatImageUpload':
      return ChatImageUpload.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CommentBody':
      return CommentBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ConfigUpdate':
      return ConfigUpdate.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CreateBoardBody':
      return CreateBoardBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateTaskBody':
      return CreateTaskBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CredentialPoolAdd':
      return CredentialPoolAdd.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CronJobCreate':
      return CronJobCreate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CronJobUpdate':
      return CronJobUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CuratorPause':
      return CuratorPause.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CustomEndpointUpdate':
      return CustomEndpointUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DebugShareRequest':
      return DebugShareRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DecomposeBody':
      return DecomposeBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DescribeAutoBody':
      return DescribeAutoBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DescribeBody':
      return DescribeBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'EnvVarDelete':
      return EnvVarDelete.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'EnvVarReveal':
      return EnvVarReveal.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'EnvVarUpdate':
      return EnvVarUpdate.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'EstimateBody':
      return EstimateBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ExportBoardBody':
      return ExportBoardBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'FontSetBody':
      return FontSetBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'FsWriteText':
      return FsWriteText.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'GitBranchSwitchBody':
      return GitBranchSwitchBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GitCommitBody':
      return GitCommitBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GitFileBody':
      return GitFileBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'GitPathBody':
      return GitPathBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'GitPrListBody':
      return GitPrListBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GitWorktreeAddBody':
      return GitWorktreeAddBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GitWorktreeRemoveBody':
      return GitWorktreeRemoveBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HTTPValidationError':
      return HTTPValidationError.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HookCreate':
      return HookCreate.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HookDelete':
      return HookDelete.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ImportBoardBody':
      return ImportBoardBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ImportRequest':
      return ImportRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LearningNodeEdit':
      return LearningNodeEdit.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LearningNodeRef':
      return LearningNodeRef.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LinkBody':
      return LinkBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'MCPCatalogInstall':
      return MCPCatalogInstall.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MCPEnabledToggle':
      return MCPEnabledToggle.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MCPServerCreate':
      return MCPServerCreate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MCPServersReplace':
      return MCPServersReplace.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ManagedDirectoryCreate':
      return ManagedDirectoryCreate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ManagedFileDelete':
      return ManagedFileDelete.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ManagedFileUpload':
      return ManagedFileUpload.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemoryProviderConfigUpdate':
      return MemoryProviderConfigUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemoryProviderSelect':
      return MemoryProviderSelect.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemoryProviderSetupRequest':
      return MemoryProviderSetupRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemoryReset':
      return MemoryReset.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'MessagingPlatformUpdate':
      return MessagingPlatformUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MoaConfigPayload':
      return MoaConfigPayload.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MoaModelSlot':
      return MoaModelSlot.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'MoaPresetPayload':
      return MoaPresetPayload.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ModelActivateBody':
      return ModelActivateBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ModelAssignment':
      return ModelAssignment.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ModelDownloadBody':
      return ModelDownloadBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ModelEjectBody':
      return ModelEjectBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'NativeRefreshBody':
      return NativeRefreshBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'NativeTokenBody':
      return NativeTokenBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OAuthSubmitBody':
      return OAuthSubmitBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OrchestrationSettingsBody':
      return OrchestrationSettingsBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PairingApprove':
      return PairingApprove.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PairingRevoke':
      return PairingRevoke.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PasswordLoginBody':
      return PasswordLoginBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PluginProvidersPutBody':
      return PluginProvidersPutBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PluginVisibilityBody':
      return PluginVisibilityBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileActiveUpdate':
      return ProfileActiveUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileCreate':
      return ProfileCreate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileDescribeAuto':
      return ProfileDescribeAuto.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileDescriptionUpdate':
      return ProfileDescriptionUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileExport':
      return ProfileExport.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileImport':
      return ProfileImport.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileModelUpdate':
      return ProfileModelUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileRename':
      return ProfileRename.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProfileSoulUpdate':
      return ProfileSoulUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'QuickstartBody':
      return QuickstartBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RawConfigUpdate':
      return RawConfigUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ReassignBody':
      return ReassignBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ReclaimBody':
      return ReclaimBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RenameBoardBody':
      return RenameBoardBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RuntimeInstallBody':
      return RuntimeInstallBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ServerActionBody':
      return ServerActionBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionOwnerBackfill':
      return SessionOwnerBackfill.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionPrScanBody':
      return SessionPrScanBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionPrune':
      return SessionPrune.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SessionRename':
      return SessionRename.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SideloadBody':
      return SideloadBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SkillContentUpdate':
      return SkillContentUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SkillCreate':
      return SkillCreate.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SkillInstallRequest':
      return SkillInstallRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SkillToggle':
      return SkillToggle.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SkillUninstallRequest':
      return SkillUninstallRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SkillsUpdateRequest':
      return SkillsUpdateRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SpecifyBody':
      return SpecifyBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TTSLeaseRequest':
      return TTSLeaseRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TTSSpeakRequest':
      return TTSSpeakRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TelegramOnboardingApply':
      return TelegramOnboardingApply.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TelegramOnboardingStart':
      return TelegramOnboardingStart.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TerminalBackendSelect':
      return TerminalBackendSelect.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TerminateRunBody':
      return TerminateRunBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ThemeSetBody':
      return ThemeSetBody.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ToolsetEnvUpdate':
      return ToolsetEnvUpdate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ToolsetModelSelect':
      return ToolsetModelSelect.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ToolsetPostSetup':
      return ToolsetPostSetup.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ToolsetProviderSelect':
      return ToolsetProviderSelect.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ToolsetToggle':
      return ToolsetToggle.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'UpdateTaskBody':
      return UpdateTaskBody.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ValidationError':
      return ValidationError.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'VoiceLiveSessionRequest':
      return VoiceLiveSessionRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'WebhookCreate':
      return WebhookCreate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'WebhookEnabledToggle':
      return WebhookEnabledToggle.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'WhatsAppOnboardingApply':
      return WhatsAppOnboardingApply.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'WhatsAppOnboardingStart':
      return WhatsAppOnboardingStart.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Object':
      return value as ReturnType;
    default:
      RegExpMatch? match;

      if (value is List && (match = _regList.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toList(growable: growable)
            as ReturnType;
      }
      if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toSet()
            as ReturnType;
      }
      if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
        targetType = match![1]!.trim(); // ignore: parameter_assignments
        return Map<String, BaseType>.fromIterables(
          value.keys as Iterable<String>,
          value.values.map(
            (dynamic v) => deserialize<BaseType, BaseType>(
              v,
              targetType,
              growable: growable,
            ),
          ),
        ) as ReturnType;
      }
      break;
  }
  throw Exception('Cannot deserialize');
}
