import { HermesProvider, SkillDetailScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const noop = () => {};

const prReview = {
  name: "pr-review",
  description: "Review a pull request",
  category: "github",
  source: "agent" as const,
  enabled: true,
  usage: 7,
};
const content = `---
name: pr-review
description: Review a pull request
---

# Review PRs

Read the diff first, then the tests.

- Flag anything that changes behaviour without a test
- Be kind; suggest, don't command

Finish with a one-line verdict: **approve**, **comment** or **request changes**.`;

export const AppleAgentSkill = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <SkillDetailScreen skill={prReview} content={content} onBack={noop} />
    </div>
  </HermesProvider>
);

export const MaterialHubSkill = () => (
  <div style={phone}>
    <SkillDetailScreen
      skill={{
        name: "compose",
        category: "devops",
        source: "hub",
        enabled: false,
      }}
      hub
      content={"# Compose\n\nManage Compose stacks with `docker compose`."}
      onBack={noop}
    />
  </div>
);

export const AppleMacBundled = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <SkillDetailScreen
        layout="desktop"
        skill={{
          name: "apple-notes",
          category: "apple",
          source: "bundled",
          enabled: true,
          usage: 14,
        }}
        content={
          "# Apple Notes\n\nRead and search the user's notes with `memo`.\n\n- List folders\n- Search by title or body"
        }
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const ContentFailed = () => (
  <div style={phone}>
    <SkillDetailScreen skill={prReview} contentState="failed" onBack={noop} />
  </div>
);

export const Loading = () => (
  <div style={phone}>
    <SkillDetailScreen skill={prReview} contentState="loading" onBack={noop} />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <SkillDetailScreen skill={prReview} content={content} onBack={noop} />
    </div>
  </HermesProvider>
);
