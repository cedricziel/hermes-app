import { HermesProvider, SkillJobSheet } from "@hermes-app/ui";

// A stand-in for the bottom sheet the job opens in.
const sheet = {
  width: 420,
  paddingTop: 22,
  borderRadius: "28px 28px 0 0",
  background: "var(--h-surface)",
  border: "1px solid var(--h-border)",
  borderBottom: 0,
} as const;

const log = ["Fetching web-scraper", "Checking the files", "Installing"];

export const Running = () => (
  <div style={sheet}>
    <SkillJobSheet title="Installing web-scraper" state="running" lines={log} />
  </div>
);

export const Succeeded = () => (
  <div style={sheet}>
    <SkillJobSheet
      title="Installing web-scraper"
      state="succeeded"
      lines={[...log, "Installed web-scraper into profile work"]}
    />
  </div>
);

export const Failed = () => (
  <div style={sheet}>
    <SkillJobSheet
      title="Installing web-scraper"
      state="failed"
      error="hermes skills install exited with code 1"
      lines={[...log, "error: scripts/fetch.sh failed the scan"]}
    />
  </div>
);

export const Unconfirmed = () => (
  <div style={sheet}>
    <SkillJobSheet title="Updating hub skills" state="unknown" />
  </div>
);

export const AppleRunning = () => (
  <HermesProvider platform="apple" style={{ padding: 0 }}>
    <div style={sheet}>
      <SkillJobSheet
        title="Installing web-scraper"
        state="running"
        lines={log}
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={sheet}>
      <SkillJobSheet
        title="Installing web-scraper"
        state="failed"
        error="hermes skills install exited with code 1"
        lines={log}
      />
    </div>
  </HermesProvider>
);
