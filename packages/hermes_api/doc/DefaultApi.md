# hermes_api.api.DefaultApi

## Load the API package
```dart
import 'package:hermes_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**achievementsApiPluginsHermesAchievementsAchievementsGet**](DefaultApi.md#achievementsapipluginshermesachievementsachievementsget) | **GET** /api/plugins/hermes-achievements/achievements | Achievements
[**activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost**](DefaultApi.md#activatecustomendpointapiproviderscustomendpointsendpointidactivatepost) | **POST** /api/providers/custom-endpoints/{endpoint_id}/activate | Activate Custom Endpoint
[**addCommentApiPluginsKanbanTasksTaskIdCommentsPost**](DefaultApi.md#addcommentapipluginskanbantaskstaskidcommentspost) | **POST** /api/plugins/kanban/tasks/{task_id}/comments | Add Comment
[**addCredentialPoolEntryApiCredentialsPoolPost**](DefaultApi.md#addcredentialpoolentryapicredentialspoolpost) | **POST** /api/credentials/pool | Add Credential Pool Entry
[**addLinkApiPluginsKanbanLinksPost**](DefaultApi.md#addlinkapipluginskanbanlinkspost) | **POST** /api/plugins/kanban/links | Add Link
[**addMcpServerApiMcpServersPost**](DefaultApi.md#addmcpserverapimcpserverspost) | **POST** /api/mcp/servers | Add Mcp Server
[**applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost**](DefaultApi.md#applytelegramonboardingapimessagingtelegramonboardingpairingidapplypost) | **POST** /api/messaging/telegram/onboarding/{pairing_id}/apply | Apply Telegram Onboarding
[**applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost**](DefaultApi.md#applywhatsapponboardingapimessagingwhatsapponboardingpairingidapplypost) | **POST** /api/messaging/whatsapp/onboarding/{pairing_id}/apply | Apply Whatsapp Onboarding
[**approvePairingApiPairingApprovePost**](DefaultApi.md#approvepairingapipairingapprovepost) | **POST** /api/pairing/approve | Approve Pairing
[**authCallbackAuthCallbackGet**](DefaultApi.md#authcallbackauthcallbackget) | **GET** /auth/callback | Auth Callback
[**authLoginAuthLoginGet**](DefaultApi.md#authloginauthloginget) | **GET** /auth/login | Auth Login
[**authLogoutAuthLogoutPost**](DefaultApi.md#authlogoutauthlogoutpost) | **POST** /auth/logout | Auth Logout
[**authMcpServerApiMcpServersNameAuthPost**](DefaultApi.md#authmcpserverapimcpserversnameauthpost) | **POST** /api/mcp/servers/{name}/auth | Auth Mcp Server
[**authMeApiAuthMeGet**](DefaultApi.md#authmeapiauthmeget) | **GET** /api/auth/me | Auth Me
[**authNativeAuthorizeAuthNativeAuthorizeGet**](DefaultApi.md#authnativeauthorizeauthnativeauthorizeget) | **GET** /auth/native/authorize | Auth Native Authorize
[**authNativeRefreshAuthNativeRefreshPost**](DefaultApi.md#authnativerefreshauthnativerefreshpost) | **POST** /auth/native/refresh | Auth Native Refresh
[**authNativeTokenAuthNativeTokenPost**](DefaultApi.md#authnativetokenauthnativetokenpost) | **POST** /auth/native/token | Auth Native Token
[**authPasswordLoginAuthPasswordLoginPost**](DefaultApi.md#authpasswordloginauthpasswordloginpost) | **POST** /auth/password-login | Auth Password Login
[**authProvidersApiAuthProvidersGet**](DefaultApi.md#authprovidersapiauthprovidersget) | **GET** /api/auth/providers | Auth Providers
[**authWsTicketApiAuthWsTicketPost**](DefaultApi.md#authwsticketapiauthwsticketpost) | **POST** /api/auth/ws-ticket | Auth Ws Ticket
[**autoDescribeProfileApiPluginsKanbanProfilesProfileNameDescribeAutoPost**](DefaultApi.md#autodescribeprofileapipluginskanbanprofilesprofilenamedescribeautopost) | **POST** /api/plugins/kanban/profiles/{profile_name}/describe-auto | Auto Describe Profile
[**backfillSessionOwnerProfilesApiSessionsOwnerBackfillPost**](DefaultApi.md#backfillsessionownerprofilesapisessionsownerbackfillpost) | **POST** /api/sessions/owner-backfill | Backfill Session Owner Profiles
[**bulkDeleteSessionsEndpointApiSessionsBulkDeletePost**](DefaultApi.md#bulkdeletesessionsendpointapisessionsbulkdeletepost) | **POST** /api/sessions/bulk-delete | Bulk Delete Sessions Endpoint
[**bulkUpdateApiPluginsKanbanTasksBulkPost**](DefaultApi.md#bulkupdateapipluginskanbantasksbulkpost) | **POST** /api/plugins/kanban/tasks/bulk | Bulk Update
[**cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete**](DefaultApi.md#cancelmcpoauthflowapimcpoauthflowsflowiddelete) | **DELETE** /api/mcp/oauth/flows/{flow_id} | Cancel Mcp Oauth Flow
[**cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete**](DefaultApi.md#canceloauthsessionapiprovidersoauthsessionssessioniddelete) | **DELETE** /api/providers/oauth/sessions/{session_id} | Cancel Oauth Session
[**cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete**](DefaultApi.md#canceltelegramonboardingapimessagingtelegramonboardingpairingiddelete) | **DELETE** /api/messaging/telegram/onboarding/{pairing_id} | Cancel Telegram Onboarding
[**cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete**](DefaultApi.md#cancelwhatsapponboardingapimessagingwhatsapponboardingpairingiddelete) | **DELETE** /api/messaging/whatsapp/onboarding/{pairing_id} | Cancel Whatsapp Onboarding
[**checkHermesUpdateApiHermesUpdateCheckGet**](DefaultApi.md#checkhermesupdateapihermesupdatecheckget) | **GET** /api/hermes/update/check | Check Hermes Update
[**clearPendingPairingApiPairingClearPendingPost**](DefaultApi.md#clearpendingpairingapipairingclearpendingpost) | **POST** /api/pairing/clear-pending | Clear Pending Pairing
[**countEmptySessionsEndpointApiSessionsEmptyCountGet**](DefaultApi.md#countemptysessionsendpointapisessionsemptycountget) | **GET** /api/sessions/empty/count | Count Empty Sessions Endpoint
[**createBoardEndpointApiPluginsKanbanBoardsPost**](DefaultApi.md#createboardendpointapipluginskanbanboardspost) | **POST** /api/plugins/kanban/boards | Create Board Endpoint
[**createCronJobApiCronJobsPost**](DefaultApi.md#createcronjobapicronjobspost) | **POST** /api/cron/jobs | Create Cron Job
[**createHookApiOpsHooksPost**](DefaultApi.md#createhookapiopshookspost) | **POST** /api/ops/hooks | Create Hook
[**createManagedDirectoryApiFilesMkdirPost**](DefaultApi.md#createmanageddirectoryapifilesmkdirpost) | **POST** /api/files/mkdir | Create Managed Directory
[**createProfileEndpointApiProfilesPost**](DefaultApi.md#createprofileendpointapiprofilespost) | **POST** /api/profiles | Create Profile Endpoint
[**createSkillApiSkillsPost**](DefaultApi.md#createskillapiskillspost) | **POST** /api/skills | Create Skill
[**createTaskApiPluginsKanbanTasksPost**](DefaultApi.md#createtaskapipluginskanbantaskspost) | **POST** /api/plugins/kanban/tasks | Create Task
[**createVoiceLiveSessionApiAudioVoiceLiveSessionPost**](DefaultApi.md#createvoicelivesessionapiaudiovoicelivesessionpost) | **POST** /api/audio/voice-live/session | Create Voice Live Session
[**createWebhookApiWebhooksPost**](DefaultApi.md#createwebhookapiwebhookspost) | **POST** /api/webhooks | Create Webhook
[**cronFireWebhookApiCronFirePost**](DefaultApi.md#cronfirewebhookapicronfirepost) | **POST** /api/cron/fire | Cron Fire Webhook
[**decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost**](DefaultApi.md#decomposetaskendpointapipluginskanbantaskstaskiddecomposepost) | **POST** /api/plugins/kanban/tasks/{task_id}/decompose | Decompose Task Endpoint
[**deleteAgentPluginApiDashboardAgentPluginsNameDelete**](DefaultApi.md#deleteagentpluginapidashboardagentpluginsnamedelete) | **DELETE** /api/dashboard/agent-plugins/{name} | Delete Agent Plugin
[**deleteBoardApiPluginsKanbanBoardsSlugDelete**](DefaultApi.md#deleteboardapipluginskanbanboardsslugdelete) | **DELETE** /api/plugins/kanban/boards/{slug} | Delete Board
[**deleteCronJobApiCronJobsJobIdDelete**](DefaultApi.md#deletecronjobapicronjobsjobiddelete) | **DELETE** /api/cron/jobs/{job_id} | Delete Cron Job
[**deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete**](DefaultApi.md#deletecustomendpointapiproviderscustomendpointsendpointiddelete) | **DELETE** /api/providers/custom-endpoints/{endpoint_id} | Delete Custom Endpoint
[**deleteEmptySessionsEndpointApiSessionsEmptyDelete**](DefaultApi.md#deleteemptysessionsendpointapisessionsemptydelete) | **DELETE** /api/sessions/empty | Delete Empty Sessions Endpoint
[**deleteHookApiOpsHooksDelete**](DefaultApi.md#deletehookapiopshooksdelete) | **DELETE** /api/ops/hooks | Delete Hook
[**deleteLearningNodeApiLearningNodeDelete**](DefaultApi.md#deletelearningnodeapilearningnodedelete) | **DELETE** /api/learning/node | Delete Learning Node
[**deleteLinkApiPluginsKanbanLinksDelete**](DefaultApi.md#deletelinkapipluginskanbanlinksdelete) | **DELETE** /api/plugins/kanban/links | Delete Link
[**deleteManagedFileApiFilesDelete**](DefaultApi.md#deletemanagedfileapifilesdelete) | **DELETE** /api/files | Delete Managed File
[**deleteProfileEndpointApiProfilesNameDelete**](DefaultApi.md#deleteprofileendpointapiprofilesnamedelete) | **DELETE** /api/profiles/{name} | Delete Profile Endpoint
[**deleteSessionEndpointApiSessionsSessionIdDelete**](DefaultApi.md#deletesessionendpointapisessionssessioniddelete) | **DELETE** /api/sessions/{session_id} | Delete Session Endpoint
[**deleteTaskApiPluginsKanbanTasksTaskIdDelete**](DefaultApi.md#deletetaskapipluginskanbantaskstaskiddelete) | **DELETE** /api/plugins/kanban/tasks/{task_id} | Delete Task
[**deleteWebhookApiWebhooksNameDelete**](DefaultApi.md#deletewebhookapiwebhooksnamedelete) | **DELETE** /api/webhooks/{name} | Delete Webhook
[**describeProfileAutoEndpointApiProfilesNameDescribeAutoPost**](DefaultApi.md#describeprofileautoendpointapiprofilesnamedescribeautopost) | **POST** /api/profiles/{name}/describe-auto | Describe Profile Auto Endpoint
[**disconnectOauthProviderApiProvidersOauthProviderIdDelete**](DefaultApi.md#disconnectoauthproviderapiprovidersoauthprovideriddelete) | **DELETE** /api/providers/oauth/{provider_id} | Disconnect Oauth Provider
[**dispatchApiPluginsKanbanDispatchPost**](DefaultApi.md#dispatchapipluginskanbandispatchpost) | **POST** /api/plugins/kanban/dispatch | Dispatch
[**downloadAttachmentApiPluginsKanbanAttachmentsAttachmentIdGet**](DefaultApi.md#downloadattachmentapipluginskanbanattachmentsattachmentidget) | **GET** /api/plugins/kanban/attachments/{attachment_id} | Download Attachment
[**downloadDashboardBackupApiOpsBackupDownloadGet**](DefaultApi.md#downloaddashboardbackupapiopsbackupdownloadget) | **GET** /api/ops/backup/download | Download Dashboard Backup
[**downloadManagedFileApiFilesDownloadGet**](DefaultApi.md#downloadmanagedfileapifilesdownloadget) | **GET** /api/files/download | Download Managed File
[**enableWebhooksApiWebhooksEnablePost**](DefaultApi.md#enablewebhooksapiwebhooksenablepost) | **POST** /api/webhooks/enable | Enable Webhooks
[**estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost**](DefaultApi.md#estimatetaskendpointapipluginskanbantaskstaskidestimatepost) | **POST** /api/plugins/kanban/tasks/{task_id}/estimate | Estimate Task Endpoint
[**estimateTextEndpointApiPluginsKanbanEstimatePost**](DefaultApi.md#estimatetextendpointapipluginskanbanestimatepost) | **POST** /api/plugins/kanban/estimate | Estimate Text Endpoint
[**exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost**](DefaultApi.md#exportboardendpointapipluginskanbanboardsslugexportpost) | **POST** /api/plugins/kanban/boards/{slug}/export | Export Board Endpoint
[**exportProfileEndpointApiProfilesNameExportPost**](DefaultApi.md#exportprofileendpointapiprofilesnameexportpost) | **POST** /api/profiles/{name}/export | Export Profile Endpoint
[**exportSessionEndpointApiSessionsSessionIdExportGet**](DefaultApi.md#exportsessionendpointapisessionssessionidexportget) | **GET** /api/sessions/{session_id}/export | Export Session Endpoint
[**fsDefaultCwdApiFsDefaultCwdGet**](DefaultApi.md#fsdefaultcwdapifsdefaultcwdget) | **GET** /api/fs/default-cwd | Fs Default Cwd
[**fsDownloadApiFsDownloadGet**](DefaultApi.md#fsdownloadapifsdownloadget) | **GET** /api/fs/download | Fs Download
[**fsGitRootApiFsGitRootGet**](DefaultApi.md#fsgitrootapifsgitrootget) | **GET** /api/fs/git-root | Fs Git Root
[**fsListApiFsListGet**](DefaultApi.md#fslistapifslistget) | **GET** /api/fs/list | Fs List
[**fsReadDataUrlApiFsReadDataUrlGet**](DefaultApi.md#fsreaddataurlapifsreaddataurlget) | **GET** /api/fs/read-data-url | Fs Read Data Url
[**fsReadTextApiFsReadTextGet**](DefaultApi.md#fsreadtextapifsreadtextget) | **GET** /api/fs/read-text | Fs Read Text
[**fsWriteTextApiFsWriteTextPost**](DefaultApi.md#fswritetextapifswritetextpost) | **POST** /api/fs/write-text | Fs Write Text
[**gatewayDrainApiGatewayDrainPost**](DefaultApi.md#gatewaydrainapigatewaydrainpost) | **POST** /api/gateway/drain | Gateway Drain
[**gatewayMigrateApiGatewayMigratePost**](DefaultApi.md#gatewaymigrateapigatewaymigratepost) | **POST** /api/gateway/migrate | Gateway Migrate
[**gatewayMigratePlanApiGatewayMigratePlanGet**](DefaultApi.md#gatewaymigrateplanapigatewaymigrateplanget) | **GET** /api/gateway/migrate/plan | Gateway Migrate Plan
[**getActionStatusApiActionsNameStatusGet**](DefaultApi.md#getactionstatusapiactionsnamestatusget) | **GET** /api/actions/{name}/status | Get Action Status
[**getActiveProfileEndpointApiProfilesActiveGet**](DefaultApi.md#getactiveprofileendpointapiprofilesactiveget) | **GET** /api/profiles/active | Get Active Profile Endpoint
[**getAssigneesApiPluginsKanbanAssigneesGet**](DefaultApi.md#getassigneesapipluginskanbanassigneesget) | **GET** /api/plugins/kanban/assignees | Get Assignees
[**getAuxiliaryModelsApiModelAuxiliaryGet**](DefaultApi.md#getauxiliarymodelsapimodelauxiliaryget) | **GET** /api/model/auxiliary | Get Auxiliary Models
[**getBoardEndpointApiPluginsKanbanBoardGet**](DefaultApi.md#getboardendpointapipluginskanbanboardget) | **GET** /api/plugins/kanban/board | Get Board Endpoint
[**getClientVoiceConfigApiAudioVoiceConfigGet**](DefaultApi.md#getclientvoiceconfigapiaudiovoiceconfigget) | **GET** /api/audio/voice-config | Get Client Voice Config
[**getComputerUseStatusApiToolsComputerUseStatusGet**](DefaultApi.md#getcomputerusestatusapitoolscomputerusestatusget) | **GET** /api/tools/computer-use/status | Get Computer Use Status
[**getConfigApiConfigGet**](DefaultApi.md#getconfigapiconfigget) | **GET** /api/config | Get Config
[**getConfigApiPluginsKanbanConfigGet**](DefaultApi.md#getconfigapipluginskanbanconfigget) | **GET** /api/plugins/kanban/config | Get Config
[**getConfigRawApiConfigRawGet**](DefaultApi.md#getconfigrawapiconfigrawget) | **GET** /api/config/raw | Get Config Raw
[**getCronDeliveryTargetsApiCronDeliveryTargetsGet**](DefaultApi.md#getcrondeliverytargetsapicrondeliverytargetsget) | **GET** /api/cron/delivery-targets | Get Cron Delivery Targets
[**getCronJobApiCronJobsJobIdGet**](DefaultApi.md#getcronjobapicronjobsjobidget) | **GET** /api/cron/jobs/{job_id} | Get Cron Job
[**getCuratorStatusApiCuratorGet**](DefaultApi.md#getcuratorstatusapicuratorget) | **GET** /api/curator | Get Curator Status
[**getDashboardFontApiDashboardFontGet**](DefaultApi.md#getdashboardfontapidashboardfontget) | **GET** /api/dashboard/font | Get Dashboard Font
[**getDashboardPluginsApiDashboardPluginsGet**](DefaultApi.md#getdashboardpluginsapidashboardpluginsget) | **GET** /api/dashboard/plugins | Get Dashboard Plugins
[**getDashboardThemesApiDashboardThemesGet**](DefaultApi.md#getdashboardthemesapidashboardthemesget) | **GET** /api/dashboard/themes | Get Dashboard Themes
[**getDefaultsApiConfigDefaultsGet**](DefaultApi.md#getdefaultsapiconfigdefaultsget) | **GET** /api/config/defaults | Get Defaults
[**getEgressStatusApiEgressStatusGet**](DefaultApi.md#getegressstatusapiegressstatusget) | **GET** /api/egress/status | Get Egress Status
[**getElevenlabsVoicesApiAudioElevenlabsVoicesGet**](DefaultApi.md#getelevenlabsvoicesapiaudioelevenlabsvoicesget) | **GET** /api/audio/elevenlabs/voices | Get Elevenlabs Voices
[**getEnvVarsApiEnvGet**](DefaultApi.md#getenvvarsapienvget) | **GET** /api/env | Get Env Vars
[**getHealthApiHealthGet**](DefaultApi.md#gethealthapihealthget) | **GET** /api/health | Get Health
[**getHealthIdleApiHealthIdleGet**](DefaultApi.md#gethealthidleapihealthidleget) | **GET** /api/health/idle | Get Health Idle
[**getHomeChannelsApiPluginsKanbanHomeChannelsGet**](DefaultApi.md#gethomechannelsapipluginskanbanhomechannelsget) | **GET** /api/plugins/kanban/home-channels | Get Home Channels
[**getLearningGraphApiLearningGraphGet**](DefaultApi.md#getlearninggraphapilearninggraphget) | **GET** /api/learning/graph | Get Learning Graph
[**getLearningNodeApiLearningNodeGet**](DefaultApi.md#getlearningnodeapilearningnodeget) | **GET** /api/learning/node | Get Learning Node
[**getLogsApiLogsGet**](DefaultApi.md#getlogsapilogsget) | **GET** /api/logs | Get Logs
[**getMediaApiMediaGet**](DefaultApi.md#getmediaapimediaget) | **GET** /api/media | Get Media
[**getMemoryProviderConfigApiMemoryProvidersNameConfigGet**](DefaultApi.md#getmemoryproviderconfigapimemoryprovidersnameconfigget) | **GET** /api/memory/providers/{name}/config | Get Memory Provider Config
[**getMemoryStatusApiMemoryGet**](DefaultApi.md#getmemorystatusapimemoryget) | **GET** /api/memory | Get Memory Status
[**getMessagingPlatformsApiMessagingPlatformsGet**](DefaultApi.md#getmessagingplatformsapimessagingplatformsget) | **GET** /api/messaging/platforms | Get Messaging Platforms
[**getMoaModelsApiModelMoaGet**](DefaultApi.md#getmoamodelsapimodelmoaget) | **GET** /api/model/moa | Get Moa Models
[**getModelInfoApiModelInfoGet**](DefaultApi.md#getmodelinfoapimodelinfoget) | **GET** /api/model/info | Get Model Info
[**getModelOptionsApiModelOptionsGet**](DefaultApi.md#getmodeloptionsapimodeloptionsget) | **GET** /api/model/options | Get Model Options
[**getModelsAnalyticsApiAnalyticsModelsGet**](DefaultApi.md#getmodelsanalyticsapianalyticsmodelsget) | **GET** /api/analytics/models | Get Models Analytics
[**getOrchestrationSettingsApiPluginsKanbanOrchestrationGet**](DefaultApi.md#getorchestrationsettingsapipluginskanbanorchestrationget) | **GET** /api/plugins/kanban/orchestration | Get Orchestration Settings
[**getPluginsCatalogApiDashboardPluginsCatalogGet**](DefaultApi.md#getpluginscatalogapidashboardpluginscatalogget) | **GET** /api/dashboard/plugins/catalog | Get Plugins Catalog
[**getPluginsHubApiDashboardPluginsHubGet**](DefaultApi.md#getpluginshubapidashboardpluginshubget) | **GET** /api/dashboard/plugins/hub | Get Plugins Hub
[**getPortalStatusApiPortalGet**](DefaultApi.md#getportalstatusapiportalget) | **GET** /api/portal | Get Portal Status
[**getProfileDesktopOverlayApiProfilesNameDesktopOverlayGet**](DefaultApi.md#getprofiledesktopoverlayapiprofilesnamedesktopoverlayget) | **GET** /api/profiles/{name}/desktop-overlay | Get Profile Desktop Overlay
[**getProfileSetupCommandApiProfilesNameSetupCommandGet**](DefaultApi.md#getprofilesetupcommandapiprofilesnamesetupcommandget) | **GET** /api/profiles/{name}/setup-command | Get Profile Setup Command
[**getProfileSoulApiProfilesNameSoulGet**](DefaultApi.md#getprofilesoulapiprofilesnamesoulget) | **GET** /api/profiles/{name}/soul | Get Profile Soul
[**getProfilesProjectsTreeApiProfilesProjectsTreeGet**](DefaultApi.md#getprofilesprojectstreeapiprofilesprojectstreeget) | **GET** /api/profiles/projects/tree | Get Profiles Projects Tree
[**getProfilesSessionsApiProfilesSessionsGet**](DefaultApi.md#getprofilessessionsapiprofilessessionsget) | **GET** /api/profiles/sessions | Get Profiles Sessions
[**getProfilesSessionsSidebarApiProfilesSessionsSidebarGet**](DefaultApi.md#getprofilessessionssidebarapiprofilessessionssidebarget) | **GET** /api/profiles/sessions/sidebar | Get Profiles Sessions Sidebar
[**getRecommendedDefaultModelApiModelRecommendedDefaultGet**](DefaultApi.md#getrecommendeddefaultmodelapimodelrecommendeddefaultget) | **GET** /api/model/recommended-default | Get Recommended Default Model
[**getRunEndpointApiPluginsKanbanRunsRunIdGet**](DefaultApi.md#getrunendpointapipluginskanbanrunsrunidget) | **GET** /api/plugins/kanban/runs/{run_id} | Get Run Endpoint
[**getSchemaApiConfigSchemaGet**](DefaultApi.md#getschemaapiconfigschemaget) | **GET** /api/config/schema | Get Schema
[**getSessionDetailApiSessionsSessionIdGet**](DefaultApi.md#getsessiondetailapisessionssessionidget) | **GET** /api/sessions/{session_id} | Get Session Detail
[**getSessionLatestDescendantApiSessionsSessionIdLatestDescendantGet**](DefaultApi.md#getsessionlatestdescendantapisessionssessionidlatestdescendantget) | **GET** /api/sessions/{session_id}/latest-descendant | Get Session Latest Descendant
[**getSessionMessagesApiSessionsSessionIdMessagesGet**](DefaultApi.md#getsessionmessagesapisessionssessionidmessagesget) | **GET** /api/sessions/{session_id}/messages | Get Session Messages
[**getSessionMessagesAroundApiSessionsSessionIdMessagesAroundGet**](DefaultApi.md#getsessionmessagesaroundapisessionssessionidmessagesaroundget) | **GET** /api/sessions/{session_id}/messages/around | Get Session Messages Around
[**getSessionStatsApiSessionsStatsGet**](DefaultApi.md#getsessionstatsapisessionsstatsget) | **GET** /api/sessions/stats | Get Session Stats
[**getSessionTimelineApiSessionsSessionIdTimelineGet**](DefaultApi.md#getsessiontimelineapisessionssessionidtimelineget) | **GET** /api/sessions/{session_id}/timeline | Get Session Timeline
[**getSessionsApiSessionsGet**](DefaultApi.md#getsessionsapisessionsget) | **GET** /api/sessions | Get Sessions
[**getSkillContentApiSkillsContentGet**](DefaultApi.md#getskillcontentapiskillscontentget) | **GET** /api/skills/content | Get Skill Content
[**getSkillsApiSkillsGet**](DefaultApi.md#getskillsapiskillsget) | **GET** /api/skills | Get Skills
[**getSshOwnershipApiSshOwnershipGet**](DefaultApi.md#getsshownershipapisshownershipget) | **GET** /api/ssh/ownership | Get Ssh Ownership
[**getStatsApiPluginsKanbanStatsGet**](DefaultApi.md#getstatsapipluginskanbanstatsget) | **GET** /api/plugins/kanban/stats | Get Stats
[**getStatusApiStatusGet**](DefaultApi.md#getstatusapistatusget) | **GET** /api/status | Get Status
[**getSystemStatsApiSystemStatsGet**](DefaultApi.md#getsystemstatsapisystemstatsget) | **GET** /api/system/stats | Get System Stats
[**getTaskApiPluginsKanbanTasksTaskIdGet**](DefaultApi.md#gettaskapipluginskanbantaskstaskidget) | **GET** /api/plugins/kanban/tasks/{task_id} | Get Task
[**getTaskLogApiPluginsKanbanTasksTaskIdLogGet**](DefaultApi.md#gettasklogapipluginskanbantaskstaskidlogget) | **GET** /api/plugins/kanban/tasks/{task_id}/log | Get Task Log
[**getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet**](DefaultApi.md#gettelegramonboardingstatusapimessagingtelegramonboardingpairingidget) | **GET** /api/messaging/telegram/onboarding/{pairing_id} | Get Telegram Onboarding Status
[**getTerminalBackendsApiToolsTerminalBackendsGet**](DefaultApi.md#getterminalbackendsapitoolsterminalbackendsget) | **GET** /api/tools/terminal/backends | Get Terminal Backends
[**getToolsetConfigApiToolsToolsetsNameConfigGet**](DefaultApi.md#gettoolsetconfigapitoolstoolsetsnameconfigget) | **GET** /api/tools/toolsets/{name}/config | Get Toolset Config
[**getToolsetModelsApiToolsToolsetsNameModelsGet**](DefaultApi.md#gettoolsetmodelsapitoolstoolsetsnamemodelsget) | **GET** /api/tools/toolsets/{name}/models | Get Toolset Models
[**getToolsetsApiToolsToolsetsGet**](DefaultApi.md#gettoolsetsapitoolstoolsetsget) | **GET** /api/tools/toolsets | Get Toolsets
[**getUpdateReceiptApiHermesUpdateReceiptGet**](DefaultApi.md#getupdatereceiptapihermesupdatereceiptget) | **GET** /api/hermes/update/receipt | Get Update Receipt
[**getUsageAnalyticsApiAnalyticsUsageGet**](DefaultApi.md#getusageanalyticsapianalyticsusageget) | **GET** /api/analytics/usage | Get Usage Analytics
[**getVoiceLiveStatusApiAudioVoiceLiveStatusGet**](DefaultApi.md#getvoicelivestatusapiaudiovoicelivestatusget) | **GET** /api/audio/voice-live/status | Get Voice Live Status
[**getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet**](DefaultApi.md#getwhatsapponboardingstatusapimessagingwhatsapponboardingpairingidget) | **GET** /api/messaging/whatsapp/onboarding/{pairing_id} | Get Whatsapp Onboarding Status
[**ghAuthStatusRouteApiGitGhAuthGet**](DefaultApi.md#ghauthstatusrouteapigitghauthget) | **GET** /api/git/gh-auth | Gh Auth Status Route
[**gitBaseBranchesRouteApiGitBaseBranchesGet**](DefaultApi.md#gitbasebranchesrouteapigitbasebranchesget) | **GET** /api/git/base-branches | Git Base Branches Route
[**gitBranchSwitchRouteApiGitBranchSwitchPost**](DefaultApi.md#gitbranchswitchrouteapigitbranchswitchpost) | **POST** /api/git/branch/switch | Git Branch Switch Route
[**gitBranchesRouteApiGitBranchesGet**](DefaultApi.md#gitbranchesrouteapigitbranchesget) | **GET** /api/git/branches | Git Branches Route
[**gitCommitContextRouteApiGitReviewCommitContextGet**](DefaultApi.md#gitcommitcontextrouteapigitreviewcommitcontextget) | **GET** /api/git/review/commit-context | Git Commit Context Route
[**gitCommitRouteApiGitReviewCommitPost**](DefaultApi.md#gitcommitrouteapigitreviewcommitpost) | **POST** /api/git/review/commit | Git Commit Route
[**gitCreatePrRouteApiGitReviewCreatePrPost**](DefaultApi.md#gitcreateprrouteapigitreviewcreateprpost) | **POST** /api/git/review/create-pr | Git Create Pr Route
[**gitFileDiffRouteApiGitFileDiffGet**](DefaultApi.md#gitfilediffrouteapigitfilediffget) | **GET** /api/git/file-diff | Git File Diff Route
[**gitPrListRouteApiGitReviewPrListPost**](DefaultApi.md#gitprlistrouteapigitreviewprlistpost) | **POST** /api/git/review/pr-list | Git Pr List Route
[**gitPushRouteApiGitReviewPushPost**](DefaultApi.md#gitpushrouteapigitreviewpushpost) | **POST** /api/git/review/push | Git Push Route
[**gitRevParseRouteApiGitReviewRevParseGet**](DefaultApi.md#gitrevparserouteapigitreviewrevparseget) | **GET** /api/git/review/rev-parse | Git Rev Parse Route
[**gitRevertRouteApiGitReviewRevertPost**](DefaultApi.md#gitrevertrouteapigitreviewrevertpost) | **POST** /api/git/review/revert | Git Revert Route
[**gitReviewDiffRouteApiGitReviewDiffGet**](DefaultApi.md#gitreviewdiffrouteapigitreviewdiffget) | **GET** /api/git/review/diff | Git Review Diff Route
[**gitReviewListRouteApiGitReviewListGet**](DefaultApi.md#gitreviewlistrouteapigitreviewlistget) | **GET** /api/git/review/list | Git Review List Route
[**gitShipInfoRouteApiGitReviewShipInfoGet**](DefaultApi.md#gitshipinforouteapigitreviewshipinfoget) | **GET** /api/git/review/ship-info | Git Ship Info Route
[**gitStageRouteApiGitReviewStagePost**](DefaultApi.md#gitstagerouteapigitreviewstagepost) | **POST** /api/git/review/stage | Git Stage Route
[**gitStatusRouteApiGitStatusGet**](DefaultApi.md#gitstatusrouteapigitstatusget) | **GET** /api/git/status | Git Status Route
[**gitUnstageRouteApiGitReviewUnstagePost**](DefaultApi.md#gitunstagerouteapigitreviewunstagepost) | **POST** /api/git/review/unstage | Git Unstage Route
[**gitWorktreeAddRouteApiGitWorktreeAddPost**](DefaultApi.md#gitworktreeaddrouteapigitworktreeaddpost) | **POST** /api/git/worktree/add | Git Worktree Add Route
[**gitWorktreeRemoveRouteApiGitWorktreeRemovePost**](DefaultApi.md#gitworktreeremoverouteapigitworktreeremovepost) | **POST** /api/git/worktree/remove | Git Worktree Remove Route
[**gitWorktreesRouteApiGitWorktreesGet**](DefaultApi.md#gitworktreesrouteapigitworktreesget) | **GET** /api/git/worktrees | Git Worktrees Route
[**grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost**](DefaultApi.md#grantcomputerusepermissionsapitoolscomputerusepermissionsgrantpost) | **POST** /api/tools/computer-use/permissions/grant | Grant Computer Use Permissions
[**importBoardEndpointApiPluginsKanbanBoardsImportPost**](DefaultApi.md#importboardendpointapipluginskanbanboardsimportpost) | **POST** /api/plugins/kanban/boards/import | Import Board Endpoint
[**importProfileEndpointApiProfilesImportPost**](DefaultApi.md#importprofileendpointapiprofilesimportpost) | **POST** /api/profiles/import | Import Profile Endpoint
[**importSessionsEndpointApiSessionsImportPost**](DefaultApi.md#importsessionsendpointapisessionsimportpost) | **POST** /api/sessions/import | Import Sessions Endpoint
[**inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet**](DefaultApi.md#inspectrunendpointapipluginskanbanrunsrunidinspectget) | **GET** /api/plugins/kanban/runs/{run_id}/inspect | Inspect Run Endpoint
[**installMcpCatalogEntryApiMcpCatalogInstallPost**](DefaultApi.md#installmcpcatalogentryapimcpcataloginstallpost) | **POST** /api/mcp/catalog/install | Install Mcp Catalog Entry
[**installSkillHubApiSkillsHubInstallPost**](DefaultApi.md#installskillhubapiskillshubinstallpost) | **POST** /api/skills/hub/install | Install Skill Hub
[**instantiateBlueprintApiCronBlueprintsInstantiatePost**](DefaultApi.md#instantiateblueprintapicronblueprintsinstantiatepost) | **POST** /api/cron/blueprints/instantiate | Instantiate Blueprint
[**listActiveWorkersApiPluginsKanbanWorkersActiveGet**](DefaultApi.md#listactiveworkersapipluginskanbanworkersactiveget) | **GET** /api/plugins/kanban/workers/active | List Active Workers
[**listBoardsApiPluginsKanbanBoardsGet**](DefaultApi.md#listboardsapipluginskanbanboardsget) | **GET** /api/plugins/kanban/boards | List Boards
[**listCheckpointsApiOpsCheckpointsGet**](DefaultApi.md#listcheckpointsapiopscheckpointsget) | **GET** /api/ops/checkpoints | List Checkpoints
[**listCredentialPoolApiCredentialsPoolGet**](DefaultApi.md#listcredentialpoolapicredentialspoolget) | **GET** /api/credentials/pool | List Credential Pool
[**listCronBlueprintsApiCronBlueprintsGet**](DefaultApi.md#listcronblueprintsapicronblueprintsget) | **GET** /api/cron/blueprints | List Cron Blueprints
[**listCronJobRunsApiCronJobsJobIdRunsGet**](DefaultApi.md#listcronjobrunsapicronjobsjobidrunsget) | **GET** /api/cron/jobs/{job_id}/runs | List Cron Job Runs
[**listCronJobsApiCronJobsGet**](DefaultApi.md#listcronjobsapicronjobsget) | **GET** /api/cron/jobs | List Cron Jobs
[**listCustomEndpointsApiProvidersCustomEndpointsGet**](DefaultApi.md#listcustomendpointsapiproviderscustomendpointsget) | **GET** /api/providers/custom-endpoints | List Custom Endpoints
[**listDiagnosticsApiPluginsKanbanDiagnosticsGet**](DefaultApi.md#listdiagnosticsapipluginskanbandiagnosticsget) | **GET** /api/plugins/kanban/diagnostics | List Diagnostics
[**listHooksApiOpsHooksGet**](DefaultApi.md#listhooksapiopshooksget) | **GET** /api/ops/hooks | List Hooks
[**listKanbanProjectsApiPluginsKanbanProjectsGet**](DefaultApi.md#listkanbanprojectsapipluginskanbanprojectsget) | **GET** /api/plugins/kanban/projects | List Kanban Projects
[**listManagedFilesApiFilesGet**](DefaultApi.md#listmanagedfilesapifilesget) | **GET** /api/files | List Managed Files
[**listMcpCatalogApiMcpCatalogGet**](DefaultApi.md#listmcpcatalogapimcpcatalogget) | **GET** /api/mcp/catalog | List Mcp Catalog
[**listMcpServersApiMcpServersGet**](DefaultApi.md#listmcpserversapimcpserversget) | **GET** /api/mcp/servers | List Mcp Servers
[**listOauthProvidersApiProvidersOauthGet**](DefaultApi.md#listoauthprovidersapiprovidersoauthget) | **GET** /api/providers/oauth | List Oauth Providers
[**listOfficialSkillsApiSkillsHubOfficialGet**](DefaultApi.md#listofficialskillsapiskillshubofficialget) | **GET** /api/skills/hub/official | List Official Skills
[**listPairingApiPairingGet**](DefaultApi.md#listpairingapipairingget) | **GET** /api/pairing | List Pairing
[**listProfileRosterApiPluginsKanbanProfilesGet**](DefaultApi.md#listprofilerosterapipluginskanbanprofilesget) | **GET** /api/plugins/kanban/profiles | List Profile Roster
[**listProfilesEndpointApiProfilesGet**](DefaultApi.md#listprofilesendpointapiprofilesget) | **GET** /api/profiles | List Profiles Endpoint
[**listSkillsHubSourcesApiSkillsHubSourcesGet**](DefaultApi.md#listskillshubsourcesapiskillshubsourcesget) | **GET** /api/skills/hub/sources | List Skills Hub Sources
[**listTaskAttachmentsApiPluginsKanbanTasksTaskIdAttachmentsGet**](DefaultApi.md#listtaskattachmentsapipluginskanbantaskstaskidattachmentsget) | **GET** /api/plugins/kanban/tasks/{task_id}/attachments | List Task Attachments
[**listWebhooksApiWebhooksGet**](DefaultApi.md#listwebhooksapiwebhooksget) | **GET** /api/webhooks | List Webhooks
[**localModelsActivateApiLocalModelsActivatePost**](DefaultApi.md#localmodelsactivateapilocalmodelsactivatepost) | **POST** /api/local-models/activate | Local Models Activate
[**localModelsCatalogApiLocalModelsCatalogGet**](DefaultApi.md#localmodelscatalogapilocalmodelscatalogget) | **GET** /api/local-models/catalog | Local Models Catalog
[**localModelsDeleteApiLocalModelsModelsModelIdDelete**](DefaultApi.md#localmodelsdeleteapilocalmodelsmodelsmodeliddelete) | **DELETE** /api/local-models/models/{model_id} | Local Models Delete
[**localModelsDownloadApiLocalModelsDownloadPost**](DefaultApi.md#localmodelsdownloadapilocalmodelsdownloadpost) | **POST** /api/local-models/download | Local Models Download
[**localModelsDownloadBrowsedApiLocalModelsDownloadBrowsedPost**](DefaultApi.md#localmodelsdownloadbrowsedapilocalmodelsdownloadbrowsedpost) | **POST** /api/local-models/download-browsed | Local Models Download Browsed
[**localModelsEjectApiLocalModelsEjectPost**](DefaultApi.md#localmodelsejectapilocalmodelsejectpost) | **POST** /api/local-models/eject | Local Models Eject
[**localModelsHardwareApiLocalModelsHardwareGet**](DefaultApi.md#localmodelshardwareapilocalmodelshardwareget) | **GET** /api/local-models/hardware | Local Models Hardware
[**localModelsJobApiLocalModelsJobsJobIdGet**](DefaultApi.md#localmodelsjobapilocalmodelsjobsjobidget) | **GET** /api/local-models/jobs/{job_id} | Local Models Job
[**localModelsJobsApiLocalModelsJobsGet**](DefaultApi.md#localmodelsjobsapilocalmodelsjobsget) | **GET** /api/local-models/jobs | Local Models Jobs
[**localModelsQuickstartApiLocalModelsQuickstartPost**](DefaultApi.md#localmodelsquickstartapilocalmodelsquickstartpost) | **POST** /api/local-models/quickstart | Local Models Quickstart
[**localModelsRuntimeInstallApiLocalModelsRuntimeInstallPost**](DefaultApi.md#localmodelsruntimeinstallapilocalmodelsruntimeinstallpost) | **POST** /api/local-models/runtime/install | Local Models Runtime Install
[**localModelsSearchApiLocalModelsSearchGet**](DefaultApi.md#localmodelssearchapilocalmodelssearchget) | **GET** /api/local-models/search | Local Models Search
[**localModelsSearchFilesApiLocalModelsSearchFilesGet**](DefaultApi.md#localmodelssearchfilesapilocalmodelssearchfilesget) | **GET** /api/local-models/search/files | Local Models Search Files
[**localModelsServerApiLocalModelsServerPost**](DefaultApi.md#localmodelsserverapilocalmodelsserverpost) | **POST** /api/local-models/server | Local Models Server
[**localModelsSideloadApiLocalModelsSideloadPost**](DefaultApi.md#localmodelssideloadapilocalmodelssideloadpost) | **POST** /api/local-models/sideload | Local Models Sideload
[**localModelsStatusApiLocalModelsStatusGet**](DefaultApi.md#localmodelsstatusapilocalmodelsstatusget) | **GET** /api/local-models/status | Local Models Status
[**loginPageLoginGet**](DefaultApi.md#loginpageloginget) | **GET** /login | Login Page
[**mcpOauthCallbackApiMcpOauthCallbackServerNameGet**](DefaultApi.md#mcpoauthcallbackapimcpoauthcallbackservernameget) | **GET** /api/mcp/oauth/callback/{server_name} | Mcp Oauth Callback
[**mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet**](DefaultApi.md#mcpoauthflowstatusapimcpoauthflowsflowidget) | **GET** /api/mcp/oauth/flows/{flow_id} | Mcp Oauth Flow Status
[**memoryOauthStatusApiMemoryProvidersProviderOauthStatusGet**](DefaultApi.md#memoryoauthstatusapimemoryprovidersprovideroauthstatusget) | **GET** /api/memory/providers/{provider}/oauth/status | Memory Oauth Status
[**modelOptionsApiPluginsKanbanModelOptionsGet**](DefaultApi.md#modeloptionsapipluginskanbanmodeloptionsget) | **GET** /api/plugins/kanban/model-options | Model Options
[**openProfileTerminalEndpointApiProfilesNameOpenTerminalPost**](DefaultApi.md#openprofileterminalendpointapiprofilesnameopenterminalpost) | **POST** /api/profiles/{name}/open-terminal | Open Profile Terminal Endpoint
[**pauseCronJobApiCronJobsJobIdPausePost**](DefaultApi.md#pausecronjobapicronjobsjobidpausepost) | **POST** /api/cron/jobs/{job_id}/pause | Pause Cron Job
[**pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet**](DefaultApi.md#polloauthsessionapiprovidersoauthprovideridpollsessionidget) | **GET** /api/providers/oauth/{provider_id}/poll/{session_id} | Poll Oauth Session
[**postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost**](DefaultApi.md#postagentplugindisableapidashboardagentpluginsnamedisablepost) | **POST** /api/dashboard/agent-plugins/{name}/disable | Post Agent Plugin Disable
[**postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost**](DefaultApi.md#postagentpluginenableapidashboardagentpluginsnameenablepost) | **POST** /api/dashboard/agent-plugins/{name}/enable | Post Agent Plugin Enable
[**postAgentPluginInstallApiDashboardAgentPluginsInstallPost**](DefaultApi.md#postagentplugininstallapidashboardagentpluginsinstallpost) | **POST** /api/dashboard/agent-plugins/install | Post Agent Plugin Install
[**postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost**](DefaultApi.md#postagentpluginupdateapidashboardagentpluginsnameupdatepost) | **POST** /api/dashboard/agent-plugins/{name}/update | Post Agent Plugin Update
[**postHealthRetirementApiHealthRetirementPost**](DefaultApi.md#posthealthretirementapihealthretirementpost) | **POST** /api/health/retirement | Post Health Retirement
[**postPluginVisibilityApiDashboardPluginsNameVisibilityPost**](DefaultApi.md#postpluginvisibilityapidashboardpluginsnamevisibilitypost) | **POST** /api/dashboard/plugins/{name}/visibility | Post Plugin Visibility
[**postProfilesSessionsPullRequestsApiProfilesSessionsPullRequestsPost**](DefaultApi.md#postprofilessessionspullrequestsapiprofilessessionspullrequestspost) | **POST** /api/profiles/sessions/pull-requests | Post Profiles Sessions Pull Requests
[**previewSkillHubApiSkillsHubPreviewGet**](DefaultApi.md#previewskillhubapiskillshubpreviewget) | **GET** /api/skills/hub/preview | Preview Skill Hub
[**pruneCheckpointsApiOpsCheckpointsPrunePost**](DefaultApi.md#prunecheckpointsapiopscheckpointsprunepost) | **POST** /api/ops/checkpoints/prune | Prune Checkpoints
[**pruneSessionsEndpointApiSessionsPrunePost**](DefaultApi.md#prunesessionsendpointapisessionsprunepost) | **POST** /api/sessions/prune | Prune Sessions Endpoint
[**putPluginProvidersApiDashboardPluginProvidersPut**](DefaultApi.md#putpluginprovidersapidashboardpluginprovidersput) | **PUT** /api/dashboard/plugin-providers | Put Plugin Providers
[**readManagedFileApiFilesReadGet**](DefaultApi.md#readmanagedfileapifilesreadget) | **GET** /api/files/read | Read Managed File
[**reassignTaskEndpointApiPluginsKanbanTasksTaskIdReassignPost**](DefaultApi.md#reassigntaskendpointapipluginskanbantaskstaskidreassignpost) | **POST** /api/plugins/kanban/tasks/{task_id}/reassign | Reassign Task Endpoint
[**recentUnlocksApiPluginsHermesAchievementsRecentUnlocksGet**](DefaultApi.md#recentunlocksapipluginshermesachievementsrecentunlocksget) | **GET** /api/plugins/hermes-achievements/recent-unlocks | Recent Unlocks
[**reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost**](DefaultApi.md#reclaimtaskendpointapipluginskanbantaskstaskidreclaimpost) | **POST** /api/plugins/kanban/tasks/{task_id}/reclaim | Reclaim Task Endpoint
[**removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete**](DefaultApi.md#removeattachmentapipluginskanbanattachmentsattachmentiddelete) | **DELETE** /api/plugins/kanban/attachments/{attachment_id} | Remove Attachment
[**removeCredentialPoolEntryApiCredentialsPoolProviderIndexDelete**](DefaultApi.md#removecredentialpoolentryapicredentialspoolproviderindexdelete) | **DELETE** /api/credentials/pool/{provider}/{index} | Remove Credential Pool Entry
[**removeEnvVarApiEnvDelete**](DefaultApi.md#removeenvvarapienvdelete) | **DELETE** /api/env | Remove Env Var
[**removeMcpServerApiMcpServersNameDelete**](DefaultApi.md#removemcpserverapimcpserversnamedelete) | **DELETE** /api/mcp/servers/{name} | Remove Mcp Server
[**renameBoardApiPluginsKanbanBoardsSlugPatch**](DefaultApi.md#renameboardapipluginskanbanboardsslugpatch) | **PATCH** /api/plugins/kanban/boards/{slug} | Rename Board
[**renameProfileEndpointApiProfilesNamePatch**](DefaultApi.md#renameprofileendpointapiprofilesnamepatch) | **PATCH** /api/profiles/{name} | Rename Profile Endpoint
[**renameSessionEndpointApiSessionsSessionIdPatch**](DefaultApi.md#renamesessionendpointapisessionssessionidpatch) | **PATCH** /api/sessions/{session_id} | Rename Session Endpoint
[**replaceMcpServersApiMcpServersPut**](DefaultApi.md#replacemcpserversapimcpserversput) | **PUT** /api/mcp/servers | Replace Mcp Servers
[**rescanApiPluginsHermesAchievementsRescanPost**](DefaultApi.md#rescanapipluginshermesachievementsrescanpost) | **POST** /api/plugins/hermes-achievements/rescan | Rescan
[**rescanDashboardPluginsApiDashboardPluginsRescanGet**](DefaultApi.md#rescandashboardpluginsapidashboardpluginsrescanget) | **GET** /api/dashboard/plugins/rescan | Rescan Dashboard Plugins
[**resetMemoryApiMemoryResetPost**](DefaultApi.md#resetmemoryapimemoryresetpost) | **POST** /api/memory/reset | Reset Memory
[**resetStateApiPluginsHermesAchievementsResetStatePost**](DefaultApi.md#resetstateapipluginshermesachievementsresetstatepost) | **POST** /api/plugins/hermes-achievements/reset-state | Reset State
[**restartGatewayApiGatewayRestartPost**](DefaultApi.md#restartgatewayapigatewayrestartpost) | **POST** /api/gateway/restart | Restart Gateway
[**resumeCronJobApiCronJobsJobIdResumePost**](DefaultApi.md#resumecronjobapicronjobsjobidresumepost) | **POST** /api/cron/jobs/{job_id}/resume | Resume Cron Job
[**revealEnvVarApiEnvRevealPost**](DefaultApi.md#revealenvvarapienvrevealpost) | **POST** /api/env/reveal | Reveal Env Var
[**revokePairingApiPairingRevokePost**](DefaultApi.md#revokepairingapipairingrevokepost) | **POST** /api/pairing/revoke | Revoke Pairing
[**runBackupApiOpsBackupPost**](DefaultApi.md#runbackupapiopsbackuppost) | **POST** /api/ops/backup | Run Backup
[**runConfigMigrateApiOpsConfigMigratePost**](DefaultApi.md#runconfigmigrateapiopsconfigmigratepost) | **POST** /api/ops/config-migrate | Run Config Migrate
[**runCuratorApiCuratorRunPost**](DefaultApi.md#runcuratorapicuratorrunpost) | **POST** /api/curator/run | Run Curator
[**runDebugShareEndpointApiOpsDebugSharePost**](DefaultApi.md#rundebugshareendpointapiopsdebugsharepost) | **POST** /api/ops/debug-share | Run Debug Share Endpoint
[**runDoctorApiOpsDoctorPost**](DefaultApi.md#rundoctorapiopsdoctorpost) | **POST** /api/ops/doctor | Run Doctor
[**runDumpApiOpsDumpPost**](DefaultApi.md#rundumpapiopsdumppost) | **POST** /api/ops/dump | Run Dump
[**runImportApiOpsImportPost**](DefaultApi.md#runimportapiopsimportpost) | **POST** /api/ops/import | Run Import
[**runImportUploadApiOpsImportUploadPost**](DefaultApi.md#runimportuploadapiopsimportuploadpost) | **POST** /api/ops/import-upload | Run Import Upload
[**runPromptSizeApiOpsPromptSizePost**](DefaultApi.md#runpromptsizeapiopspromptsizepost) | **POST** /api/ops/prompt-size | Run Prompt Size
[**runSecurityAuditApiOpsSecurityAuditPost**](DefaultApi.md#runsecurityauditapiopssecurityauditpost) | **POST** /api/ops/security-audit | Run Security Audit
[**runToolsetPostSetupApiToolsToolsetsNamePostSetupPost**](DefaultApi.md#runtoolsetpostsetupapitoolstoolsetsnamepostsetuppost) | **POST** /api/tools/toolsets/{name}/post-setup | Run Toolset Post Setup
[**saveToolsetEnvApiToolsToolsetsNameEnvPut**](DefaultApi.md#savetoolsetenvapitoolstoolsetsnameenvput) | **PUT** /api/tools/toolsets/{name}/env | Save Toolset Env
[**scanSkillHubApiSkillsHubScanGet**](DefaultApi.md#scanskillhubapiskillshubscanget) | **GET** /api/skills/hub/scan | Scan Skill Hub
[**scanStatusApiPluginsHermesAchievementsScanStatusGet**](DefaultApi.md#scanstatusapipluginshermesachievementsscanstatusget) | **GET** /api/plugins/hermes-achievements/scan-status | Scan Status
[**searchSessionsApiSessionsSearchGet**](DefaultApi.md#searchsessionsapisessionssearchget) | **GET** /api/sessions/search | Search Sessions
[**searchSkillsHubApiSkillsHubSearchGet**](DefaultApi.md#searchskillshubapiskillshubsearchget) | **GET** /api/skills/hub/search | Search Skills Hub
[**selectTerminalBackendApiToolsTerminalBackendPut**](DefaultApi.md#selectterminalbackendapitoolsterminalbackendput) | **PUT** /api/tools/terminal/backend | Select Terminal Backend
[**selectToolsetModelApiToolsToolsetsNameModelPut**](DefaultApi.md#selecttoolsetmodelapitoolstoolsetsnamemodelput) | **PUT** /api/tools/toolsets/{name}/model | Select Toolset Model
[**selectToolsetProviderApiToolsToolsetsNameProviderPut**](DefaultApi.md#selecttoolsetproviderapitoolstoolsetsnameproviderput) | **PUT** /api/tools/toolsets/{name}/provider | Select Toolset Provider
[**serveCssAssetsFilenameCssGet**](DefaultApi.md#servecssassetsfilenamecssget) | **GET** /assets/{filename}.css | Serve Css
[**servePluginAssetDashboardPluginsPluginNameFilePathGet**](DefaultApi.md#servepluginassetdashboardpluginspluginnamefilepathget) | **GET** /dashboard-plugins/{plugin_name}/{file_path} | Serve Plugin Asset
[**serveSpaFullPathGet**](DefaultApi.md#servespafullpathget) | **GET** /{full_path} | Serve Spa
[**sessionBadgesApiPluginsHermesAchievementsSessionsSessionIdBadgesGet**](DefaultApi.md#sessionbadgesapipluginshermesachievementssessionssessionidbadgesget) | **GET** /api/plugins/hermes-achievements/sessions/{session_id}/badges | Session Badges
[**setActiveProfileEndpointApiProfilesActivePost**](DefaultApi.md#setactiveprofileendpointapiprofilesactivepost) | **POST** /api/profiles/active | Set Active Profile Endpoint
[**setCuratorPausedApiCuratorPausedPut**](DefaultApi.md#setcuratorpausedapicuratorpausedput) | **PUT** /api/curator/paused | Set Curator Paused
[**setDashboardFontApiDashboardFontPut**](DefaultApi.md#setdashboardfontapidashboardfontput) | **PUT** /api/dashboard/font | Set Dashboard Font
[**setDashboardThemeApiDashboardThemePut**](DefaultApi.md#setdashboardthemeapidashboardthemeput) | **PUT** /api/dashboard/theme | Set Dashboard Theme
[**setEnvVarApiEnvPut**](DefaultApi.md#setenvvarapienvput) | **PUT** /api/env | Set Env Var
[**setMcpServerEnabledApiMcpServersNameEnabledPut**](DefaultApi.md#setmcpserverenabledapimcpserversnameenabledput) | **PUT** /api/mcp/servers/{name}/enabled | Set Mcp Server Enabled
[**setMemoryProviderApiMemoryProviderPut**](DefaultApi.md#setmemoryproviderapimemoryproviderput) | **PUT** /api/memory/provider | Set Memory Provider
[**setMoaModelsApiModelMoaPut**](DefaultApi.md#setmoamodelsapimodelmoaput) | **PUT** /api/model/moa | Set Moa Models
[**setModelAssignmentApiModelSetPost**](DefaultApi.md#setmodelassignmentapimodelsetpost) | **POST** /api/model/set | Set Model Assignment
[**setOrchestrationSettingsApiPluginsKanbanOrchestrationPut**](DefaultApi.md#setorchestrationsettingsapipluginskanbanorchestrationput) | **PUT** /api/plugins/kanban/orchestration | Set Orchestration Settings
[**setWebhookEnabledApiWebhooksNameEnabledPut**](DefaultApi.md#setwebhookenabledapiwebhooksnameenabledput) | **PUT** /api/webhooks/{name}/enabled | Set Webhook Enabled
[**setupMemoryProviderApiMemoryProvidersNameSetupPost**](DefaultApi.md#setupmemoryproviderapimemoryprovidersnamesetuppost) | **POST** /api/memory/providers/{name}/setup | Setup Memory Provider
[**speakTextApiAudioSpeakPost**](DefaultApi.md#speaktextapiaudiospeakpost) | **POST** /api/audio/speak | Speak Text
[**specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost**](DefaultApi.md#specifytaskendpointapipluginskanbantaskstaskidspecifypost) | **POST** /api/plugins/kanban/tasks/{task_id}/specify | Specify Task Endpoint
[**startGatewayApiGatewayStartPost**](DefaultApi.md#startgatewayapigatewaystartpost) | **POST** /api/gateway/start | Start Gateway
[**startMemoryOauthApiMemoryProvidersProviderOauthStartPost**](DefaultApi.md#startmemoryoauthapimemoryprovidersprovideroauthstartpost) | **POST** /api/memory/providers/{provider}/oauth/start | Start Memory Oauth
[**startOauthLoginApiProvidersOauthProviderIdStartPost**](DefaultApi.md#startoauthloginapiprovidersoauthprovideridstartpost) | **POST** /api/providers/oauth/{provider_id}/start | Start Oauth Login
[**startTelegramOnboardingApiMessagingTelegramOnboardingStartPost**](DefaultApi.md#starttelegramonboardingapimessagingtelegramonboardingstartpost) | **POST** /api/messaging/telegram/onboarding/start | Start Telegram Onboarding
[**startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost**](DefaultApi.md#startwhatsapponboardingapimessagingwhatsapponboardingstartpost) | **POST** /api/messaging/whatsapp/onboarding/start | Start Whatsapp Onboarding
[**stopGatewayApiGatewayStopPost**](DefaultApi.md#stopgatewayapigatewaystoppost) | **POST** /api/gateway/stop | Stop Gateway
[**streamManagedFileApiFilesStreamGet**](DefaultApi.md#streammanagedfileapifilesstreamget) | **GET** /api/files/stream | Stream Managed File
[**streamManagedFileApiFilesStreamHead**](DefaultApi.md#streammanagedfileapifilesstreamhead) | **HEAD** /api/files/stream | Stream Managed File
[**submitOauthCodeApiProvidersOauthProviderIdSubmitPost**](DefaultApi.md#submitoauthcodeapiprovidersoauthprovideridsubmitpost) | **POST** /api/providers/oauth/{provider_id}/submit | Submit Oauth Code
[**subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost**](DefaultApi.md#subscribehomeapipluginskanbantaskstaskidhomesubscribeplatformpost) | **POST** /api/plugins/kanban/tasks/{task_id}/home-subscribe/{platform} | Subscribe Home
[**switchBoardApiPluginsKanbanBoardsSlugSwitchPost**](DefaultApi.md#switchboardapipluginskanbanboardsslugswitchpost) | **POST** /api/plugins/kanban/boards/{slug}/switch | Switch Board
[**terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost**](DefaultApi.md#terminaterunendpointapipluginskanbanrunsrunidterminatepost) | **POST** /api/plugins/kanban/runs/{run_id}/terminate | Terminate Run Endpoint
[**testMcpServerApiMcpServersNameTestPost**](DefaultApi.md#testmcpserverapimcpserversnametestpost) | **POST** /api/mcp/servers/{name}/test | Test Mcp Server
[**testMessagingPlatformApiMessagingPlatformsPlatformIdTestPost**](DefaultApi.md#testmessagingplatformapimessagingplatformsplatformidtestpost) | **POST** /api/messaging/platforms/{platform_id}/test | Test Messaging Platform
[**toggleSkillApiSkillsTogglePut**](DefaultApi.md#toggleskillapiskillstoggleput) | **PUT** /api/skills/toggle | Toggle Skill
[**toggleToolsetApiToolsToolsetsNamePut**](DefaultApi.md#toggletoolsetapitoolstoolsetsnameput) | **PUT** /api/tools/toolsets/{name} | Toggle Toolset
[**transcribeAudioUploadApiAudioTranscribePost**](DefaultApi.md#transcribeaudiouploadapiaudiotranscribepost) | **POST** /api/audio/transcribe | Transcribe Audio Upload
[**triggerCronJobApiCronJobsJobIdTriggerPost**](DefaultApi.md#triggercronjobapicronjobsjobidtriggerpost) | **POST** /api/cron/jobs/{job_id}/trigger | Trigger Cron Job
[**ttsLeaseApiAudioTtsLeasePost**](DefaultApi.md#ttsleaseapiaudiottsleasepost) | **POST** /api/audio/tts-lease | Tts Lease
[**uninstallSkillHubApiSkillsHubUninstallPost**](DefaultApi.md#uninstallskillhubapiskillshubuninstallpost) | **POST** /api/skills/hub/uninstall | Uninstall Skill Hub
[**unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete**](DefaultApi.md#unsubscribehomeapipluginskanbantaskstaskidhomesubscribeplatformdelete) | **DELETE** /api/plugins/kanban/tasks/{task_id}/home-subscribe/{platform} | Unsubscribe Home
[**updateConfigApiConfigPut**](DefaultApi.md#updateconfigapiconfigput) | **PUT** /api/config | Update Config
[**updateConfigRawApiConfigRawPut**](DefaultApi.md#updateconfigrawapiconfigrawput) | **PUT** /api/config/raw | Update Config Raw
[**updateCronJobApiCronJobsJobIdPut**](DefaultApi.md#updatecronjobapicronjobsjobidput) | **PUT** /api/cron/jobs/{job_id} | Update Cron Job
[**updateHermesApiHermesUpdatePost**](DefaultApi.md#updatehermesapihermesupdatepost) | **POST** /api/hermes/update | Update Hermes
[**updateLearningNodeApiLearningNodePut**](DefaultApi.md#updatelearningnodeapilearningnodeput) | **PUT** /api/learning/node | Update Learning Node
[**updateMemoryProviderConfigApiMemoryProvidersNameConfigPut**](DefaultApi.md#updatememoryproviderconfigapimemoryprovidersnameconfigput) | **PUT** /api/memory/providers/{name}/config | Update Memory Provider Config
[**updateMessagingPlatformApiMessagingPlatformsPlatformIdPut**](DefaultApi.md#updatemessagingplatformapimessagingplatformsplatformidput) | **PUT** /api/messaging/platforms/{platform_id} | Update Messaging Platform
[**updateProfileDescriptionApiPluginsKanbanProfilesProfileNamePatch**](DefaultApi.md#updateprofiledescriptionapipluginskanbanprofilesprofilenamepatch) | **PATCH** /api/plugins/kanban/profiles/{profile_name} | Update Profile Description
[**updateProfileDescriptionEndpointApiProfilesNameDescriptionPut**](DefaultApi.md#updateprofiledescriptionendpointapiprofilesnamedescriptionput) | **PUT** /api/profiles/{name}/description | Update Profile Description Endpoint
[**updateProfileModelEndpointApiProfilesNameModelPut**](DefaultApi.md#updateprofilemodelendpointapiprofilesnamemodelput) | **PUT** /api/profiles/{name}/model | Update Profile Model Endpoint
[**updateProfileSoulApiProfilesNameSoulPut**](DefaultApi.md#updateprofilesoulapiprofilesnamesoulput) | **PUT** /api/profiles/{name}/soul | Update Profile Soul
[**updateSkillContentApiSkillsContentPut**](DefaultApi.md#updateskillcontentapiskillscontentput) | **PUT** /api/skills/content | Update Skill Content
[**updateSkillsHubApiSkillsHubUpdatePost**](DefaultApi.md#updateskillshubapiskillshubupdatepost) | **POST** /api/skills/hub/update | Update Skills Hub
[**updateTaskApiPluginsKanbanTasksTaskIdPatch**](DefaultApi.md#updatetaskapipluginskanbantaskstaskidpatch) | **PATCH** /api/plugins/kanban/tasks/{task_id} | Update Task
[**uploadChatImageApiChatImageUploadPost**](DefaultApi.md#uploadchatimageapichatimageuploadpost) | **POST** /api/chat/image-upload | Upload Chat Image
[**uploadManagedFileApiFilesUploadPost**](DefaultApi.md#uploadmanagedfileapifilesuploadpost) | **POST** /api/files/upload | Upload Managed File
[**uploadManagedFileStreamApiFilesUploadStreamPost**](DefaultApi.md#uploadmanagedfilestreamapifilesuploadstreampost) | **POST** /api/files/upload-stream | Upload Managed File Stream
[**uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost**](DefaultApi.md#uploadtaskattachmentapipluginskanbantaskstaskidattachmentspost) | **POST** /api/plugins/kanban/tasks/{task_id}/attachments | Upload Task Attachment
[**upsertCustomEndpointApiProvidersCustomEndpointsPost**](DefaultApi.md#upsertcustomendpointapiproviderscustomendpointspost) | **POST** /api/providers/custom-endpoints | Upsert Custom Endpoint
[**validateCustomEndpointApiProvidersCustomEndpointsValidatePost**](DefaultApi.md#validatecustomendpointapiproviderscustomendpointsvalidatepost) | **POST** /api/providers/custom-endpoints/validate | Validate Custom Endpoint
[**validateProviderCredentialApiProvidersValidatePost**](DefaultApi.md#validateprovidercredentialapiprovidersvalidatepost) | **POST** /api/providers/validate | Validate Provider Credential


# **achievementsApiPluginsHermesAchievementsAchievementsGet**
> Object achievementsApiPluginsHermesAchievementsAchievementsGet()

Achievements

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.achievementsApiPluginsHermesAchievementsAchievementsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->achievementsApiPluginsHermesAchievementsAchievementsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost**
> Object activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost(endpointId, profile)

Activate Custom Endpoint

Set a configured custom endpoint as the default model provider.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String endpointId = endpointId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost(endpointId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **endpointId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **addCommentApiPluginsKanbanTasksTaskIdCommentsPost**
> Object addCommentApiPluginsKanbanTasksTaskIdCommentsPost(taskId, commentBody, board)

Add Comment

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final CommentBody commentBody = ; // CommentBody | 
final String board = board_example; // String | 

try {
    final response = api.addCommentApiPluginsKanbanTasksTaskIdCommentsPost(taskId, commentBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->addCommentApiPluginsKanbanTasksTaskIdCommentsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **commentBody** | [**CommentBody**](CommentBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **addCredentialPoolEntryApiCredentialsPoolPost**
> Object addCredentialPoolEntryApiCredentialsPoolPost(credentialPoolAdd)

Add Credential Pool Entry

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final CredentialPoolAdd credentialPoolAdd = ; // CredentialPoolAdd | 

try {
    final response = api.addCredentialPoolEntryApiCredentialsPoolPost(credentialPoolAdd);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->addCredentialPoolEntryApiCredentialsPoolPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **credentialPoolAdd** | [**CredentialPoolAdd**](CredentialPoolAdd.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **addLinkApiPluginsKanbanLinksPost**
> Object addLinkApiPluginsKanbanLinksPost(linkBody, board)

Add Link

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final LinkBody linkBody = ; // LinkBody | 
final String board = board_example; // String | 

try {
    final response = api.addLinkApiPluginsKanbanLinksPost(linkBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->addLinkApiPluginsKanbanLinksPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **linkBody** | [**LinkBody**](LinkBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **addMcpServerApiMcpServersPost**
> Object addMcpServerApiMcpServersPost(mCPServerCreate, profile)

Add Mcp Server

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MCPServerCreate mCPServerCreate = ; // MCPServerCreate | 
final String profile = profile_example; // String | 

try {
    final response = api.addMcpServerApiMcpServersPost(mCPServerCreate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->addMcpServerApiMcpServersPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **mCPServerCreate** | [**MCPServerCreate**](MCPServerCreate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost**
> Object applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost(pairingId, telegramOnboardingApply, profile)

Apply Telegram Onboarding

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String pairingId = pairingId_example; // String | 
final TelegramOnboardingApply telegramOnboardingApply = ; // TelegramOnboardingApply | 
final String profile = profile_example; // String | 

try {
    final response = api.applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost(pairingId, telegramOnboardingApply, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingId** | **String**|  | 
 **telegramOnboardingApply** | [**TelegramOnboardingApply**](TelegramOnboardingApply.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost**
> Object applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost(pairingId, whatsAppOnboardingApply, profile)

Apply Whatsapp Onboarding

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String pairingId = pairingId_example; // String | 
final WhatsAppOnboardingApply whatsAppOnboardingApply = ; // WhatsAppOnboardingApply | 
final String profile = profile_example; // String | 

try {
    final response = api.applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost(pairingId, whatsAppOnboardingApply, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingId** | **String**|  | 
 **whatsAppOnboardingApply** | [**WhatsAppOnboardingApply**](WhatsAppOnboardingApply.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **approvePairingApiPairingApprovePost**
> Object approvePairingApiPairingApprovePost(pairingApprove)

Approve Pairing

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final PairingApprove pairingApprove = ; // PairingApprove | 

try {
    final response = api.approvePairingApiPairingApprovePost(pairingApprove);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->approvePairingApiPairingApprovePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingApprove** | [**PairingApprove**](PairingApprove.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authCallbackAuthCallbackGet**
> Object authCallbackAuthCallbackGet(code, state, error, errorDescription)

Auth Callback

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String code = code_example; // String | 
final String state = state_example; // String | 
final String error = error_example; // String | 
final String errorDescription = errorDescription_example; // String | 

try {
    final response = api.authCallbackAuthCallbackGet(code, state, error, errorDescription);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authCallbackAuthCallbackGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **code** | **String**|  | [optional] [default to '']
 **state** | **String**|  | [optional] [default to '']
 **error** | **String**|  | [optional] [default to '']
 **errorDescription** | **String**|  | [optional] [default to '']

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authLoginAuthLoginGet**
> Object authLoginAuthLoginGet(provider, next)

Auth Login

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String provider = provider_example; // String | 
final String next = next_example; // String | 

try {
    final response = api.authLoginAuthLoginGet(provider, next);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authLoginAuthLoginGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | 
 **next** | **String**|  | [optional] [default to '']

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authLogoutAuthLogoutPost**
> Object authLogoutAuthLogoutPost()

Auth Logout

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.authLogoutAuthLogoutPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authLogoutAuthLogoutPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authMcpServerApiMcpServersNameAuthPost**
> Object authMcpServerApiMcpServersNameAuthPost(name, profile)

Auth Mcp Server

Start MCP OAuth and hand the authorization URL to the dashboard browser.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.authMcpServerApiMcpServersNameAuthPost(name, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authMcpServerApiMcpServersNameAuthPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authMeApiAuthMeGet**
> Object authMeApiAuthMeGet()

Auth Me

Return the verified session as JSON. Auth-required (gate enforces).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.authMeApiAuthMeGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authMeApiAuthMeGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authNativeAuthorizeAuthNativeAuthorizeGet**
> Object authNativeAuthorizeAuthNativeAuthorizeGet(provider, codeChallenge, codeChallengeMethod, redirectUri, state)

Auth Native Authorize

Begin an RFC 8252 native-app login: stash a pending broker authorization keyed by an opaque ``broker_state`` riding in the gateway's own PKCE cookie (the desktop's challenge/state never touch it), then run the normal upstream round trip. Password providers go to the ``/login`` form instead.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String provider = provider_example; // String | 
final String codeChallenge = codeChallenge_example; // String | 
final String codeChallengeMethod = codeChallengeMethod_example; // String | 
final String redirectUri = redirectUri_example; // String | 
final String state = state_example; // String | 

try {
    final response = api.authNativeAuthorizeAuthNativeAuthorizeGet(provider, codeChallenge, codeChallengeMethod, redirectUri, state);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authNativeAuthorizeAuthNativeAuthorizeGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | [optional] [default to '']
 **codeChallenge** | **String**|  | [optional] [default to '']
 **codeChallengeMethod** | **String**|  | [optional] [default to '']
 **redirectUri** | **String**|  | [optional] [default to '']
 **state** | **String**|  | [optional] [default to '']

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authNativeRefreshAuthNativeRefreshPost**
> Object authNativeRefreshAuthNativeRefreshPost(nativeRefreshBody)

Auth Native Refresh

Rotate a desktop-held refresh token (mirrors the gate's ``_attempt_refresh``): every provider rejecting the RT -> 401 ``session_expired`` (desktop re-logs); none rotated and one unreachable -> 503.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final NativeRefreshBody nativeRefreshBody = ; // NativeRefreshBody | 

try {
    final response = api.authNativeRefreshAuthNativeRefreshPost(nativeRefreshBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authNativeRefreshAuthNativeRefreshPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **nativeRefreshBody** | [**NativeRefreshBody**](NativeRefreshBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authNativeTokenAuthNativeTokenPost**
> Object authNativeTokenAuthNativeTokenPost(nativeTokenBody)

Auth Native Token

Exchange a loopback gateway code + PKCE verifier for bearer tokens. The code is consumed on every path (no verifier oracle, no replay); any failure is a generic 400. Tokens go in the JSON body; no cookie is set.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final NativeTokenBody nativeTokenBody = ; // NativeTokenBody | 

try {
    final response = api.authNativeTokenAuthNativeTokenPost(nativeTokenBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authNativeTokenAuthNativeTokenPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **nativeTokenBody** | [**NativeTokenBody**](NativeTokenBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authPasswordLoginAuthPasswordLoginPost**
> Object authPasswordLoginAuthPasswordLoginPost(passwordLoginBody)

Auth Password Login

Authenticate a username/password against a password provider.  Returns ``{\"ok\": true, \"next\": <path>}`` (the form POSTs via fetch, which follows a 302 opaquely) and sets the session cookies; with a native ``broker`` handle in the PKCE cookie, ``next`` is the desktop's loopback redirect and NO cookies are set. Failures are deliberately generic (no username/provider oracle): unknown/non-password provider 404, bad credentials 401, store unreachable 503, rate limited 429.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final PasswordLoginBody passwordLoginBody = ; // PasswordLoginBody | 

try {
    final response = api.authPasswordLoginAuthPasswordLoginPost(passwordLoginBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authPasswordLoginAuthPasswordLoginPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **passwordLoginBody** | [**PasswordLoginBody**](PasswordLoginBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authProvidersApiAuthProvidersGet**
> Object authProvidersApiAuthProvidersGet()

Auth Providers

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.authProvidersApiAuthProvidersGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authProvidersApiAuthProvidersGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authWsTicketApiAuthWsTicketPost**
> Object authWsTicketApiAuthWsTicketPost()

Auth Ws Ticket

Mint a 30s single-use ticket for a WS upgrade (browsers cannot set ``Authorization`` on the upgrade); one ticket per WS.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.authWsTicketApiAuthWsTicketPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->authWsTicketApiAuthWsTicketPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **autoDescribeProfileApiPluginsKanbanProfilesProfileNameDescribeAutoPost**
> Object autoDescribeProfileApiPluginsKanbanProfilesProfileNameDescribeAutoPost(profileName, describeAutoBody)

Auto Describe Profile

``hermes profile describe <name> --auto``: persist with ``description_auto: true``. Non-OK outcomes are NOT HTTP errors — the UI renders the reason inline.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profileName = profileName_example; // String | 
final DescribeAutoBody describeAutoBody = ; // DescribeAutoBody | 

try {
    final response = api.autoDescribeProfileApiPluginsKanbanProfilesProfileNameDescribeAutoPost(profileName, describeAutoBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->autoDescribeProfileApiPluginsKanbanProfilesProfileNameDescribeAutoPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profileName** | **String**|  | 
 **describeAutoBody** | [**DescribeAutoBody**](DescribeAutoBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **backfillSessionOwnerProfilesApiSessionsOwnerBackfillPost**
> Object backfillSessionOwnerProfilesApiSessionsOwnerBackfillPost(sessionOwnerBackfill)

Backfill Session Owner Profiles

Stamp legacy ``profile_name = NULL`` rows with the serving-profile identity.  A multi-connection Desktop fails closed on unowned rows.  Each ``state.db`` belongs to exactly one profile, so this is a single-match, idempotent backfill (non-NULL owners are never overwritten).  That was fine while one backend served everything, but a Desktop with registry topology (≥2 registered connections) fails closed on unowned rows by design — leaving every pre-campaign session unresumable with no migration path. Each profile's ``state.db`` belongs to exactly one profile, so stamping that store's own name is a single-match backfill, never a guess; the value written is the SAME serving-profile identity the list endpoints already stamp onto outgoing rows (``row_profile`` in ``get_sessions``). See #95407.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SessionOwnerBackfill sessionOwnerBackfill = ; // SessionOwnerBackfill | 

try {
    final response = api.backfillSessionOwnerProfilesApiSessionsOwnerBackfillPost(sessionOwnerBackfill);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->backfillSessionOwnerProfilesApiSessionsOwnerBackfillPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionOwnerBackfill** | [**SessionOwnerBackfill**](SessionOwnerBackfill.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **bulkDeleteSessionsEndpointApiSessionsBulkDeletePost**
> Object bulkDeleteSessionsEndpointApiSessionsBulkDeletePost(bulkDeleteSessions)

Bulk Delete Sessions Endpoint

Delete every session in ``body.ids`` in one transaction (POST: many clients refuse a DELETE body).  Per :meth:`SessionDB.delete_sessions`: unknown ids are skipped (``deleted`` reports what really happened), children are orphaned, active/archived rows ARE deleted (hand-picked), on-disk cleanup is left to the next prune.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final BulkDeleteSessions bulkDeleteSessions = ; // BulkDeleteSessions | 

try {
    final response = api.bulkDeleteSessionsEndpointApiSessionsBulkDeletePost(bulkDeleteSessions);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->bulkDeleteSessionsEndpointApiSessionsBulkDeletePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **bulkDeleteSessions** | [**BulkDeleteSessions**](BulkDeleteSessions.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **bulkUpdateApiPluginsKanbanTasksBulkPost**
> Object bulkUpdateApiPluginsKanbanTasksBulkPost(bulkTaskBody, board)

Bulk Update

Apply the same patch to every id. Independent iteration — per-task failures don't abort siblings; returns per-id outcome for partials.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final BulkTaskBody bulkTaskBody = ; // BulkTaskBody | 
final String board = board_example; // String | 

try {
    final response = api.bulkUpdateApiPluginsKanbanTasksBulkPost(bulkTaskBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->bulkUpdateApiPluginsKanbanTasksBulkPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **bulkTaskBody** | [**BulkTaskBody**](BulkTaskBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete**
> Object cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete(flowId)

Cancel Mcp Oauth Flow

Cancel an in-flight flow. mark_error unblocks the worker so it frees the per-server \"already in progress\" slot — otherwise a renderer that stops polling leaves the flow squatting until the 300s callback timeout and every retry 409s. Idempotent: a settled flow is left as-is.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String flowId = flowId_example; // String | 

try {
    final response = api.cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete(flowId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **flowId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete**
> Object cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete(sessionId, profile)

Cancel Oauth Session

Cancel a pending OAuth session. Token-protected.  Marks the session dict ``cancelled`` before popping it so a background worker still holding that dict (e.g. the Codex poller) stops polling/exchanging/saving instead of completing the login after the user believed it was aborted.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete(sessionId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete**
> Object cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete(pairingId)

Cancel Telegram Onboarding

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String pairingId = pairingId_example; // String | 

try {
    final response = api.cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete(pairingId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete**
> Object cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete(pairingId)

Cancel Whatsapp Onboarding

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String pairingId = pairingId_example; // String | 

try {
    final response = api.cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete(pairingId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **checkHermesUpdateApiHermesUpdateCheckGet**
> Object checkHermesUpdateApiHermesUpdateCheckGet(force)

Check Hermes Update

Report whether a Hermes update is available, without applying it.  Returns install_method ('apt'|'git'|'docker'|'nix'|'nixos'|'unknown'), current_version, behind (commits behind, 0 = up to date, -1 = unknown count, null = check could not run), update_available, can_apply (git only — the dashboard button can apply in place), update_command, message (guidance for non-applyable methods) and, for git installs that are behind, commits [{sha, summary, author, at}] (additive; existing consumers ignore it).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final bool force = true; // bool | 

try {
    final response = api.checkHermesUpdateApiHermesUpdateCheckGet(force);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->checkHermesUpdateApiHermesUpdateCheckGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **force** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **clearPendingPairingApiPairingClearPendingPost**
> Object clearPendingPairingApiPairingClearPendingPost(profile)

Clear Pending Pairing

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.clearPendingPairingApiPairingClearPendingPost(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->clearPendingPairingApiPairingClearPendingPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **countEmptySessionsEndpointApiSessionsEmptyCountGet**
> Object countEmptySessionsEndpointApiSessionsEmptyCountGet(profile)

Count Empty Sessions Endpoint

Count of empty, ended, non-archived sessions (the \"Delete empty (N)\" button).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.countEmptySessionsEndpointApiSessionsEmptyCountGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->countEmptySessionsEndpointApiSessionsEmptyCountGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createBoardEndpointApiPluginsKanbanBoardsPost**
> Object createBoardEndpointApiPluginsKanbanBoardsPost(createBoardBody)

Create Board Endpoint

Create a board. Idempotent — ``slug`` collision returns the existing one.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final CreateBoardBody createBoardBody = ; // CreateBoardBody | 

try {
    final response = api.createBoardEndpointApiPluginsKanbanBoardsPost(createBoardBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createBoardEndpointApiPluginsKanbanBoardsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createBoardBody** | [**CreateBoardBody**](CreateBoardBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createCronJobApiCronJobsPost**
> Object createCronJobApiCronJobsPost(cronJobCreate, profile)

Create Cron Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final CronJobCreate cronJobCreate = ; // CronJobCreate | 
final String profile = profile_example; // String | 

try {
    final response = api.createCronJobApiCronJobsPost(cronJobCreate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createCronJobApiCronJobsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cronJobCreate** | [**CronJobCreate**](CronJobCreate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createHookApiOpsHooksPost**
> Object createHookApiOpsHooksPost(hookCreate)

Create Hook

Add a shell hook to config.yaml and optionally record consent.  Shell hooks run arbitrary commands, so this is privileged: it writes the ``hooks:`` block and, with ``approve``, records the allowlist entry so the hook actually fires. Takes effect on the next session / gateway restart.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final HookCreate hookCreate = ; // HookCreate | 

try {
    final response = api.createHookApiOpsHooksPost(hookCreate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createHookApiOpsHooksPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **hookCreate** | [**HookCreate**](HookCreate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createManagedDirectoryApiFilesMkdirPost**
> Object createManagedDirectoryApiFilesMkdirPost(managedDirectoryCreate)

Create Managed Directory

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ManagedDirectoryCreate managedDirectoryCreate = ; // ManagedDirectoryCreate | 

try {
    final response = api.createManagedDirectoryApiFilesMkdirPost(managedDirectoryCreate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createManagedDirectoryApiFilesMkdirPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **managedDirectoryCreate** | [**ManagedDirectoryCreate**](ManagedDirectoryCreate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createProfileEndpointApiProfilesPost**
> Object createProfileEndpointApiProfilesPost(profileCreate)

Create Profile Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ProfileCreate profileCreate = ; // ProfileCreate | 

try {
    final response = api.createProfileEndpointApiProfilesPost(profileCreate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createProfileEndpointApiProfilesPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profileCreate** | [**ProfileCreate**](ProfileCreate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createSkillApiSkillsPost**
> Object createSkillApiSkillsPost(skillCreate)

Create Skill

Create a skill via the agent's ``skill_manage`` write path, minus the write-approval gate — an authenticated dashboard write IS the user.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SkillCreate skillCreate = ; // SkillCreate | 

try {
    final response = api.createSkillApiSkillsPost(skillCreate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createSkillApiSkillsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **skillCreate** | [**SkillCreate**](SkillCreate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createTaskApiPluginsKanbanTasksPost**
> Object createTaskApiPluginsKanbanTasksPost(createTaskBody, board)

Create Task

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final CreateTaskBody createTaskBody = ; // CreateTaskBody | 
final String board = board_example; // String | 

try {
    final response = api.createTaskApiPluginsKanbanTasksPost(createTaskBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createTaskApiPluginsKanbanTasksPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createTaskBody** | [**CreateTaskBody**](CreateTaskBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createVoiceLiveSessionApiAudioVoiceLiveSessionPost**
> Object createVoiceLiveSessionApiAudioVoiceLiveSessionPost(voiceLiveSessionRequest, profile)

Create Voice Live Session

Exchange the renderer's WebRTC SDP offer for a GPT-Live session answer.  The project API key stays on this host; the renderer only receives the session id and the SDP answer. Client delegation is fixed at creation: every ``session.delegation.created`` the renderer receives becomes a Hermes turn on the session it belongs to.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final VoiceLiveSessionRequest voiceLiveSessionRequest = ; // VoiceLiveSessionRequest | 
final String profile = profile_example; // String | 

try {
    final response = api.createVoiceLiveSessionApiAudioVoiceLiveSessionPost(voiceLiveSessionRequest, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createVoiceLiveSessionApiAudioVoiceLiveSessionPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **voiceLiveSessionRequest** | [**VoiceLiveSessionRequest**](VoiceLiveSessionRequest.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createWebhookApiWebhooksPost**
> Object createWebhookApiWebhooksPost(webhookCreate)

Create Webhook

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final WebhookCreate webhookCreate = ; // WebhookCreate | 

try {
    final response = api.createWebhookApiWebhooksPost(webhookCreate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->createWebhookApiWebhooksPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **webhookCreate** | [**WebhookCreate**](WebhookCreate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cronFireWebhookApiCronFirePost**
> Object cronFireWebhookApiCronFirePost()

Cron Fire Webhook

Chronos managed-cron fire webhook (NAS -> agent) — gateway forwarder.  Gated by the NAS-minted JWT (path is in ``PUBLIC_API_PATHS``), not the dashboard cookie. Execution belongs to the GATEWAY process (it owns the live platform adapters relay-fronted and E2EE targets need), so the fire is forwarded to the gateway api_server's own ``/api/cron/fire`` on loopback and its response passed through (the gateway re-verifies the JWT). Gateway unreachable -> 503 so NAS retries; deliberately NO local-execution fallback.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.cronFireWebhookApiCronFirePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->cronFireWebhookApiCronFirePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost**
> Object decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost(taskId, decomposeBody, board)

Decompose Task Endpoint

Fan a triage task out into child tasks via the auxiliary LLM (``hermes kanban decompose``). Non-OK is NOT an HTTP error. Sync ``def`` → runs in the threadpool.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final DecomposeBody decomposeBody = ; // DecomposeBody | 
final String board = board_example; // String | 

try {
    final response = api.decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost(taskId, decomposeBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **decomposeBody** | [**DecomposeBody**](DecomposeBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteAgentPluginApiDashboardAgentPluginsNameDelete**
> Object deleteAgentPluginApiDashboardAgentPluginsNameDelete(name)

Delete Agent Plugin

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.deleteAgentPluginApiDashboardAgentPluginsNameDelete(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteAgentPluginApiDashboardAgentPluginsNameDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteBoardApiPluginsKanbanBoardsSlugDelete**
> Object deleteBoardApiPluginsKanbanBoardsSlugDelete(slug, delete)

Delete Board

Archive (default) or hard-delete a board.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String slug = slug_example; // String | 
final bool delete = true; // bool | Hard-delete instead of archive

try {
    final response = api.deleteBoardApiPluginsKanbanBoardsSlugDelete(slug, delete);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteBoardApiPluginsKanbanBoardsSlugDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **delete** | **bool**| Hard-delete instead of archive | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteCronJobApiCronJobsJobIdDelete**
> Object deleteCronJobApiCronJobsJobIdDelete(jobId, profile)

Delete Cron Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.deleteCronJobApiCronJobsJobIdDelete(jobId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteCronJobApiCronJobsJobIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete**
> Object deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete(endpointId, profile)

Delete Custom Endpoint

Remove a configured custom endpoint from ``providers``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String endpointId = endpointId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete(endpointId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **endpointId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteEmptySessionsEndpointApiSessionsEmptyDelete**
> Object deleteEmptySessionsEndpointApiSessionsEmptyDelete(profile)

Delete Empty Sessions Endpoint

Delete every empty, ended, non-archived session in one transaction.  \"Empty\" means NO ``messages`` rows at all — a rewound/compacted chat reads ``message_count == 0`` while its soft-archived rows are the only transcript copy (see :meth:`SessionDB.delete_empty_sessions`).  * Active sessions are skipped (``ended_at IS NULL``) so a live agent isn't yanked mid-handshake. * Archived sessions are skipped — the user explicitly chose to keep those rows. * Children of deleted parents are orphaned, not cascade-deleted. See #95868.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.deleteEmptySessionsEndpointApiSessionsEmptyDelete(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteEmptySessionsEndpointApiSessionsEmptyDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteHookApiOpsHooksDelete**
> Object deleteHookApiOpsHooksDelete(hookDelete)

Delete Hook

Remove a hook from config.yaml and revoke its consent allowlist entry.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final HookDelete hookDelete = ; // HookDelete | 

try {
    final response = api.deleteHookApiOpsHooksDelete(hookDelete);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteHookApiOpsHooksDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **hookDelete** | [**HookDelete**](HookDelete.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteLearningNodeApiLearningNodeDelete**
> Object deleteLearningNodeApiLearningNodeDelete(learningNodeRef)

Delete Learning Node

Delete a journey node — skills are archived (restorable), memories removed.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final LearningNodeRef learningNodeRef = ; // LearningNodeRef | 

try {
    final response = api.deleteLearningNodeApiLearningNodeDelete(learningNodeRef);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteLearningNodeApiLearningNodeDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **learningNodeRef** | [**LearningNodeRef**](LearningNodeRef.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteLinkApiPluginsKanbanLinksDelete**
> Object deleteLinkApiPluginsKanbanLinksDelete(parentId, childId, board)

Delete Link

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String parentId = parentId_example; // String | 
final String childId = childId_example; // String | 
final String board = board_example; // String | 

try {
    final response = api.deleteLinkApiPluginsKanbanLinksDelete(parentId, childId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteLinkApiPluginsKanbanLinksDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **parentId** | **String**|  | 
 **childId** | **String**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteManagedFileApiFilesDelete**
> Object deleteManagedFileApiFilesDelete(managedFileDelete)

Delete Managed File

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ManagedFileDelete managedFileDelete = ; // ManagedFileDelete | 

try {
    final response = api.deleteManagedFileApiFilesDelete(managedFileDelete);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteManagedFileApiFilesDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **managedFileDelete** | [**ManagedFileDelete**](ManagedFileDelete.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteProfileEndpointApiProfilesNameDelete**
> Object deleteProfileEndpointApiProfilesNameDelete(name)

Delete Profile Endpoint

The dashboard collects the user's confirmation in its own dialog, so ``yes=True`` always skips the CLI's interactive prompt.  A delete whose identity settlement stays pending answers ``ok`` with ``settlement_pending`` and the retry command: the profile directory is already gone, and folding that state into the generic 500 made a dashboard client read a completed delete as a failure (its retry then 404'd).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.deleteProfileEndpointApiProfilesNameDelete(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteProfileEndpointApiProfilesNameDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteSessionEndpointApiSessionsSessionIdDelete**
> Object deleteSessionEndpointApiSessionsSessionIdDelete(sessionId, profile)

Delete Session Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.deleteSessionEndpointApiSessionsSessionIdDelete(sessionId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteSessionEndpointApiSessionsSessionIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteTaskApiPluginsKanbanTasksTaskIdDelete**
> Object deleteTaskApiPluginsKanbanTasksTaskIdDelete(taskId, board)

Delete Task

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String board = board_example; // String | 

try {
    final response = api.deleteTaskApiPluginsKanbanTasksTaskIdDelete(taskId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteTaskApiPluginsKanbanTasksTaskIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteWebhookApiWebhooksNameDelete**
> Object deleteWebhookApiWebhooksNameDelete(name)

Delete Webhook

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.deleteWebhookApiWebhooksNameDelete(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->deleteWebhookApiWebhooksNameDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **describeProfileAutoEndpointApiProfilesNameDescribeAutoPost**
> Object describeProfileAutoEndpointApiProfilesNameDescribeAutoPost(name, profileDescribeAuto)

Describe Profile Auto Endpoint

Auto-generate a profile's description via the auxiliary LLM (mirrors ``hermes profile describe <name> --auto``). A failed generation is ``ok: false`` with a reason rather than an HTTP error so the UI can surface it inline and let the operator retry.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ProfileDescribeAuto profileDescribeAuto = ; // ProfileDescribeAuto | 

try {
    final response = api.describeProfileAutoEndpointApiProfilesNameDescribeAutoPost(name, profileDescribeAuto);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->describeProfileAutoEndpointApiProfilesNameDescribeAutoPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profileDescribeAuto** | [**ProfileDescribeAuto**](ProfileDescribeAuto.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **disconnectOauthProviderApiProvidersOauthProviderIdDelete**
> Object disconnectOauthProviderApiProvidersOauthProviderIdDelete(providerId, profile)

Disconnect Oauth Provider

Disconnect an OAuth provider. Token-protected (matches /env/reveal).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String providerId = providerId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.disconnectOauthProviderApiProvidersOauthProviderIdDelete(providerId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->disconnectOauthProviderApiProvidersOauthProviderIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **providerId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **dispatchApiPluginsKanbanDispatchPost**
> Object dispatchApiPluginsKanbanDispatchPost(dryRun, max, board)

Dispatch

Dispatch nudge so the UI doesn't wait out the 60 s dispatcher tick.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final bool dryRun = true; // bool | 
final int max = 56; // int | 
final String board = board_example; // String | 

try {
    final response = api.dispatchApiPluginsKanbanDispatchPost(dryRun, max, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->dispatchApiPluginsKanbanDispatchPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **dryRun** | **bool**|  | [optional] [default to false]
 **max** | **int**|  | [optional] [default to 8]
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **downloadAttachmentApiPluginsKanbanAttachmentsAttachmentIdGet**
> Object downloadAttachmentApiPluginsKanbanAttachmentsAttachmentIdGet(attachmentId, board)

Download Attachment

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int attachmentId = 56; // int | 
final String board = board_example; // String | 

try {
    final response = api.downloadAttachmentApiPluginsKanbanAttachmentsAttachmentIdGet(attachmentId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->downloadAttachmentApiPluginsKanbanAttachmentsAttachmentIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **attachmentId** | **int**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **downloadDashboardBackupApiOpsBackupDownloadGet**
> Object downloadDashboardBackupApiOpsBackupDownloadGet(archive)

Download Dashboard Backup

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String archive = archive_example; // String | 

try {
    final response = api.downloadDashboardBackupApiOpsBackupDownloadGet(archive);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->downloadDashboardBackupApiOpsBackupDownloadGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **archive** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **downloadManagedFileApiFilesDownloadGet**
> Object downloadManagedFileApiFilesDownloadGet(path)

Download Managed File

Stream a managed file as an attachment download.  ``auth_middleware`` also accepts the session token as ``?token=`` here so a shell/browser-opened download (no session header) still authenticates. Chromium marks ``<audio>``/``<video>`` subresource requests via ``Sec-Fetch-Dest``; those are served inline for Desktop builds that still use this route as their player source, attachment semantics otherwise.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.downloadManagedFileApiFilesDownloadGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->downloadManagedFileApiFilesDownloadGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **enableWebhooksApiWebhooksEnablePost**
> Object enableWebhooksApiWebhooksEnablePost()

Enable Webhooks

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.enableWebhooksApiWebhooksEnablePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->enableWebhooksApiWebhooksEnablePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost**
> Object estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost(taskId, board)

Estimate Task Endpoint

Estimate for an existing task; ``{ok, est_tokens, complexity, rationale, model}``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String board = board_example; // String | 

try {
    final response = api.estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost(taskId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **estimateTextEndpointApiPluginsKanbanEstimatePost**
> Object estimateTextEndpointApiPluginsKanbanEstimatePost(estimateBody)

Estimate Text Endpoint

Estimate from raw title/body (create dialog, before a task exists).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final EstimateBody estimateBody = ; // EstimateBody | 

try {
    final response = api.estimateTextEndpointApiPluginsKanbanEstimatePost(estimateBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->estimateTextEndpointApiPluginsKanbanEstimatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **estimateBody** | [**EstimateBody**](EstimateBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost**
> Object exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost(slug, exportBoardBody)

Export Board Endpoint

Write ``slug`` to a portable archive; return the path written.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String slug = slug_example; // String | 
final ExportBoardBody exportBoardBody = ; // ExportBoardBody | 

try {
    final response = api.exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost(slug, exportBoardBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **exportBoardBody** | [**ExportBoardBody**](ExportBoardBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **exportProfileEndpointApiProfilesNameExportPost**
> Object exportProfileEndpointApiProfilesNameExportPost(name, profileExport)

Export Profile Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ProfileExport profileExport = ; // ProfileExport | 

try {
    final response = api.exportProfileEndpointApiProfilesNameExportPost(name, profileExport);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->exportProfileEndpointApiProfilesNameExportPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profileExport** | [**ProfileExport**](ProfileExport.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **exportSessionEndpointApiSessionsSessionIdExportGet**
> Object exportSessionEndpointApiSessionsSessionIdExportGet(sessionId, profile)

Export Session Endpoint

Stream a single session (metadata + messages) as JSON.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.exportSessionEndpointApiSessionsSessionIdExportGet(sessionId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->exportSessionEndpointApiSessionsSessionIdExportGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **fsDefaultCwdApiFsDefaultCwdGet**
> Object fsDefaultCwdApiFsDefaultCwdGet()

Fs Default Cwd

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.fsDefaultCwdApiFsDefaultCwdGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->fsDefaultCwdApiFsDefaultCwdGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **fsDownloadApiFsDownloadGet**
> Object fsDownloadApiFsDownloadGet(path, profile, sessionId)

Fs Download

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 
final String profile = profile_example; // String | 
final String sessionId = sessionId_example; // String | 

try {
    final response = api.fsDownloadApiFsDownloadGet(path, profile, sessionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->fsDownloadApiFsDownloadGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 
 **profile** | **String**|  | [optional] 
 **sessionId** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **fsGitRootApiFsGitRootGet**
> Object fsGitRootApiFsGitRootGet(path)

Fs Git Root

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.fsGitRootApiFsGitRootGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->fsGitRootApiFsGitRootGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **fsListApiFsListGet**
> Object fsListApiFsListGet(path)

Fs List

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.fsListApiFsListGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->fsListApiFsListGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **fsReadDataUrlApiFsReadDataUrlGet**
> Object fsReadDataUrlApiFsReadDataUrlGet(path, profile, sessionId)

Fs Read Data Url

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 
final String profile = profile_example; // String | 
final String sessionId = sessionId_example; // String | 

try {
    final response = api.fsReadDataUrlApiFsReadDataUrlGet(path, profile, sessionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->fsReadDataUrlApiFsReadDataUrlGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 
 **profile** | **String**|  | [optional] 
 **sessionId** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **fsReadTextApiFsReadTextGet**
> Object fsReadTextApiFsReadTextGet(path)

Fs Read Text

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.fsReadTextApiFsReadTextGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->fsReadTextApiFsReadTextGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **fsWriteTextApiFsWriteTextPost**
> Object fsWriteTextApiFsWriteTextPost(fsWriteText)

Fs Write Text

Overwrite (or create) a UTF-8 text file for the in-app spot editor.  Mirrors the Electron ``hermes:fs:writeText`` hardening: path validated by ``_fs_path``, the parent must already exist (never build trees), only regular files may be replaced, payload size-capped, staged to a sibling temp file and ``os.replace``-d so a crash can't truncate the original. Stale-on-disk detection is the client's job (re-read before save).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final FsWriteText fsWriteText = ; // FsWriteText | 

try {
    final response = api.fsWriteTextApiFsWriteTextPost(fsWriteText);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->fsWriteTextApiFsWriteTextPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **fsWriteText** | [**FsWriteText**](FsWriteText.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gatewayDrainApiGatewayDrainPost**
> Object gatewayDrainApiGatewayDrainPost()

Gateway Drain

Begin or cancel an external (NAS-driven) gateway drain.  Authenticated by the non-interactive token-auth seam (the ``dashboard_auth/drain`` plugin registers this path as a token route and verifies the bearer secret); without that plugin the cookie gate covers a gated bind and the legacy session-token gate a loopback bind — never unauthenticated on a network bind.  Body ``{\"action\": \"drain\"|\"cancel\"}``. Only the ``.drain_request.json`` marker is written/removed here — the gateway's ``_drain_control_watcher`` owns the state transition (the marker IS the control channel). Idempotent on both sides; ``POST /api/gateway/restart`` is the force-override that supersedes a drain.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.gatewayDrainApiGatewayDrainPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gatewayDrainApiGatewayDrainPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gatewayMigrateApiGatewayMigratePost**
> Object gatewayMigrateApiGatewayMigratePost()

Gateway Migrate

Run ``hermes gateway migrate --multiplex --yes`` detached; the CLI re-runs the preflight and refuses (exit 1 into the action log) when blocked, so the UI should gate on the plan first.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.gatewayMigrateApiGatewayMigratePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gatewayMigrateApiGatewayMigratePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gatewayMigratePlanApiGatewayMigratePlanGet**
> Object gatewayMigratePlanApiGatewayMigratePlanGet()

Gateway Migrate Plan

Preflight for folding per-profile gateways into one multiplexer (same JSON as the CLI plan).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.gatewayMigratePlanApiGatewayMigratePlanGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gatewayMigratePlanApiGatewayMigratePlanGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getActionStatusApiActionsNameStatusGet**
> Object getActionStatusApiActionsNameStatusGet(name, lines)

Get Action Status

Tail an action log and report whether the process is still running.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final int lines = 56; // int | 

try {
    final response = api.getActionStatusApiActionsNameStatusGet(name, lines);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getActionStatusApiActionsNameStatusGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **lines** | **int**|  | [optional] [default to 200]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getActiveProfileEndpointApiProfilesActiveGet**
> Object getActiveProfileEndpointApiProfilesActiveGet()

Get Active Profile Endpoint

``active`` is the sticky default written by ``hermes profile use`` (what new CLI invocations pick up); ``current`` is the profile this running dashboard is scoped to.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getActiveProfileEndpointApiProfilesActiveGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getActiveProfileEndpointApiProfilesActiveGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAssigneesApiPluginsKanbanAssigneesGet**
> Object getAssigneesApiPluginsKanbanAssigneesGet(board)

Get Assignees

Union of on-disk profiles and assignees used on the board, so a fresh profile appears in the picker before it has any task.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String board = board_example; // String | 

try {
    final response = api.getAssigneesApiPluginsKanbanAssigneesGet(board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getAssigneesApiPluginsKanbanAssigneesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAuxiliaryModelsApiModelAuxiliaryGet**
> Object getAuxiliaryModelsApiModelAuxiliaryGet(profile)

Get Auxiliary Models

Current auxiliary task assignments: ``{\"tasks\": [{task, provider, model, base_url}, ...], \"main\": {provider, model}}``. ``profile`` scopes the read — without it the Models page would show the dashboard profile's pins while /api/model/set wrote the selected profile's.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getAuxiliaryModelsApiModelAuxiliaryGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getAuxiliaryModelsApiModelAuxiliaryGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getBoardEndpointApiPluginsKanbanBoardGet**
> Object getBoardEndpointApiPluginsKanbanBoardGet(tenant, includeArchived, board, workflowTemplateId, currentStepKey)

Get Board Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String tenant = tenant_example; // String | Filter to a single tenant
final bool includeArchived = true; // bool | 
final String board = board_example; // String | Kanban board slug (omit for current)
final String workflowTemplateId = workflowTemplateId_example; // String | Restrict to tasks using this workflow template id
final String currentStepKey = currentStepKey_example; // String | Restrict to tasks at this workflow step key

try {
    final response = api.getBoardEndpointApiPluginsKanbanBoardGet(tenant, includeArchived, board, workflowTemplateId, currentStepKey);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getBoardEndpointApiPluginsKanbanBoardGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **tenant** | **String**| Filter to a single tenant | [optional] 
 **includeArchived** | **bool**|  | [optional] [default to false]
 **board** | **String**| Kanban board slug (omit for current) | [optional] 
 **workflowTemplateId** | **String**| Restrict to tasks using this workflow template id | [optional] 
 **currentStepKey** | **String**| Restrict to tasks at this workflow step key | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getClientVoiceConfigApiAudioVoiceConfigGet**
> Object getClientVoiceConfigApiAudioVoiceConfigGet(profile)

Get Client Voice Config

The active profile's STT/TTS config for CLIENT-DIRECT voice.  Lets the desktop cut the audio relay hop: mic audio goes straight to the profile's STT provider and reply text is synthesized on the client with the profile's TTS provider — the desktop↔gateway link carries only text. Providers that can only run on this host (local whisper, edge-tts, command/plugin providers) resolve to ``{\"mode\": \"relay\"}`` and the desktop keeps using the /api/audio/_* relay endpoints.  Same trust boundary as every profile-scoped route: the caller is an authenticated client that can already drive the agent. Keys in the response are held in client memory only, never persisted client-side. Gate: ``voice.client_direct`` in config.yaml (default true).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getClientVoiceConfigApiAudioVoiceConfigGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getClientVoiceConfigApiAudioVoiceConfigGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getComputerUseStatusApiToolsComputerUseStatusGet**
> Object getComputerUseStatusApiToolsComputerUseStatusGet(profile)

Get Computer Use Status

Computer Use readiness for the desktop card (payload shape: see ``tools.computer_use.permissions.computer_use_status``).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getComputerUseStatusApiToolsComputerUseStatusGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getComputerUseStatusApiToolsComputerUseStatusGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getConfigApiConfigGet**
> Object getConfigApiConfigGet(profile, includeDefaults)

Get Config

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 
final bool includeDefaults = true; // bool | 

try {
    final response = api.getConfigApiConfigGet(profile, includeDefaults);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getConfigApiConfigGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 
 **includeDefaults** | **bool**|  | [optional] [default to true]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getConfigApiPluginsKanbanConfigGet**
> Object getConfigApiPluginsKanbanConfigGet()

Get Config

Kanban dashboard preferences from the ``dashboard.kanban`` config section.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getConfigApiPluginsKanbanConfigGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getConfigApiPluginsKanbanConfigGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getConfigRawApiConfigRawGet**
> Object getConfigRawApiConfigRawGet(profile)

Get Config Raw

Raw config.yaml text plus its resolved path.  ``path`` is resolved inside ``_profile_scope`` so the Config page header shows the file the switched profile actually reads/writes — /api/status's ``config_path`` is machine-global and always reports the dashboard process's own profile, which is wrong under the global profile switcher.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getConfigRawApiConfigRawGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getConfigRawApiConfigRawGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCronDeliveryTargetsApiCronDeliveryTargetsGet**
> Object getCronDeliveryTargetsApiCronDeliveryTargetsGet()

Get Cron Delivery Targets

Delivery targets for the cron dropdown: implicit ``local`` plus the configured gateway platforms (a platform without a cron home channel is still listed with ``home_target_set: false`` so the UI can say so).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getCronDeliveryTargetsApiCronDeliveryTargetsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getCronDeliveryTargetsApiCronDeliveryTargetsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCronJobApiCronJobsJobIdGet**
> Object getCronJobApiCronJobsJobIdGet(jobId, profile)

Get Cron Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getCronJobApiCronJobsJobIdGet(jobId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getCronJobApiCronJobsJobIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCuratorStatusApiCuratorGet**
> Object getCuratorStatusApiCuratorGet()

Get Curator Status

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getCuratorStatusApiCuratorGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getCuratorStatusApiCuratorGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDashboardFontApiDashboardFontGet**
> Object getDashboardFontApiDashboardFontGet()

Get Dashboard Font

Return the active font override (``\"theme\"`` = use the theme's font).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getDashboardFontApiDashboardFontGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getDashboardFontApiDashboardFontGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDashboardPluginsApiDashboardPluginsGet**
> Object getDashboardPluginsApiDashboardPluginsGet()

Get Dashboard Plugins

Return discovered dashboard plugins (excludes user-hidden and non-enabled ones).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getDashboardPluginsApiDashboardPluginsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getDashboardPluginsApiDashboardPluginsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDashboardThemesApiDashboardThemesGet**
> Object getDashboardThemesApiDashboardThemesGet()

Get Dashboard Themes

Available themes + the active one. Built-ins ship name/label/description only (the frontend owns their definitions in `web/src/themes/presets.ts`); user themes from `~/.hermes/dashboard-themes/_*.yaml` ship their normalised `definition`.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getDashboardThemesApiDashboardThemesGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getDashboardThemesApiDashboardThemesGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getDefaultsApiConfigDefaultsGet**
> Object getDefaultsApiConfigDefaultsGet()

Get Defaults

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getDefaultsApiConfigDefaultsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getDefaultsApiConfigDefaultsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getEgressStatusApiEgressStatusGet**
> Object getEgressStatusApiEgressStatusGet()

Get Egress Status

Dashboard/Desktop-readable egress proxy status and remediation text.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getEgressStatusApiEgressStatusGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getEgressStatusApiEgressStatusGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getElevenlabsVoicesApiAudioElevenlabsVoicesGet**
> Object getElevenlabsVoicesApiAudioElevenlabsVoicesGet(profile)

Get Elevenlabs Voices

Return ElevenLabs voices when an API key is configured.  The desktop UI uses this for the ``tts.elevenlabs.voice_id`` dropdown. Only non-secret voice metadata is returned; the API key stays server-side.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getElevenlabsVoicesApiAudioElevenlabsVoicesGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getElevenlabsVoicesApiAudioElevenlabsVoicesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getEnvVarsApiEnvGet**
> Object getEnvVarsApiEnvGet(profile)

Get Env Vars

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getEnvVarsApiEnvGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getEnvVarsApiEnvGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getHealthApiHealthGet**
> Object getHealthApiHealthGet()

Get Health

Lightweight process liveness for desktop/backend readiness probes.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getHealthApiHealthGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getHealthApiHealthGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getHealthIdleApiHealthIdleGet**
> Object getHealthIdleApiHealthIdleGet()

Get Health Idle

Token-gated diagnostic snapshot; never a retirement permit. None means cannot prove idle.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getHealthIdleApiHealthIdleGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getHealthIdleApiHealthIdleGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getHomeChannelsApiPluginsKanbanHomeChannelsGet**
> Object getHomeChannelsApiPluginsKanbanHomeChannelsGet(taskId, board)

Get Home Channels

Every platform with a home channel plus whether *task_id* (if given) is subscribed to it; without ``task_id`` every ``subscribed`` is false.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String board = board_example; // String | 

try {
    final response = api.getHomeChannelsApiPluginsKanbanHomeChannelsGet(taskId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getHomeChannelsApiPluginsKanbanHomeChannelsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | [optional] 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getLearningGraphApiLearningGraphGet**
> Object getLearningGraphApiLearningGraphGet(profile)

Get Learning Graph

Learning graph for the desktop panel: profile-scoped learned skills + memory chunks.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getLearningGraphApiLearningGraphGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getLearningGraphApiLearningGraphGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getLearningNodeApiLearningNodeGet**
> Object getLearningNodeApiLearningNodeGet(id, profile)

Get Learning Node

Current content of a journey node (skill SKILL.md or memory chunk), for an edit prefill.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String id = id_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getLearningNodeApiLearningNodeGet(id, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getLearningNodeApiLearningNodeGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getLogsApiLogsGet**
> Object getLogsApiLogsGet(file, lines, level, component, search)

Get Logs

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String file = file_example; // String | 
final int lines = 56; // int | 
final String level = level_example; // String | 
final String component = component_example; // String | 
final String search = search_example; // String | 

try {
    final response = api.getLogsApiLogsGet(file, lines, level, component, search);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getLogsApiLogsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **file** | **String**|  | [optional] [default to 'agent']
 **lines** | **int**|  | [optional] [default to 100]
 **level** | **String**|  | [optional] 
 **component** | **String**|  | [optional] 
 **search** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMediaApiMediaGet**
> Object getMediaApiMediaGet(path)

Get Media

Return a gateway-local image as a base64 data URL for remote clients that can't read this machine's disk. Auth-gated; restricted to the image allowlist, a size cap AND the resolved (symlink-safe) media roots.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.getMediaApiMediaGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getMediaApiMediaGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMemoryProviderConfigApiMemoryProvidersNameConfigGet**
> Object getMemoryProviderConfigApiMemoryProvidersNameConfigGet(name, surface, profile)

Get Memory Provider Config

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final String surface = surface_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getMemoryProviderConfigApiMemoryProvidersNameConfigGet(name, surface, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getMemoryProviderConfigApiMemoryProvidersNameConfigGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **surface** | **String**|  | [optional] 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMemoryStatusApiMemoryGet**
> Object getMemoryStatusApiMemoryGet()

Get Memory Status

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getMemoryStatusApiMemoryGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getMemoryStatusApiMemoryGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMessagingPlatformsApiMessagingPlatformsGet**
> Object getMessagingPlatformsApiMessagingPlatformsGet(profile)

Get Messaging Platforms

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getMessagingPlatformsApiMessagingPlatformsGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getMessagingPlatformsApiMessagingPlatformsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMoaModelsApiModelMoaGet**
> Object getMoaModelsApiModelMoaGet(profile)

Get Moa Models

Return the configured Mixture-of-Agents provider/model slots.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getMoaModelsApiModelMoaGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getMoaModelsApiModelMoaGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getModelInfoApiModelInfoGet**
> Object getModelInfoApiModelInfoGet(profile)

Get Model Info

Resolved metadata for the configured model: auto-detected vs configured context length (so the UI can show \"Auto-detected: 200K\" beside the override) plus models.dev capabilities when available.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getModelInfoApiModelInfoGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getModelInfoApiModelInfoGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getModelOptionsApiModelOptionsGet**
> Object getModelOptionsApiModelOptionsGet(profile, refresh, includeUnconfigured, explicitOnly)

Get Model Options

Authenticated providers + curated model lists — REST twin of the ``model.options`` JSON-RPC on tui_gateway, same response shape so ``ModelPickerDialog`` shares the types. ``profile`` scopes the picker context so the Models page reads the SAME profile /api/model/set writes. ``refresh`` busts the per-provider model-id disk cache (picker's explicit \"Refresh Models\"); normal opens stay on the 1h cache.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 
final bool refresh = true; // bool | 
final bool includeUnconfigured = true; // bool | 
final bool explicitOnly = true; // bool | 

try {
    final response = api.getModelOptionsApiModelOptionsGet(profile, refresh, includeUnconfigured, explicitOnly);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getModelOptionsApiModelOptionsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 
 **refresh** | **bool**|  | [optional] [default to false]
 **includeUnconfigured** | **bool**|  | [optional] [default to false]
 **explicitOnly** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getModelsAnalyticsApiAnalyticsModelsGet**
> Object getModelsAnalyticsApiAnalyticsModelsGet(days, profile)

Get Models Analytics

Return model analytics without blocking the serving event loop.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int days = 56; // int | 
final String profile = profile_example; // String | 

try {
    final response = api.getModelsAnalyticsApiAnalyticsModelsGet(days, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getModelsAnalyticsApiAnalyticsModelsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **days** | **int**|  | [optional] [default to 30]
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getOrchestrationSettingsApiPluginsKanbanOrchestrationGet**
> Object getOrchestrationSettingsApiPluginsKanbanOrchestrationGet()

Get Orchestration Settings

Current orchestration knobs from config.yaml plus the resolved effective values. An unset/unknown profile resolves to the active profile here; the decomposer prefers the root card's assignee in that case and uses the active profile only for cards with no assignee.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getOrchestrationSettingsApiPluginsKanbanOrchestrationGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getOrchestrationSettingsApiPluginsKanbanOrchestrationGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPluginsCatalogApiDashboardPluginsCatalogGet**
> Object getPluginsCatalogApiDashboardPluginsCatalogGet()

Get Plugins Catalog

Curated plugin catalog merged with installed state (session protected).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getPluginsCatalogApiDashboardPluginsCatalogGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getPluginsCatalogApiDashboardPluginsCatalogGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPluginsHubApiDashboardPluginsHubGet**
> Object getPluginsHubApiDashboardPluginsHubGet()

Get Plugins Hub

Unified agent plugins + dashboard extension metadata (session protected).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getPluginsHubApiDashboardPluginsHubGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getPluginsHubApiDashboardPluginsHubGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPortalStatusApiPortalGet**
> Object getPortalStatusApiPortalGet()

Get Portal Status

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getPortalStatusApiPortalGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getPortalStatusApiPortalGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getProfileDesktopOverlayApiProfilesNameDesktopOverlayGet**
> Object getProfileDesktopOverlayApiProfilesNameDesktopOverlayGet(name)

Get Profile Desktop Overlay

The desktop appearance/interface overlay bundled with an imported profile (``desktop.json`` at the profile root), or ``exists: false``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.getProfileDesktopOverlayApiProfilesNameDesktopOverlayGet(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getProfileDesktopOverlayApiProfilesNameDesktopOverlayGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getProfileSetupCommandApiProfilesNameSetupCommandGet**
> Object getProfileSetupCommandApiProfilesNameSetupCommandGet(name)

Get Profile Setup Command

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.getProfileSetupCommandApiProfilesNameSetupCommandGet(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getProfileSetupCommandApiProfilesNameSetupCommandGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getProfileSoulApiProfilesNameSoulGet**
> Object getProfileSoulApiProfilesNameSoulGet(name)

Get Profile Soul

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.getProfileSoulApiProfilesNameSoulGet(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getProfileSoulApiProfilesNameSoulGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getProfilesProjectsTreeApiProfilesProjectsTreeGet**
> Object getProfilesProjectsTreeApiProfilesProjectsTreeGet(previewLimit, sessionLimit)

Get Profiles Projects Tree

Project tree for every profile at once, for the all-profiles sidebar.  ``projects.tree`` over JSON-RPC answers for the backend's own profile only; this runs the same builder once per profile against its ``state.db``, scoping the other inputs (projects.db, repo-scan policy, junk filters) through the home override. Discovery is off: a repo with zero sessions is the same repo in every profile (the disk scan would multiply empty lanes by the profile count), and discovery is the one part of the builder that writes (policy reconciliation), which a read-only fan-out must not do.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int previewLimit = 56; // int | 
final int sessionLimit = 56; // int | 

try {
    final response = api.getProfilesProjectsTreeApiProfilesProjectsTreeGet(previewLimit, sessionLimit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getProfilesProjectsTreeApiProfilesProjectsTreeGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **previewLimit** | **int**|  | [optional] [default to 3]
 **sessionLimit** | **int**|  | [optional] [default to 2000]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getProfilesSessionsApiProfilesSessionsGet**
> Object getProfilesSessionsApiProfilesSessionsGet(limit, offset, minMessages, archived, order, profile, source_, sources, excludeSources, full)

Get Profiles Sessions

Unified, read-only session list aggregated across ALL profiles: opens each profile's ``state.db`` directly (no dashboard backend per profile) and tags rows with their owning ``profile``. Rows omit ``system_prompt`` / ``model_config`` unless ``full=1`` — same projection as ``/api/sessions``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int limit = 56; // int | 
final int offset = 56; // int | 
final int minMessages = 56; // int | 
final String archived = archived_example; // String | 
final String order = order_example; // String | 
final String profile = profile_example; // String | 
final String source_ = source__example; // String | 
final String sources = sources_example; // String | 
final String excludeSources = excludeSources_example; // String | 
final bool full = true; // bool | 

try {
    final response = api.getProfilesSessionsApiProfilesSessionsGet(limit, offset, minMessages, archived, order, profile, source_, sources, excludeSources, full);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getProfilesSessionsApiProfilesSessionsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 20]
 **offset** | **int**|  | [optional] [default to 0]
 **minMessages** | **int**|  | [optional] [default to 0]
 **archived** | **String**|  | [optional] [default to 'exclude']
 **order** | **String**|  | [optional] [default to 'recent']
 **profile** | **String**|  | [optional] [default to 'all']
 **source_** | **String**|  | [optional] 
 **sources** | **String**|  | [optional] 
 **excludeSources** | **String**|  | [optional] 
 **full** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getProfilesSessionsSidebarApiProfilesSessionsSidebarGet**
> Object getProfilesSessionsSidebarApiProfilesSessionsSidebarGet(recentsProfile, recentsLimit, recentsExclude, cronLimit, messagingLimit, messagingExclude)

Get Profiles Sessions Sidebar

Batched sidebar session slices (recents / cron / messaging) — one profile-DB open per refresh instead of three ``/api/profiles/sessions`` calls. Same row projection and 300s active heuristic as the per-slice endpoint; all slices use ``min_messages=1`` / ``archived=exclude`` / recency order.  ``recents_profile`` scopes the WHOLE payload, not just recents — the sidebar has one scope, so a concrete profile must never show another profile's Telegram threads or cronjobs; ``all`` asks for everything.  See #42651, #65710, #70629.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String recentsProfile = recentsProfile_example; // String | 
final int recentsLimit = 56; // int | 
final String recentsExclude = recentsExclude_example; // String | 
final int cronLimit = 56; // int | 
final int messagingLimit = 56; // int | 
final String messagingExclude = messagingExclude_example; // String | 

try {
    final response = api.getProfilesSessionsSidebarApiProfilesSessionsSidebarGet(recentsProfile, recentsLimit, recentsExclude, cronLimit, messagingLimit, messagingExclude);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getProfilesSessionsSidebarApiProfilesSessionsSidebarGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **recentsProfile** | **String**|  | [optional] [default to 'all']
 **recentsLimit** | **int**|  | [optional] [default to 20]
 **recentsExclude** | **String**|  | [optional] 
 **cronLimit** | **int**|  | [optional] [default to 50]
 **messagingLimit** | **int**|  | [optional] [default to 100]
 **messagingExclude** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRecommendedDefaultModelApiModelRecommendedDefaultGet**
> Object getRecommendedDefaultModelApiModelRecommendedDefaultGet(provider)

Get Recommended Default Model

Recommended default model for a freshly-authenticated provider, mirroring ``hermes model``'s curation so GUI onboarding lands on a sensible default. Nous honors the user's free/paid tier. Any other provider gets the preferred silent default when its curated list carries it, else the first curated model — aggregator lists lead with the priciest Anthropic flagship, which must never be the model a user lands on without explicitly picking it. Response: {\"provider\", \"model\", \"free_tier\": bool | None} — free_tier only for Nous; ``model`` may be empty (caller degrades gracefully).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String provider = provider_example; // String | 

try {
    final response = api.getRecommendedDefaultModelApiModelRecommendedDefaultGet(provider);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getRecommendedDefaultModelApiModelRecommendedDefaultGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | [optional] [default to '']

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRunEndpointApiPluginsKanbanRunsRunIdGet**
> Object getRunEndpointApiPluginsKanbanRunsRunIdGet(runId, board)

Get Run Endpoint

``{run: {...}}`` with the same serialisation as ``GET /tasks/{id}``; 404 if unknown.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int runId = 56; // int | 
final String board = board_example; // String | Kanban board slug (omit for current)

try {
    final response = api.getRunEndpointApiPluginsKanbanRunsRunIdGet(runId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getRunEndpointApiPluginsKanbanRunsRunIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **runId** | **int**|  | 
 **board** | **String**| Kanban board slug (omit for current) | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSchemaApiConfigSchemaGet**
> Object getSchemaApiConfigSchemaGet(profile)

Get Schema

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getSchemaApiConfigSchemaGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSchemaApiConfigSchemaGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSessionDetailApiSessionsSessionIdGet**
> Object getSessionDetailApiSessionsSessionIdGet(sessionId, profile)

Get Session Detail

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getSessionDetailApiSessionsSessionIdGet(sessionId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSessionDetailApiSessionsSessionIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSessionLatestDescendantApiSessionsSessionIdLatestDescendantGet**
> Object getSessionLatestDescendantApiSessionsSessionIdLatestDescendantGet(sessionId, profile)

Get Session Latest Descendant

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getSessionLatestDescendantApiSessionsSessionIdLatestDescendantGet(sessionId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSessionLatestDescendantApiSessionsSessionIdLatestDescendantGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSessionMessagesApiSessionsSessionIdMessagesGet**
> Object getSessionMessagesApiSessionsSessionIdMessagesGet(sessionId, profile, limit, offset, order, includeCompacted)

Get Session Messages

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 
final int limit = 56; // int | 
final int offset = 56; // int | 
final String order = order_example; // String | 
final bool includeCompacted = true; // bool | 

try {
    final response = api.getSessionMessagesApiSessionsSessionIdMessagesGet(sessionId, profile, limit, offset, order, includeCompacted);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSessionMessagesApiSessionsSessionIdMessagesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] 
 **offset** | **int**|  | [optional] [default to 0]
 **order** | **String**|  | [optional] 
 **includeCompacted** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSessionMessagesAroundApiSessionsSessionIdMessagesAroundGet**
> Object getSessionMessagesAroundApiSessionsSessionIdMessagesAroundGet(sessionId, rowId, profile, limit)

Get Session Messages Around

Bounded display page starting at a timeline prompt; no intervening payloads.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final int rowId = 56; // int | 
final String profile = profile_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.getSessionMessagesAroundApiSessionsSessionIdMessagesAroundGet(sessionId, rowId, profile, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSessionMessagesAroundApiSessionsSessionIdMessagesAroundGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **rowId** | **int**|  | 
 **profile** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 120]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSessionStatsApiSessionsStatsGet**
> Object getSessionStatsApiSessionsStatsGet(profile)

Get Session Stats

Session-store statistics (mirrors `hermes sessions stats`).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getSessionStatsApiSessionsStatsGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSessionStatsApiSessionsStatsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSessionTimelineApiSessionsSessionIdTimelineGet**
> Object getSessionTimelineApiSessionsSessionIdTimelineGet(sessionId, profile, limit, afterRowId)

Get Session Timeline

Prompt metadata only, including compacted display history (never rewind rows).  ``next_cursor`` is a stable logical first-row id; pass it as ``after_row_id``. Entry ``row_id`` addresses the current representative for /messages/around.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 
final int limit = 56; // int | 
final int afterRowId = 56; // int | 

try {
    final response = api.getSessionTimelineApiSessionsSessionIdTimelineGet(sessionId, profile, limit, afterRowId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSessionTimelineApiSessionsSessionIdTimelineGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 500]
 **afterRowId** | **int**|  | [optional] [default to 0]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSessionsApiSessionsGet**
> Object getSessionsApiSessionsGet(limit, offset, minMessages, archived, order, source_, sources, excludeSources, cwdPrefix, full, profile)

Get Sessions

List sessions.  ``order=recent`` sorts by latest activity across the compression chain, so a long-running chat stays on page one after it auto-compresses onto a fresh id.  Rows omit ``system_prompt`` / ``model_config`` unless ``full=1``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int limit = 56; // int | 
final int offset = 56; // int | 
final int minMessages = 56; // int | 
final String archived = archived_example; // String | 
final String order = order_example; // String | 
final String source_ = source__example; // String | 
final String sources = sources_example; // String | 
final String excludeSources = excludeSources_example; // String | 
final String cwdPrefix = cwdPrefix_example; // String | 
final bool full = true; // bool | 
final String profile = profile_example; // String | 

try {
    final response = api.getSessionsApiSessionsGet(limit, offset, minMessages, archived, order, source_, sources, excludeSources, cwdPrefix, full, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSessionsApiSessionsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 20]
 **offset** | **int**|  | [optional] [default to 0]
 **minMessages** | **int**|  | [optional] [default to 0]
 **archived** | **String**|  | [optional] [default to 'exclude']
 **order** | **String**|  | [optional] [default to 'created']
 **source_** | **String**|  | [optional] 
 **sources** | **String**|  | [optional] 
 **excludeSources** | **String**|  | [optional] 
 **cwdPrefix** | **String**|  | [optional] 
 **full** | **bool**|  | [optional] [default to false]
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSkillContentApiSkillsContentGet**
> Object getSkillContentApiSkillsContentGet(name, profile)

Get Skill Content

Raw SKILL.md text for the dashboard editor.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getSkillContentApiSkillsContentGet(name, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSkillContentApiSkillsContentGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSkillsApiSkillsGet**
> Object getSkillsApiSkillsGet(profile)

Get Skills

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getSkillsApiSkillsGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSkillsApiSkillsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSshOwnershipApiSshOwnershipGet**
> Object getSshOwnershipApiSshOwnershipGet()

Get Ssh Ownership

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getSshOwnershipApiSshOwnershipGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSshOwnershipApiSshOwnershipGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getStatsApiPluginsKanbanStatsGet**
> Object getStatsApiPluginsKanbanStatsGet(board)

Get Stats

Per-status + per-assignee counts + oldest-ready age (HUD and router profiles).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String board = board_example; // String | 

try {
    final response = api.getStatsApiPluginsKanbanStatsGet(board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getStatsApiPluginsKanbanStatsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getStatusApiStatusGet**
> Object getStatusApiStatusGet(profile)

Get Status

Public machine-level liveness probe (``PUBLIC_API_PATHS``): version, gateway state, active session count and the auth-gate shape — no bodies, no session content, no secrets.  ``?profile=`` (dashboard management switcher) uses the config-only contextvar scope, NOT _profile_scope: this handler awaits the remote health probe, and _profile_scope swaps process-global skills-module attributes a concurrent request would cross-restore.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getStatusApiStatusGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getStatusApiStatusGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getSystemStatsApiSystemStatsGet**
> Object getSystemStatsApiSystemStatsGet()

Get System Stats

Host + process system stats for the System page (stdlib identity; psutil CPU/memory/ disk/uptime when available). Non-sensitive: no env values, no paths beyond hermes home.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getSystemStatsApiSystemStatsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getSystemStatsApiSystemStatsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getTaskApiPluginsKanbanTasksTaskIdGet**
> Object getTaskApiPluginsKanbanTasksTaskIdGet(taskId, board, runStateType, runStateName)

Get Task

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String board = board_example; // String | 
final String runStateType = runStateType_example; // String | With run_state_name: filter runs by column 'status' or 'outcome'
final String runStateName = runStateName_example; // String | With run_state_type: exact value for that run column

try {
    final response = api.getTaskApiPluginsKanbanTasksTaskIdGet(taskId, board, runStateType, runStateName);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getTaskApiPluginsKanbanTasksTaskIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **board** | **String**|  | [optional] 
 **runStateType** | **String**| With run_state_name: filter runs by column 'status' or 'outcome' | [optional] 
 **runStateName** | **String**| With run_state_type: exact value for that run column | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getTaskLogApiPluginsKanbanTasksTaskIdLogGet**
> Object getTaskLogApiPluginsKanbanTasksTaskIdLogGet(taskId, tail, board)

Get Task Log

Worker stdout/stderr log. ``tail`` caps the response bytes; 404 if the task never spawned. On-disk log rotates at 2 MiB with one ``.log.1`` kept.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final int tail = 56; // int | 
final String board = board_example; // String | 

try {
    final response = api.getTaskLogApiPluginsKanbanTasksTaskIdLogGet(taskId, tail, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getTaskLogApiPluginsKanbanTasksTaskIdLogGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **tail** | **int**|  | [optional] 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet**
> Object getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet(pairingId)

Get Telegram Onboarding Status

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String pairingId = pairingId_example; // String | 

try {
    final response = api.getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet(pairingId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getTerminalBackendsApiToolsTerminalBackendsGet**
> Object getTerminalBackendsApiToolsTerminalBackendsGet(profile)

Get Terminal Backends

Terminal backend rows with health probes: ``status`` is ``ready`` / ``needs_setup`` / ``unavailable``; a probe failure is a status, never an error response.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getTerminalBackendsApiToolsTerminalBackendsGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getTerminalBackendsApiToolsTerminalBackendsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getToolsetConfigApiToolsToolsetsNameConfigGet**
> Object getToolsetConfigApiToolsToolsetsNameConfigGet(name, profile)

Get Toolset Config

Provider matrix + key status for a toolset's config panel (the CLI picker rows, each env var annotated ``is_set``); no category -> ``has_category: false``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getToolsetConfigApiToolsToolsetsNameConfigGet(name, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getToolsetConfigApiToolsToolsetsNameConfigGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getToolsetModelsApiToolsToolsetsNameModelsGet**
> Object getToolsetModelsApiToolsToolsetsNameModelsGet(name, provider, profile)

Get Toolset Models

Model catalog for a toolset backend (image/video gen) — the GUI counterpart of the CLI model picker.  ``provider`` names a picker row (default: the active provider); no catalog -> ``has_models: false``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final String provider = provider_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.getToolsetModelsApiToolsToolsetsNameModelsGet(name, provider, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getToolsetModelsApiToolsToolsetsNameModelsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **provider** | **String**|  | [optional] 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getToolsetsApiToolsToolsetsGet**
> Object getToolsetsApiToolsToolsetsGet(profile)

Get Toolsets

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getToolsetsApiToolsToolsetsGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getToolsetsApiToolsToolsetsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getUpdateReceiptApiHermesUpdateReceiptGet**
> Object getUpdateReceiptApiHermesUpdateReceiptGet()

Get Update Receipt

The FULL latest update receipt (steps, skips, gateway restart outcome, fleet matrix) plus a compact ``summary``; 404 when no update has run since receipts landed. Clients read this instead of inferring success from backend liveness, which misread the update's own restart gap as a failed update/boot.  See #81193, #87359, #91277.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.getUpdateReceiptApiHermesUpdateReceiptGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getUpdateReceiptApiHermesUpdateReceiptGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getUsageAnalyticsApiAnalyticsUsageGet**
> Object getUsageAnalyticsApiAnalyticsUsageGet(days, profile)

Get Usage Analytics

``days`` is clamped to 1-365 (idea from #74778): huge or non-positive values would force expensive full-history SQL and InsightsEngine work, or produce empty/inverted time windows. The UI only offers 7/30/90-day presets.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int days = 56; // int | 
final String profile = profile_example; // String | 

try {
    final response = api.getUsageAnalyticsApiAnalyticsUsageGet(days, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getUsageAnalyticsApiAnalyticsUsageGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **days** | **int**|  | [optional] [default to 30]
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getVoiceLiveStatusApiAudioVoiceLiveStatusGet**
> Object getVoiceLiveStatusApiAudioVoiceLiveStatusGet(profile)

Get Voice Live Status

Which voice chat mode the profile selected (``chained`` | ``gpt-live``) and whether GPT-Live can start. Non-secret: the desktop decides which conversation engine to mount from this.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.getVoiceLiveStatusApiAudioVoiceLiveStatusGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getVoiceLiveStatusApiAudioVoiceLiveStatusGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet**
> Object getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet(pairingId)

Get Whatsapp Onboarding Status

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String pairingId = pairingId_example; // String | 

try {
    final response = api.getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet(pairingId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **ghAuthStatusRouteApiGitGhAuthGet**
> Object ghAuthStatusRouteApiGitGhAuthGet(refresh)

Gh Auth Status Route

``{\"available\", \"authenticated\"}`` for the `gh` CLI; cached 5 min (``refresh=true`` bypasses so the pill withdraws right after a login).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final bool refresh = true; // bool | 

try {
    final response = api.ghAuthStatusRouteApiGitGhAuthGet(refresh);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->ghAuthStatusRouteApiGitGhAuthGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refresh** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitBaseBranchesRouteApiGitBaseBranchesGet**
> Object gitBaseBranchesRouteApiGitBaseBranchesGet(path)

Git Base Branches Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.gitBaseBranchesRouteApiGitBaseBranchesGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitBaseBranchesRouteApiGitBaseBranchesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitBranchSwitchRouteApiGitBranchSwitchPost**
> Object gitBranchSwitchRouteApiGitBranchSwitchPost(gitBranchSwitchBody)

Git Branch Switch Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitBranchSwitchBody gitBranchSwitchBody = ; // GitBranchSwitchBody | 

try {
    final response = api.gitBranchSwitchRouteApiGitBranchSwitchPost(gitBranchSwitchBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitBranchSwitchRouteApiGitBranchSwitchPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitBranchSwitchBody** | [**GitBranchSwitchBody**](GitBranchSwitchBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitBranchesRouteApiGitBranchesGet**
> Object gitBranchesRouteApiGitBranchesGet(path)

Git Branches Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.gitBranchesRouteApiGitBranchesGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitBranchesRouteApiGitBranchesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitCommitContextRouteApiGitReviewCommitContextGet**
> Object gitCommitContextRouteApiGitReviewCommitContextGet(path)

Git Commit Context Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.gitCommitContextRouteApiGitReviewCommitContextGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitCommitContextRouteApiGitReviewCommitContextGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitCommitRouteApiGitReviewCommitPost**
> Object gitCommitRouteApiGitReviewCommitPost(gitCommitBody)

Git Commit Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitCommitBody gitCommitBody = ; // GitCommitBody | 

try {
    final response = api.gitCommitRouteApiGitReviewCommitPost(gitCommitBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitCommitRouteApiGitReviewCommitPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitCommitBody** | [**GitCommitBody**](GitCommitBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitCreatePrRouteApiGitReviewCreatePrPost**
> Object gitCreatePrRouteApiGitReviewCreatePrPost(gitPathBody)

Git Create Pr Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitPathBody gitPathBody = ; // GitPathBody | 

try {
    final response = api.gitCreatePrRouteApiGitReviewCreatePrPost(gitPathBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitCreatePrRouteApiGitReviewCreatePrPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitPathBody** | [**GitPathBody**](GitPathBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitFileDiffRouteApiGitFileDiffGet**
> Object gitFileDiffRouteApiGitFileDiffGet(path, file)

Git File Diff Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 
final String file = file_example; // String | 

try {
    final response = api.gitFileDiffRouteApiGitFileDiffGet(path, file);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitFileDiffRouteApiGitFileDiffGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 
 **file** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitPrListRouteApiGitReviewPrListPost**
> Object gitPrListRouteApiGitReviewPrListPost(gitPrListBody)

Git Pr List Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitPrListBody gitPrListBody = ; // GitPrListBody | 

try {
    final response = api.gitPrListRouteApiGitReviewPrListPost(gitPrListBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitPrListRouteApiGitReviewPrListPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitPrListBody** | [**GitPrListBody**](GitPrListBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitPushRouteApiGitReviewPushPost**
> Object gitPushRouteApiGitReviewPushPost(gitPathBody)

Git Push Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitPathBody gitPathBody = ; // GitPathBody | 

try {
    final response = api.gitPushRouteApiGitReviewPushPost(gitPathBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitPushRouteApiGitReviewPushPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitPathBody** | [**GitPathBody**](GitPathBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitRevParseRouteApiGitReviewRevParseGet**
> Object gitRevParseRouteApiGitReviewRevParseGet(path, ref)

Git Rev Parse Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 
final String ref = ref_example; // String | 

try {
    final response = api.gitRevParseRouteApiGitReviewRevParseGet(path, ref);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitRevParseRouteApiGitReviewRevParseGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 
 **ref** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitRevertRouteApiGitReviewRevertPost**
> Object gitRevertRouteApiGitReviewRevertPost(gitFileBody)

Git Revert Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitFileBody gitFileBody = ; // GitFileBody | 

try {
    final response = api.gitRevertRouteApiGitReviewRevertPost(gitFileBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitRevertRouteApiGitReviewRevertPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitFileBody** | [**GitFileBody**](GitFileBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitReviewDiffRouteApiGitReviewDiffGet**
> Object gitReviewDiffRouteApiGitReviewDiffGet(path, file, scope, base_, staged)

Git Review Diff Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 
final String file = file_example; // String | 
final String scope = scope_example; // String | 
final String base_ = base__example; // String | 
final bool staged = true; // bool | 

try {
    final response = api.gitReviewDiffRouteApiGitReviewDiffGet(path, file, scope, base_, staged);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitReviewDiffRouteApiGitReviewDiffGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 
 **file** | **String**|  | 
 **scope** | **String**|  | [optional] [default to 'uncommitted']
 **base_** | **String**|  | [optional] 
 **staged** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitReviewListRouteApiGitReviewListGet**
> Object gitReviewListRouteApiGitReviewListGet(path, scope, base_)

Git Review List Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 
final String scope = scope_example; // String | 
final String base_ = base__example; // String | 

try {
    final response = api.gitReviewListRouteApiGitReviewListGet(path, scope, base_);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitReviewListRouteApiGitReviewListGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 
 **scope** | **String**|  | [optional] [default to 'uncommitted']
 **base_** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitShipInfoRouteApiGitReviewShipInfoGet**
> Object gitShipInfoRouteApiGitReviewShipInfoGet(path)

Git Ship Info Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.gitShipInfoRouteApiGitReviewShipInfoGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitShipInfoRouteApiGitReviewShipInfoGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitStageRouteApiGitReviewStagePost**
> Object gitStageRouteApiGitReviewStagePost(gitFileBody)

Git Stage Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitFileBody gitFileBody = ; // GitFileBody | 

try {
    final response = api.gitStageRouteApiGitReviewStagePost(gitFileBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitStageRouteApiGitReviewStagePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitFileBody** | [**GitFileBody**](GitFileBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitStatusRouteApiGitStatusGet**
> Object gitStatusRouteApiGitStatusGet(path)

Git Status Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.gitStatusRouteApiGitStatusGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitStatusRouteApiGitStatusGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitUnstageRouteApiGitReviewUnstagePost**
> Object gitUnstageRouteApiGitReviewUnstagePost(gitFileBody)

Git Unstage Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitFileBody gitFileBody = ; // GitFileBody | 

try {
    final response = api.gitUnstageRouteApiGitReviewUnstagePost(gitFileBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitUnstageRouteApiGitReviewUnstagePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitFileBody** | [**GitFileBody**](GitFileBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitWorktreeAddRouteApiGitWorktreeAddPost**
> Object gitWorktreeAddRouteApiGitWorktreeAddPost(gitWorktreeAddBody)

Git Worktree Add Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitWorktreeAddBody gitWorktreeAddBody = ; // GitWorktreeAddBody | 

try {
    final response = api.gitWorktreeAddRouteApiGitWorktreeAddPost(gitWorktreeAddBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitWorktreeAddRouteApiGitWorktreeAddPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitWorktreeAddBody** | [**GitWorktreeAddBody**](GitWorktreeAddBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitWorktreeRemoveRouteApiGitWorktreeRemovePost**
> Object gitWorktreeRemoveRouteApiGitWorktreeRemovePost(gitWorktreeRemoveBody)

Git Worktree Remove Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final GitWorktreeRemoveBody gitWorktreeRemoveBody = ; // GitWorktreeRemoveBody | 

try {
    final response = api.gitWorktreeRemoveRouteApiGitWorktreeRemovePost(gitWorktreeRemoveBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitWorktreeRemoveRouteApiGitWorktreeRemovePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gitWorktreeRemoveBody** | [**GitWorktreeRemoveBody**](GitWorktreeRemoveBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gitWorktreesRouteApiGitWorktreesGet**
> Object gitWorktreesRouteApiGitWorktreesGet(path)

Git Worktrees Route

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.gitWorktreesRouteApiGitWorktreesGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->gitWorktreesRouteApiGitWorktreesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost**
> Object grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost(profile)

Grant Computer Use Permissions

Spawn ``hermes computer-use permissions grant`` (macOS-only: launches CuaDriver via LaunchServices so the TCC dialog is attributed correctly). The frontend polls ``GET /api/actions/computer-use-grant/status``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **importBoardEndpointApiPluginsKanbanBoardsImportPost**
> Object importBoardEndpointApiPluginsKanbanBoardsImportPost(importBoardBody)

Import Board Endpoint

Import a board archive as a NEW board; return the landed board.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ImportBoardBody importBoardBody = ; // ImportBoardBody | 

try {
    final response = api.importBoardEndpointApiPluginsKanbanBoardsImportPost(importBoardBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->importBoardEndpointApiPluginsKanbanBoardsImportPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importBoardBody** | [**ImportBoardBody**](ImportBoardBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **importProfileEndpointApiProfilesImportPost**
> Object importProfileEndpointApiProfilesImportPost(profileImport)

Import Profile Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ProfileImport profileImport = ; // ProfileImport | 

try {
    final response = api.importProfileEndpointApiProfilesImportPost(profileImport);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->importProfileEndpointApiProfilesImportPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profileImport** | [**ProfileImport**](ProfileImport.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **importSessionsEndpointApiSessionsImportPost**
> Object importSessionsEndpointApiSessionsImportPost()

Import Sessions Endpoint

Import sessions exported from the dashboard or CLI (session rows only — ``/api/ops/import`` restores a whole backup archive).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.importSessionsEndpointApiSessionsImportPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->importSessionsEndpointApiSessionsImportPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet**
> Object inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet(runId, board)

Inspect Run Endpoint

Live psutil stats for a run's worker; ``{alive: false, reason}`` when unavailable and access-denied reported inline rather than as a 500.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int runId = 56; // int | 
final String board = board_example; // String | Kanban board slug (omit for current)

try {
    final response = api.inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet(runId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **runId** | **int**|  | 
 **board** | **String**| Kanban board slug (omit for current) | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **installMcpCatalogEntryApiMcpCatalogInstallPost**
> Object installMcpCatalogEntryApiMcpCatalogInstallPost(mCPCatalogInstall, profile)

Install Mcp Catalog Entry

Install a catalog MCP into config.yaml (declared env vars go to .env first; git-bootstrap entries run via the background CLI action path).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MCPCatalogInstall mCPCatalogInstall = ; // MCPCatalogInstall | 
final String profile = profile_example; // String | 

try {
    final response = api.installMcpCatalogEntryApiMcpCatalogInstallPost(mCPCatalogInstall, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->installMcpCatalogEntryApiMcpCatalogInstallPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **mCPCatalogInstall** | [**MCPCatalogInstall**](MCPCatalogInstall.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **installSkillHubApiSkillsHubInstallPost**
> Object installSkillHubApiSkillsHubInstallPost(skillInstallRequest, profile)

Install Skill Hub

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SkillInstallRequest skillInstallRequest = ; // SkillInstallRequest | 
final String profile = profile_example; // String | 

try {
    final response = api.installSkillHubApiSkillsHubInstallPost(skillInstallRequest, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->installSkillHubApiSkillsHubInstallPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **skillInstallRequest** | [**SkillInstallRequest**](SkillInstallRequest.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **instantiateBlueprintApiCronBlueprintsInstantiatePost**
> Object instantiateBlueprintApiCronBlueprintsInstantiatePost(automationBlueprintInstantiate, profile)

Instantiate Blueprint

Fill a blueprint's slots and create the cron job (form-submit path).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final AutomationBlueprintInstantiate automationBlueprintInstantiate = ; // AutomationBlueprintInstantiate | 
final String profile = profile_example; // String | 

try {
    final response = api.instantiateBlueprintApiCronBlueprintsInstantiatePost(automationBlueprintInstantiate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->instantiateBlueprintApiCronBlueprintsInstantiatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **automationBlueprintInstantiate** | [**AutomationBlueprintInstantiate**](AutomationBlueprintInstantiate.md)|  | 
 **profile** | **String**|  | [optional] [default to 'default']

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listActiveWorkersApiPluginsKanbanWorkersActiveGet**
> Object listActiveWorkersApiPluginsKanbanWorkersActiveGet(board)

List Active Workers

Every running worker: an open ``task_runs`` row with a ``worker_pid`` whose task is ``running``. Returns ``{workers, count, checked_at}``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String board = board_example; // String | Kanban board slug (omit for current)

try {
    final response = api.listActiveWorkersApiPluginsKanbanWorkersActiveGet(board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listActiveWorkersApiPluginsKanbanWorkersActiveGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **board** | **String**| Kanban board slug (omit for current) | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listBoardsApiPluginsKanbanBoardsGet**
> Object listBoardsApiPluginsKanbanBoardsGet(includeArchived)

List Boards

Every board on disk with task counts and the active slug.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final bool includeArchived = true; // bool | 

try {
    final response = api.listBoardsApiPluginsKanbanBoardsGet(includeArchived);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listBoardsApiPluginsKanbanBoardsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **includeArchived** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCheckpointsApiOpsCheckpointsGet**
> Object listCheckpointsApiOpsCheckpointsGet()

List Checkpoints

/rollback shadow-store checkpoints (read-only): count + size per session so the UI can show what a prune reclaims; pruning itself is a spawned CLI action so the confirmation logic stays in one place.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listCheckpointsApiOpsCheckpointsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listCheckpointsApiOpsCheckpointsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCredentialPoolApiCredentialsPoolGet**
> Object listCredentialPoolApiCredentialsPoolGet()

List Credential Pool

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listCredentialPoolApiCredentialsPoolGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listCredentialPoolApiCredentialsPoolGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCronBlueprintsApiCronBlueprintsGet**
> Object listCronBlueprintsApiCronBlueprintsGet()

List Cron Blueprints

Blueprint catalog as form schemas; the ``deliver`` slot's options are rewritten from the actually configured gateway platforms.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listCronBlueprintsApiCronBlueprintsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listCronBlueprintsApiCronBlueprintsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCronJobRunsApiCronJobsJobIdRunsGet**
> Object listCronJobRunsApiCronJobsJobIdRunsGet(jobId, profile, limit)

List Cron Job Runs

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 
final String profile = profile_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.listCronJobRunsApiCronJobsJobIdRunsGet(jobId, profile, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listCronJobRunsApiCronJobsJobIdRunsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **profile** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 20]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCronJobsApiCronJobsGet**
> Object listCronJobsApiCronJobsGet(profile)

List Cron Jobs

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.listCronJobsApiCronJobsGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listCronJobsApiCronJobsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] [default to 'all']

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCustomEndpointsApiProvidersCustomEndpointsGet**
> Object listCustomEndpointsApiProvidersCustomEndpointsGet(profile)

List Custom Endpoints

Return configured OpenAI-compatible custom endpoints for Desktop.  Scoped to the requested profile's config.yaml: the desktop settings UI targets the active profile, so read/write must resolve that profile's home rather than the process-level HERMES_HOME (mirrors ``/api/config``).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.listCustomEndpointsApiProvidersCustomEndpointsGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listCustomEndpointsApiProvidersCustomEndpointsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listDiagnosticsApiPluginsKanbanDiagnosticsGet**
> Object listDiagnosticsApiPluginsKanbanDiagnosticsGet(board, severity)

List Diagnostics

Tasks with an active diagnostic, highest severity first then most recent; also consumed by ``hermes kanban diagnostics`` when the dashboard runs.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String board = board_example; // String | Kanban board slug (omit for current)
final String severity = severity_example; // String | Filter by severity: warning|error|critical

try {
    final response = api.listDiagnosticsApiPluginsKanbanDiagnosticsGet(board, severity);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listDiagnosticsApiPluginsKanbanDiagnosticsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **board** | **String**| Kanban board slug (omit for current) | [optional] 
 **severity** | **String**| Filter by severity: warning|error|critical | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listHooksApiOpsHooksGet**
> Object listHooksApiOpsHooksGet()

List Hooks

Configured shell hooks with consent (allowlist) status, whether the script is currently executable, and the valid hook events for the form.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listHooksApiOpsHooksGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listHooksApiOpsHooksGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listKanbanProjectsApiPluginsKanbanProjectsGet**
> Object listKanbanProjectsApiPluginsKanbanProjectsGet()

List Kanban Projects

Live (non-archived) projects available for board scoping.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listKanbanProjectsApiPluginsKanbanProjectsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listKanbanProjectsApiPluginsKanbanProjectsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listManagedFilesApiFilesGet**
> Object listManagedFilesApiFilesGet(path)

List Managed Files

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.listManagedFilesApiFilesGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listManagedFilesApiFilesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listMcpCatalogApiMcpCatalogGet**
> Object listMcpCatalogApiMcpCatalogGet(profile, detectApps)

List Mcp Catalog

Browse the Nous-approved MCP catalog (optional-mcps/ manifests), each entry annotated with installed/enabled state for ``profile``. Opt-in app signals describe this backend machine, never the client or terminal sandbox.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 
final bool detectApps = true; // bool | 

try {
    final response = api.listMcpCatalogApiMcpCatalogGet(profile, detectApps);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listMcpCatalogApiMcpCatalogGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 
 **detectApps** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listMcpServersApiMcpServersGet**
> Object listMcpServersApiMcpServersGet(profile)

List Mcp Servers

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.listMcpServersApiMcpServersGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listMcpServersApiMcpServersGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listOauthProvidersApiProvidersOauthGet**
> Object listOauthProvidersApiProvidersOauthGet(profile)

List Oauth Providers

Every OAuth-capable provider with current status (token_preview is the last N chars, never the full token; disconnect_command only for external providers).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.listOauthProvidersApiProvidersOauthGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listOauthProvidersApiProvidersOauthGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listOfficialSkillsApiSkillsHubOfficialGet**
> Object listOfficialSkillsApiSkillsHubOfficialGet(profile)

List Official Skills

The ENTIRE optional-skills catalog (local scan), marked installed for ``profile``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.listOfficialSkillsApiSkillsHubOfficialGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listOfficialSkillsApiSkillsHubOfficialGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPairingApiPairingGet**
> Object listPairingApiPairingGet(profile)

List Pairing

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.listPairingApiPairingGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listPairingApiPairingGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listProfileRosterApiPluginsKanbanProfilesGet**
> Object listProfileRosterApiPluginsKanbanProfilesGet()

List Profile Roster

Every installed profile with its description (profiles without one are still routable on name alone, just less precisely).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listProfileRosterApiPluginsKanbanProfilesGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listProfileRosterApiPluginsKanbanProfilesGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listProfilesEndpointApiProfilesGet**
> Object listProfilesEndpointApiProfilesGet()

List Profiles Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listProfilesEndpointApiProfilesGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listProfilesEndpointApiProfilesGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listSkillsHubSourcesApiSkillsHubSourcesGet**
> Object listSkillsHubSourcesApiSkillsHubSourcesGet(profile)

List Skills Hub Sources

Configured skill-hub sources + installed-skill provenance (scoped to ``profile``), so the Browse-hub tab has something before a search runs.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.listSkillsHubSourcesApiSkillsHubSourcesGet(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listSkillsHubSourcesApiSkillsHubSourcesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listTaskAttachmentsApiPluginsKanbanTasksTaskIdAttachmentsGet**
> Object listTaskAttachmentsApiPluginsKanbanTasksTaskIdAttachmentsGet(taskId, board)

List Task Attachments

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String board = board_example; // String | 

try {
    final response = api.listTaskAttachmentsApiPluginsKanbanTasksTaskIdAttachmentsGet(taskId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listTaskAttachmentsApiPluginsKanbanTasksTaskIdAttachmentsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listWebhooksApiWebhooksGet**
> Object listWebhooksApiWebhooksGet()

List Webhooks

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.listWebhooksApiWebhooksGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listWebhooksApiWebhooksGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsActivateApiLocalModelsActivatePost**
> Object localModelsActivateApiLocalModelsActivatePost(modelActivateBody)

Local Models Activate

Make a downloaded model the default for new chats: a config write via the same machinery as /api/model/set plus making sure the server is up. NO model loading (residency v2: models load on first inference; an empty router costs nothing). Kept as a job for UI continuity.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ModelActivateBody modelActivateBody = ; // ModelActivateBody | 

try {
    final response = api.localModelsActivateApiLocalModelsActivatePost(modelActivateBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsActivateApiLocalModelsActivatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **modelActivateBody** | [**ModelActivateBody**](ModelActivateBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsCatalogApiLocalModelsCatalogGet**
> Object localModelsCatalogApiLocalModelsCatalogGet()

Local Models Catalog

Every entry answers up front: how big is the download, will it fit, what context/speed shape will I get. The row advertises the BEST build for this machine (highest quality fully on GPU at the 64K floor; else the smallest that works, spilled and priced). No entry is hidden; unaffordable models show WHY. Sync def: blocking I/O -> threadpool.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.localModelsCatalogApiLocalModelsCatalogGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsCatalogApiLocalModelsCatalogGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsDeleteApiLocalModelsModelsModelIdDelete**
> Object localModelsDeleteApiLocalModelsModelsModelIdDelete(modelId)

Local Models Delete

Remove every split part plus private assets, then bounce the router off the request thread (deleting the active file mid-serve is exactly the stale state the refresh exists for).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String modelId = modelId_example; // String | 

try {
    final response = api.localModelsDeleteApiLocalModelsModelsModelIdDelete(modelId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsDeleteApiLocalModelsModelsModelIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **modelId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsDownloadApiLocalModelsDownloadPost**
> Object localModelsDownloadApiLocalModelsDownloadPost(modelDownloadBody)

Local Models Download

Accepts either a family id (downloads this machine's selected variant) or an exact variant model_id.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ModelDownloadBody modelDownloadBody = ; // ModelDownloadBody | 

try {
    final response = api.localModelsDownloadApiLocalModelsDownloadPost(modelDownloadBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsDownloadApiLocalModelsDownloadPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **modelDownloadBody** | [**ModelDownloadBody**](ModelDownloadBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsDownloadBrowsedApiLocalModelsDownloadBrowsedPost**
> Object localModelsDownloadBrowsedApiLocalModelsDownloadBrowsedPost(browsedDownloadBody)

Local Models Download Browsed

Download an arbitrary HF GGUF into the managed models dir. Once landed it is a normal staged model (the post-download bounce regenerates presets from its real header); with no catalog entry it serves 'unverified', capabilities answered from the live server only.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final BrowsedDownloadBody browsedDownloadBody = ; // BrowsedDownloadBody | 

try {
    final response = api.localModelsDownloadBrowsedApiLocalModelsDownloadBrowsedPost(browsedDownloadBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsDownloadBrowsedApiLocalModelsDownloadBrowsedPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **browsedDownloadBody** | [**BrowsedDownloadBody**](BrowsedDownloadBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsEjectApiLocalModelsEjectPost**
> Object localModelsEjectApiLocalModelsEjectPost(modelEjectBody)

Local Models Eject

Free a loaded model's GPU memory now; only demand (the next message) reloads it — residency v2 has no automatic loading anywhere. Sync def: the fallback path blocks on a 120s urlopen — threadpool, never the loop.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ModelEjectBody modelEjectBody = ; // ModelEjectBody | 

try {
    final response = api.localModelsEjectApiLocalModelsEjectPost(modelEjectBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsEjectApiLocalModelsEjectPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **modelEjectBody** | [**ModelEjectBody**](ModelEjectBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsHardwareApiLocalModelsHardwareGet**
> Object localModelsHardwareApiLocalModelsHardwareGet()

Local Models Hardware

The budget as plain facts, polled by the pane and statusbar. Sync def: shells out to nvidia-smi — threadpool.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.localModelsHardwareApiLocalModelsHardwareGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsHardwareApiLocalModelsHardwareGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsJobApiLocalModelsJobsJobIdGet**
> Object localModelsJobApiLocalModelsJobsJobIdGet(jobId)

Local Models Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 

try {
    final response = api.localModelsJobApiLocalModelsJobsJobIdGet(jobId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsJobApiLocalModelsJobsJobIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsJobsApiLocalModelsJobsGet**
> Object localModelsJobsApiLocalModelsJobsGet()

Local Models Jobs

All recent jobs, running first — the pane and app-level poller rediscover in-flight work here after a remount.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.localModelsJobsApiLocalModelsJobsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsJobsApiLocalModelsJobsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsQuickstartApiLocalModelsQuickstartPost**
> Object localModelsQuickstartApiLocalModelsQuickstartPost(quickstartBody)

Local Models Quickstart

One job: install the runtime (if missing), download this machine's build of the recommended model (if missing), make it the default. Each leg uses the same code as the individual setup routes. Preflight rejects (no automatic recommendation or no servable choice) fail the POST synchronously so the button can explain itself; everything slow runs in the job with phase/byte progress.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final QuickstartBody quickstartBody = ; // QuickstartBody | 

try {
    final response = api.localModelsQuickstartApiLocalModelsQuickstartPost(quickstartBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsQuickstartApiLocalModelsQuickstartPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **quickstartBody** | [**QuickstartBody**](QuickstartBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsRuntimeInstallApiLocalModelsRuntimeInstallPost**
> Object localModelsRuntimeInstallApiLocalModelsRuntimeInstallPost(runtimeInstallBody)

Local Models Runtime Install

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final RuntimeInstallBody runtimeInstallBody = ; // RuntimeInstallBody | 

try {
    final response = api.localModelsRuntimeInstallApiLocalModelsRuntimeInstallPost(runtimeInstallBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsRuntimeInstallApiLocalModelsRuntimeInstallPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **runtimeInstallBody** | [**RuntimeInstallBody**](RuntimeInstallBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsSearchApiLocalModelsSearchGet**
> Object localModelsSearchApiLocalModelsSearchGet(q, limit)

Local Models Search

Full-text HF search over GGUF models — the firehose behind the curated catalog; fit pills come from /search/files.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String q = q_example; // String | 
final int limit = 56; // int | 

try {
    final response = api.localModelsSearchApiLocalModelsSearchGet(q, limit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsSearchApiLocalModelsSearchGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **q** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 20]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsSearchFilesApiLocalModelsSearchFilesGet**
> Object localModelsSearchFilesApiLocalModelsSearchFilesGet(repo)

Local Models Search Files

Servable GGUFs in one HF repo with a rough pre-download fit verdict per quant (file size + conservative fill-ins; the GGUF header refines it).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String repo = repo_example; // String | 

try {
    final response = api.localModelsSearchFilesApiLocalModelsSearchFilesGet(repo);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsSearchFilesApiLocalModelsSearchFilesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **repo** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsServerApiLocalModelsServerPost**
> Object localModelsServerApiLocalModelsServerPost(serverActionBody)

Local Models Server

Turn the local engine off (stop the server, free ALL GPU memory, disable auto-start) or back on. Unlike per-model eject the off switch IS durable: the user said off, so boots stay off until they say on.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ServerActionBody serverActionBody = ; // ServerActionBody | 

try {
    final response = api.localModelsServerApiLocalModelsServerPost(serverActionBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsServerApiLocalModelsServerPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **serverActionBody** | [**ServerActionBody**](ServerActionBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsSideloadApiLocalModelsSideloadPost**
> Object localModelsSideloadApiLocalModelsSideloadPost(sideloadBody)

Local Models Sideload

Register a GGUF already on this machine: link it into the managed models dir (copy only when linking is impossible) and bounce the router. The original stays put; delete-from-Hermes removes only our link.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SideloadBody sideloadBody = ; // SideloadBody | 

try {
    final response = api.localModelsSideloadApiLocalModelsSideloadPost(sideloadBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsSideloadApiLocalModelsSideloadPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sideloadBody** | [**SideloadBody**](SideloadBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **localModelsStatusApiLocalModelsStatusGet**
> Object localModelsStatusApiLocalModelsStatusGet()

Local Models Status

Cheap, immediate: config state + installed runtime + staged models + supervisor state (GPU facts live in /hardware). Sync def on purpose: blocking urlopen/scans run in the threadpool.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.localModelsStatusApiLocalModelsStatusGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->localModelsStatusApiLocalModelsStatusGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **loginPageLoginGet**
> Object loginPageLoginGet()

Login Page

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.loginPageLoginGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->loginPageLoginGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **mcpOauthCallbackApiMcpOauthCallbackServerNameGet**
> Object mcpOauthCallbackApiMcpOauthCallbackServerNameGet(serverName, code, state, error, iss)

Mcp Oauth Callback

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String serverName = serverName_example; // String | 
final String code = code_example; // String | 
final String state = state_example; // String | 
final String error = error_example; // String | 
final String iss = iss_example; // String | 

try {
    final response = api.mcpOauthCallbackApiMcpOauthCallbackServerNameGet(serverName, code, state, error, iss);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->mcpOauthCallbackApiMcpOauthCallbackServerNameGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **serverName** | **String**|  | 
 **code** | **String**|  | [optional] 
 **state** | **String**|  | [optional] 
 **error** | **String**|  | [optional] 
 **iss** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet**
> Object mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet(flowId)

Mcp Oauth Flow Status

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String flowId = flowId_example; // String | 

try {
    final response = api.mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet(flowId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **flowId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **memoryOauthStatusApiMemoryProvidersProviderOauthStatusGet**
> Object memoryOauthStatusApiMemoryProvidersProviderOauthStatusGet(provider, profile)

Memory Oauth Status

Poll a provider's OAuth flow: idle | pending | connected | error.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String provider = provider_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.memoryOauthStatusApiMemoryProvidersProviderOauthStatusGet(provider, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->memoryOauthStatusApiMemoryProvidersProviderOauthStatusGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **modelOptionsApiPluginsKanbanModelOptionsGet**
> Object modelOptionsApiPluginsKanbanModelOptionsGet()

Model Options

Providers + curated models for the override dropdown via ``inventory.build_models_payload`` (same substrate as the Models page) so it can't offer a pair Hermes rejects. Skips pricing and custom-provider probes: a slow/offline local endpoint must not hang the drawer.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.modelOptionsApiPluginsKanbanModelOptionsGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->modelOptionsApiPluginsKanbanModelOptionsGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **openProfileTerminalEndpointApiProfilesNameOpenTerminalPost**
> Object openProfileTerminalEndpointApiProfilesNameOpenTerminalPost(name)

Open Profile Terminal Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.openProfileTerminalEndpointApiProfilesNameOpenTerminalPost(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->openProfileTerminalEndpointApiProfilesNameOpenTerminalPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **pauseCronJobApiCronJobsJobIdPausePost**
> Object pauseCronJobApiCronJobsJobIdPausePost(jobId, profile)

Pause Cron Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.pauseCronJobApiCronJobsJobIdPausePost(jobId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->pauseCronJobApiCronJobsJobIdPausePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet**
> Object pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet(providerId, sessionId, profile)

Poll Oauth Session

Poll a session's status (no auth — read-only state). One endpoint serves every device-code flow: all report progress via the worker-updated ``status``.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String providerId = providerId_example; // String | 
final String sessionId = sessionId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet(providerId, sessionId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **providerId** | **String**|  | 
 **sessionId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost**
> Object postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost(name)

Post Agent Plugin Disable

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost**
> Object postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost(name)

Post Agent Plugin Enable

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postAgentPluginInstallApiDashboardAgentPluginsInstallPost**
> Object postAgentPluginInstallApiDashboardAgentPluginsInstallPost(agentPluginInstallBody)

Post Agent Plugin Install

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final AgentPluginInstallBody agentPluginInstallBody = ; // AgentPluginInstallBody | 

try {
    final response = api.postAgentPluginInstallApiDashboardAgentPluginsInstallPost(agentPluginInstallBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postAgentPluginInstallApiDashboardAgentPluginsInstallPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **agentPluginInstallBody** | [**AgentPluginInstallBody**](AgentPluginInstallBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost**
> Object postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost(name)

Post Agent Plugin Update

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 

try {
    final response = api.postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost(name);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postHealthRetirementApiHealthRetirementPost**
> Object postHealthRetirementApiHealthRetirementPost()

Post Health Retirement

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.postHealthRetirementApiHealthRetirementPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postHealthRetirementApiHealthRetirementPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postPluginVisibilityApiDashboardPluginsNameVisibilityPost**
> Object postPluginVisibilityApiDashboardPluginsNameVisibilityPost(name, pluginVisibilityBody)

Post Plugin Visibility

Toggle a plugin's sidebar visibility (persists to config.yaml dashboard.hidden_plugins).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final PluginVisibilityBody pluginVisibilityBody = ; // PluginVisibilityBody | 

try {
    final response = api.postPluginVisibilityApiDashboardPluginsNameVisibilityPost(name, pluginVisibilityBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postPluginVisibilityApiDashboardPluginsNameVisibilityPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **pluginVisibilityBody** | [**PluginVisibilityBody**](PluginVisibilityBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **postProfilesSessionsPullRequestsApiProfilesSessionsPullRequestsPost**
> Object postProfilesSessionsPullRequestsApiProfilesSessionsPullRequestsPost(sessionPrScanBody)

Post Profiles Sessions Pull Requests

The PR each of these sessions opened, recovered from its own transcript: a session that starts in the main checkout and works in a worktree has no branch of its own, so its PR is invisible to the branch join — but ``gh pr create`` ran in the conversation (see ``_pr_url_from_tool_output``). Read-only across every profile.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SessionPrScanBody sessionPrScanBody = ; // SessionPrScanBody | 

try {
    final response = api.postProfilesSessionsPullRequestsApiProfilesSessionsPullRequestsPost(sessionPrScanBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->postProfilesSessionsPullRequestsApiProfilesSessionsPullRequestsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionPrScanBody** | [**SessionPrScanBody**](SessionPrScanBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewSkillHubApiSkillsHubPreviewGet**
> Object previewSkillHubApiSkillsHubPreviewGet(identifier, profile)

Preview Skill Hub

A hub skill's SKILL.md + file manifest WITHOUT installing it; scoped to ``profile`` so different hub taps resolve against THAT source router.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String identifier = identifier_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.previewSkillHubApiSkillsHubPreviewGet(identifier, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->previewSkillHubApiSkillsHubPreviewGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **identifier** | **String**|  | [optional] [default to '']
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **pruneCheckpointsApiOpsCheckpointsPrunePost**
> Object pruneCheckpointsApiOpsCheckpointsPrunePost()

Prune Checkpoints

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.pruneCheckpointsApiOpsCheckpointsPrunePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->pruneCheckpointsApiOpsCheckpointsPrunePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **pruneSessionsEndpointApiSessionsPrunePost**
> Object pruneSessionsEndpointApiSessionsPrunePost(sessionPrune)

Prune Sessions Endpoint

Delete ended sessions matching filters without blocking the event loop.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SessionPrune sessionPrune = ; // SessionPrune | 

try {
    final response = api.pruneSessionsEndpointApiSessionsPrunePost(sessionPrune);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->pruneSessionsEndpointApiSessionsPrunePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionPrune** | [**SessionPrune**](SessionPrune.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **putPluginProvidersApiDashboardPluginProvidersPut**
> Object putPluginProvidersApiDashboardPluginProvidersPut(pluginProvidersPutBody)

Put Plugin Providers

Persist memory provider / context engine selection (writes config.yaml).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final PluginProvidersPutBody pluginProvidersPutBody = ; // PluginProvidersPutBody | 

try {
    final response = api.putPluginProvidersApiDashboardPluginProvidersPut(pluginProvidersPutBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->putPluginProvidersApiDashboardPluginProvidersPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pluginProvidersPutBody** | [**PluginProvidersPutBody**](PluginProvidersPutBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **readManagedFileApiFilesReadGet**
> Object readManagedFileApiFilesReadGet(path)

Read Managed File

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.readManagedFileApiFilesReadGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->readManagedFileApiFilesReadGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reassignTaskEndpointApiPluginsKanbanTasksTaskIdReassignPost**
> Object reassignTaskEndpointApiPluginsKanbanTasksTaskIdReassignPost(taskId, reassignBody, board)

Reassign Task Endpoint

Reassign to another profile, optionally reclaiming first (``hermes kanban reassign <task_id> <profile> [--reclaim]``).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final ReassignBody reassignBody = ; // ReassignBody | 
final String board = board_example; // String | 

try {
    final response = api.reassignTaskEndpointApiPluginsKanbanTasksTaskIdReassignPost(taskId, reassignBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->reassignTaskEndpointApiPluginsKanbanTasksTaskIdReassignPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **reassignBody** | [**ReassignBody**](ReassignBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **recentUnlocksApiPluginsHermesAchievementsRecentUnlocksGet**
> Object recentUnlocksApiPluginsHermesAchievementsRecentUnlocksGet()

Recent Unlocks

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.recentUnlocksApiPluginsHermesAchievementsRecentUnlocksGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->recentUnlocksApiPluginsHermesAchievementsRecentUnlocksGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost**
> Object reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost(taskId, reclaimBody, board)

Reclaim Task Endpoint

Release an active worker claim without waiting for the claim TTL (``hermes kanban reclaim <task_id> --reason ...``).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final ReclaimBody reclaimBody = ; // ReclaimBody | 
final String board = board_example; // String | 

try {
    final response = api.reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost(taskId, reclaimBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **reclaimBody** | [**ReclaimBody**](ReclaimBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete**
> Object removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete(attachmentId, board)

Remove Attachment

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int attachmentId = 56; // int | 
final String board = board_example; // String | 

try {
    final response = api.removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete(attachmentId, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **attachmentId** | **int**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **removeCredentialPoolEntryApiCredentialsPoolProviderIndexDelete**
> Object removeCredentialPoolEntryApiCredentialsPoolProviderIndexDelete(provider, index)

Remove Credential Pool Entry

Remove a pool entry (``index`` is 1-based, as listed).  Removal must be sticky: ``load_pool()`` re-seeds entries from their backing source (.env var, OAuth file, custom-provider config) on every call, so deleting only the row silently reverts on the next refresh. Dispatch through the same RemovalStep registry as ``hermes auth remove``: each source cleans its external state and suppresses ``(provider, source)`` so seeders skip it. Manual entries have no step — nothing external, and they aren't re-seeded.  See #55217.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String provider = provider_example; // String | 
final int index = 56; // int | 

try {
    final response = api.removeCredentialPoolEntryApiCredentialsPoolProviderIndexDelete(provider, index);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->removeCredentialPoolEntryApiCredentialsPoolProviderIndexDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | 
 **index** | **int**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **removeEnvVarApiEnvDelete**
> Object removeEnvVarApiEnvDelete(envVarDelete, profile)

Remove Env Var

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final EnvVarDelete envVarDelete = ; // EnvVarDelete | 
final String profile = profile_example; // String | 

try {
    final response = api.removeEnvVarApiEnvDelete(envVarDelete, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->removeEnvVarApiEnvDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **envVarDelete** | [**EnvVarDelete**](EnvVarDelete.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **removeMcpServerApiMcpServersNameDelete**
> Object removeMcpServerApiMcpServersNameDelete(name, profile)

Remove Mcp Server

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.removeMcpServerApiMcpServersNameDelete(name, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->removeMcpServerApiMcpServersNameDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **renameBoardApiPluginsKanbanBoardsSlugPatch**
> Object renameBoardApiPluginsKanbanBoardsSlugPatch(slug, renameBoardBody)

Rename Board

Update display metadata / default workdir / project scope (slug is immutable).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String slug = slug_example; // String | 
final RenameBoardBody renameBoardBody = ; // RenameBoardBody | 

try {
    final response = api.renameBoardApiPluginsKanbanBoardsSlugPatch(slug, renameBoardBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->renameBoardApiPluginsKanbanBoardsSlugPatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **renameBoardBody** | [**RenameBoardBody**](RenameBoardBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **renameProfileEndpointApiProfilesNamePatch**
> Object renameProfileEndpointApiProfilesNamePatch(name, profileRename)

Rename Profile Endpoint

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ProfileRename profileRename = ; // ProfileRename | 

try {
    final response = api.renameProfileEndpointApiProfilesNamePatch(name, profileRename);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->renameProfileEndpointApiProfilesNamePatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profileRename** | [**ProfileRename**](ProfileRename.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **renameSessionEndpointApiSessionsSessionIdPatch**
> Object renameSessionEndpointApiSessionsSessionIdPatch(sessionId, sessionRename)

Rename Session Endpoint

Update ``title`` (empty clears) and/or the flags; ``pinned`` exempts from the auto-archive sweep, ``unread=False`` marks read up to now.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 
final SessionRename sessionRename = ; // SessionRename | 

try {
    final response = api.renameSessionEndpointApiSessionsSessionIdPatch(sessionId, sessionRename);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->renameSessionEndpointApiSessionsSessionIdPatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 
 **sessionRename** | [**SessionRename**](SessionRename.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **replaceMcpServersApiMcpServersPut**
> Object replaceMcpServersApiMcpServersPut(mCPServersReplace, profile)

Replace Mcp Servers

Replace the entire ``mcp_servers`` map (the mcp.json editor's save) — the deep-merging ``/api/config`` can never delete a key or drop an ``enabled: false``, so removals wouldn't persist through it.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MCPServersReplace mCPServersReplace = ; // MCPServersReplace | 
final String profile = profile_example; // String | 

try {
    final response = api.replaceMcpServersApiMcpServersPut(mCPServersReplace, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->replaceMcpServersApiMcpServersPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **mCPServersReplace** | [**MCPServersReplace**](MCPServersReplace.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **rescanApiPluginsHermesAchievementsRescanPost**
> Object rescanApiPluginsHermesAchievementsRescanPost()

Rescan

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.rescanApiPluginsHermesAchievementsRescanPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->rescanApiPluginsHermesAchievementsRescanPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **rescanDashboardPluginsApiDashboardPluginsRescanGet**
> Object rescanDashboardPluginsApiDashboardPluginsRescanGet()

Rescan Dashboard Plugins

Force re-scan of dashboard plugins.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.rescanDashboardPluginsApiDashboardPluginsRescanGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->rescanDashboardPluginsApiDashboardPluginsRescanGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resetMemoryApiMemoryResetPost**
> Object resetMemoryApiMemoryResetPost(memoryReset)

Reset Memory

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MemoryReset memoryReset = ; // MemoryReset | 

try {
    final response = api.resetMemoryApiMemoryResetPost(memoryReset);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->resetMemoryApiMemoryResetPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **memoryReset** | [**MemoryReset**](MemoryReset.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resetStateApiPluginsHermesAchievementsResetStatePost**
> Object resetStateApiPluginsHermesAchievementsResetStatePost()

Reset State

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.resetStateApiPluginsHermesAchievementsResetStatePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->resetStateApiPluginsHermesAchievementsResetStatePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **restartGatewayApiGatewayRestartPost**
> Object restartGatewayApiGatewayRestartPost(profile)

Restart Gateway

Kick off a ``hermes gateway restart`` in the background.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.restartGatewayApiGatewayRestartPost(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->restartGatewayApiGatewayRestartPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resumeCronJobApiCronJobsJobIdResumePost**
> Object resumeCronJobApiCronJobsJobIdResumePost(jobId, profile)

Resume Cron Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.resumeCronJobApiCronJobsJobIdResumePost(jobId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->resumeCronJobApiCronJobsJobIdResumePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **revealEnvVarApiEnvRevealPost**
> Object revealEnvVarApiEnvRevealPost(envVarReveal, profile)

Reveal Env Var

Return the real (unredacted) value of a single env var.  Protected by the ephemeral session token (per server start, injected into the SPA), rate limiting (max 5 reveals per 30s window) and audit logging.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final EnvVarReveal envVarReveal = ; // EnvVarReveal | 
final String profile = profile_example; // String | 

try {
    final response = api.revealEnvVarApiEnvRevealPost(envVarReveal, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->revealEnvVarApiEnvRevealPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **envVarReveal** | [**EnvVarReveal**](EnvVarReveal.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **revokePairingApiPairingRevokePost**
> Object revokePairingApiPairingRevokePost(pairingRevoke)

Revoke Pairing

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final PairingRevoke pairingRevoke = ; // PairingRevoke | 

try {
    final response = api.revokePairingApiPairingRevokePost(pairingRevoke);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->revokePairingApiPairingRevokePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pairingRevoke** | [**PairingRevoke**](PairingRevoke.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runBackupApiOpsBackupPost**
> Object runBackupApiOpsBackupPost(backupRequest)

Run Backup

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final BackupRequest backupRequest = ; // BackupRequest | 

try {
    final response = api.runBackupApiOpsBackupPost(backupRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runBackupApiOpsBackupPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **backupRequest** | [**BackupRequest**](BackupRequest.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runConfigMigrateApiOpsConfigMigratePost**
> Object runConfigMigrateApiOpsConfigMigratePost()

Run Config Migrate

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.runConfigMigrateApiOpsConfigMigratePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runConfigMigrateApiOpsConfigMigratePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runCuratorApiCuratorRunPost**
> Object runCuratorApiCuratorRunPost()

Run Curator

Trigger a curator review now (backgrounded; tail via action status).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.runCuratorApiCuratorRunPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runCuratorApiCuratorRunPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runDebugShareEndpointApiOpsDebugSharePost**
> Object runDebugShareEndpointApiOpsDebugSharePost(debugShareRequest)

Run Debug Share Endpoint

Upload a redacted debug report + full logs and return the paste URLs. Synchronous, unlike the other diagnostics actions: the point is the shareable URLs, returned as a structured payload the dashboard renders as copyable links.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final DebugShareRequest debugShareRequest = ; // DebugShareRequest | 

try {
    final response = api.runDebugShareEndpointApiOpsDebugSharePost(debugShareRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runDebugShareEndpointApiOpsDebugSharePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **debugShareRequest** | [**DebugShareRequest**](DebugShareRequest.md)|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runDoctorApiOpsDoctorPost**
> Object runDoctorApiOpsDoctorPost()

Run Doctor

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.runDoctorApiOpsDoctorPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runDoctorApiOpsDoctorPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runDumpApiOpsDumpPost**
> Object runDumpApiOpsDumpPost()

Run Dump

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.runDumpApiOpsDumpPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runDumpApiOpsDumpPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runImportApiOpsImportPost**
> Object runImportApiOpsImportPost(importRequest)

Run Import

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ImportRequest importRequest = ; // ImportRequest | 

try {
    final response = api.runImportApiOpsImportPost(importRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runImportApiOpsImportPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importRequest** | [**ImportRequest**](ImportRequest.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runImportUploadApiOpsImportUploadPost**
> Object runImportUploadApiOpsImportUploadPost(file, force)

Run Import Upload

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MultipartFile file = BINARY_DATA_HERE; // MultipartFile | 
final bool force = true; // bool | 

try {
    final response = api.runImportUploadApiOpsImportUploadPost(file, force);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runImportUploadApiOpsImportUploadPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **file** | **MultipartFile**|  | 
 **force** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: multipart/form-data
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runPromptSizeApiOpsPromptSizePost**
> Object runPromptSizeApiOpsPromptSizePost()

Run Prompt Size

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.runPromptSizeApiOpsPromptSizePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runPromptSizeApiOpsPromptSizePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runSecurityAuditApiOpsSecurityAuditPost**
> Object runSecurityAuditApiOpsSecurityAuditPost()

Run Security Audit

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.runSecurityAuditApiOpsSecurityAuditPost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runSecurityAuditApiOpsSecurityAuditPost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runToolsetPostSetupApiToolsToolsetsNamePostSetupPost**
> Object runToolsetPostSetupApiToolsToolsetsNamePostSetupPost(name, toolsetPostSetup, profile)

Run Toolset Post Setup

Spawn ``hermes tools post-setup <key>`` (long-running installs) as a background action tailed via ``GET /api/actions/tools-post-setup/status``; ``profile`` is threaded so hooks see the drawer's HERMES_HOME.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ToolsetPostSetup toolsetPostSetup = ; // ToolsetPostSetup | 
final String profile = profile_example; // String | 

try {
    final response = api.runToolsetPostSetupApiToolsToolsetsNamePostSetupPost(name, toolsetPostSetup, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->runToolsetPostSetupApiToolsToolsetsNamePostSetupPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **toolsetPostSetup** | [**ToolsetPostSetup**](ToolsetPostSetup.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **saveToolsetEnvApiToolsToolsetsNameEnvPut**
> Object saveToolsetEnvApiToolsToolsetsNameEnvPut(name, toolsetEnvUpdate, profile)

Save Toolset Env

Persist API keys to ``.env`` via ``save_env_value``.  Keys are validated against the union of the category's visible-provider ``env_vars`` so this can't write arbitrary env vars; a blank value means \"leave unchanged\".

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ToolsetEnvUpdate toolsetEnvUpdate = ; // ToolsetEnvUpdate | 
final String profile = profile_example; // String | 

try {
    final response = api.saveToolsetEnvApiToolsToolsetsNameEnvPut(name, toolsetEnvUpdate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->saveToolsetEnvApiToolsToolsetsNameEnvPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **toolsetEnvUpdate** | [**ToolsetEnvUpdate**](ToolsetEnvUpdate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **scanSkillHubApiSkillsHubScanGet**
> Object scanSkillHubApiSkillsHubScanGet(identifier, profile)

Scan Skill Hub

Install-time security scan of a hub skill WITHOUT installing it (the CLI's ``scan_skill`` / ``should_allow_install`` pipeline on a quarantined bundle); scoped to ``profile`` so the bundle resolves where an install would.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String identifier = identifier_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.scanSkillHubApiSkillsHubScanGet(identifier, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->scanSkillHubApiSkillsHubScanGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **identifier** | **String**|  | [optional] [default to '']
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **scanStatusApiPluginsHermesAchievementsScanStatusGet**
> Object scanStatusApiPluginsHermesAchievementsScanStatusGet()

Scan Status

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.scanStatusApiPluginsHermesAchievementsScanStatusGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->scanStatusApiPluginsHermesAchievementsScanStatusGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **searchSessionsApiSessionsSearchGet**
> Object searchSessionsApiSessionsSearchGet(q, limit, profile, source_, sources, excludeSources)

Search Sessions

Search sessions by ID (first) plus FTS5 message content.  Results are deduped by compression lineage, not raw ``session_id``: auto-compression rotates a chat onto a fresh id and leaves the old segment in the FTS index.  Branches also use ``parent_session_id`` but are real alternate conversations — they are NOT collapsed into the parent.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String q = q_example; // String | 
final int limit = 56; // int | 
final String profile = profile_example; // String | 
final String source_ = source__example; // String | 
final String sources = sources_example; // String | 
final String excludeSources = excludeSources_example; // String | 

try {
    final response = api.searchSessionsApiSessionsSearchGet(q, limit, profile, source_, sources, excludeSources);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->searchSessionsApiSessionsSearchGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **q** | **String**|  | [optional] [default to '']
 **limit** | **int**|  | [optional] [default to 20]
 **profile** | **String**|  | [optional] 
 **source_** | **String**|  | [optional] 
 **sources** | **String**|  | [optional] 
 **excludeSources** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **searchSkillsHubApiSkillsHubSearchGet**
> Object searchSkillsHubApiSkillsHubSearchGet(q, source_, limit, profile)

Search Skills Hub

Search the skill hub across all configured sources (network-bound).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String q = q_example; // String | 
final String source_ = source__example; // String | 
final int limit = 56; // int | 
final String profile = profile_example; // String | 

try {
    final response = api.searchSkillsHubApiSkillsHubSearchGet(q, source_, limit, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->searchSkillsHubApiSkillsHubSearchGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **q** | **String**|  | [optional] [default to '']
 **source_** | **String**|  | [optional] [default to 'all']
 **limit** | **int**|  | [optional] [default to 20]
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **selectTerminalBackendApiToolsTerminalBackendPut**
> Object selectTerminalBackendApiToolsTerminalBackendPut(terminalBackendSelect, profile)

Select Terminal Backend

Persist ``terminal.backend``.  A backend that still needs setup is allowed — the picker shows guidance instead of blocking, like the CLI.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final TerminalBackendSelect terminalBackendSelect = ; // TerminalBackendSelect | 
final String profile = profile_example; // String | 

try {
    final response = api.selectTerminalBackendApiToolsTerminalBackendPut(terminalBackendSelect, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->selectTerminalBackendApiToolsTerminalBackendPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **terminalBackendSelect** | [**TerminalBackendSelect**](TerminalBackendSelect.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **selectToolsetModelApiToolsToolsetsNameModelPut**
> Object selectToolsetModelApiToolsToolsetsNameModelPut(name, toolsetModelSelect, profile)

Select Toolset Model

Persist a backend model selection (``image_gen.model`` / ``video_gen.model``), validated against the resolved backend's catalog.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ToolsetModelSelect toolsetModelSelect = ; // ToolsetModelSelect | 
final String profile = profile_example; // String | 

try {
    final response = api.selectToolsetModelApiToolsToolsetsNameModelPut(name, toolsetModelSelect, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->selectToolsetModelApiToolsToolsetsNameModelPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **toolsetModelSelect** | [**ToolsetModelSelect**](ToolsetModelSelect.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **selectToolsetProviderApiToolsToolsetsNameProviderPut**
> Object selectToolsetProviderApiToolsToolsetsNameProviderPut(name, toolsetProviderSelect, profile)

Select Toolset Provider

Persist a provider selection via ``apply_provider_selection`` (shared with ``hermes tools``, so both write identical keys).  ``web`` only: ``capability`` ('search' | 'extract') writes ``web.<capability>_backend`` (the override the dispatchers resolve first); omitted -> legacy ``web.backend``.  Managed Nous rows report Portal entitlement (``needs_nous_auth`` + ``feature``): the GUI has no inline login, so an unentitled selection would write config and never activate.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ToolsetProviderSelect toolsetProviderSelect = ; // ToolsetProviderSelect | 
final String profile = profile_example; // String | 

try {
    final response = api.selectToolsetProviderApiToolsToolsetsNameProviderPut(name, toolsetProviderSelect, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->selectToolsetProviderApiToolsToolsetsNameProviderPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **toolsetProviderSelect** | [**ToolsetProviderSelect**](ToolsetProviderSelect.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **serveCssAssetsFilenameCssGet**
> Object serveCssAssetsFilenameCssGet(filename)

Serve Css

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String filename = filename_example; // String | 

try {
    final response = api.serveCssAssetsFilenameCssGet(filename);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->serveCssAssetsFilenameCssGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **filename** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **servePluginAssetDashboardPluginsPluginNameFilePathGet**
> Object servePluginAssetDashboardPluginsPluginNameFilePathGet(pluginName, filePath)

Serve Plugin Asset

Serve static assets from a dashboard plugin's ``dashboard/`` directory.  Unauthenticated on purpose: the SPA loads plugin JS via ``<script src>`` and CSS via ``<link href>``, which cannot attach an auth header. Hence the suffix allowlist — user plugins ship a ``plugin_api.py`` backend the browser never fetches, and without it anyone on the loopback port could curl a private plugin's source. Path traversal is blocked via ``resolve().is_relative_to()``; user plugins must be enabled (bundled ones not disabled) (GHSA-mcfc-hp25-cjv7).  See #46435.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String pluginName = pluginName_example; // String | 
final String filePath = filePath_example; // String | 

try {
    final response = api.servePluginAssetDashboardPluginsPluginNameFilePathGet(pluginName, filePath);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->servePluginAssetDashboardPluginsPluginNameFilePathGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pluginName** | **String**|  | 
 **filePath** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **serveSpaFullPathGet**
> Object serveSpaFullPathGet(fullPath)

Serve Spa

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String fullPath = fullPath_example; // String | 

try {
    final response = api.serveSpaFullPathGet(fullPath);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->serveSpaFullPathGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **fullPath** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **sessionBadgesApiPluginsHermesAchievementsSessionsSessionIdBadgesGet**
> Object sessionBadgesApiPluginsHermesAchievementsSessionsSessionIdBadgesGet(sessionId)

Session Badges

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String sessionId = sessionId_example; // String | 

try {
    final response = api.sessionBadgesApiPluginsHermesAchievementsSessionsSessionIdBadgesGet(sessionId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->sessionBadgesApiPluginsHermesAchievementsSessionsSessionIdBadgesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setActiveProfileEndpointApiProfilesActivePost**
> Object setActiveProfileEndpointApiProfilesActivePost(profileActiveUpdate)

Set Active Profile Endpoint

Set the sticky active profile (mirrors ``hermes profile use``); does not retarget the running dashboard, only subsequent CLI commands and gateways.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ProfileActiveUpdate profileActiveUpdate = ; // ProfileActiveUpdate | 

try {
    final response = api.setActiveProfileEndpointApiProfilesActivePost(profileActiveUpdate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setActiveProfileEndpointApiProfilesActivePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profileActiveUpdate** | [**ProfileActiveUpdate**](ProfileActiveUpdate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setCuratorPausedApiCuratorPausedPut**
> Object setCuratorPausedApiCuratorPausedPut(curatorPause)

Set Curator Paused

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final CuratorPause curatorPause = ; // CuratorPause | 

try {
    final response = api.setCuratorPausedApiCuratorPausedPut(curatorPause);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setCuratorPausedApiCuratorPausedPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **curatorPause** | [**CuratorPause**](CuratorPause.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setDashboardFontApiDashboardFontPut**
> Object setDashboardFontApiDashboardFontPut(fontSetBody)

Set Dashboard Font

Set the font override (config.yaml). Unknown ids coerce to ``\"theme\"`` rather than 400 so a stale client can't wedge the picker.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final FontSetBody fontSetBody = ; // FontSetBody | 

try {
    final response = api.setDashboardFontApiDashboardFontPut(fontSetBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setDashboardFontApiDashboardFontPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **fontSetBody** | [**FontSetBody**](FontSetBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setDashboardThemeApiDashboardThemePut**
> Object setDashboardThemeApiDashboardThemePut(themeSetBody)

Set Dashboard Theme

Set the active dashboard theme (persists to config.yaml).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ThemeSetBody themeSetBody = ; // ThemeSetBody | 

try {
    final response = api.setDashboardThemeApiDashboardThemePut(themeSetBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setDashboardThemeApiDashboardThemePut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **themeSetBody** | [**ThemeSetBody**](ThemeSetBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setEnvVarApiEnvPut**
> Object setEnvVarApiEnvPut(envVarUpdate, profile)

Set Env Var

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final EnvVarUpdate envVarUpdate = ; // EnvVarUpdate | 
final String profile = profile_example; // String | 

try {
    final response = api.setEnvVarApiEnvPut(envVarUpdate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setEnvVarApiEnvPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **envVarUpdate** | [**EnvVarUpdate**](EnvVarUpdate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setMcpServerEnabledApiMcpServersNameEnabledPut**
> Object setMcpServerEnabledApiMcpServersNameEnabledPut(name, mCPEnabledToggle, profile)

Set Mcp Server Enabled

Toggle ``enabled`` (takes effect on next session/gateway); disabled servers stay in config so they can be re-enabled without re-entry.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final MCPEnabledToggle mCPEnabledToggle = ; // MCPEnabledToggle | 
final String profile = profile_example; // String | 

try {
    final response = api.setMcpServerEnabledApiMcpServersNameEnabledPut(name, mCPEnabledToggle, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setMcpServerEnabledApiMcpServersNameEnabledPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **mCPEnabledToggle** | [**MCPEnabledToggle**](MCPEnabledToggle.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setMemoryProviderApiMemoryProviderPut**
> Object setMemoryProviderApiMemoryProviderPut(memoryProviderSelect)

Set Memory Provider

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MemoryProviderSelect memoryProviderSelect = ; // MemoryProviderSelect | 

try {
    final response = api.setMemoryProviderApiMemoryProviderPut(memoryProviderSelect);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setMemoryProviderApiMemoryProviderPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **memoryProviderSelect** | [**MemoryProviderSelect**](MemoryProviderSelect.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setMoaModelsApiModelMoaPut**
> Object setMoaModelsApiModelMoaPut(moaConfigPayload, profile)

Set Moa Models

Persist the Mixture-of-Agents provider/model slots.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MoaConfigPayload moaConfigPayload = ; // MoaConfigPayload | 
final String profile = profile_example; // String | 

try {
    final response = api.setMoaModelsApiModelMoaPut(moaConfigPayload, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setMoaModelsApiModelMoaPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **moaConfigPayload** | [**MoaConfigPayload**](MoaConfigPayload.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setModelAssignmentApiModelSetPost**
> Object setModelAssignmentApiModelSetPost(modelAssignment, profile)

Set Model Assignment

Assign a model to the main slot or an auxiliary task slot. Writes ``~/.hermes/config.yaml`` — applies to **new** sessions only; a running chat PTY hot-swaps via the ``/model`` slash command instead.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ModelAssignment modelAssignment = ; // ModelAssignment | 
final String profile = profile_example; // String | 

try {
    final response = api.setModelAssignmentApiModelSetPost(modelAssignment, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setModelAssignmentApiModelSetPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **modelAssignment** | [**ModelAssignment**](ModelAssignment.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setOrchestrationSettingsApiPluginsKanbanOrchestrationPut**
> Object setOrchestrationSettingsApiPluginsKanbanOrchestrationPut(orchestrationSettingsBody)

Set Orchestration Settings

Update orchestration knobs in config.yaml. Only fields explicitly passed are written; empty profile strings clear the override.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final OrchestrationSettingsBody orchestrationSettingsBody = ; // OrchestrationSettingsBody | 

try {
    final response = api.setOrchestrationSettingsApiPluginsKanbanOrchestrationPut(orchestrationSettingsBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setOrchestrationSettingsApiPluginsKanbanOrchestrationPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **orchestrationSettingsBody** | [**OrchestrationSettingsBody**](OrchestrationSettingsBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setWebhookEnabledApiWebhooksNameEnabledPut**
> Object setWebhookEnabledApiWebhooksNameEnabledPut(name, webhookEnabledToggle)

Set Webhook Enabled

Disabled routes stay on disk (re-enable later) but the gateway rejects their events with 403; it hot-reloads the file, so no restart is needed.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final WebhookEnabledToggle webhookEnabledToggle = ; // WebhookEnabledToggle | 

try {
    final response = api.setWebhookEnabledApiWebhooksNameEnabledPut(name, webhookEnabledToggle);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setWebhookEnabledApiWebhooksNameEnabledPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **webhookEnabledToggle** | [**WebhookEnabledToggle**](WebhookEnabledToggle.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setupMemoryProviderApiMemoryProvidersNameSetupPost**
> Object setupMemoryProviderApiMemoryProvidersNameSetupPost(name, memoryProviderSetupRequest)

Setup Memory Provider

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final MemoryProviderSetupRequest memoryProviderSetupRequest = ; // MemoryProviderSetupRequest | 

try {
    final response = api.setupMemoryProviderApiMemoryProvidersNameSetupPost(name, memoryProviderSetupRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->setupMemoryProviderApiMemoryProvidersNameSetupPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **memoryProviderSetupRequest** | [**MemoryProviderSetupRequest**](MemoryProviderSetupRequest.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **speakTextApiAudioSpeakPost**
> Object speakTextApiAudioSpeakPost(tTSSpeakRequest, profile)

Speak Text

Synthesize speech and return audio as base64 data URL.  Used by the desktop voice-conversation mode to play back assistant responses without exposing the on-disk file path; reuses the TTS provider chain configured under ``tts.`` in config.yaml.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final TTSSpeakRequest tTSSpeakRequest = ; // TTSSpeakRequest | 
final String profile = profile_example; // String | 

try {
    final response = api.speakTextApiAudioSpeakPost(tTSSpeakRequest, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->speakTextApiAudioSpeakPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **tTSSpeakRequest** | [**TTSSpeakRequest**](TTSSpeakRequest.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost**
> Object specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost(taskId, specifyBody, board)

Specify Task Endpoint

Flesh out a triage task via the auxiliary LLM (``hermes kanban specify``). Non-OK is NOT an HTTP error — the UI renders the reason inline. Sync ``def`` → runs in the threadpool.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final SpecifyBody specifyBody = ; // SpecifyBody | 
final String board = board_example; // String | 

try {
    final response = api.specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost(taskId, specifyBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **specifyBody** | [**SpecifyBody**](SpecifyBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startGatewayApiGatewayStartPost**
> Object startGatewayApiGatewayStartPost(profile)

Start Gateway

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.startGatewayApiGatewayStartPost(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->startGatewayApiGatewayStartPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startMemoryOauthApiMemoryProvidersProviderOauthStartPost**
> Object startMemoryOauthApiMemoryProvidersProviderOauthStartPost(provider, profile)

Start Memory Oauth

Begin a provider's zero-CLI OAuth flow (browser + loopback listener); returns immediately, poll status.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String provider = provider_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.startMemoryOauthApiMemoryProvidersProviderOauthStartPost(provider, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->startMemoryOauthApiMemoryProvidersProviderOauthStartPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startOauthLoginApiProvidersOauthProviderIdStartPost**
> Object startOauthLoginApiProvidersOauthProviderIdStartPost(providerId, profile)

Start Oauth Login

Initiate an OAuth login flow. Token-protected.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String providerId = providerId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.startOauthLoginApiProvidersOauthProviderIdStartPost(providerId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->startOauthLoginApiProvidersOauthProviderIdStartPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **providerId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startTelegramOnboardingApiMessagingTelegramOnboardingStartPost**
> Object startTelegramOnboardingApiMessagingTelegramOnboardingStartPost(telegramOnboardingStart)

Start Telegram Onboarding

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final TelegramOnboardingStart telegramOnboardingStart = ; // TelegramOnboardingStart | 

try {
    final response = api.startTelegramOnboardingApiMessagingTelegramOnboardingStartPost(telegramOnboardingStart);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->startTelegramOnboardingApiMessagingTelegramOnboardingStartPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **telegramOnboardingStart** | [**TelegramOnboardingStart**](TelegramOnboardingStart.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost**
> Object startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost(whatsAppOnboardingStart)

Start Whatsapp Onboarding

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final WhatsAppOnboardingStart whatsAppOnboardingStart = ; // WhatsAppOnboardingStart | 

try {
    final response = api.startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost(whatsAppOnboardingStart);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **whatsAppOnboardingStart** | [**WhatsAppOnboardingStart**](WhatsAppOnboardingStart.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **stopGatewayApiGatewayStopPost**
> Object stopGatewayApiGatewayStopPost(profile)

Stop Gateway

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 

try {
    final response = api.stopGatewayApiGatewayStopPost(profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->stopGatewayApiGatewayStopPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **streamManagedFileApiFilesStreamGet**
> Object streamManagedFileApiFilesStreamGet(path)

Stream Managed File

Stream managed audio/video inline with HTTP Range support — Electron's media pipeline may reject an attachment response as an ``<audio>``/ ``<video>`` source. Same auth, size cap, sensitive guard and MIME detection as download.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.streamManagedFileApiFilesStreamGet(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->streamManagedFileApiFilesStreamGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **streamManagedFileApiFilesStreamHead**
> Object streamManagedFileApiFilesStreamHead(path)

Stream Managed File

Stream managed audio/video inline with HTTP Range support — Electron's media pipeline may reject an attachment response as an ``<audio>``/ ``<video>`` source. Same auth, size cap, sensitive guard and MIME detection as download.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String path = path_example; // String | 

try {
    final response = api.streamManagedFileApiFilesStreamHead(path);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->streamManagedFileApiFilesStreamHead: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **path** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **submitOauthCodeApiProvidersOauthProviderIdSubmitPost**
> Object submitOauthCodeApiProvidersOauthProviderIdSubmitPost(providerId, oAuthSubmitBody, profile)

Submit Oauth Code

Submit the auth code for PKCE flows. Token-protected.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String providerId = providerId_example; // String | 
final OAuthSubmitBody oAuthSubmitBody = ; // OAuthSubmitBody | 
final String profile = profile_example; // String | 

try {
    final response = api.submitOauthCodeApiProvidersOauthProviderIdSubmitPost(providerId, oAuthSubmitBody, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->submitOauthCodeApiProvidersOauthProviderIdSubmitPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **providerId** | **String**|  | 
 **oAuthSubmitBody** | [**OAuthSubmitBody**](OAuthSubmitBody.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost**
> Object subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost(taskId, platform, board)

Subscribe Home

Subscribe *task_id* to *platform*'s home channel. Idempotent at the DB layer; 404 when the platform has no home or the task doesn't exist.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String platform = platform_example; // String | 
final String board = board_example; // String | 

try {
    final response = api.subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost(taskId, platform, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **platform** | **String**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **switchBoardApiPluginsKanbanBoardsSlugSwitchPost**
> Object switchBoardApiPluginsKanbanBoardsSlugSwitchPost(slug)

Switch Board

Persist ``slug`` as the active board for CLI / slash-command parity (dashboard users pick boards client-side via localStorage).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String slug = slug_example; // String | 

try {
    final response = api.switchBoardApiPluginsKanbanBoardsSlugSwitchPost(slug);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->switchBoardApiPluginsKanbanBoardsSlugSwitchPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost**
> Object terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost(runId, terminateRunBody, board)

Terminate Run Endpoint

Terminate an in-flight run via ``reclaim_task`` (same SIGTERM->SIGKILL flow, bookkeeping and events as ``POST /tasks/{id}/reclaim``); 409 if already ended / not reclaimable.  Closes the gap left by PR #28432, which shipped the read-only sibling endpoints (``/workers/active``, ``/runs/{run_id}``, ``/runs/{run_id}/inspect``) but no termination control surface.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final int runId = 56; // int | 
final TerminateRunBody terminateRunBody = ; // TerminateRunBody | 
final String board = board_example; // String | Kanban board slug (omit for current)

try {
    final response = api.terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost(runId, terminateRunBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **runId** | **int**|  | 
 **terminateRunBody** | [**TerminateRunBody**](TerminateRunBody.md)|  | 
 **board** | **String**| Kanban board slug (omit for current) | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **testMcpServerApiMcpServersNameTestPost**
> Object testMcpServerApiMcpServersNameTestPost(name, profile)

Test Mcp Server

Connect to the server, list its tools, disconnect.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.testMcpServerApiMcpServersNameTestPost(name, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->testMcpServerApiMcpServersNameTestPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **testMessagingPlatformApiMessagingPlatformsPlatformIdTestPost**
> Object testMessagingPlatformApiMessagingPlatformsPlatformIdTestPost(platformId, profile)

Test Messaging Platform

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String platformId = platformId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.testMessagingPlatformApiMessagingPlatformsPlatformIdTestPost(platformId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->testMessagingPlatformApiMessagingPlatformsPlatformIdTestPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **platformId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **toggleSkillApiSkillsTogglePut**
> Object toggleSkillApiSkillsTogglePut(skillToggle, profile)

Toggle Skill

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SkillToggle skillToggle = ; // SkillToggle | 
final String profile = profile_example; // String | 

try {
    final response = api.toggleSkillApiSkillsTogglePut(skillToggle, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->toggleSkillApiSkillsTogglePut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **skillToggle** | [**SkillToggle**](SkillToggle.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **toggleToolsetApiToolsToolsetsNamePut**
> Object toggleToolsetApiToolsToolsetsNamePut(name, toolsetToggle, profile)

Toggle Toolset

Enable/disable a configurable toolset for its configuration platform (``platform_toolsets.cli`` for most; platform-restricted toolsets target their own platform) via the same ``_save_platform_tools`` the CLI uses.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ToolsetToggle toolsetToggle = ; // ToolsetToggle | 
final String profile = profile_example; // String | 

try {
    final response = api.toggleToolsetApiToolsToolsetsNamePut(name, toolsetToggle, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->toggleToolsetApiToolsToolsetsNamePut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **toolsetToggle** | [**ToolsetToggle**](ToolsetToggle.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **transcribeAudioUploadApiAudioTranscribePost**
> Object transcribeAudioUploadApiAudioTranscribePost(audioTranscriptionRequest, profile)

Transcribe Audio Upload

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final AudioTranscriptionRequest audioTranscriptionRequest = ; // AudioTranscriptionRequest | 
final String profile = profile_example; // String | 

try {
    final response = api.transcribeAudioUploadApiAudioTranscribePost(audioTranscriptionRequest, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->transcribeAudioUploadApiAudioTranscribePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **audioTranscriptionRequest** | [**AudioTranscriptionRequest**](AudioTranscriptionRequest.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **triggerCronJobApiCronJobsJobIdTriggerPost**
> Object triggerCronJobApiCronJobsJobIdTriggerPost(jobId, profile)

Trigger Cron Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.triggerCronJobApiCronJobsJobIdTriggerPost(jobId, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->triggerCronJobApiCronJobsJobIdTriggerPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **ttsLeaseApiAudioTtsLeasePost**
> Object ttsLeaseApiAudioTtsLeasePost(tTSLeaseRequest, profile)

Tts Lease

Desktop TTS-output toggles as warm-up / release signals.  ``active: true`` registers a lease on the TTS engine and pre-loads the configured provider (local model, lazily-installed SDK) so the first spoken reply doesn't pay the load as dead air; ``active: false`` drops the lease and, once no surface holds one, unloads resident local models. Blocking work runs off the event loop. Warm-up failures are reported in the body, never as an HTTP error — the toggle must succeed even when preload fails.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final TTSLeaseRequest tTSLeaseRequest = ; // TTSLeaseRequest | 
final String profile = profile_example; // String | 

try {
    final response = api.ttsLeaseApiAudioTtsLeasePost(tTSLeaseRequest, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->ttsLeaseApiAudioTtsLeasePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **tTSLeaseRequest** | [**TTSLeaseRequest**](TTSLeaseRequest.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **uninstallSkillHubApiSkillsHubUninstallPost**
> Object uninstallSkillHubApiSkillsHubUninstallPost(skillUninstallRequest, profile)

Uninstall Skill Hub

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SkillUninstallRequest skillUninstallRequest = ; // SkillUninstallRequest | 
final String profile = profile_example; // String | 

try {
    final response = api.uninstallSkillHubApiSkillsHubUninstallPost(skillUninstallRequest, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->uninstallSkillHubApiSkillsHubUninstallPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **skillUninstallRequest** | [**SkillUninstallRequest**](SkillUninstallRequest.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete**
> Object unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete(taskId, platform, board)

Unsubscribe Home

Remove any notify subscription on *task_id* matching *platform*'s home.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final String platform = platform_example; // String | 
final String board = board_example; // String | 

try {
    final response = api.unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete(taskId, platform, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **platform** | **String**|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateConfigApiConfigPut**
> Object updateConfigApiConfigPut(configUpdate, profile, preserveLanguage)

Update Config

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ConfigUpdate configUpdate = ; // ConfigUpdate | 
final String profile = profile_example; // String | 
final bool preserveLanguage = true; // bool | 

try {
    final response = api.updateConfigApiConfigPut(configUpdate, profile, preserveLanguage);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateConfigApiConfigPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **configUpdate** | [**ConfigUpdate**](ConfigUpdate.md)|  | 
 **profile** | **String**|  | [optional] 
 **preserveLanguage** | **bool**|  | [optional] [default to false]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateConfigRawApiConfigRawPut**
> Object updateConfigRawApiConfigRawPut(rawConfigUpdate, profile)

Update Config Raw

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final RawConfigUpdate rawConfigUpdate = ; // RawConfigUpdate | 
final String profile = profile_example; // String | 

try {
    final response = api.updateConfigRawApiConfigRawPut(rawConfigUpdate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateConfigRawApiConfigRawPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **rawConfigUpdate** | [**RawConfigUpdate**](RawConfigUpdate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateCronJobApiCronJobsJobIdPut**
> Object updateCronJobApiCronJobsJobIdPut(jobId, cronJobUpdate, profile)

Update Cron Job

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String jobId = jobId_example; // String | 
final CronJobUpdate cronJobUpdate = ; // CronJobUpdate | 
final String profile = profile_example; // String | 

try {
    final response = api.updateCronJobApiCronJobsJobIdPut(jobId, cronJobUpdate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateCronJobApiCronJobsJobIdPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**|  | 
 **cronJobUpdate** | [**CronJobUpdate**](CronJobUpdate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateHermesApiHermesUpdatePost**
> Object updateHermesApiHermesUpdatePost()

Update Hermes

Kick off ``hermes update`` in the background.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();

try {
    final response = api.updateHermesApiHermesUpdatePost();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateHermesApiHermesUpdatePost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateLearningNodeApiLearningNodePut**
> Object updateLearningNodeApiLearningNodePut(learningNodeEdit)

Update Learning Node

Rewrite a journey node's content (SKILL.md or memory chunk).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final LearningNodeEdit learningNodeEdit = ; // LearningNodeEdit | 

try {
    final response = api.updateLearningNodeApiLearningNodePut(learningNodeEdit);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateLearningNodeApiLearningNodePut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **learningNodeEdit** | [**LearningNodeEdit**](LearningNodeEdit.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateMemoryProviderConfigApiMemoryProvidersNameConfigPut**
> Object updateMemoryProviderConfigApiMemoryProvidersNameConfigPut(name, memoryProviderConfigUpdate, surface, profile)

Update Memory Provider Config

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final MemoryProviderConfigUpdate memoryProviderConfigUpdate = ; // MemoryProviderConfigUpdate | 
final String surface = surface_example; // String | 
final String profile = profile_example; // String | 

try {
    final response = api.updateMemoryProviderConfigApiMemoryProvidersNameConfigPut(name, memoryProviderConfigUpdate, surface, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateMemoryProviderConfigApiMemoryProvidersNameConfigPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **memoryProviderConfigUpdate** | [**MemoryProviderConfigUpdate**](MemoryProviderConfigUpdate.md)|  | 
 **surface** | **String**|  | [optional] 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateMessagingPlatformApiMessagingPlatformsPlatformIdPut**
> Object updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(platformId, messagingPlatformUpdate, profile)

Update Messaging Platform

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String platformId = platformId_example; // String | 
final MessagingPlatformUpdate messagingPlatformUpdate = ; // MessagingPlatformUpdate | 
final String profile = profile_example; // String | 

try {
    final response = api.updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(platformId, messagingPlatformUpdate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateMessagingPlatformApiMessagingPlatformsPlatformIdPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **platformId** | **String**|  | 
 **messagingPlatformUpdate** | [**MessagingPlatformUpdate**](MessagingPlatformUpdate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateProfileDescriptionApiPluginsKanbanProfilesProfileNamePatch**
> Object updateProfileDescriptionApiPluginsKanbanProfilesProfileNamePatch(profileName, describeBody)

Update Profile Description

Set (``description_auto: false`` so the auto-describer won't overwrite it without ``--overwrite``) or clear (empty string) a profile's description.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profileName = profileName_example; // String | 
final DescribeBody describeBody = ; // DescribeBody | 

try {
    final response = api.updateProfileDescriptionApiPluginsKanbanProfilesProfileNamePatch(profileName, describeBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateProfileDescriptionApiPluginsKanbanProfilesProfileNamePatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profileName** | **String**|  | 
 **describeBody** | [**DescribeBody**](DescribeBody.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateProfileDescriptionEndpointApiProfilesNameDescriptionPut**
> Object updateProfileDescriptionEndpointApiProfilesNameDescriptionPut(name, profileDescriptionUpdate)

Update Profile Description Endpoint

Set or clear a profile's role description (kanban routing signal), stored as user-authored (``description_auto: false``) so the auto-describer won't overwrite it.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ProfileDescriptionUpdate profileDescriptionUpdate = ; // ProfileDescriptionUpdate | 

try {
    final response = api.updateProfileDescriptionEndpointApiProfilesNameDescriptionPut(name, profileDescriptionUpdate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateProfileDescriptionEndpointApiProfilesNameDescriptionPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profileDescriptionUpdate** | [**ProfileDescriptionUpdate**](ProfileDescriptionUpdate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateProfileModelEndpointApiProfilesNameModelPut**
> Object updateProfileModelEndpointApiProfilesNameModelPut(name, profileModelUpdate)

Update Profile Model Endpoint

Set the main model for a specific profile's config.yaml without touching the dashboard's own profile — ``POST /api/model/set`` (main scope) via the HERMES_HOME override.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ProfileModelUpdate profileModelUpdate = ; // ProfileModelUpdate | 

try {
    final response = api.updateProfileModelEndpointApiProfilesNameModelPut(name, profileModelUpdate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateProfileModelEndpointApiProfilesNameModelPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profileModelUpdate** | [**ProfileModelUpdate**](ProfileModelUpdate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateProfileSoulApiProfilesNameSoulPut**
> Object updateProfileSoulApiProfilesNameSoulPut(name, profileSoulUpdate)

Update Profile Soul

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String name = name_example; // String | 
final ProfileSoulUpdate profileSoulUpdate = ; // ProfileSoulUpdate | 

try {
    final response = api.updateProfileSoulApiProfilesNameSoulPut(name, profileSoulUpdate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateProfileSoulApiProfilesNameSoulPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **name** | **String**|  | 
 **profileSoulUpdate** | [**ProfileSoulUpdate**](ProfileSoulUpdate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateSkillContentApiSkillsContentPut**
> Object updateSkillContentApiSkillsContentPut(skillContentUpdate)

Update Skill Content

Replace the SKILL.md of an existing skill (full rewrite) from the editor.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final SkillContentUpdate skillContentUpdate = ; // SkillContentUpdate | 

try {
    final response = api.updateSkillContentApiSkillsContentPut(skillContentUpdate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateSkillContentApiSkillsContentPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **skillContentUpdate** | [**SkillContentUpdate**](SkillContentUpdate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateSkillsHubApiSkillsHubUpdatePost**
> Object updateSkillsHubApiSkillsHubUpdatePost(profile, skillsUpdateRequest)

Update Skills Hub

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String profile = profile_example; // String | 
final SkillsUpdateRequest skillsUpdateRequest = ; // SkillsUpdateRequest | 

try {
    final response = api.updateSkillsHubApiSkillsHubUpdatePost(profile, skillsUpdateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateSkillsHubApiSkillsHubUpdatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profile** | **String**|  | [optional] 
 **skillsUpdateRequest** | [**SkillsUpdateRequest**](SkillsUpdateRequest.md)|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateTaskApiPluginsKanbanTasksTaskIdPatch**
> Object updateTaskApiPluginsKanbanTasksTaskIdPatch(taskId, updateTaskBody, board)

Update Task

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final UpdateTaskBody updateTaskBody = ; // UpdateTaskBody | 
final String board = board_example; // String | 

try {
    final response = api.updateTaskApiPluginsKanbanTasksTaskIdPatch(taskId, updateTaskBody, board);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->updateTaskApiPluginsKanbanTasksTaskIdPatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **updateTaskBody** | [**UpdateTaskBody**](UpdateTaskBody.md)|  | 
 **board** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **uploadChatImageApiChatImageUploadPost**
> Object uploadChatImageApiChatImageUploadPost(chatImageUpload, profile)

Upload Chat Image

Persist a browser clipboard image where the embedded TUI can read it.  Browser clipboard bytes aren't visible to the server-side clipboard, so the /chat page uploads them here and drives the TUI's ``/image <path>`` with the returned gateway-visible path under ``HERMES_HOME/images/`` (the same dir ``clipboard.paste`` / ``image.attach`` use).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ChatImageUpload chatImageUpload = ; // ChatImageUpload | 
final String profile = profile_example; // String | 

try {
    final response = api.uploadChatImageApiChatImageUploadPost(chatImageUpload, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->uploadChatImageApiChatImageUploadPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **chatImageUpload** | [**ChatImageUpload**](ChatImageUpload.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **uploadManagedFileApiFilesUploadPost**
> Object uploadManagedFileApiFilesUploadPost(managedFileUpload)

Upload Managed File

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final ManagedFileUpload managedFileUpload = ; // ManagedFileUpload | 

try {
    final response = api.uploadManagedFileApiFilesUploadPost(managedFileUpload);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->uploadManagedFileApiFilesUploadPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **managedFileUpload** | [**ManagedFileUpload**](ManagedFileUpload.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **uploadManagedFileStreamApiFilesUploadStreamPost**
> Object uploadManagedFileStreamApiFilesUploadStreamPost(file, path, overwrite)

Upload Managed File Stream

Chunked multipart upload: constant memory and no base64 inflation, unlike the JSON data-URL endpoint that trips proxy body-size limits on large archives.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final MultipartFile file = BINARY_DATA_HERE; // MultipartFile | 
final String path = path_example; // String | 
final bool overwrite = true; // bool | 

try {
    final response = api.uploadManagedFileStreamApiFilesUploadStreamPost(file, path, overwrite);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->uploadManagedFileStreamApiFilesUploadStreamPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **file** | **MultipartFile**|  | 
 **path** | **String**|  | 
 **overwrite** | **bool**|  | [optional] [default to true]

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: multipart/form-data
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost**
> Object uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost(taskId, file, board, uploadedBy)

Upload Task Attachment

Store an upload under ``attachments_root(board)/<task_id>/`` (sanitised, collision-resolved name; ``_safe_attachment_name`` ValueError → 400) and record it.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final String taskId = taskId_example; // String | 
final MultipartFile file = BINARY_DATA_HERE; // MultipartFile | 
final String board = board_example; // String | 
final String uploadedBy = uploadedBy_example; // String | 

try {
    final response = api.uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost(taskId, file, board, uploadedBy);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **taskId** | **String**|  | 
 **file** | **MultipartFile**|  | 
 **board** | **String**|  | [optional] 
 **uploadedBy** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: multipart/form-data
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **upsertCustomEndpointApiProvidersCustomEndpointsPost**
> Object upsertCustomEndpointApiProvidersCustomEndpointsPost(customEndpointUpdate, profile)

Upsert Custom Endpoint

Create or update a v12+ ``providers`` custom endpoint entry.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final CustomEndpointUpdate customEndpointUpdate = ; // CustomEndpointUpdate | 
final String profile = profile_example; // String | 

try {
    final response = api.upsertCustomEndpointApiProvidersCustomEndpointsPost(customEndpointUpdate, profile);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->upsertCustomEndpointApiProvidersCustomEndpointsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **customEndpointUpdate** | [**CustomEndpointUpdate**](CustomEndpointUpdate.md)|  | 
 **profile** | **String**|  | [optional] 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **validateCustomEndpointApiProvidersCustomEndpointsValidatePost**
> Object validateCustomEndpointApiProvidersCustomEndpointsValidatePost(customEndpointUpdate)

Validate Custom Endpoint

Probe a custom endpoint by calling its OpenAI-compatible /models URL.

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final CustomEndpointUpdate customEndpointUpdate = ; // CustomEndpointUpdate | 

try {
    final response = api.validateCustomEndpointApiProvidersCustomEndpointsValidatePost(customEndpointUpdate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->validateCustomEndpointApiProvidersCustomEndpointsValidatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **customEndpointUpdate** | [**CustomEndpointUpdate**](CustomEndpointUpdate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **validateProviderCredentialApiProvidersValidatePost**
> Object validateProviderCredentialApiProvidersValidatePost(envVarUpdate)

Validate Provider Credential

Live-probe a provider credential before it's saved.  Returns {ok, reachable, message}. ok=True means the provider accepted the key; ok=False + reachable=True means the key is bad (caller should block); reachable=False means the network probe couldn't run (caller may save with a warning rather than hard-blocking offline users).

### Example
```dart
import 'package:hermes_api/api.dart';

final api = HermesApi().getDefaultApi();
final EnvVarUpdate envVarUpdate = ; // EnvVarUpdate | 

try {
    final response = api.validateProviderCredentialApiProvidersValidatePost(envVarUpdate);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->validateProviderCredentialApiProvidersValidatePost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **envVarUpdate** | [**EnvVarUpdate**](EnvVarUpdate.md)|  | 

### Return type

**Object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

