import 'package:test/test.dart';
import 'package:hermes_api/hermes_api.dart';

/// tests for DefaultApi
void main() {
  final instance = HermesApi().getDefaultApi();

  group(DefaultApi, () {
    // Achievements
    //
    //Future<Object> achievementsApiPluginsHermesAchievementsAchievementsGet() async
    test(
      'test achievementsApiPluginsHermesAchievementsAchievementsGet',
      () async {
        // TODO
      },
    );

    // Activate Custom Endpoint
    //
    // Set a configured custom endpoint as the default model provider.
    //
    //Future<Object> activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost(String endpointId, { String profile }) async
    test('test activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost', () async {
      // TODO
    });

    // Add Comment
    //
    //Future<Object> addCommentApiPluginsKanbanTasksTaskIdCommentsPost(String taskId, CommentBody commentBody, { String board }) async
    test('test addCommentApiPluginsKanbanTasksTaskIdCommentsPost', () async {
      // TODO
    });

    // Add Credential Pool Entry
    //
    //Future<Object> addCredentialPoolEntryApiCredentialsPoolPost(CredentialPoolAdd credentialPoolAdd) async
    test('test addCredentialPoolEntryApiCredentialsPoolPost', () async {
      // TODO
    });

    // Add Link
    //
    //Future<Object> addLinkApiPluginsKanbanLinksPost(LinkBody linkBody, { String board }) async
    test('test addLinkApiPluginsKanbanLinksPost', () async {
      // TODO
    });

    // Add Mcp Server
    //
    //Future<Object> addMcpServerApiMcpServersPost(MCPServerCreate mCPServerCreate, { String profile }) async
    test('test addMcpServerApiMcpServersPost', () async {
      // TODO
    });

    // Apply Telegram Onboarding
    //
    //Future<Object> applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost(String pairingId, TelegramOnboardingApply telegramOnboardingApply, { String profile }) async
    test('test applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost', () async {
      // TODO
    });

    // Apply Whatsapp Onboarding
    //
    //Future<Object> applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost(String pairingId, WhatsAppOnboardingApply whatsAppOnboardingApply, { String profile }) async
    test('test applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost', () async {
      // TODO
    });

    // Approve Pairing
    //
    //Future<Object> approvePairingApiPairingApprovePost(PairingApprove pairingApprove) async
    test('test approvePairingApiPairingApprovePost', () async {
      // TODO
    });

    // Auth Callback
    //
    //Future<Object> authCallbackAuthCallbackGet({ String code, String state, String error, String errorDescription }) async
    test('test authCallbackAuthCallbackGet', () async {
      // TODO
    });

    // Auth Login
    //
    //Future<Object> authLoginAuthLoginGet(String provider, { String next }) async
    test('test authLoginAuthLoginGet', () async {
      // TODO
    });

    // Auth Logout
    //
    //Future<Object> authLogoutAuthLogoutPost() async
    test('test authLogoutAuthLogoutPost', () async {
      // TODO
    });

    // Auth Mcp Server
    //
    // Start MCP OAuth and hand the authorization URL to the dashboard browser.
    //
    //Future<Object> authMcpServerApiMcpServersNameAuthPost(String name, { String profile }) async
    test('test authMcpServerApiMcpServersNameAuthPost', () async {
      // TODO
    });

    // Auth Me
    //
    // Return the verified session as JSON. Auth-required (gate enforces).
    //
    //Future<Object> authMeApiAuthMeGet() async
    test('test authMeApiAuthMeGet', () async {
      // TODO
    });

    // Auth Native Authorize
    //
    // Begin an RFC 8252 native-app login: stash a pending broker authorization keyed by an opaque ``broker_state`` riding in the gateway's own PKCE cookie (the desktop's challenge/state never touch it), then run the normal upstream round trip. Password providers go to the ``/login`` form instead.
    //
    //Future<Object> authNativeAuthorizeAuthNativeAuthorizeGet({ String provider, String codeChallenge, String codeChallengeMethod, String redirectUri, String state }) async
    test('test authNativeAuthorizeAuthNativeAuthorizeGet', () async {
      // TODO
    });

    // Auth Native Refresh
    //
    // Rotate a desktop-held refresh token (mirrors the gate's ``_attempt_refresh``): every provider rejecting the RT -> 401 ``session_expired`` (desktop re-logs); none rotated and one unreachable -> 503.
    //
    //Future<Object> authNativeRefreshAuthNativeRefreshPost(NativeRefreshBody nativeRefreshBody) async
    test('test authNativeRefreshAuthNativeRefreshPost', () async {
      // TODO
    });

    // Auth Native Token
    //
    // Exchange a loopback gateway code + PKCE verifier for bearer tokens. The code is consumed on every path (no verifier oracle, no replay); any failure is a generic 400. Tokens go in the JSON body; no cookie is set.
    //
    //Future<Object> authNativeTokenAuthNativeTokenPost(NativeTokenBody nativeTokenBody) async
    test('test authNativeTokenAuthNativeTokenPost', () async {
      // TODO
    });

    // Auth Password Login
    //
    // Authenticate a username/password against a password provider.  Returns ``{\"ok\": true, \"next\": <path>}`` (the form POSTs via fetch, which follows a 302 opaquely) and sets the session cookies; with a native ``broker`` handle in the PKCE cookie, ``next`` is the desktop's loopback redirect and NO cookies are set. Failures are deliberately generic (no username/provider oracle): unknown/non-password provider 404, bad credentials 401, store unreachable 503, rate limited 429.
    //
    //Future<Object> authPasswordLoginAuthPasswordLoginPost(PasswordLoginBody passwordLoginBody) async
    test('test authPasswordLoginAuthPasswordLoginPost', () async {
      // TODO
    });

    // Auth Providers
    //
    //Future<Object> authProvidersApiAuthProvidersGet() async
    test('test authProvidersApiAuthProvidersGet', () async {
      // TODO
    });

    // Auth Ws Ticket
    //
    // Mint a 30s single-use ticket for a WS upgrade (browsers cannot set ``Authorization`` on the upgrade); one ticket per WS.
    //
    //Future<Object> authWsTicketApiAuthWsTicketPost() async
    test('test authWsTicketApiAuthWsTicketPost', () async {
      // TODO
    });

    // Auto Describe Profile
    //
    // ``hermes profile describe <name> --auto``: persist with ``description_auto: true``. Non-OK outcomes are NOT HTTP errors — the UI renders the reason inline.
    //
    //Future<Object> autoDescribeProfileApiPluginsKanbanProfilesProfileNameDescribeAutoPost(String profileName, DescribeAutoBody describeAutoBody) async
    test('test autoDescribeProfileApiPluginsKanbanProfilesProfileNameDescribeAutoPost', () async {
      // TODO
    });

    // Backfill Session Owner Profiles
    //
    // Stamp legacy ``profile_name = NULL`` rows with the serving-profile identity.  A multi-connection Desktop fails closed on unowned rows.  Each ``state.db`` belongs to exactly one profile, so this is a single-match, idempotent backfill (non-NULL owners are never overwritten).  That was fine while one backend served everything, but a Desktop with registry topology (≥2 registered connections) fails closed on unowned rows by design — leaving every pre-campaign session unresumable with no migration path. Each profile's ``state.db`` belongs to exactly one profile, so stamping that store's own name is a single-match backfill, never a guess; the value written is the SAME serving-profile identity the list endpoints already stamp onto outgoing rows (``row_profile`` in ``get_sessions``). See #95407.
    //
    //Future<Object> backfillSessionOwnerProfilesApiSessionsOwnerBackfillPost(SessionOwnerBackfill sessionOwnerBackfill) async
    test(
      'test backfillSessionOwnerProfilesApiSessionsOwnerBackfillPost',
      () async {
        // TODO
      },
    );

    // Bulk Delete Sessions Endpoint
    //
    // Delete every session in ``body.ids`` in one transaction (POST: many clients refuse a DELETE body).  Per :meth:`SessionDB.delete_sessions`: unknown ids are skipped (``deleted`` reports what really happened), children are orphaned, active/archived rows ARE deleted (hand-picked), on-disk cleanup is left to the next prune.
    //
    //Future<Object> bulkDeleteSessionsEndpointApiSessionsBulkDeletePost(BulkDeleteSessions bulkDeleteSessions) async
    test('test bulkDeleteSessionsEndpointApiSessionsBulkDeletePost', () async {
      // TODO
    });

    // Bulk Update
    //
    // Apply the same patch to every id. Independent iteration — per-task failures don't abort siblings; returns per-id outcome for partials.
    //
    //Future<Object> bulkUpdateApiPluginsKanbanTasksBulkPost(BulkTaskBody bulkTaskBody, { String board }) async
    test('test bulkUpdateApiPluginsKanbanTasksBulkPost', () async {
      // TODO
    });

    // Cancel Mcp Oauth Flow
    //
    // Cancel an in-flight flow. mark_error unblocks the worker so it frees the per-server \"already in progress\" slot — otherwise a renderer that stops polling leaves the flow squatting until the 300s callback timeout and every retry 409s. Idempotent: a settled flow is left as-is.
    //
    //Future<Object> cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete(String flowId) async
    test('test cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete', () async {
      // TODO
    });

    // Cancel Oauth Session
    //
    // Cancel a pending OAuth session. Token-protected.  Marks the session dict ``cancelled`` before popping it so a background worker still holding that dict (e.g. the Codex poller) stops polling/exchanging/saving instead of completing the login after the user believed it was aborted.
    //
    //Future<Object> cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete(String sessionId, { String profile }) async
    test(
      'test cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete',
      () async {
        // TODO
      },
    );

    // Cancel Telegram Onboarding
    //
    //Future<Object> cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete(String pairingId) async
    test('test cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete', () async {
      // TODO
    });

    // Cancel Whatsapp Onboarding
    //
    //Future<Object> cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete(String pairingId) async
    test('test cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete', () async {
      // TODO
    });

    // Check Hermes Update
    //
    // Report whether a Hermes update is available, without applying it.  Returns install_method ('apt'|'git'|'docker'|'nix'|'nixos'|'unknown'), current_version, behind (commits behind, 0 = up to date, -1 = unknown count, null = check could not run), update_available, can_apply (git only — the dashboard button can apply in place), update_command, message (guidance for non-applyable methods) and, for git installs that are behind, commits [{sha, summary, author, at}] (additive; existing consumers ignore it).
    //
    //Future<Object> checkHermesUpdateApiHermesUpdateCheckGet({ bool force }) async
    test('test checkHermesUpdateApiHermesUpdateCheckGet', () async {
      // TODO
    });

    // Clear Pending Pairing
    //
    //Future<Object> clearPendingPairingApiPairingClearPendingPost({ String profile }) async
    test('test clearPendingPairingApiPairingClearPendingPost', () async {
      // TODO
    });

    // Count Empty Sessions Endpoint
    //
    // Count of empty, ended, non-archived sessions (the \"Delete empty (N)\" button).
    //
    //Future<Object> countEmptySessionsEndpointApiSessionsEmptyCountGet({ String profile }) async
    test('test countEmptySessionsEndpointApiSessionsEmptyCountGet', () async {
      // TODO
    });

    // Create Board Endpoint
    //
    // Create a board. Idempotent — ``slug`` collision returns the existing one.
    //
    //Future<Object> createBoardEndpointApiPluginsKanbanBoardsPost(CreateBoardBody createBoardBody) async
    test('test createBoardEndpointApiPluginsKanbanBoardsPost', () async {
      // TODO
    });

    // Create Cron Job
    //
    //Future<Object> createCronJobApiCronJobsPost(CronJobCreate cronJobCreate, { String profile }) async
    test('test createCronJobApiCronJobsPost', () async {
      // TODO
    });

    // Create Hook
    //
    // Add a shell hook to config.yaml and optionally record consent.  Shell hooks run arbitrary commands, so this is privileged: it writes the ``hooks:`` block and, with ``approve``, records the allowlist entry so the hook actually fires. Takes effect on the next session / gateway restart.
    //
    //Future<Object> createHookApiOpsHooksPost(HookCreate hookCreate) async
    test('test createHookApiOpsHooksPost', () async {
      // TODO
    });

    // Create Managed Directory
    //
    //Future<Object> createManagedDirectoryApiFilesMkdirPost(ManagedDirectoryCreate managedDirectoryCreate) async
    test('test createManagedDirectoryApiFilesMkdirPost', () async {
      // TODO
    });

    // Create Profile Endpoint
    //
    //Future<Object> createProfileEndpointApiProfilesPost(ProfileCreate profileCreate) async
    test('test createProfileEndpointApiProfilesPost', () async {
      // TODO
    });

    // Create Skill
    //
    // Create a skill via the agent's ``skill_manage`` write path, minus the write-approval gate — an authenticated dashboard write IS the user.
    //
    //Future<Object> createSkillApiSkillsPost(SkillCreate skillCreate) async
    test('test createSkillApiSkillsPost', () async {
      // TODO
    });

    // Create Task
    //
    //Future<Object> createTaskApiPluginsKanbanTasksPost(CreateTaskBody createTaskBody, { String board }) async
    test('test createTaskApiPluginsKanbanTasksPost', () async {
      // TODO
    });

    // Create Voice Live Session
    //
    // Exchange the renderer's WebRTC SDP offer for a GPT-Live session answer.  The project API key stays on this host; the renderer only receives the session id and the SDP answer. Client delegation is fixed at creation: every ``session.delegation.created`` the renderer receives becomes a Hermes turn on the session it belongs to.
    //
    //Future<Object> createVoiceLiveSessionApiAudioVoiceLiveSessionPost(VoiceLiveSessionRequest voiceLiveSessionRequest, { String profile }) async
    test('test createVoiceLiveSessionApiAudioVoiceLiveSessionPost', () async {
      // TODO
    });

    // Create Webhook
    //
    //Future<Object> createWebhookApiWebhooksPost(WebhookCreate webhookCreate) async
    test('test createWebhookApiWebhooksPost', () async {
      // TODO
    });

    // Cron Fire Webhook
    //
    // Chronos managed-cron fire webhook (NAS -> agent) — gateway forwarder.  Gated by the NAS-minted JWT (path is in ``PUBLIC_API_PATHS``), not the dashboard cookie. Execution belongs to the GATEWAY process (it owns the live platform adapters relay-fronted and E2EE targets need), so the fire is forwarded to the gateway api_server's own ``/api/cron/fire`` on loopback and its response passed through (the gateway re-verifies the JWT). Gateway unreachable -> 503 so NAS retries; deliberately NO local-execution fallback.
    //
    //Future<Object> cronFireWebhookApiCronFirePost() async
    test('test cronFireWebhookApiCronFirePost', () async {
      // TODO
    });

    // Decompose Task Endpoint
    //
    // Fan a triage task out into child tasks via the auxiliary LLM (``hermes kanban decompose``). Non-OK is NOT an HTTP error. Sync ``def`` → runs in the threadpool.
    //
    //Future<Object> decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost(String taskId, DecomposeBody decomposeBody, { String board }) async
    test(
      'test decomposeTaskEndpointApiPluginsKanbanTasksTaskIdDecomposePost',
      () async {
        // TODO
      },
    );

    // Delete Agent Plugin
    //
    //Future<Object> deleteAgentPluginApiDashboardAgentPluginsNameDelete(String name) async
    test('test deleteAgentPluginApiDashboardAgentPluginsNameDelete', () async {
      // TODO
    });

    // Delete Board
    //
    // Archive (default) or hard-delete a board.
    //
    //Future<Object> deleteBoardApiPluginsKanbanBoardsSlugDelete(String slug, { bool delete }) async
    test('test deleteBoardApiPluginsKanbanBoardsSlugDelete', () async {
      // TODO
    });

    // Delete Cron Job
    //
    //Future<Object> deleteCronJobApiCronJobsJobIdDelete(String jobId, { String profile }) async
    test('test deleteCronJobApiCronJobsJobIdDelete', () async {
      // TODO
    });

    // Delete Custom Endpoint
    //
    // Remove a configured custom endpoint from ``providers``.
    //
    //Future<Object> deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete(String endpointId, { String profile }) async
    test(
      'test deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete',
      () async {
        // TODO
      },
    );

    // Delete Empty Sessions Endpoint
    //
    // Delete every empty, ended, non-archived session in one transaction.  \"Empty\" means NO ``messages`` rows at all — a rewound/compacted chat reads ``message_count == 0`` while its soft-archived rows are the only transcript copy (see :meth:`SessionDB.delete_empty_sessions`).  * Active sessions are skipped (``ended_at IS NULL``) so a live agent isn't yanked mid-handshake. * Archived sessions are skipped — the user explicitly chose to keep those rows. * Children of deleted parents are orphaned, not cascade-deleted. See #95868.
    //
    //Future<Object> deleteEmptySessionsEndpointApiSessionsEmptyDelete({ String profile }) async
    test('test deleteEmptySessionsEndpointApiSessionsEmptyDelete', () async {
      // TODO
    });

    // Delete Hook
    //
    // Remove a hook from config.yaml and revoke its consent allowlist entry.
    //
    //Future<Object> deleteHookApiOpsHooksDelete(HookDelete hookDelete) async
    test('test deleteHookApiOpsHooksDelete', () async {
      // TODO
    });

    // Delete Learning Node
    //
    // Delete a journey node — skills are archived (restorable), memories removed.
    //
    //Future<Object> deleteLearningNodeApiLearningNodeDelete(LearningNodeRef learningNodeRef) async
    test('test deleteLearningNodeApiLearningNodeDelete', () async {
      // TODO
    });

    // Delete Link
    //
    //Future<Object> deleteLinkApiPluginsKanbanLinksDelete(String parentId, String childId, { String board }) async
    test('test deleteLinkApiPluginsKanbanLinksDelete', () async {
      // TODO
    });

    // Delete Managed File
    //
    //Future<Object> deleteManagedFileApiFilesDelete(ManagedFileDelete managedFileDelete) async
    test('test deleteManagedFileApiFilesDelete', () async {
      // TODO
    });

    // Delete Profile Endpoint
    //
    // The dashboard collects the user's confirmation in its own dialog, so ``yes=True`` always skips the CLI's interactive prompt.  A delete whose identity settlement stays pending answers ``ok`` with ``settlement_pending`` and the retry command: the profile directory is already gone, and folding that state into the generic 500 made a dashboard client read a completed delete as a failure (its retry then 404'd).
    //
    //Future<Object> deleteProfileEndpointApiProfilesNameDelete(String name) async
    test('test deleteProfileEndpointApiProfilesNameDelete', () async {
      // TODO
    });

    // Delete Session Endpoint
    //
    //Future<Object> deleteSessionEndpointApiSessionsSessionIdDelete(String sessionId, { String profile }) async
    test('test deleteSessionEndpointApiSessionsSessionIdDelete', () async {
      // TODO
    });

    // Delete Task
    //
    //Future<Object> deleteTaskApiPluginsKanbanTasksTaskIdDelete(String taskId, { String board }) async
    test('test deleteTaskApiPluginsKanbanTasksTaskIdDelete', () async {
      // TODO
    });

    // Delete Webhook
    //
    //Future<Object> deleteWebhookApiWebhooksNameDelete(String name) async
    test('test deleteWebhookApiWebhooksNameDelete', () async {
      // TODO
    });

    // Describe Profile Auto Endpoint
    //
    // Auto-generate a profile's description via the auxiliary LLM (mirrors ``hermes profile describe <name> --auto``). A failed generation is ``ok: false`` with a reason rather than an HTTP error so the UI can surface it inline and let the operator retry.
    //
    //Future<Object> describeProfileAutoEndpointApiProfilesNameDescribeAutoPost(String name, ProfileDescribeAuto profileDescribeAuto) async
    test(
      'test describeProfileAutoEndpointApiProfilesNameDescribeAutoPost',
      () async {
        // TODO
      },
    );

    // Disconnect Oauth Provider
    //
    // Disconnect an OAuth provider. Token-protected (matches /env/reveal).
    //
    //Future<Object> disconnectOauthProviderApiProvidersOauthProviderIdDelete(String providerId, { String profile }) async
    test(
      'test disconnectOauthProviderApiProvidersOauthProviderIdDelete',
      () async {
        // TODO
      },
    );

    // Dispatch
    //
    // Dispatch nudge so the UI doesn't wait out the 60 s dispatcher tick.
    //
    //Future<Object> dispatchApiPluginsKanbanDispatchPost({ bool dryRun, int max, String board }) async
    test('test dispatchApiPluginsKanbanDispatchPost', () async {
      // TODO
    });

    // Download Attachment
    //
    //Future<Object> downloadAttachmentApiPluginsKanbanAttachmentsAttachmentIdGet(int attachmentId, { String board }) async
    test(
      'test downloadAttachmentApiPluginsKanbanAttachmentsAttachmentIdGet',
      () async {
        // TODO
      },
    );

    // Download Dashboard Backup
    //
    //Future<Object> downloadDashboardBackupApiOpsBackupDownloadGet(String archive) async
    test('test downloadDashboardBackupApiOpsBackupDownloadGet', () async {
      // TODO
    });

    // Download Managed File
    //
    // Stream a managed file as an attachment download.  ``auth_middleware`` also accepts the session token as ``?token=`` here so a shell/browser-opened download (no session header) still authenticates. Chromium marks ``<audio>``/``<video>`` subresource requests via ``Sec-Fetch-Dest``; those are served inline for Desktop builds that still use this route as their player source, attachment semantics otherwise.
    //
    //Future<Object> downloadManagedFileApiFilesDownloadGet(String path) async
    test('test downloadManagedFileApiFilesDownloadGet', () async {
      // TODO
    });

    // Enable Webhooks
    //
    //Future<Object> enableWebhooksApiWebhooksEnablePost() async
    test('test enableWebhooksApiWebhooksEnablePost', () async {
      // TODO
    });

    // Estimate Task Endpoint
    //
    // Estimate for an existing task; ``{ok, est_tokens, complexity, rationale, model}``.
    //
    //Future<Object> estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost(String taskId, { String board }) async
    test(
      'test estimateTaskEndpointApiPluginsKanbanTasksTaskIdEstimatePost',
      () async {
        // TODO
      },
    );

    // Estimate Text Endpoint
    //
    // Estimate from raw title/body (create dialog, before a task exists).
    //
    //Future<Object> estimateTextEndpointApiPluginsKanbanEstimatePost(EstimateBody estimateBody) async
    test('test estimateTextEndpointApiPluginsKanbanEstimatePost', () async {
      // TODO
    });

    // Export Board Endpoint
    //
    // Write ``slug`` to a portable archive; return the path written.
    //
    //Future<Object> exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost(String slug, ExportBoardBody exportBoardBody) async
    test(
      'test exportBoardEndpointApiPluginsKanbanBoardsSlugExportPost',
      () async {
        // TODO
      },
    );

    // Export Profile Endpoint
    //
    //Future<Object> exportProfileEndpointApiProfilesNameExportPost(String name, ProfileExport profileExport) async
    test('test exportProfileEndpointApiProfilesNameExportPost', () async {
      // TODO
    });

    // Export Session Endpoint
    //
    // Stream a single session (metadata + messages) as JSON.
    //
    //Future<Object> exportSessionEndpointApiSessionsSessionIdExportGet(String sessionId, { String profile }) async
    test('test exportSessionEndpointApiSessionsSessionIdExportGet', () async {
      // TODO
    });

    // Fs Default Cwd
    //
    //Future<Object> fsDefaultCwdApiFsDefaultCwdGet() async
    test('test fsDefaultCwdApiFsDefaultCwdGet', () async {
      // TODO
    });

    // Fs Download
    //
    //Future<Object> fsDownloadApiFsDownloadGet(String path, { String profile, String sessionId }) async
    test('test fsDownloadApiFsDownloadGet', () async {
      // TODO
    });

    // Fs Git Root
    //
    //Future<Object> fsGitRootApiFsGitRootGet(String path) async
    test('test fsGitRootApiFsGitRootGet', () async {
      // TODO
    });

    // Fs List
    //
    //Future<Object> fsListApiFsListGet(String path) async
    test('test fsListApiFsListGet', () async {
      // TODO
    });

    // Fs Read Data Url
    //
    //Future<Object> fsReadDataUrlApiFsReadDataUrlGet(String path, { String profile, String sessionId }) async
    test('test fsReadDataUrlApiFsReadDataUrlGet', () async {
      // TODO
    });

    // Fs Read Text
    //
    //Future<Object> fsReadTextApiFsReadTextGet(String path) async
    test('test fsReadTextApiFsReadTextGet', () async {
      // TODO
    });

    // Fs Write Text
    //
    // Overwrite (or create) a UTF-8 text file for the in-app spot editor.  Mirrors the Electron ``hermes:fs:writeText`` hardening: path validated by ``_fs_path``, the parent must already exist (never build trees), only regular files may be replaced, payload size-capped, staged to a sibling temp file and ``os.replace``-d so a crash can't truncate the original. Stale-on-disk detection is the client's job (re-read before save).
    //
    //Future<Object> fsWriteTextApiFsWriteTextPost(FsWriteText fsWriteText) async
    test('test fsWriteTextApiFsWriteTextPost', () async {
      // TODO
    });

    // Gateway Drain
    //
    // Begin or cancel an external (NAS-driven) gateway drain.  Authenticated by the non-interactive token-auth seam (the ``dashboard_auth/drain`` plugin registers this path as a token route and verifies the bearer secret); without that plugin the cookie gate covers a gated bind and the legacy session-token gate a loopback bind — never unauthenticated on a network bind.  Body ``{\"action\": \"drain\"|\"cancel\"}``. Only the ``.drain_request.json`` marker is written/removed here — the gateway's ``_drain_control_watcher`` owns the state transition (the marker IS the control channel). Idempotent on both sides; ``POST /api/gateway/restart`` is the force-override that supersedes a drain.
    //
    //Future<Object> gatewayDrainApiGatewayDrainPost() async
    test('test gatewayDrainApiGatewayDrainPost', () async {
      // TODO
    });

    // Gateway Migrate
    //
    // Run ``hermes gateway migrate --multiplex --yes`` detached; the CLI re-runs the preflight and refuses (exit 1 into the action log) when blocked, so the UI should gate on the plan first.
    //
    //Future<Object> gatewayMigrateApiGatewayMigratePost() async
    test('test gatewayMigrateApiGatewayMigratePost', () async {
      // TODO
    });

    // Gateway Migrate Plan
    //
    // Preflight for folding per-profile gateways into one multiplexer (same JSON as the CLI plan).
    //
    //Future<Object> gatewayMigratePlanApiGatewayMigratePlanGet() async
    test('test gatewayMigratePlanApiGatewayMigratePlanGet', () async {
      // TODO
    });

    // Get Action Status
    //
    // Tail an action log and report whether the process is still running.
    //
    //Future<Object> getActionStatusApiActionsNameStatusGet(String name, { int lines }) async
    test('test getActionStatusApiActionsNameStatusGet', () async {
      // TODO
    });

    // Get Active Profile Endpoint
    //
    // ``active`` is the sticky default written by ``hermes profile use`` (what new CLI invocations pick up); ``current`` is the profile this running dashboard is scoped to.
    //
    //Future<Object> getActiveProfileEndpointApiProfilesActiveGet() async
    test('test getActiveProfileEndpointApiProfilesActiveGet', () async {
      // TODO
    });

    // Get Assignees
    //
    // Union of on-disk profiles and assignees used on the board, so a fresh profile appears in the picker before it has any task.
    //
    //Future<Object> getAssigneesApiPluginsKanbanAssigneesGet({ String board }) async
    test('test getAssigneesApiPluginsKanbanAssigneesGet', () async {
      // TODO
    });

    // Get Auxiliary Models
    //
    // Current auxiliary task assignments: ``{\"tasks\": [{task, provider, model, base_url}, ...], \"main\": {provider, model}}``. ``profile`` scopes the read — without it the Models page would show the dashboard profile's pins while /api/model/set wrote the selected profile's.
    //
    //Future<Object> getAuxiliaryModelsApiModelAuxiliaryGet({ String profile }) async
    test('test getAuxiliaryModelsApiModelAuxiliaryGet', () async {
      // TODO
    });

    // Get Board Endpoint
    //
    //Future<Object> getBoardEndpointApiPluginsKanbanBoardGet({ String tenant, bool includeArchived, String board, String workflowTemplateId, String currentStepKey }) async
    test('test getBoardEndpointApiPluginsKanbanBoardGet', () async {
      // TODO
    });

    // Get Client Voice Config
    //
    // The active profile's STT/TTS config for CLIENT-DIRECT voice.  Lets the desktop cut the audio relay hop: mic audio goes straight to the profile's STT provider and reply text is synthesized on the client with the profile's TTS provider — the desktop↔gateway link carries only text. Providers that can only run on this host (local whisper, edge-tts, command/plugin providers) resolve to ``{\"mode\": \"relay\"}`` and the desktop keeps using the /api/audio/_* relay endpoints.  Same trust boundary as every profile-scoped route: the caller is an authenticated client that can already drive the agent. Keys in the response are held in client memory only, never persisted client-side. Gate: ``voice.client_direct`` in config.yaml (default true).
    //
    //Future<Object> getClientVoiceConfigApiAudioVoiceConfigGet({ String profile }) async
    test('test getClientVoiceConfigApiAudioVoiceConfigGet', () async {
      // TODO
    });

    // Get Computer Use Status
    //
    // Computer Use readiness for the desktop card (payload shape: see ``tools.computer_use.permissions.computer_use_status``).
    //
    //Future<Object> getComputerUseStatusApiToolsComputerUseStatusGet({ String profile }) async
    test('test getComputerUseStatusApiToolsComputerUseStatusGet', () async {
      // TODO
    });

    // Get Config
    //
    //Future<Object> getConfigApiConfigGet({ String profile, bool includeDefaults }) async
    test('test getConfigApiConfigGet', () async {
      // TODO
    });

    // Get Config
    //
    // Kanban dashboard preferences from the ``dashboard.kanban`` config section.
    //
    //Future<Object> getConfigApiPluginsKanbanConfigGet() async
    test('test getConfigApiPluginsKanbanConfigGet', () async {
      // TODO
    });

    // Get Config Raw
    //
    // Raw config.yaml text plus its resolved path.  ``path`` is resolved inside ``_profile_scope`` so the Config page header shows the file the switched profile actually reads/writes — /api/status's ``config_path`` is machine-global and always reports the dashboard process's own profile, which is wrong under the global profile switcher.
    //
    //Future<Object> getConfigRawApiConfigRawGet({ String profile }) async
    test('test getConfigRawApiConfigRawGet', () async {
      // TODO
    });

    // Get Cron Delivery Targets
    //
    // Delivery targets for the cron dropdown: implicit ``local`` plus the configured gateway platforms (a platform without a cron home channel is still listed with ``home_target_set: false`` so the UI can say so).
    //
    //Future<Object> getCronDeliveryTargetsApiCronDeliveryTargetsGet() async
    test('test getCronDeliveryTargetsApiCronDeliveryTargetsGet', () async {
      // TODO
    });

    // Get Cron Job
    //
    //Future<Object> getCronJobApiCronJobsJobIdGet(String jobId, { String profile }) async
    test('test getCronJobApiCronJobsJobIdGet', () async {
      // TODO
    });

    // Get Curator Status
    //
    //Future<Object> getCuratorStatusApiCuratorGet() async
    test('test getCuratorStatusApiCuratorGet', () async {
      // TODO
    });

    // Get Dashboard Font
    //
    // Return the active font override (``\"theme\"`` = use the theme's font).
    //
    //Future<Object> getDashboardFontApiDashboardFontGet() async
    test('test getDashboardFontApiDashboardFontGet', () async {
      // TODO
    });

    // Get Dashboard Plugins
    //
    // Return discovered dashboard plugins (excludes user-hidden and non-enabled ones).
    //
    //Future<Object> getDashboardPluginsApiDashboardPluginsGet() async
    test('test getDashboardPluginsApiDashboardPluginsGet', () async {
      // TODO
    });

    // Get Dashboard Themes
    //
    // Available themes + the active one. Built-ins ship name/label/description only (the frontend owns their definitions in `web/src/themes/presets.ts`); user themes from `~/.hermes/dashboard-themes/_*.yaml` ship their normalised `definition`.
    //
    //Future<Object> getDashboardThemesApiDashboardThemesGet() async
    test('test getDashboardThemesApiDashboardThemesGet', () async {
      // TODO
    });

    // Get Defaults
    //
    //Future<Object> getDefaultsApiConfigDefaultsGet() async
    test('test getDefaultsApiConfigDefaultsGet', () async {
      // TODO
    });

    // Get Egress Status
    //
    // Dashboard/Desktop-readable egress proxy status and remediation text.
    //
    //Future<Object> getEgressStatusApiEgressStatusGet() async
    test('test getEgressStatusApiEgressStatusGet', () async {
      // TODO
    });

    // Get Elevenlabs Voices
    //
    // Return ElevenLabs voices when an API key is configured.  The desktop UI uses this for the ``tts.elevenlabs.voice_id`` dropdown. Only non-secret voice metadata is returned; the API key stays server-side.
    //
    //Future<Object> getElevenlabsVoicesApiAudioElevenlabsVoicesGet({ String profile }) async
    test('test getElevenlabsVoicesApiAudioElevenlabsVoicesGet', () async {
      // TODO
    });

    // Get Env Vars
    //
    //Future<Object> getEnvVarsApiEnvGet({ String profile }) async
    test('test getEnvVarsApiEnvGet', () async {
      // TODO
    });

    // Get Health
    //
    // Lightweight process liveness for desktop/backend readiness probes.
    //
    //Future<Object> getHealthApiHealthGet() async
    test('test getHealthApiHealthGet', () async {
      // TODO
    });

    // Get Health Idle
    //
    // Token-gated diagnostic snapshot; never a retirement permit. None means cannot prove idle.
    //
    //Future<Object> getHealthIdleApiHealthIdleGet() async
    test('test getHealthIdleApiHealthIdleGet', () async {
      // TODO
    });

    // Get Home Channels
    //
    // Every platform with a home channel plus whether *task_id* (if given) is subscribed to it; without ``task_id`` every ``subscribed`` is false.
    //
    //Future<Object> getHomeChannelsApiPluginsKanbanHomeChannelsGet({ String taskId, String board }) async
    test('test getHomeChannelsApiPluginsKanbanHomeChannelsGet', () async {
      // TODO
    });

    // Get Learning Graph
    //
    // Learning graph for the desktop panel: profile-scoped learned skills + memory chunks.
    //
    //Future<Object> getLearningGraphApiLearningGraphGet({ String profile }) async
    test('test getLearningGraphApiLearningGraphGet', () async {
      // TODO
    });

    // Get Learning Node
    //
    // Current content of a journey node (skill SKILL.md or memory chunk), for an edit prefill.
    //
    //Future<Object> getLearningNodeApiLearningNodeGet(String id, { String profile }) async
    test('test getLearningNodeApiLearningNodeGet', () async {
      // TODO
    });

    // Get Logs
    //
    //Future<Object> getLogsApiLogsGet({ String file, int lines, String level, String component, String search }) async
    test('test getLogsApiLogsGet', () async {
      // TODO
    });

    // Get Media
    //
    // Return a gateway-local image as a base64 data URL for remote clients that can't read this machine's disk. Auth-gated; restricted to the image allowlist, a size cap AND the resolved (symlink-safe) media roots.
    //
    //Future<Object> getMediaApiMediaGet(String path) async
    test('test getMediaApiMediaGet', () async {
      // TODO
    });

    // Get Memory Provider Config
    //
    //Future<Object> getMemoryProviderConfigApiMemoryProvidersNameConfigGet(String name, { String surface, String profile }) async
    test(
      'test getMemoryProviderConfigApiMemoryProvidersNameConfigGet',
      () async {
        // TODO
      },
    );

    // Get Memory Status
    //
    //Future<Object> getMemoryStatusApiMemoryGet() async
    test('test getMemoryStatusApiMemoryGet', () async {
      // TODO
    });

    // Get Messaging Platforms
    //
    //Future<Object> getMessagingPlatformsApiMessagingPlatformsGet({ String profile }) async
    test('test getMessagingPlatformsApiMessagingPlatformsGet', () async {
      // TODO
    });

    // Get Moa Models
    //
    // Return the configured Mixture-of-Agents provider/model slots.
    //
    //Future<Object> getMoaModelsApiModelMoaGet({ String profile }) async
    test('test getMoaModelsApiModelMoaGet', () async {
      // TODO
    });

    // Get Model Info
    //
    // Resolved metadata for the configured model: auto-detected vs configured context length (so the UI can show \"Auto-detected: 200K\" beside the override) plus models.dev capabilities when available.
    //
    //Future<Object> getModelInfoApiModelInfoGet({ String profile }) async
    test('test getModelInfoApiModelInfoGet', () async {
      // TODO
    });

    // Get Model Options
    //
    // Authenticated providers + curated model lists — REST twin of the ``model.options`` JSON-RPC on tui_gateway, same response shape so ``ModelPickerDialog`` shares the types. ``profile`` scopes the picker context so the Models page reads the SAME profile /api/model/set writes. ``refresh`` busts the per-provider model-id disk cache (picker's explicit \"Refresh Models\"); normal opens stay on the 1h cache.
    //
    //Future<Object> getModelOptionsApiModelOptionsGet({ String profile, bool refresh, bool includeUnconfigured, bool explicitOnly }) async
    test('test getModelOptionsApiModelOptionsGet', () async {
      // TODO
    });

    // Get Models Analytics
    //
    // Return model analytics without blocking the serving event loop.
    //
    //Future<Object> getModelsAnalyticsApiAnalyticsModelsGet({ int days, String profile }) async
    test('test getModelsAnalyticsApiAnalyticsModelsGet', () async {
      // TODO
    });

    // Get Orchestration Settings
    //
    // Current orchestration knobs from config.yaml plus the resolved effective values. An unset/unknown profile resolves to the active profile here; the decomposer prefers the root card's assignee in that case and uses the active profile only for cards with no assignee.
    //
    //Future<Object> getOrchestrationSettingsApiPluginsKanbanOrchestrationGet() async
    test(
      'test getOrchestrationSettingsApiPluginsKanbanOrchestrationGet',
      () async {
        // TODO
      },
    );

    // Get Plugins Catalog
    //
    // Curated plugin catalog merged with installed state (session protected).
    //
    //Future<Object> getPluginsCatalogApiDashboardPluginsCatalogGet() async
    test('test getPluginsCatalogApiDashboardPluginsCatalogGet', () async {
      // TODO
    });

    // Get Plugins Hub
    //
    // Unified agent plugins + dashboard extension metadata (session protected).
    //
    //Future<Object> getPluginsHubApiDashboardPluginsHubGet() async
    test('test getPluginsHubApiDashboardPluginsHubGet', () async {
      // TODO
    });

    // Get Portal Status
    //
    //Future<Object> getPortalStatusApiPortalGet() async
    test('test getPortalStatusApiPortalGet', () async {
      // TODO
    });

    // Get Profile Desktop Overlay
    //
    // The desktop appearance/interface overlay bundled with an imported profile (``desktop.json`` at the profile root), or ``exists: false``.
    //
    //Future<Object> getProfileDesktopOverlayApiProfilesNameDesktopOverlayGet(String name) async
    test(
      'test getProfileDesktopOverlayApiProfilesNameDesktopOverlayGet',
      () async {
        // TODO
      },
    );

    // Get Profile Setup Command
    //
    //Future<Object> getProfileSetupCommandApiProfilesNameSetupCommandGet(String name) async
    test('test getProfileSetupCommandApiProfilesNameSetupCommandGet', () async {
      // TODO
    });

    // Get Profile Soul
    //
    //Future<Object> getProfileSoulApiProfilesNameSoulGet(String name) async
    test('test getProfileSoulApiProfilesNameSoulGet', () async {
      // TODO
    });

    // Get Profiles Projects Tree
    //
    // Project tree for every profile at once, for the all-profiles sidebar.  ``projects.tree`` over JSON-RPC answers for the backend's own profile only; this runs the same builder once per profile against its ``state.db``, scoping the other inputs (projects.db, repo-scan policy, junk filters) through the home override. Discovery is off: a repo with zero sessions is the same repo in every profile (the disk scan would multiply empty lanes by the profile count), and discovery is the one part of the builder that writes (policy reconciliation), which a read-only fan-out must not do.
    //
    //Future<Object> getProfilesProjectsTreeApiProfilesProjectsTreeGet({ int previewLimit, int sessionLimit }) async
    test('test getProfilesProjectsTreeApiProfilesProjectsTreeGet', () async {
      // TODO
    });

    // Get Profiles Sessions
    //
    // Unified, read-only session list aggregated across ALL profiles: opens each profile's ``state.db`` directly (no dashboard backend per profile) and tags rows with their owning ``profile``. Rows omit ``system_prompt`` / ``model_config`` unless ``full=1`` — same projection as ``/api/sessions``.
    //
    //Future<Object> getProfilesSessionsApiProfilesSessionsGet({ int limit, int offset, int minMessages, String archived, String order, String profile, String source_, String sources, String excludeSources, bool full }) async
    test('test getProfilesSessionsApiProfilesSessionsGet', () async {
      // TODO
    });

    // Get Profiles Sessions Sidebar
    //
    // Batched sidebar session slices (recents / cron / messaging) — one profile-DB open per refresh instead of three ``/api/profiles/sessions`` calls. Same row projection and 300s active heuristic as the per-slice endpoint; all slices use ``min_messages=1`` / ``archived=exclude`` / recency order.  ``recents_profile`` scopes the WHOLE payload, not just recents — the sidebar has one scope, so a concrete profile must never show another profile's Telegram threads or cronjobs; ``all`` asks for everything.  See #42651, #65710, #70629.
    //
    //Future<Object> getProfilesSessionsSidebarApiProfilesSessionsSidebarGet({ String recentsProfile, int recentsLimit, String recentsExclude, int cronLimit, int messagingLimit, String messagingExclude }) async
    test(
      'test getProfilesSessionsSidebarApiProfilesSessionsSidebarGet',
      () async {
        // TODO
      },
    );

    // Get Recommended Default Model
    //
    // Recommended default model for a freshly-authenticated provider, mirroring ``hermes model``'s curation so GUI onboarding lands on a sensible default. Nous honors the user's free/paid tier. Any other provider gets the preferred silent default when its curated list carries it, else the first curated model — aggregator lists lead with the priciest Anthropic flagship, which must never be the model a user lands on without explicitly picking it. Response: {\"provider\", \"model\", \"free_tier\": bool | None} — free_tier only for Nous; ``model`` may be empty (caller degrades gracefully).
    //
    //Future<Object> getRecommendedDefaultModelApiModelRecommendedDefaultGet({ String provider }) async
    test(
      'test getRecommendedDefaultModelApiModelRecommendedDefaultGet',
      () async {
        // TODO
      },
    );

    // Get Run Endpoint
    //
    // ``{run: {...}}`` with the same serialisation as ``GET /tasks/{id}``; 404 if unknown.
    //
    //Future<Object> getRunEndpointApiPluginsKanbanRunsRunIdGet(int runId, { String board }) async
    test('test getRunEndpointApiPluginsKanbanRunsRunIdGet', () async {
      // TODO
    });

    // Get Schema
    //
    //Future<Object> getSchemaApiConfigSchemaGet({ String profile }) async
    test('test getSchemaApiConfigSchemaGet', () async {
      // TODO
    });

    // Get Session Detail
    //
    //Future<Object> getSessionDetailApiSessionsSessionIdGet(String sessionId, { String profile }) async
    test('test getSessionDetailApiSessionsSessionIdGet', () async {
      // TODO
    });

    // Get Session Latest Descendant
    //
    //Future<Object> getSessionLatestDescendantApiSessionsSessionIdLatestDescendantGet(String sessionId, { String profile }) async
    test(
      'test getSessionLatestDescendantApiSessionsSessionIdLatestDescendantGet',
      () async {
        // TODO
      },
    );

    // Get Session Messages
    //
    //Future<Object> getSessionMessagesApiSessionsSessionIdMessagesGet(String sessionId, { String profile, int limit, int offset, String order, bool includeCompacted }) async
    test('test getSessionMessagesApiSessionsSessionIdMessagesGet', () async {
      // TODO
    });

    // Get Session Messages Around
    //
    // Bounded display page starting at a timeline prompt; no intervening payloads.
    //
    //Future<Object> getSessionMessagesAroundApiSessionsSessionIdMessagesAroundGet(String sessionId, int rowId, { String profile, int limit }) async
    test(
      'test getSessionMessagesAroundApiSessionsSessionIdMessagesAroundGet',
      () async {
        // TODO
      },
    );

    // Get Session Stats
    //
    // Session-store statistics (mirrors `hermes sessions stats`).
    //
    //Future<Object> getSessionStatsApiSessionsStatsGet({ String profile }) async
    test('test getSessionStatsApiSessionsStatsGet', () async {
      // TODO
    });

    // Get Session Timeline
    //
    // Prompt metadata only, including compacted display history (never rewind rows).  ``next_cursor`` is a stable logical first-row id; pass it as ``after_row_id``. Entry ``row_id`` addresses the current representative for /messages/around.
    //
    //Future<Object> getSessionTimelineApiSessionsSessionIdTimelineGet(String sessionId, { String profile, int limit, int afterRowId }) async
    test('test getSessionTimelineApiSessionsSessionIdTimelineGet', () async {
      // TODO
    });

    // Get Sessions
    //
    // List sessions.  ``order=recent`` sorts by latest activity across the compression chain, so a long-running chat stays on page one after it auto-compresses onto a fresh id.  Rows omit ``system_prompt`` / ``model_config`` unless ``full=1``.
    //
    //Future<Object> getSessionsApiSessionsGet({ int limit, int offset, int minMessages, String archived, String order, String source_, String sources, String excludeSources, String cwdPrefix, bool full, String profile }) async
    test('test getSessionsApiSessionsGet', () async {
      // TODO
    });

    // Get Skill Content
    //
    // Raw SKILL.md text for the dashboard editor.
    //
    //Future<Object> getSkillContentApiSkillsContentGet(String name, { String profile }) async
    test('test getSkillContentApiSkillsContentGet', () async {
      // TODO
    });

    // Get Skills
    //
    //Future<Object> getSkillsApiSkillsGet({ String profile }) async
    test('test getSkillsApiSkillsGet', () async {
      // TODO
    });

    // Get Ssh Ownership
    //
    //Future<Object> getSshOwnershipApiSshOwnershipGet() async
    test('test getSshOwnershipApiSshOwnershipGet', () async {
      // TODO
    });

    // Get Stats
    //
    // Per-status + per-assignee counts + oldest-ready age (HUD and router profiles).
    //
    //Future<Object> getStatsApiPluginsKanbanStatsGet({ String board }) async
    test('test getStatsApiPluginsKanbanStatsGet', () async {
      // TODO
    });

    // Get Status
    //
    // Public machine-level liveness probe (``PUBLIC_API_PATHS``): version, gateway state, active session count and the auth-gate shape — no bodies, no session content, no secrets.  ``?profile=`` (dashboard management switcher) uses the config-only contextvar scope, NOT _profile_scope: this handler awaits the remote health probe, and _profile_scope swaps process-global skills-module attributes a concurrent request would cross-restore.
    //
    //Future<Object> getStatusApiStatusGet({ String profile }) async
    test('test getStatusApiStatusGet', () async {
      // TODO
    });

    // Get System Stats
    //
    // Host + process system stats for the System page (stdlib identity; psutil CPU/memory/ disk/uptime when available). Non-sensitive: no env values, no paths beyond hermes home.
    //
    //Future<Object> getSystemStatsApiSystemStatsGet() async
    test('test getSystemStatsApiSystemStatsGet', () async {
      // TODO
    });

    // Get Task
    //
    //Future<Object> getTaskApiPluginsKanbanTasksTaskIdGet(String taskId, { String board, String runStateType, String runStateName }) async
    test('test getTaskApiPluginsKanbanTasksTaskIdGet', () async {
      // TODO
    });

    // Get Task Log
    //
    // Worker stdout/stderr log. ``tail`` caps the response bytes; 404 if the task never spawned. On-disk log rotates at 2 MiB with one ``.log.1`` kept.
    //
    //Future<Object> getTaskLogApiPluginsKanbanTasksTaskIdLogGet(String taskId, { int tail, String board }) async
    test('test getTaskLogApiPluginsKanbanTasksTaskIdLogGet', () async {
      // TODO
    });

    // Get Telegram Onboarding Status
    //
    //Future<Object> getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet(String pairingId) async
    test('test getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet', () async {
      // TODO
    });

    // Get Terminal Backends
    //
    // Terminal backend rows with health probes: ``status`` is ``ready`` / ``needs_setup`` / ``unavailable``; a probe failure is a status, never an error response.
    //
    //Future<Object> getTerminalBackendsApiToolsTerminalBackendsGet({ String profile }) async
    test('test getTerminalBackendsApiToolsTerminalBackendsGet', () async {
      // TODO
    });

    // Get Toolset Config
    //
    // Provider matrix + key status for a toolset's config panel (the CLI picker rows, each env var annotated ``is_set``); no category -> ``has_category: false``.
    //
    //Future<Object> getToolsetConfigApiToolsToolsetsNameConfigGet(String name, { String profile }) async
    test('test getToolsetConfigApiToolsToolsetsNameConfigGet', () async {
      // TODO
    });

    // Get Toolset Models
    //
    // Model catalog for a toolset backend (image/video gen) — the GUI counterpart of the CLI model picker.  ``provider`` names a picker row (default: the active provider); no catalog -> ``has_models: false``.
    //
    //Future<Object> getToolsetModelsApiToolsToolsetsNameModelsGet(String name, { String provider, String profile }) async
    test('test getToolsetModelsApiToolsToolsetsNameModelsGet', () async {
      // TODO
    });

    // Get Toolsets
    //
    //Future<Object> getToolsetsApiToolsToolsetsGet({ String profile }) async
    test('test getToolsetsApiToolsToolsetsGet', () async {
      // TODO
    });

    // Get Update Receipt
    //
    // The FULL latest update receipt (steps, skips, gateway restart outcome, fleet matrix) plus a compact ``summary``; 404 when no update has run since receipts landed. Clients read this instead of inferring success from backend liveness, which misread the update's own restart gap as a failed update/boot.  See #81193, #87359, #91277.
    //
    //Future<Object> getUpdateReceiptApiHermesUpdateReceiptGet() async
    test('test getUpdateReceiptApiHermesUpdateReceiptGet', () async {
      // TODO
    });

    // Get Usage Analytics
    //
    // ``days`` is clamped to 1-365 (idea from #74778): huge or non-positive values would force expensive full-history SQL and InsightsEngine work, or produce empty/inverted time windows. The UI only offers 7/30/90-day presets.
    //
    //Future<Object> getUsageAnalyticsApiAnalyticsUsageGet({ int days, String profile }) async
    test('test getUsageAnalyticsApiAnalyticsUsageGet', () async {
      // TODO
    });

    // Get Voice Live Status
    //
    // Which voice chat mode the profile selected (``chained`` | ``gpt-live``) and whether GPT-Live can start. Non-secret: the desktop decides which conversation engine to mount from this.
    //
    //Future<Object> getVoiceLiveStatusApiAudioVoiceLiveStatusGet({ String profile }) async
    test('test getVoiceLiveStatusApiAudioVoiceLiveStatusGet', () async {
      // TODO
    });

    // Get Whatsapp Onboarding Status
    //
    //Future<Object> getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet(String pairingId) async
    test('test getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet', () async {
      // TODO
    });

    // Gh Auth Status Route
    //
    // ``{\"available\", \"authenticated\"}`` for the `gh` CLI; cached 5 min (``refresh=true`` bypasses so the pill withdraws right after a login).
    //
    //Future<Object> ghAuthStatusRouteApiGitGhAuthGet({ bool refresh }) async
    test('test ghAuthStatusRouteApiGitGhAuthGet', () async {
      // TODO
    });

    // Git Base Branches Route
    //
    //Future<Object> gitBaseBranchesRouteApiGitBaseBranchesGet(String path) async
    test('test gitBaseBranchesRouteApiGitBaseBranchesGet', () async {
      // TODO
    });

    // Git Branch Switch Route
    //
    //Future<Object> gitBranchSwitchRouteApiGitBranchSwitchPost(GitBranchSwitchBody gitBranchSwitchBody) async
    test('test gitBranchSwitchRouteApiGitBranchSwitchPost', () async {
      // TODO
    });

    // Git Branches Route
    //
    //Future<Object> gitBranchesRouteApiGitBranchesGet(String path) async
    test('test gitBranchesRouteApiGitBranchesGet', () async {
      // TODO
    });

    // Git Commit Context Route
    //
    //Future<Object> gitCommitContextRouteApiGitReviewCommitContextGet(String path) async
    test('test gitCommitContextRouteApiGitReviewCommitContextGet', () async {
      // TODO
    });

    // Git Commit Route
    //
    //Future<Object> gitCommitRouteApiGitReviewCommitPost(GitCommitBody gitCommitBody) async
    test('test gitCommitRouteApiGitReviewCommitPost', () async {
      // TODO
    });

    // Git Create Pr Route
    //
    //Future<Object> gitCreatePrRouteApiGitReviewCreatePrPost(GitPathBody gitPathBody) async
    test('test gitCreatePrRouteApiGitReviewCreatePrPost', () async {
      // TODO
    });

    // Git File Diff Route
    //
    //Future<Object> gitFileDiffRouteApiGitFileDiffGet(String path, String file) async
    test('test gitFileDiffRouteApiGitFileDiffGet', () async {
      // TODO
    });

    // Git Pr List Route
    //
    //Future<Object> gitPrListRouteApiGitReviewPrListPost(GitPrListBody gitPrListBody) async
    test('test gitPrListRouteApiGitReviewPrListPost', () async {
      // TODO
    });

    // Git Push Route
    //
    //Future<Object> gitPushRouteApiGitReviewPushPost(GitPathBody gitPathBody) async
    test('test gitPushRouteApiGitReviewPushPost', () async {
      // TODO
    });

    // Git Rev Parse Route
    //
    //Future<Object> gitRevParseRouteApiGitReviewRevParseGet(String path, { String ref }) async
    test('test gitRevParseRouteApiGitReviewRevParseGet', () async {
      // TODO
    });

    // Git Revert Route
    //
    //Future<Object> gitRevertRouteApiGitReviewRevertPost(GitFileBody gitFileBody) async
    test('test gitRevertRouteApiGitReviewRevertPost', () async {
      // TODO
    });

    // Git Review Diff Route
    //
    //Future<Object> gitReviewDiffRouteApiGitReviewDiffGet(String path, String file, { String scope, String base_, bool staged }) async
    test('test gitReviewDiffRouteApiGitReviewDiffGet', () async {
      // TODO
    });

    // Git Review List Route
    //
    //Future<Object> gitReviewListRouteApiGitReviewListGet(String path, { String scope, String base_ }) async
    test('test gitReviewListRouteApiGitReviewListGet', () async {
      // TODO
    });

    // Git Ship Info Route
    //
    //Future<Object> gitShipInfoRouteApiGitReviewShipInfoGet(String path) async
    test('test gitShipInfoRouteApiGitReviewShipInfoGet', () async {
      // TODO
    });

    // Git Stage Route
    //
    //Future<Object> gitStageRouteApiGitReviewStagePost(GitFileBody gitFileBody) async
    test('test gitStageRouteApiGitReviewStagePost', () async {
      // TODO
    });

    // Git Status Route
    //
    //Future<Object> gitStatusRouteApiGitStatusGet(String path) async
    test('test gitStatusRouteApiGitStatusGet', () async {
      // TODO
    });

    // Git Unstage Route
    //
    //Future<Object> gitUnstageRouteApiGitReviewUnstagePost(GitFileBody gitFileBody) async
    test('test gitUnstageRouteApiGitReviewUnstagePost', () async {
      // TODO
    });

    // Git Worktree Add Route
    //
    //Future<Object> gitWorktreeAddRouteApiGitWorktreeAddPost(GitWorktreeAddBody gitWorktreeAddBody) async
    test('test gitWorktreeAddRouteApiGitWorktreeAddPost', () async {
      // TODO
    });

    // Git Worktree Remove Route
    //
    //Future<Object> gitWorktreeRemoveRouteApiGitWorktreeRemovePost(GitWorktreeRemoveBody gitWorktreeRemoveBody) async
    test('test gitWorktreeRemoveRouteApiGitWorktreeRemovePost', () async {
      // TODO
    });

    // Git Worktrees Route
    //
    //Future<Object> gitWorktreesRouteApiGitWorktreesGet(String path) async
    test('test gitWorktreesRouteApiGitWorktreesGet', () async {
      // TODO
    });

    // Grant Computer Use Permissions
    //
    // Spawn ``hermes computer-use permissions grant`` (macOS-only: launches CuaDriver via LaunchServices so the TCC dialog is attributed correctly). The frontend polls ``GET /api/actions/computer-use-grant/status``.
    //
    //Future<Object> grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost({ String profile }) async
    test(
      'test grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost',
      () async {
        // TODO
      },
    );

    // Import Board Endpoint
    //
    // Import a board archive as a NEW board; return the landed board.
    //
    //Future<Object> importBoardEndpointApiPluginsKanbanBoardsImportPost(ImportBoardBody importBoardBody) async
    test('test importBoardEndpointApiPluginsKanbanBoardsImportPost', () async {
      // TODO
    });

    // Import Profile Endpoint
    //
    //Future<Object> importProfileEndpointApiProfilesImportPost(ProfileImport profileImport) async
    test('test importProfileEndpointApiProfilesImportPost', () async {
      // TODO
    });

    // Import Sessions Endpoint
    //
    // Import sessions exported from the dashboard or CLI (session rows only — ``/api/ops/import`` restores a whole backup archive).
    //
    //Future<Object> importSessionsEndpointApiSessionsImportPost() async
    test('test importSessionsEndpointApiSessionsImportPost', () async {
      // TODO
    });

    // Inspect Run Endpoint
    //
    // Live psutil stats for a run's worker; ``{alive: false, reason}`` when unavailable and access-denied reported inline rather than as a 500.
    //
    //Future<Object> inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet(int runId, { String board }) async
    test(
      'test inspectRunEndpointApiPluginsKanbanRunsRunIdInspectGet',
      () async {
        // TODO
      },
    );

    // Install Mcp Catalog Entry
    //
    // Install a catalog MCP into config.yaml (declared env vars go to .env first; git-bootstrap entries run via the background CLI action path).
    //
    //Future<Object> installMcpCatalogEntryApiMcpCatalogInstallPost(MCPCatalogInstall mCPCatalogInstall, { String profile }) async
    test('test installMcpCatalogEntryApiMcpCatalogInstallPost', () async {
      // TODO
    });

    // Install Skill Hub
    //
    //Future<Object> installSkillHubApiSkillsHubInstallPost(SkillInstallRequest skillInstallRequest, { String profile }) async
    test('test installSkillHubApiSkillsHubInstallPost', () async {
      // TODO
    });

    // Instantiate Blueprint
    //
    // Fill a blueprint's slots and create the cron job (form-submit path).
    //
    //Future<Object> instantiateBlueprintApiCronBlueprintsInstantiatePost(AutomationBlueprintInstantiate automationBlueprintInstantiate, { String profile }) async
    test('test instantiateBlueprintApiCronBlueprintsInstantiatePost', () async {
      // TODO
    });

    // List Active Workers
    //
    // Every running worker: an open ``task_runs`` row with a ``worker_pid`` whose task is ``running``. Returns ``{workers, count, checked_at}``.
    //
    //Future<Object> listActiveWorkersApiPluginsKanbanWorkersActiveGet({ String board }) async
    test('test listActiveWorkersApiPluginsKanbanWorkersActiveGet', () async {
      // TODO
    });

    // List Boards
    //
    // Every board on disk with task counts and the active slug.
    //
    //Future<Object> listBoardsApiPluginsKanbanBoardsGet({ bool includeArchived }) async
    test('test listBoardsApiPluginsKanbanBoardsGet', () async {
      // TODO
    });

    // List Checkpoints
    //
    // /rollback shadow-store checkpoints (read-only): count + size per session so the UI can show what a prune reclaims; pruning itself is a spawned CLI action so the confirmation logic stays in one place.
    //
    //Future<Object> listCheckpointsApiOpsCheckpointsGet() async
    test('test listCheckpointsApiOpsCheckpointsGet', () async {
      // TODO
    });

    // List Credential Pool
    //
    //Future<Object> listCredentialPoolApiCredentialsPoolGet() async
    test('test listCredentialPoolApiCredentialsPoolGet', () async {
      // TODO
    });

    // List Cron Blueprints
    //
    // Blueprint catalog as form schemas; the ``deliver`` slot's options are rewritten from the actually configured gateway platforms.
    //
    //Future<Object> listCronBlueprintsApiCronBlueprintsGet() async
    test('test listCronBlueprintsApiCronBlueprintsGet', () async {
      // TODO
    });

    // List Cron Job Runs
    //
    //Future<Object> listCronJobRunsApiCronJobsJobIdRunsGet(String jobId, { String profile, int limit }) async
    test('test listCronJobRunsApiCronJobsJobIdRunsGet', () async {
      // TODO
    });

    // List Cron Jobs
    //
    //Future<Object> listCronJobsApiCronJobsGet({ String profile }) async
    test('test listCronJobsApiCronJobsGet', () async {
      // TODO
    });

    // List Custom Endpoints
    //
    // Return configured OpenAI-compatible custom endpoints for Desktop.  Scoped to the requested profile's config.yaml: the desktop settings UI targets the active profile, so read/write must resolve that profile's home rather than the process-level HERMES_HOME (mirrors ``/api/config``).
    //
    //Future<Object> listCustomEndpointsApiProvidersCustomEndpointsGet({ String profile }) async
    test('test listCustomEndpointsApiProvidersCustomEndpointsGet', () async {
      // TODO
    });

    // List Diagnostics
    //
    // Tasks with an active diagnostic, highest severity first then most recent; also consumed by ``hermes kanban diagnostics`` when the dashboard runs.
    //
    //Future<Object> listDiagnosticsApiPluginsKanbanDiagnosticsGet({ String board, String severity }) async
    test('test listDiagnosticsApiPluginsKanbanDiagnosticsGet', () async {
      // TODO
    });

    // List Hooks
    //
    // Configured shell hooks with consent (allowlist) status, whether the script is currently executable, and the valid hook events for the form.
    //
    //Future<Object> listHooksApiOpsHooksGet() async
    test('test listHooksApiOpsHooksGet', () async {
      // TODO
    });

    // List Kanban Projects
    //
    // Live (non-archived) projects available for board scoping.
    //
    //Future<Object> listKanbanProjectsApiPluginsKanbanProjectsGet() async
    test('test listKanbanProjectsApiPluginsKanbanProjectsGet', () async {
      // TODO
    });

    // List Managed Files
    //
    //Future<Object> listManagedFilesApiFilesGet({ String path }) async
    test('test listManagedFilesApiFilesGet', () async {
      // TODO
    });

    // List Mcp Catalog
    //
    // Browse the Nous-approved MCP catalog (optional-mcps/ manifests), each entry annotated with installed/enabled state for ``profile``. Opt-in app signals describe this backend machine, never the client or terminal sandbox.
    //
    //Future<Object> listMcpCatalogApiMcpCatalogGet({ String profile, bool detectApps }) async
    test('test listMcpCatalogApiMcpCatalogGet', () async {
      // TODO
    });

    // List Mcp Servers
    //
    //Future<Object> listMcpServersApiMcpServersGet({ String profile }) async
    test('test listMcpServersApiMcpServersGet', () async {
      // TODO
    });

    // List Oauth Providers
    //
    // Every OAuth-capable provider with current status (token_preview is the last N chars, never the full token; disconnect_command only for external providers).
    //
    //Future<Object> listOauthProvidersApiProvidersOauthGet({ String profile }) async
    test('test listOauthProvidersApiProvidersOauthGet', () async {
      // TODO
    });

    // List Official Skills
    //
    // The ENTIRE optional-skills catalog (local scan), marked installed for ``profile``.
    //
    //Future<Object> listOfficialSkillsApiSkillsHubOfficialGet({ String profile }) async
    test('test listOfficialSkillsApiSkillsHubOfficialGet', () async {
      // TODO
    });

    // List Pairing
    //
    //Future<Object> listPairingApiPairingGet({ String profile }) async
    test('test listPairingApiPairingGet', () async {
      // TODO
    });

    // List Profile Roster
    //
    // Every installed profile with its description (profiles without one are still routable on name alone, just less precisely).
    //
    //Future<Object> listProfileRosterApiPluginsKanbanProfilesGet() async
    test('test listProfileRosterApiPluginsKanbanProfilesGet', () async {
      // TODO
    });

    // List Profiles Endpoint
    //
    //Future<Object> listProfilesEndpointApiProfilesGet() async
    test('test listProfilesEndpointApiProfilesGet', () async {
      // TODO
    });

    // List Skills Hub Sources
    //
    // Configured skill-hub sources + installed-skill provenance (scoped to ``profile``), so the Browse-hub tab has something before a search runs.
    //
    //Future<Object> listSkillsHubSourcesApiSkillsHubSourcesGet({ String profile }) async
    test('test listSkillsHubSourcesApiSkillsHubSourcesGet', () async {
      // TODO
    });

    // List Task Attachments
    //
    //Future<Object> listTaskAttachmentsApiPluginsKanbanTasksTaskIdAttachmentsGet(String taskId, { String board }) async
    test(
      'test listTaskAttachmentsApiPluginsKanbanTasksTaskIdAttachmentsGet',
      () async {
        // TODO
      },
    );

    // List Webhooks
    //
    //Future<Object> listWebhooksApiWebhooksGet() async
    test('test listWebhooksApiWebhooksGet', () async {
      // TODO
    });

    // Local Models Activate
    //
    // Make a downloaded model the default for new chats: a config write via the same machinery as /api/model/set plus making sure the server is up. NO model loading (residency v2: models load on first inference; an empty router costs nothing). Kept as a job for UI continuity.
    //
    //Future<Object> localModelsActivateApiLocalModelsActivatePost(ModelActivateBody modelActivateBody) async
    test('test localModelsActivateApiLocalModelsActivatePost', () async {
      // TODO
    });

    // Local Models Catalog
    //
    // Every entry answers up front: how big is the download, will it fit, what context/speed shape will I get. The row advertises the BEST build for this machine (highest quality fully on GPU at the 64K floor; else the smallest that works, spilled and priced). No entry is hidden; unaffordable models show WHY. Sync def: blocking I/O -> threadpool.
    //
    //Future<Object> localModelsCatalogApiLocalModelsCatalogGet() async
    test('test localModelsCatalogApiLocalModelsCatalogGet', () async {
      // TODO
    });

    // Local Models Delete
    //
    // Remove every split part plus private assets, then bounce the router off the request thread (deleting the active file mid-serve is exactly the stale state the refresh exists for).
    //
    //Future<Object> localModelsDeleteApiLocalModelsModelsModelIdDelete(String modelId) async
    test('test localModelsDeleteApiLocalModelsModelsModelIdDelete', () async {
      // TODO
    });

    // Local Models Download
    //
    // Accepts either a family id (downloads this machine's selected variant) or an exact variant model_id.
    //
    //Future<Object> localModelsDownloadApiLocalModelsDownloadPost(ModelDownloadBody modelDownloadBody) async
    test('test localModelsDownloadApiLocalModelsDownloadPost', () async {
      // TODO
    });

    // Local Models Download Browsed
    //
    // Download an arbitrary HF GGUF into the managed models dir. Once landed it is a normal staged model (the post-download bounce regenerates presets from its real header); with no catalog entry it serves 'unverified', capabilities answered from the live server only.
    //
    //Future<Object> localModelsDownloadBrowsedApiLocalModelsDownloadBrowsedPost(BrowsedDownloadBody browsedDownloadBody) async
    test(
      'test localModelsDownloadBrowsedApiLocalModelsDownloadBrowsedPost',
      () async {
        // TODO
      },
    );

    // Local Models Eject
    //
    // Free a loaded model's GPU memory now; only demand (the next message) reloads it — residency v2 has no automatic loading anywhere. Sync def: the fallback path blocks on a 120s urlopen — threadpool, never the loop.
    //
    //Future<Object> localModelsEjectApiLocalModelsEjectPost(ModelEjectBody modelEjectBody) async
    test('test localModelsEjectApiLocalModelsEjectPost', () async {
      // TODO
    });

    // Local Models Hardware
    //
    // The budget as plain facts, polled by the pane and statusbar. Sync def: shells out to nvidia-smi — threadpool.
    //
    //Future<Object> localModelsHardwareApiLocalModelsHardwareGet() async
    test('test localModelsHardwareApiLocalModelsHardwareGet', () async {
      // TODO
    });

    // Local Models Job
    //
    //Future<Object> localModelsJobApiLocalModelsJobsJobIdGet(String jobId) async
    test('test localModelsJobApiLocalModelsJobsJobIdGet', () async {
      // TODO
    });

    // Local Models Jobs
    //
    // All recent jobs, running first — the pane and app-level poller rediscover in-flight work here after a remount.
    //
    //Future<Object> localModelsJobsApiLocalModelsJobsGet() async
    test('test localModelsJobsApiLocalModelsJobsGet', () async {
      // TODO
    });

    // Local Models Quickstart
    //
    // One job: install the runtime (if missing), download this machine's build of the recommended model (if missing), make it the default. Each leg uses the same code as the individual setup routes. Preflight rejects (no automatic recommendation or no servable choice) fail the POST synchronously so the button can explain itself; everything slow runs in the job with phase/byte progress.
    //
    //Future<Object> localModelsQuickstartApiLocalModelsQuickstartPost(QuickstartBody quickstartBody) async
    test('test localModelsQuickstartApiLocalModelsQuickstartPost', () async {
      // TODO
    });

    // Local Models Runtime Install
    //
    //Future<Object> localModelsRuntimeInstallApiLocalModelsRuntimeInstallPost(RuntimeInstallBody runtimeInstallBody) async
    test(
      'test localModelsRuntimeInstallApiLocalModelsRuntimeInstallPost',
      () async {
        // TODO
      },
    );

    // Local Models Search
    //
    // Full-text HF search over GGUF models — the firehose behind the curated catalog; fit pills come from /search/files.
    //
    //Future<Object> localModelsSearchApiLocalModelsSearchGet(String q, { int limit }) async
    test('test localModelsSearchApiLocalModelsSearchGet', () async {
      // TODO
    });

    // Local Models Search Files
    //
    // Servable GGUFs in one HF repo with a rough pre-download fit verdict per quant (file size + conservative fill-ins; the GGUF header refines it).
    //
    //Future<Object> localModelsSearchFilesApiLocalModelsSearchFilesGet(String repo) async
    test('test localModelsSearchFilesApiLocalModelsSearchFilesGet', () async {
      // TODO
    });

    // Local Models Server
    //
    // Turn the local engine off (stop the server, free ALL GPU memory, disable auto-start) or back on. Unlike per-model eject the off switch IS durable: the user said off, so boots stay off until they say on.
    //
    //Future<Object> localModelsServerApiLocalModelsServerPost(ServerActionBody serverActionBody) async
    test('test localModelsServerApiLocalModelsServerPost', () async {
      // TODO
    });

    // Local Models Sideload
    //
    // Register a GGUF already on this machine: link it into the managed models dir (copy only when linking is impossible) and bounce the router. The original stays put; delete-from-Hermes removes only our link.
    //
    //Future<Object> localModelsSideloadApiLocalModelsSideloadPost(SideloadBody sideloadBody) async
    test('test localModelsSideloadApiLocalModelsSideloadPost', () async {
      // TODO
    });

    // Local Models Status
    //
    // Cheap, immediate: config state + installed runtime + staged models + supervisor state (GPU facts live in /hardware). Sync def on purpose: blocking urlopen/scans run in the threadpool.
    //
    //Future<Object> localModelsStatusApiLocalModelsStatusGet() async
    test('test localModelsStatusApiLocalModelsStatusGet', () async {
      // TODO
    });

    // Login Page
    //
    //Future<Object> loginPageLoginGet() async
    test('test loginPageLoginGet', () async {
      // TODO
    });

    // Mcp Oauth Callback
    //
    //Future<Object> mcpOauthCallbackApiMcpOauthCallbackServerNameGet(String serverName, { String code, String state, String error, String iss }) async
    test('test mcpOauthCallbackApiMcpOauthCallbackServerNameGet', () async {
      // TODO
    });

    // Mcp Oauth Flow Status
    //
    //Future<Object> mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet(String flowId) async
    test('test mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet', () async {
      // TODO
    });

    // Memory Oauth Status
    //
    // Poll a provider's OAuth flow: idle | pending | connected | error.
    //
    //Future<Object> memoryOauthStatusApiMemoryProvidersProviderOauthStatusGet(String provider, { String profile }) async
    test(
      'test memoryOauthStatusApiMemoryProvidersProviderOauthStatusGet',
      () async {
        // TODO
      },
    );

    // Model Options
    //
    // Providers + curated models for the override dropdown via ``inventory.build_models_payload`` (same substrate as the Models page) so it can't offer a pair Hermes rejects. Skips pricing and custom-provider probes: a slow/offline local endpoint must not hang the drawer.
    //
    //Future<Object> modelOptionsApiPluginsKanbanModelOptionsGet() async
    test('test modelOptionsApiPluginsKanbanModelOptionsGet', () async {
      // TODO
    });

    // Open Profile Terminal Endpoint
    //
    //Future<Object> openProfileTerminalEndpointApiProfilesNameOpenTerminalPost(String name) async
    test(
      'test openProfileTerminalEndpointApiProfilesNameOpenTerminalPost',
      () async {
        // TODO
      },
    );

    // Pause Cron Job
    //
    //Future<Object> pauseCronJobApiCronJobsJobIdPausePost(String jobId, { String profile }) async
    test('test pauseCronJobApiCronJobsJobIdPausePost', () async {
      // TODO
    });

    // Poll Oauth Session
    //
    // Poll a session's status (no auth — read-only state). One endpoint serves every device-code flow: all report progress via the worker-updated ``status``.
    //
    //Future<Object> pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet(String providerId, String sessionId, { String profile }) async
    test(
      'test pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet',
      () async {
        // TODO
      },
    );

    // Post Agent Plugin Disable
    //
    //Future<Object> postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost(String name) async
    test(
      'test postAgentPluginDisableApiDashboardAgentPluginsNameDisablePost',
      () async {
        // TODO
      },
    );

    // Post Agent Plugin Enable
    //
    //Future<Object> postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost(String name) async
    test(
      'test postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost',
      () async {
        // TODO
      },
    );

    // Post Agent Plugin Install
    //
    //Future<Object> postAgentPluginInstallApiDashboardAgentPluginsInstallPost(AgentPluginInstallBody agentPluginInstallBody) async
    test(
      'test postAgentPluginInstallApiDashboardAgentPluginsInstallPost',
      () async {
        // TODO
      },
    );

    // Post Agent Plugin Update
    //
    //Future<Object> postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost(String name) async
    test(
      'test postAgentPluginUpdateApiDashboardAgentPluginsNameUpdatePost',
      () async {
        // TODO
      },
    );

    // Post Health Retirement
    //
    //Future<Object> postHealthRetirementApiHealthRetirementPost() async
    test('test postHealthRetirementApiHealthRetirementPost', () async {
      // TODO
    });

    // Post Plugin Visibility
    //
    // Toggle a plugin's sidebar visibility (persists to config.yaml dashboard.hidden_plugins).
    //
    //Future<Object> postPluginVisibilityApiDashboardPluginsNameVisibilityPost(String name, PluginVisibilityBody pluginVisibilityBody) async
    test(
      'test postPluginVisibilityApiDashboardPluginsNameVisibilityPost',
      () async {
        // TODO
      },
    );

    // Post Profiles Sessions Pull Requests
    //
    // The PR each of these sessions opened, recovered from its own transcript: a session that starts in the main checkout and works in a worktree has no branch of its own, so its PR is invisible to the branch join — but ``gh pr create`` ran in the conversation (see ``_pr_url_from_tool_output``). Read-only across every profile.
    //
    //Future<Object> postProfilesSessionsPullRequestsApiProfilesSessionsPullRequestsPost(SessionPrScanBody sessionPrScanBody) async
    test('test postProfilesSessionsPullRequestsApiProfilesSessionsPullRequestsPost', () async {
      // TODO
    });

    // Preview Skill Hub
    //
    // A hub skill's SKILL.md + file manifest WITHOUT installing it; scoped to ``profile`` so different hub taps resolve against THAT source router.
    //
    //Future<Object> previewSkillHubApiSkillsHubPreviewGet({ String identifier, String profile }) async
    test('test previewSkillHubApiSkillsHubPreviewGet', () async {
      // TODO
    });

    // Prune Checkpoints
    //
    //Future<Object> pruneCheckpointsApiOpsCheckpointsPrunePost() async
    test('test pruneCheckpointsApiOpsCheckpointsPrunePost', () async {
      // TODO
    });

    // Prune Sessions Endpoint
    //
    // Delete ended sessions matching filters without blocking the event loop.
    //
    //Future<Object> pruneSessionsEndpointApiSessionsPrunePost(SessionPrune sessionPrune) async
    test('test pruneSessionsEndpointApiSessionsPrunePost', () async {
      // TODO
    });

    // Put Plugin Providers
    //
    // Persist memory provider / context engine selection (writes config.yaml).
    //
    //Future<Object> putPluginProvidersApiDashboardPluginProvidersPut(PluginProvidersPutBody pluginProvidersPutBody) async
    test('test putPluginProvidersApiDashboardPluginProvidersPut', () async {
      // TODO
    });

    // Read Managed File
    //
    //Future<Object> readManagedFileApiFilesReadGet(String path) async
    test('test readManagedFileApiFilesReadGet', () async {
      // TODO
    });

    // Reassign Task Endpoint
    //
    // Reassign to another profile, optionally reclaiming first (``hermes kanban reassign <task_id> <profile> [--reclaim]``).
    //
    //Future<Object> reassignTaskEndpointApiPluginsKanbanTasksTaskIdReassignPost(String taskId, ReassignBody reassignBody, { String board }) async
    test(
      'test reassignTaskEndpointApiPluginsKanbanTasksTaskIdReassignPost',
      () async {
        // TODO
      },
    );

    // Recent Unlocks
    //
    //Future<Object> recentUnlocksApiPluginsHermesAchievementsRecentUnlocksGet() async
    test(
      'test recentUnlocksApiPluginsHermesAchievementsRecentUnlocksGet',
      () async {
        // TODO
      },
    );

    // Reclaim Task Endpoint
    //
    // Release an active worker claim without waiting for the claim TTL (``hermes kanban reclaim <task_id> --reason ...``).
    //
    //Future<Object> reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost(String taskId, ReclaimBody reclaimBody, { String board }) async
    test(
      'test reclaimTaskEndpointApiPluginsKanbanTasksTaskIdReclaimPost',
      () async {
        // TODO
      },
    );

    // Remove Attachment
    //
    //Future<Object> removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete(int attachmentId, { String board }) async
    test(
      'test removeAttachmentApiPluginsKanbanAttachmentsAttachmentIdDelete',
      () async {
        // TODO
      },
    );

    // Remove Credential Pool Entry
    //
    // Remove a pool entry (``index`` is 1-based, as listed).  Removal must be sticky: ``load_pool()`` re-seeds entries from their backing source (.env var, OAuth file, custom-provider config) on every call, so deleting only the row silently reverts on the next refresh. Dispatch through the same RemovalStep registry as ``hermes auth remove``: each source cleans its external state and suppresses ``(provider, source)`` so seeders skip it. Manual entries have no step — nothing external, and they aren't re-seeded.  See #55217.
    //
    //Future<Object> removeCredentialPoolEntryApiCredentialsPoolProviderIndexDelete(String provider, int index) async
    test(
      'test removeCredentialPoolEntryApiCredentialsPoolProviderIndexDelete',
      () async {
        // TODO
      },
    );

    // Remove Env Var
    //
    //Future<Object> removeEnvVarApiEnvDelete(EnvVarDelete envVarDelete, { String profile }) async
    test('test removeEnvVarApiEnvDelete', () async {
      // TODO
    });

    // Remove Mcp Server
    //
    //Future<Object> removeMcpServerApiMcpServersNameDelete(String name, { String profile }) async
    test('test removeMcpServerApiMcpServersNameDelete', () async {
      // TODO
    });

    // Rename Board
    //
    // Update display metadata / default workdir / project scope (slug is immutable).
    //
    //Future<Object> renameBoardApiPluginsKanbanBoardsSlugPatch(String slug, RenameBoardBody renameBoardBody) async
    test('test renameBoardApiPluginsKanbanBoardsSlugPatch', () async {
      // TODO
    });

    // Rename Profile Endpoint
    //
    //Future<Object> renameProfileEndpointApiProfilesNamePatch(String name, ProfileRename profileRename) async
    test('test renameProfileEndpointApiProfilesNamePatch', () async {
      // TODO
    });

    // Rename Session Endpoint
    //
    // Update ``title`` (empty clears) and/or the flags; ``pinned`` exempts from the auto-archive sweep, ``unread=False`` marks read up to now.
    //
    //Future<Object> renameSessionEndpointApiSessionsSessionIdPatch(String sessionId, SessionRename sessionRename) async
    test('test renameSessionEndpointApiSessionsSessionIdPatch', () async {
      // TODO
    });

    // Replace Mcp Servers
    //
    // Replace the entire ``mcp_servers`` map (the mcp.json editor's save) — the deep-merging ``/api/config`` can never delete a key or drop an ``enabled: false``, so removals wouldn't persist through it.
    //
    //Future<Object> replaceMcpServersApiMcpServersPut(MCPServersReplace mCPServersReplace, { String profile }) async
    test('test replaceMcpServersApiMcpServersPut', () async {
      // TODO
    });

    // Rescan
    //
    //Future<Object> rescanApiPluginsHermesAchievementsRescanPost() async
    test('test rescanApiPluginsHermesAchievementsRescanPost', () async {
      // TODO
    });

    // Rescan Dashboard Plugins
    //
    // Force re-scan of dashboard plugins.
    //
    //Future<Object> rescanDashboardPluginsApiDashboardPluginsRescanGet() async
    test('test rescanDashboardPluginsApiDashboardPluginsRescanGet', () async {
      // TODO
    });

    // Reset Memory
    //
    //Future<Object> resetMemoryApiMemoryResetPost(MemoryReset memoryReset) async
    test('test resetMemoryApiMemoryResetPost', () async {
      // TODO
    });

    // Reset State
    //
    //Future<Object> resetStateApiPluginsHermesAchievementsResetStatePost() async
    test('test resetStateApiPluginsHermesAchievementsResetStatePost', () async {
      // TODO
    });

    // Restart Gateway
    //
    // Kick off a ``hermes gateway restart`` in the background.
    //
    //Future<Object> restartGatewayApiGatewayRestartPost({ String profile }) async
    test('test restartGatewayApiGatewayRestartPost', () async {
      // TODO
    });

    // Resume Cron Job
    //
    //Future<Object> resumeCronJobApiCronJobsJobIdResumePost(String jobId, { String profile }) async
    test('test resumeCronJobApiCronJobsJobIdResumePost', () async {
      // TODO
    });

    // Reveal Env Var
    //
    // Return the real (unredacted) value of a single env var.  Protected by the ephemeral session token (per server start, injected into the SPA), rate limiting (max 5 reveals per 30s window) and audit logging.
    //
    //Future<Object> revealEnvVarApiEnvRevealPost(EnvVarReveal envVarReveal, { String profile }) async
    test('test revealEnvVarApiEnvRevealPost', () async {
      // TODO
    });

    // Revoke Pairing
    //
    //Future<Object> revokePairingApiPairingRevokePost(PairingRevoke pairingRevoke) async
    test('test revokePairingApiPairingRevokePost', () async {
      // TODO
    });

    // Run Backup
    //
    //Future<Object> runBackupApiOpsBackupPost(BackupRequest backupRequest) async
    test('test runBackupApiOpsBackupPost', () async {
      // TODO
    });

    // Run Config Migrate
    //
    //Future<Object> runConfigMigrateApiOpsConfigMigratePost() async
    test('test runConfigMigrateApiOpsConfigMigratePost', () async {
      // TODO
    });

    // Run Curator
    //
    // Trigger a curator review now (backgrounded; tail via action status).
    //
    //Future<Object> runCuratorApiCuratorRunPost() async
    test('test runCuratorApiCuratorRunPost', () async {
      // TODO
    });

    // Run Debug Share Endpoint
    //
    // Upload a redacted debug report + full logs and return the paste URLs. Synchronous, unlike the other diagnostics actions: the point is the shareable URLs, returned as a structured payload the dashboard renders as copyable links.
    //
    //Future<Object> runDebugShareEndpointApiOpsDebugSharePost({ DebugShareRequest debugShareRequest }) async
    test('test runDebugShareEndpointApiOpsDebugSharePost', () async {
      // TODO
    });

    // Run Doctor
    //
    //Future<Object> runDoctorApiOpsDoctorPost() async
    test('test runDoctorApiOpsDoctorPost', () async {
      // TODO
    });

    // Run Dump
    //
    //Future<Object> runDumpApiOpsDumpPost() async
    test('test runDumpApiOpsDumpPost', () async {
      // TODO
    });

    // Run Import
    //
    //Future<Object> runImportApiOpsImportPost(ImportRequest importRequest) async
    test('test runImportApiOpsImportPost', () async {
      // TODO
    });

    // Run Import Upload
    //
    //Future<Object> runImportUploadApiOpsImportUploadPost(MultipartFile file, { bool force }) async
    test('test runImportUploadApiOpsImportUploadPost', () async {
      // TODO
    });

    // Run Prompt Size
    //
    //Future<Object> runPromptSizeApiOpsPromptSizePost() async
    test('test runPromptSizeApiOpsPromptSizePost', () async {
      // TODO
    });

    // Run Security Audit
    //
    //Future<Object> runSecurityAuditApiOpsSecurityAuditPost() async
    test('test runSecurityAuditApiOpsSecurityAuditPost', () async {
      // TODO
    });

    // Run Toolset Post Setup
    //
    // Spawn ``hermes tools post-setup <key>`` (long-running installs) as a background action tailed via ``GET /api/actions/tools-post-setup/status``; ``profile`` is threaded so hooks see the drawer's HERMES_HOME.
    //
    //Future<Object> runToolsetPostSetupApiToolsToolsetsNamePostSetupPost(String name, ToolsetPostSetup toolsetPostSetup, { String profile }) async
    test('test runToolsetPostSetupApiToolsToolsetsNamePostSetupPost', () async {
      // TODO
    });

    // Save Toolset Env
    //
    // Persist API keys to ``.env`` via ``save_env_value``.  Keys are validated against the union of the category's visible-provider ``env_vars`` so this can't write arbitrary env vars; a blank value means \"leave unchanged\".
    //
    //Future<Object> saveToolsetEnvApiToolsToolsetsNameEnvPut(String name, ToolsetEnvUpdate toolsetEnvUpdate, { String profile }) async
    test('test saveToolsetEnvApiToolsToolsetsNameEnvPut', () async {
      // TODO
    });

    // Scan Skill Hub
    //
    // Install-time security scan of a hub skill WITHOUT installing it (the CLI's ``scan_skill`` / ``should_allow_install`` pipeline on a quarantined bundle); scoped to ``profile`` so the bundle resolves where an install would.
    //
    //Future<Object> scanSkillHubApiSkillsHubScanGet({ String identifier, String profile }) async
    test('test scanSkillHubApiSkillsHubScanGet', () async {
      // TODO
    });

    // Scan Status
    //
    //Future<Object> scanStatusApiPluginsHermesAchievementsScanStatusGet() async
    test('test scanStatusApiPluginsHermesAchievementsScanStatusGet', () async {
      // TODO
    });

    // Search Sessions
    //
    // Search sessions by ID (first) plus FTS5 message content.  Results are deduped by compression lineage, not raw ``session_id``: auto-compression rotates a chat onto a fresh id and leaves the old segment in the FTS index.  Branches also use ``parent_session_id`` but are real alternate conversations — they are NOT collapsed into the parent.
    //
    //Future<Object> searchSessionsApiSessionsSearchGet({ String q, int limit, String profile, String source_, String sources, String excludeSources }) async
    test('test searchSessionsApiSessionsSearchGet', () async {
      // TODO
    });

    // Search Skills Hub
    //
    // Search the skill hub across all configured sources (network-bound).
    //
    //Future<Object> searchSkillsHubApiSkillsHubSearchGet({ String q, String source_, int limit, String profile }) async
    test('test searchSkillsHubApiSkillsHubSearchGet', () async {
      // TODO
    });

    // Select Terminal Backend
    //
    // Persist ``terminal.backend``.  A backend that still needs setup is allowed — the picker shows guidance instead of blocking, like the CLI.
    //
    //Future<Object> selectTerminalBackendApiToolsTerminalBackendPut(TerminalBackendSelect terminalBackendSelect, { String profile }) async
    test('test selectTerminalBackendApiToolsTerminalBackendPut', () async {
      // TODO
    });

    // Select Toolset Model
    //
    // Persist a backend model selection (``image_gen.model`` / ``video_gen.model``), validated against the resolved backend's catalog.
    //
    //Future<Object> selectToolsetModelApiToolsToolsetsNameModelPut(String name, ToolsetModelSelect toolsetModelSelect, { String profile }) async
    test('test selectToolsetModelApiToolsToolsetsNameModelPut', () async {
      // TODO
    });

    // Select Toolset Provider
    //
    // Persist a provider selection via ``apply_provider_selection`` (shared with ``hermes tools``, so both write identical keys).  ``web`` only: ``capability`` ('search' | 'extract') writes ``web.<capability>_backend`` (the override the dispatchers resolve first); omitted -> legacy ``web.backend``.  Managed Nous rows report Portal entitlement (``needs_nous_auth`` + ``feature``): the GUI has no inline login, so an unentitled selection would write config and never activate.
    //
    //Future<Object> selectToolsetProviderApiToolsToolsetsNameProviderPut(String name, ToolsetProviderSelect toolsetProviderSelect, { String profile }) async
    test('test selectToolsetProviderApiToolsToolsetsNameProviderPut', () async {
      // TODO
    });

    // Serve Css
    //
    //Future<Object> serveCssAssetsFilenameCssGet(String filename) async
    test('test serveCssAssetsFilenameCssGet', () async {
      // TODO
    });

    // Serve Plugin Asset
    //
    // Serve static assets from a dashboard plugin's ``dashboard/`` directory.  Unauthenticated on purpose: the SPA loads plugin JS via ``<script src>`` and CSS via ``<link href>``, which cannot attach an auth header. Hence the suffix allowlist — user plugins ship a ``plugin_api.py`` backend the browser never fetches, and without it anyone on the loopback port could curl a private plugin's source. Path traversal is blocked via ``resolve().is_relative_to()``; user plugins must be enabled (bundled ones not disabled) (GHSA-mcfc-hp25-cjv7).  See #46435.
    //
    //Future<Object> servePluginAssetDashboardPluginsPluginNameFilePathGet(String pluginName, String filePath) async
    test(
      'test servePluginAssetDashboardPluginsPluginNameFilePathGet',
      () async {
        // TODO
      },
    );

    // Serve Spa
    //
    //Future<Object> serveSpaFullPathGet(String fullPath) async
    test('test serveSpaFullPathGet', () async {
      // TODO
    });

    // Session Badges
    //
    //Future<Object> sessionBadgesApiPluginsHermesAchievementsSessionsSessionIdBadgesGet(String sessionId) async
    test('test sessionBadgesApiPluginsHermesAchievementsSessionsSessionIdBadgesGet', () async {
      // TODO
    });

    // Set Active Profile Endpoint
    //
    // Set the sticky active profile (mirrors ``hermes profile use``); does not retarget the running dashboard, only subsequent CLI commands and gateways.
    //
    //Future<Object> setActiveProfileEndpointApiProfilesActivePost(ProfileActiveUpdate profileActiveUpdate) async
    test('test setActiveProfileEndpointApiProfilesActivePost', () async {
      // TODO
    });

    // Set Curator Paused
    //
    //Future<Object> setCuratorPausedApiCuratorPausedPut(CuratorPause curatorPause) async
    test('test setCuratorPausedApiCuratorPausedPut', () async {
      // TODO
    });

    // Set Dashboard Font
    //
    // Set the font override (config.yaml). Unknown ids coerce to ``\"theme\"`` rather than 400 so a stale client can't wedge the picker.
    //
    //Future<Object> setDashboardFontApiDashboardFontPut(FontSetBody fontSetBody) async
    test('test setDashboardFontApiDashboardFontPut', () async {
      // TODO
    });

    // Set Dashboard Theme
    //
    // Set the active dashboard theme (persists to config.yaml).
    //
    //Future<Object> setDashboardThemeApiDashboardThemePut(ThemeSetBody themeSetBody) async
    test('test setDashboardThemeApiDashboardThemePut', () async {
      // TODO
    });

    // Set Env Var
    //
    //Future<Object> setEnvVarApiEnvPut(EnvVarUpdate envVarUpdate, { String profile }) async
    test('test setEnvVarApiEnvPut', () async {
      // TODO
    });

    // Set Mcp Server Enabled
    //
    // Toggle ``enabled`` (takes effect on next session/gateway); disabled servers stay in config so they can be re-enabled without re-entry.
    //
    //Future<Object> setMcpServerEnabledApiMcpServersNameEnabledPut(String name, MCPEnabledToggle mCPEnabledToggle, { String profile }) async
    test('test setMcpServerEnabledApiMcpServersNameEnabledPut', () async {
      // TODO
    });

    // Set Memory Provider
    //
    //Future<Object> setMemoryProviderApiMemoryProviderPut(MemoryProviderSelect memoryProviderSelect) async
    test('test setMemoryProviderApiMemoryProviderPut', () async {
      // TODO
    });

    // Set Moa Models
    //
    // Persist the Mixture-of-Agents provider/model slots.
    //
    //Future<Object> setMoaModelsApiModelMoaPut(MoaConfigPayload moaConfigPayload, { String profile }) async
    test('test setMoaModelsApiModelMoaPut', () async {
      // TODO
    });

    // Set Model Assignment
    //
    // Assign a model to the main slot or an auxiliary task slot. Writes ``~/.hermes/config.yaml`` — applies to **new** sessions only; a running chat PTY hot-swaps via the ``/model`` slash command instead.
    //
    //Future<Object> setModelAssignmentApiModelSetPost(ModelAssignment modelAssignment, { String profile }) async
    test('test setModelAssignmentApiModelSetPost', () async {
      // TODO
    });

    // Set Orchestration Settings
    //
    // Update orchestration knobs in config.yaml. Only fields explicitly passed are written; empty profile strings clear the override.
    //
    //Future<Object> setOrchestrationSettingsApiPluginsKanbanOrchestrationPut(OrchestrationSettingsBody orchestrationSettingsBody) async
    test(
      'test setOrchestrationSettingsApiPluginsKanbanOrchestrationPut',
      () async {
        // TODO
      },
    );

    // Set Webhook Enabled
    //
    // Disabled routes stay on disk (re-enable later) but the gateway rejects their events with 403; it hot-reloads the file, so no restart is needed.
    //
    //Future<Object> setWebhookEnabledApiWebhooksNameEnabledPut(String name, WebhookEnabledToggle webhookEnabledToggle) async
    test('test setWebhookEnabledApiWebhooksNameEnabledPut', () async {
      // TODO
    });

    // Setup Memory Provider
    //
    //Future<Object> setupMemoryProviderApiMemoryProvidersNameSetupPost(String name, MemoryProviderSetupRequest memoryProviderSetupRequest) async
    test('test setupMemoryProviderApiMemoryProvidersNameSetupPost', () async {
      // TODO
    });

    // Speak Text
    //
    // Synthesize speech and return audio as base64 data URL.  Used by the desktop voice-conversation mode to play back assistant responses without exposing the on-disk file path; reuses the TTS provider chain configured under ``tts.`` in config.yaml.
    //
    //Future<Object> speakTextApiAudioSpeakPost(TTSSpeakRequest tTSSpeakRequest, { String profile }) async
    test('test speakTextApiAudioSpeakPost', () async {
      // TODO
    });

    // Specify Task Endpoint
    //
    // Flesh out a triage task via the auxiliary LLM (``hermes kanban specify``). Non-OK is NOT an HTTP error — the UI renders the reason inline. Sync ``def`` → runs in the threadpool.
    //
    //Future<Object> specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost(String taskId, SpecifyBody specifyBody, { String board }) async
    test(
      'test specifyTaskEndpointApiPluginsKanbanTasksTaskIdSpecifyPost',
      () async {
        // TODO
      },
    );

    // Start Gateway
    //
    //Future<Object> startGatewayApiGatewayStartPost({ String profile }) async
    test('test startGatewayApiGatewayStartPost', () async {
      // TODO
    });

    // Start Memory Oauth
    //
    // Begin a provider's zero-CLI OAuth flow (browser + loopback listener); returns immediately, poll status.
    //
    //Future<Object> startMemoryOauthApiMemoryProvidersProviderOauthStartPost(String provider, { String profile }) async
    test(
      'test startMemoryOauthApiMemoryProvidersProviderOauthStartPost',
      () async {
        // TODO
      },
    );

    // Start Oauth Login
    //
    // Initiate an OAuth login flow. Token-protected.
    //
    //Future<Object> startOauthLoginApiProvidersOauthProviderIdStartPost(String providerId, { String profile }) async
    test('test startOauthLoginApiProvidersOauthProviderIdStartPost', () async {
      // TODO
    });

    // Start Telegram Onboarding
    //
    //Future<Object> startTelegramOnboardingApiMessagingTelegramOnboardingStartPost(TelegramOnboardingStart telegramOnboardingStart) async
    test(
      'test startTelegramOnboardingApiMessagingTelegramOnboardingStartPost',
      () async {
        // TODO
      },
    );

    // Start Whatsapp Onboarding
    //
    //Future<Object> startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost(WhatsAppOnboardingStart whatsAppOnboardingStart) async
    test(
      'test startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost',
      () async {
        // TODO
      },
    );

    // Stop Gateway
    //
    //Future<Object> stopGatewayApiGatewayStopPost({ String profile }) async
    test('test stopGatewayApiGatewayStopPost', () async {
      // TODO
    });

    // Stream Managed File
    //
    // Stream managed audio/video inline with HTTP Range support — Electron's media pipeline may reject an attachment response as an ``<audio>``/ ``<video>`` source. Same auth, size cap, sensitive guard and MIME detection as download.
    //
    //Future<Object> streamManagedFileApiFilesStreamGet(String path) async
    test('test streamManagedFileApiFilesStreamGet', () async {
      // TODO
    });

    // Stream Managed File
    //
    // Stream managed audio/video inline with HTTP Range support — Electron's media pipeline may reject an attachment response as an ``<audio>``/ ``<video>`` source. Same auth, size cap, sensitive guard and MIME detection as download.
    //
    //Future<Object> streamManagedFileApiFilesStreamHead(String path) async
    test('test streamManagedFileApiFilesStreamHead', () async {
      // TODO
    });

    // Submit Oauth Code
    //
    // Submit the auth code for PKCE flows. Token-protected.
    //
    //Future<Object> submitOauthCodeApiProvidersOauthProviderIdSubmitPost(String providerId, OAuthSubmitBody oAuthSubmitBody, { String profile }) async
    test('test submitOauthCodeApiProvidersOauthProviderIdSubmitPost', () async {
      // TODO
    });

    // Subscribe Home
    //
    // Subscribe *task_id* to *platform*'s home channel. Idempotent at the DB layer; 404 when the platform has no home or the task doesn't exist.
    //
    //Future<Object> subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost(String taskId, String platform, { String board }) async
    test(
      'test subscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformPost',
      () async {
        // TODO
      },
    );

    // Switch Board
    //
    // Persist ``slug`` as the active board for CLI / slash-command parity (dashboard users pick boards client-side via localStorage).
    //
    //Future<Object> switchBoardApiPluginsKanbanBoardsSlugSwitchPost(String slug) async
    test('test switchBoardApiPluginsKanbanBoardsSlugSwitchPost', () async {
      // TODO
    });

    // Terminate Run Endpoint
    //
    // Terminate an in-flight run via ``reclaim_task`` (same SIGTERM->SIGKILL flow, bookkeeping and events as ``POST /tasks/{id}/reclaim``); 409 if already ended / not reclaimable.  Closes the gap left by PR #28432, which shipped the read-only sibling endpoints (``/workers/active``, ``/runs/{run_id}``, ``/runs/{run_id}/inspect``) but no termination control surface.
    //
    //Future<Object> terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost(int runId, TerminateRunBody terminateRunBody, { String board }) async
    test(
      'test terminateRunEndpointApiPluginsKanbanRunsRunIdTerminatePost',
      () async {
        // TODO
      },
    );

    // Test Mcp Server
    //
    // Connect to the server, list its tools, disconnect.
    //
    //Future<Object> testMcpServerApiMcpServersNameTestPost(String name, { String profile }) async
    test('test testMcpServerApiMcpServersNameTestPost', () async {
      // TODO
    });

    // Test Messaging Platform
    //
    //Future<Object> testMessagingPlatformApiMessagingPlatformsPlatformIdTestPost(String platformId, { String profile }) async
    test(
      'test testMessagingPlatformApiMessagingPlatformsPlatformIdTestPost',
      () async {
        // TODO
      },
    );

    // Toggle Skill
    //
    //Future<Object> toggleSkillApiSkillsTogglePut(SkillToggle skillToggle, { String profile }) async
    test('test toggleSkillApiSkillsTogglePut', () async {
      // TODO
    });

    // Toggle Toolset
    //
    // Enable/disable a configurable toolset for its configuration platform (``platform_toolsets.cli`` for most; platform-restricted toolsets target their own platform) via the same ``_save_platform_tools`` the CLI uses.
    //
    //Future<Object> toggleToolsetApiToolsToolsetsNamePut(String name, ToolsetToggle toolsetToggle, { String profile }) async
    test('test toggleToolsetApiToolsToolsetsNamePut', () async {
      // TODO
    });

    // Transcribe Audio Upload
    //
    //Future<Object> transcribeAudioUploadApiAudioTranscribePost(AudioTranscriptionRequest audioTranscriptionRequest, { String profile }) async
    test('test transcribeAudioUploadApiAudioTranscribePost', () async {
      // TODO
    });

    // Trigger Cron Job
    //
    //Future<Object> triggerCronJobApiCronJobsJobIdTriggerPost(String jobId, { String profile }) async
    test('test triggerCronJobApiCronJobsJobIdTriggerPost', () async {
      // TODO
    });

    // Tts Lease
    //
    // Desktop TTS-output toggles as warm-up / release signals.  ``active: true`` registers a lease on the TTS engine and pre-loads the configured provider (local model, lazily-installed SDK) so the first spoken reply doesn't pay the load as dead air; ``active: false`` drops the lease and, once no surface holds one, unloads resident local models. Blocking work runs off the event loop. Warm-up failures are reported in the body, never as an HTTP error — the toggle must succeed even when preload fails.
    //
    //Future<Object> ttsLeaseApiAudioTtsLeasePost(TTSLeaseRequest tTSLeaseRequest, { String profile }) async
    test('test ttsLeaseApiAudioTtsLeasePost', () async {
      // TODO
    });

    // Uninstall Skill Hub
    //
    //Future<Object> uninstallSkillHubApiSkillsHubUninstallPost(SkillUninstallRequest skillUninstallRequest, { String profile }) async
    test('test uninstallSkillHubApiSkillsHubUninstallPost', () async {
      // TODO
    });

    // Unsubscribe Home
    //
    // Remove any notify subscription on *task_id* matching *platform*'s home.
    //
    //Future<Object> unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete(String taskId, String platform, { String board }) async
    test('test unsubscribeHomeApiPluginsKanbanTasksTaskIdHomeSubscribePlatformDelete', () async {
      // TODO
    });

    // Update Config
    //
    //Future<Object> updateConfigApiConfigPut(ConfigUpdate configUpdate, { String profile, bool preserveLanguage }) async
    test('test updateConfigApiConfigPut', () async {
      // TODO
    });

    // Update Config Raw
    //
    //Future<Object> updateConfigRawApiConfigRawPut(RawConfigUpdate rawConfigUpdate, { String profile }) async
    test('test updateConfigRawApiConfigRawPut', () async {
      // TODO
    });

    // Update Cron Job
    //
    //Future<Object> updateCronJobApiCronJobsJobIdPut(String jobId, CronJobUpdate cronJobUpdate, { String profile }) async
    test('test updateCronJobApiCronJobsJobIdPut', () async {
      // TODO
    });

    // Update Hermes
    //
    // Kick off ``hermes update`` in the background.
    //
    //Future<Object> updateHermesApiHermesUpdatePost() async
    test('test updateHermesApiHermesUpdatePost', () async {
      // TODO
    });

    // Update Learning Node
    //
    // Rewrite a journey node's content (SKILL.md or memory chunk).
    //
    //Future<Object> updateLearningNodeApiLearningNodePut(LearningNodeEdit learningNodeEdit) async
    test('test updateLearningNodeApiLearningNodePut', () async {
      // TODO
    });

    // Update Memory Provider Config
    //
    //Future<Object> updateMemoryProviderConfigApiMemoryProvidersNameConfigPut(String name, MemoryProviderConfigUpdate memoryProviderConfigUpdate, { String surface, String profile }) async
    test(
      'test updateMemoryProviderConfigApiMemoryProvidersNameConfigPut',
      () async {
        // TODO
      },
    );

    // Update Messaging Platform
    //
    //Future<Object> updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(String platformId, MessagingPlatformUpdate messagingPlatformUpdate, { String profile }) async
    test(
      'test updateMessagingPlatformApiMessagingPlatformsPlatformIdPut',
      () async {
        // TODO
      },
    );

    // Update Profile Description
    //
    // Set (``description_auto: false`` so the auto-describer won't overwrite it without ``--overwrite``) or clear (empty string) a profile's description.
    //
    //Future<Object> updateProfileDescriptionApiPluginsKanbanProfilesProfileNamePatch(String profileName, DescribeBody describeBody) async
    test(
      'test updateProfileDescriptionApiPluginsKanbanProfilesProfileNamePatch',
      () async {
        // TODO
      },
    );

    // Update Profile Description Endpoint
    //
    // Set or clear a profile's role description (kanban routing signal), stored as user-authored (``description_auto: false``) so the auto-describer won't overwrite it.
    //
    //Future<Object> updateProfileDescriptionEndpointApiProfilesNameDescriptionPut(String name, ProfileDescriptionUpdate profileDescriptionUpdate) async
    test(
      'test updateProfileDescriptionEndpointApiProfilesNameDescriptionPut',
      () async {
        // TODO
      },
    );

    // Update Profile Model Endpoint
    //
    // Set the main model for a specific profile's config.yaml without touching the dashboard's own profile — ``POST /api/model/set`` (main scope) via the HERMES_HOME override.
    //
    //Future<Object> updateProfileModelEndpointApiProfilesNameModelPut(String name, ProfileModelUpdate profileModelUpdate) async
    test('test updateProfileModelEndpointApiProfilesNameModelPut', () async {
      // TODO
    });

    // Update Profile Soul
    //
    //Future<Object> updateProfileSoulApiProfilesNameSoulPut(String name, ProfileSoulUpdate profileSoulUpdate) async
    test('test updateProfileSoulApiProfilesNameSoulPut', () async {
      // TODO
    });

    // Update Skill Content
    //
    // Replace the SKILL.md of an existing skill (full rewrite) from the editor.
    //
    //Future<Object> updateSkillContentApiSkillsContentPut(SkillContentUpdate skillContentUpdate) async
    test('test updateSkillContentApiSkillsContentPut', () async {
      // TODO
    });

    // Update Skills Hub
    //
    //Future<Object> updateSkillsHubApiSkillsHubUpdatePost({ String profile, SkillsUpdateRequest skillsUpdateRequest }) async
    test('test updateSkillsHubApiSkillsHubUpdatePost', () async {
      // TODO
    });

    // Update Task
    //
    //Future<Object> updateTaskApiPluginsKanbanTasksTaskIdPatch(String taskId, UpdateTaskBody updateTaskBody, { String board }) async
    test('test updateTaskApiPluginsKanbanTasksTaskIdPatch', () async {
      // TODO
    });

    // Upload Chat Image
    //
    // Persist a browser clipboard image where the embedded TUI can read it.  Browser clipboard bytes aren't visible to the server-side clipboard, so the /chat page uploads them here and drives the TUI's ``/image <path>`` with the returned gateway-visible path under ``HERMES_HOME/images/`` (the same dir ``clipboard.paste`` / ``image.attach`` use).
    //
    //Future<Object> uploadChatImageApiChatImageUploadPost(ChatImageUpload chatImageUpload, { String profile }) async
    test('test uploadChatImageApiChatImageUploadPost', () async {
      // TODO
    });

    // Upload Managed File
    //
    //Future<Object> uploadManagedFileApiFilesUploadPost(ManagedFileUpload managedFileUpload) async
    test('test uploadManagedFileApiFilesUploadPost', () async {
      // TODO
    });

    // Upload Managed File Stream
    //
    // Chunked multipart upload: constant memory and no base64 inflation, unlike the JSON data-URL endpoint that trips proxy body-size limits on large archives.
    //
    //Future<Object> uploadManagedFileStreamApiFilesUploadStreamPost(MultipartFile file, String path, { bool overwrite }) async
    test('test uploadManagedFileStreamApiFilesUploadStreamPost', () async {
      // TODO
    });

    // Upload Task Attachment
    //
    // Store an upload under ``attachments_root(board)/<task_id>/`` (sanitised, collision-resolved name; ``_safe_attachment_name`` ValueError → 400) and record it.
    //
    //Future<Object> uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost(String taskId, MultipartFile file, { String board, String uploadedBy }) async
    test(
      'test uploadTaskAttachmentApiPluginsKanbanTasksTaskIdAttachmentsPost',
      () async {
        // TODO
      },
    );

    // Upsert Custom Endpoint
    //
    // Create or update a v12+ ``providers`` custom endpoint entry.
    //
    //Future<Object> upsertCustomEndpointApiProvidersCustomEndpointsPost(CustomEndpointUpdate customEndpointUpdate, { String profile }) async
    test('test upsertCustomEndpointApiProvidersCustomEndpointsPost', () async {
      // TODO
    });

    // Validate Custom Endpoint
    //
    // Probe a custom endpoint by calling its OpenAI-compatible /models URL.
    //
    //Future<Object> validateCustomEndpointApiProvidersCustomEndpointsValidatePost(CustomEndpointUpdate customEndpointUpdate) async
    test(
      'test validateCustomEndpointApiProvidersCustomEndpointsValidatePost',
      () async {
        // TODO
      },
    );

    // Validate Provider Credential
    //
    // Live-probe a provider credential before it's saved.  Returns {ok, reachable, message}. ok=True means the provider accepted the key; ok=False + reachable=True means the key is bad (caller should block); reachable=False means the network probe couldn't run (caller may save with a warning rather than hard-blocking offline users).
    //
    //Future<Object> validateProviderCredentialApiProvidersValidatePost(EnvVarUpdate envVarUpdate) async
    test('test validateProviderCredentialApiProvidersValidatePost', () async {
      // TODO
    });
  });
}
