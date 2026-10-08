import { AssistantMessage, HermesProvider } from "@hermes-app/ui";

const reply = `I checked the logs. The job died at **02:14** with a connection reset.

- The TLS certificate was rotated at 02:10
- The backup agent still pinned the old one
- Retries all failed with the same error

\`\`\`
backup-agent  2026-09-19T02:14:03Z  ERROR  upload failed: x509: certificate signed by unknown authority
backup-agent  2026-09-19T02:14:33Z  ERROR  retry 3/3 failed, giving up
\`\`\`

Artifact: https://staging.example.internal/api/v2/jobs/2f9d6c1e/artifacts/nightly-backup-analytics-warehouse-2026-09-19.tar.zst`;

export const Reply = () => (
  <div style={{ width: 720 }}>
    <AssistantMessage text={reply} />
  </div>
);

/** The latest reply: Copy, Try again and Edit prompt (#463). */
export const LatestWithRetry = () => (
  <div style={{ width: 720 }}>
    <AssistantMessage
      text="Yes. Every retry reused the same stale pin, so each one failed the same way. Run `backup-agent repin --env staging` to fix it."
      onRetry={() => {}}
      onEdit={() => {}}
    />
  </div>
);

/** What Hermes' background review saved after reading the reply (#495), under its actions. */
export const ReviewSaved = () => (
  <div style={{ width: 720 }}>
    <AssistantMessage
      text="Noted: staging deploys go out after 18:00 and need a green smoke test first. I'll check both before the next one."
      onRetry={() => {}}
      onEdit={() => {}}
      reviewNotes={["Memory updated", "Skill 'staging-deploy' patched"]}
    />
  </div>
);

export const Stopped = () => (
  <div style={{ width: 720 }}>
    <AssistantMessage
      text="Re-pinning the certificate on staging first."
      stopped
      onRetry={() => {}}
    />
  </div>
);

export const Failed = () => (
  <div style={{ width: 720 }}>
    <AssistantMessage
      error="The model is overloaded. Try again."
      onRetry={() => {}}
    />
  </div>
);

export const Streaming = () => (
  <div style={{ width: 720 }}>
    <AssistantMessage
      text="The job died at **02:14** with a connection reset. The certificate"
      streaming
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 720 }}
  >
    <AssistantMessage
      text={reply}
      copied
      onRetry={() => {}}
      onEdit={() => {}}
      reviewNotes={["Memory updated"]}
    />
  </HermesProvider>
);

/** Material (top) and iOS (bottom): 14.5px vs 17px Body text, 32px vs 44px action buttons, the review note's bookmark glyph from each set. */
export const PlatformCompare = () => (
  <div
    style={{ width: 640, display: "flex", flexDirection: "column", gap: 16 }}
  >
    <AssistantMessage
      text="Every retry reused the same stale pin. Run `backup-agent repin --env staging`."
      onRetry={() => {}}
      onEdit={() => {}}
      reviewNotes={["Memory updated"]}
    />
    <HermesProvider platform="apple">
      <AssistantMessage
        text="Every retry reused the same stale pin. Run `backup-agent repin --env staging`."
        onRetry={() => {}}
        onEdit={() => {}}
        reviewNotes={["Memory updated"]}
      />
    </HermesProvider>
  </div>
);
