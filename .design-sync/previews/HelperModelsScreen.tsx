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

export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <HelperModelsScreen
        slots={slots}
        mainModel="claude-opus-4"
        moa={moa}
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const MaterialPhone = () => (
  <div style={phone}>
    <HelperModelsScreen
      slots={[slots[0], { ...slots[1], saving: true }, slots[2], slots[3]]}
      mainModel="claude-opus-4"
      moa={moa}
      onBack={noop}
    />
  </div>
);

export const AppleMacWithoutMoa = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <HelperModelsScreen
        layout="desktop"
        slots={slots}
        mainModel="claude-opus-4"
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const PrivacyFilter = () => (
  <div style={phone}>
    <HelperModelsScreen
      slots={slots.slice(0, 2)}
      mainModel="claude-opus-4"
      moa={{ ...moa, preset: "cheap", privacyFilterOn: true }}
      onBack={noop}
    />
  </div>
);

export const Loading = () => (
  <div style={phone}>
    <HelperModelsScreen state="loading" onBack={noop} />
  </div>
);

export const Failed = () => (
  <div style={phone}>
    <HelperModelsScreen state="failed" onBack={noop} />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <HelperModelsScreen
        slots={slots}
        mainModel="claude-opus-4"
        moa={moa}
        onBack={noop}
      />
    </div>
  </HermesProvider>
);
