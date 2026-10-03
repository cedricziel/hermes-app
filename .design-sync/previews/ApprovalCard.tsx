import { ApprovalCard, HermesProvider } from "@hermes-app/ui";

const box = { width: 640 } as const;

export const Pending = () => (
  <div style={box}>
    <ApprovalCard
      description="Replace the pinned certificate the backup agent trusts"
      command="backup-agent pin-cert --from /etc/ssl/certs/staging-2026-09.pem"
      choices={["once", "session", "always", "deny"]}
      onAnswer={() => {}}
    />
  </div>
);

export const SendFailed = () => (
  <div style={box}>
    <ApprovalCard
      description="Delete the build folder"
      command="rm -rf build"
      onAnswer={() => {}}
      error="Could not send your answer. Try again."
    />
  </div>
);

export const Answered = () => (
  <div style={box}>
    <ApprovalCard
      description="Delete the build folder"
      command="rm -rf build"
      status="answered"
      choice="once"
    />
  </div>
);

export const Expired = () => (
  <div style={box}>
    <ApprovalCard
      description="Delete the build folder"
      command="rm -rf build"
      status="expired"
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={box}>
      <ApprovalCard
        description="Replace the pinned certificate the backup agent trusts"
        command="backup-agent pin-cert --from /etc/ssl/certs/staging-2026-09.pem"
        choices={["once", "session", "always", "deny"]}
        onAnswer={() => {}}
      />
    </div>
  </HermesProvider>
);
