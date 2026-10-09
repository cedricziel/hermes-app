import { HelperModelsScreen, HermesProvider } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const noop = () => {};

const slots = [
  { task: "vision", label: "Vision" },
  {
    task: "title_generation",
    label: "Chat titles",
    choice: { provider: "openrouter", model: "gemini-flash", effort: "low" },
  },
  {
    task: "compression",
    label: "Context compression",
    choice: { provider: "openai", model: "gpt-5-mini" },
  },
  { task: "approval", label: "Approval checks" },
];

const moa = {
  preset: "default",
  slots: [
    {
      key: "advisor:0",
      label: "Advisor 1",
      choice: { provider: "openai-codex", model: "gpt-5.5" },
    },
    {
      key: "advisor:2",
      label: "Advisor 2",
      enabled: false,
      choice: {
        provider: "openrouter",
        model: "deepseek/deepseek-v4-pro",
        effort: "high",
      },
    },
    {
      key: "aggregator",
      label: "Aggregator",
      choice: { provider: "openrouter", model: "anthropic/claude-opus-4.8" },
    },
  ],
};

/** iPhone: the title over the profile, the slots as value rows (muted model, chevron) with the main model in the footer, and the Mixture of agents group with its Preset. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <HelperModelsScreen
      profile="work"
      slots={slots}
      mainModel="claude-opus-4"
      moa={moa}
      onBack={noop}
    />
  </HermesProvider>
);

/** Material: two-line rows (label over model), one slot saving. */
export const MaterialPhone = () => (
  <HermesProvider style={phone}>
    <HelperModelsScreen
      profile="work"
      slots={[slots[0], { ...slots[1], saving: true }, slots[2], slots[3]]}
      mainModel="claude-opus-4"
      moa={moa}
      onBack={noop}
    />
  </HermesProvider>
);

/** Mac without a mixture of agents: "work · main model claude-opus-4" in the toolbar and each model in a pop-up button. */
export const AppleMacWithoutMoa = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <HelperModelsScreen
      layout="desktop"
      profile="work"
      slots={slots}
      mainModel="claude-opus-4"
      onBack={noop}
    />
  </HermesProvider>
);

/** Hermes' privacy filter is on: a named preset and a footer saying to change the slots on the server, which do not open. */
export const PrivacyFilter = () => (
  <HermesProvider platform="apple" style={phone}>
    <HelperModelsScreen
      profile="work"
      slots={slots.slice(0, 2)}
      mainModel="claude-opus-4"
      moa={{ ...moa, preset: "cheap", privacyFilterOn: true }}
      onBack={noop}
    />
  </HermesProvider>
);

export const Loading = () => (
  <HermesProvider platform="apple" style={phone}>
    <HelperModelsScreen state="loading" profile="work" onBack={noop} />
  </HermesProvider>
);

export const Failed = () => (
  <HermesProvider style={phone}>
    <HelperModelsScreen state="failed" profile="work" onBack={noop} />
  </HermesProvider>
);

/** Dark on iPhone and a Mac. */
export const Dark = () => (
  <div style={{ display: "flex", gap: 12 }}>
    <HermesProvider platform="apple" theme="dark" style={phone}>
      <HelperModelsScreen
        profile="work"
        slots={slots}
        mainModel="claude-opus-4"
        moa={moa}
        onBack={noop}
      />
    </HermesProvider>
    <HermesProvider
      platform="apple"
      typeRamp="default"
      theme="dark"
      style={{ ...phone, width: 400 }}
    >
      <HelperModelsScreen
        layout="desktop"
        profile="work"
        slots={slots}
        mainModel="claude-opus-4"
        moa={moa}
        onBack={noop}
      />
    </HermesProvider>
  </div>
);
