import { HermesProvider, HubSkillScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const noop = () => {};

const scraper = {
  name: "web-scraper",
  description: "Scrape pages into markdown.",
  trust: "community" as const,
  tags: ["web"],
};
const files = ["SKILL.md", "scripts/fetch.sh"];
const markdown = "# Web scraper\n\nFetch pages and turn them into markdown.";
const caution = {
  state: "done" as const,
  policy: "ask" as const,
  summary: "1 finding",
  severityCounts: { critical: 0, high: 0, medium: 1, low: 0 },
  findings: [
    {
      severity: "medium",
      description: "Downloads and runs a remote script",
      file: "scripts/fetch.sh",
      line: 4,
    },
  ],
};

export const AppleCaution = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <HubSkillScreen
        skill={scraper}
        source="github"
        previewState="loaded"
        files={files}
        markdown={markdown}
        scan={caution}
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const MaterialPassed = () => (
  <div style={phone}>
    <HubSkillScreen
      skill={{
        name: "web-research",
        description: "Search the web and cite sources.",
        trust: "builtin",
      }}
      source="official"
      previewState="loaded"
      files={["SKILL.md"]}
      markdown={"# Web research\n\nSearch, read, and cite what you used."}
      scan={{ state: "done", policy: "allow", summary: "No findings" }}
      onBack={noop}
    />
  </div>
);

export const AppleMacBlocked = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <HubSkillScreen
        layout="desktop"
        skill={{ ...scraper, name: "ssh-sync" }}
        source="github"
        previewState="loaded"
        files={["SKILL.md", "scripts/sync.sh"]}
        markdown={"# SSH sync\n\nKeeps hosts in sync."}
        scan={{
          state: "done",
          policy: "block",
          summary: "1 finding",
          severityCounts: { critical: 1 },
          policyReason:
            "Skills with critical findings are blocked on this server.",
          findings: [
            {
              severity: "critical",
              description: "Sends ~/.ssh to a remote host",
              file: "scripts/sync.sh",
              line: 12,
            },
          ],
        }}
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const Scanning = () => (
  <div style={phone}>
    <HubSkillScreen
      skill={scraper}
      source="github"
      scan={{ state: "running" }}
      onBack={noop}
    />
  </div>
);

export const PreviewAndScanFail = () => (
  <div style={phone}>
    <HubSkillScreen
      skill={scraper}
      source="github"
      previewState="failed"
      scan={{ state: "failed" }}
      onBack={noop}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <HubSkillScreen
        skill={scraper}
        source="github"
        previewState="loaded"
        files={files}
        markdown={markdown}
        scan={caution}
        onBack={noop}
      />
    </div>
  </HermesProvider>
);
