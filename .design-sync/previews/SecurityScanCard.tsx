import { HermesProvider, SecurityScanCard } from "@hermes-app/ui";

const pane = { width: 480 } as const;

const finding = {
  severity: "medium",
  description: "Downloads and runs a remote script",
  file: "scripts/fetch.sh",
  line: 4,
};

export const Caution = () => (
  <div style={pane}>
    <SecurityScanCard
      state="done"
      policy="ask"
      summary="1 finding"
      severityCounts={{ critical: 0, high: 0, medium: 1, low: 0 }}
      findings={[finding]}
    />
  </div>
);

export const Passed = () => (
  <div style={pane}>
    <SecurityScanCard
      state="done"
      policy="allow"
      summary="No findings in 3 files"
    />
  </div>
);

export const Blocked = () => (
  <div style={pane}>
    <SecurityScanCard
      state="done"
      policy="block"
      summary="2 findings"
      severityCounts={{ critical: 1, high: 1 }}
      policyReason="Skills with critical findings are blocked on this server."
      findings={[
        {
          severity: "critical",
          description: "Sends ~/.ssh to a remote host",
          file: "scripts/sync.sh",
          line: 12,
        },
        {
          severity: "high",
          description: "Writes outside the skill directory",
          file: "SKILL.md",
        },
      ]}
    />
  </div>
);

export const Running = () => (
  <div style={pane}>
    <SecurityScanCard state="running" />
  </div>
);

export const Failed = () => (
  <div style={pane}>
    <SecurityScanCard state="failed" />
  </div>
);

export const AppleRunning = () => (
  <HermesProvider platform="apple" style={{ padding: 16 }}>
    <div style={{ width: 358 }}>
      <SecurityScanCard state="running" />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <SecurityScanCard
        state="done"
        policy="ask"
        summary="1 finding"
        severityCounts={{ medium: 1 }}
        findings={[finding]}
      />
    </div>
  </HermesProvider>
);
