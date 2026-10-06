import { HermesProvider, SkillEditorScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 520 } as const;
const noop = () => {};

const prReview = `---
name: pr-review
description: Review a pull request
---

# Review PRs

Read the diff first, then the tests.

- Flag anything that changes behaviour without a test
- Be kind; suggest, don't command
`;

export const AppleEdit = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <SkillEditorScreen
        mode="edit"
        name="pr-review"
        text={prReview}
        canSave
        canUndo
        onClose={noop}
      />
    </div>
  </HermesProvider>
);

export const MaterialCreate = () => (
  <div style={phone}>
    <SkillEditorScreen
      mode="create"
      nameValue="web-research"
      canSave
      onClose={noop}
    />
  </div>
);

export const Preview = () => (
  <div style={phone}>
    <SkillEditorScreen
      mode="edit"
      name="pr-review"
      text={prReview}
      view="preview"
      canSave
      onClose={noop}
    />
  </div>
);

export const SaveFailed = () => (
  <div style={phone}>
    <SkillEditorScreen
      mode="create"
      nameValue="pr-review"
      text={prReview}
      canSave
      error="A skill named pr-review already exists"
      onClose={noop}
    />
  </div>
);

export const AppleMacCreate = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <SkillEditorScreen
        layout="desktop"
        mode="create"
        nameValue="web-research"
        category="research"
        saving
        canUndo
        canRedo
        onClose={noop}
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <SkillEditorScreen
        mode="edit"
        name="pr-review"
        text={prReview}
        canSave
        canUndo
        onClose={noop}
      />
    </div>
  </HermesProvider>
);
