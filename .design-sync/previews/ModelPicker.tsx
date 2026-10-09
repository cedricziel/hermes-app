import {
  HermesProvider,
  ModelPicker,
  type ModelPickerProvider,
} from "@hermes-app/ui";

const efforts = [
  "none",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
  "ultra",
];
const providers: ModelPickerProvider[] = [
  {
    id: "anthropic",
    label: "Anthropic",
    models: [
      { id: "claude-opus-4", efforts },
      { id: "claude-sonnet-4-5", efforts },
      { id: "claude-haiku-4-5" },
    ],
  },
  {
    id: "openrouter",
    label: "OpenRouter",
    models: [
      { id: "openai/gpt-5.1", efforts },
      { id: "openai/gpt-5.1-mini" },
      { id: "google/gemini-2.5-pro" },
      { id: "deepseek/deepseek-v4-pro" },
      { id: "qwen/qwen3-coder" },
      { id: "moonshotai/kimi-k2" },
    ],
  },
];
const kanbanProviders: ModelPickerProvider[] = [
  {
    id: "anthropic",
    label: "Anthropic",
    models: [{ id: "claude-opus-4" }, { id: "claude-haiku-4-5" }],
  },
  {
    id: "openrouter",
    label: "OpenRouter",
    models: [{ id: "openai/gpt-5.1" }],
  },
];
const opusHigh = {
  provider: "anthropic",
  model: "claude-opus-4",
  effort: "high",
};

const phone = {
  position: "relative",
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;
const desktop = { ...phone, width: 720, height: 560 } as const;
const row = { display: "flex", gap: 16, alignItems: "flex-start" } as const;
const noop = () => {};

/** iPhone: the chat's picker as a bottom sheet, search above the 9 models, the picked model checked, Reasoning effort pinned under the list with High picked. Beside it the Kanban picker led by "Use the profile’s default". */
export const IPhone = () => (
  <HermesProvider platform="apple" style={row}>
    <div style={phone}>
      <ModelPicker
        providers={providers}
        selected={opusHigh}
        onChange={noop}
        onDismiss={noop}
      />
    </div>
    <div style={phone}>
      <ModelPicker
        providers={kanbanProviders}
        withEffort={false}
        onUseDefault={noop}
        onChange={noop}
        onDismiss={noop}
      />
    </div>
  </HermesProvider>
);

/** Mac: the 440px dialog, the search field beside the 13px bold title, compact rows and 24px effort pills. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <ModelPicker
        providers={providers}
        selected={opusHigh}
        presentation="desktop"
        device="mac"
        onChange={noop}
        onDismiss={noop}
      />
    </div>
  </HermesProvider>
);

/** Material: leading radios and round effort pills in the sheet; and a search with no hit. */
export const Material = () => (
  <HermesProvider style={row}>
    <div style={phone}>
      <ModelPicker
        providers={providers}
        selected={{
          provider: "openrouter",
          model: "openai/gpt-5.1",
          effort: "medium",
        }}
        onChange={noop}
        onDismiss={noop}
      />
    </div>
    <div style={phone}>
      <ModelPicker
        providers={providers}
        query="mistral"
        onChange={noop}
        onDismiss={noop}
      />
    </div>
  </HermesProvider>
);

/** A helper slot's picker with a note and the profile's default, searching "gpt": OpenRouter keeps only its matching models. Material desktop dialog. */
export const HelperSlot = () => (
  <HermesProvider>
    <div style={desktop}>
      <ModelPicker
        providers={providers}
        title="Compression"
        note="Runs on the main model unless you pick one. Applies to new chats."
        withEffort={false}
        selected={{ provider: "openrouter", model: "openai/gpt-5.1-mini" }}
        query="gpt"
        presentation="desktop"
        onUseDefault={noop}
        onChange={noop}
        onDismiss={noop}
      />
    </div>
  </HermesProvider>
);

/** Dark: iPhone sheet and Material sheet with radios. */
export const Dark = () => (
  <HermesProvider theme="dark" style={row}>
    <HermesProvider theme="dark" platform="apple">
      <div style={phone}>
        <ModelPicker
          providers={providers}
          selected={opusHigh}
          onChange={noop}
          onDismiss={noop}
        />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={phone}>
        <ModelPicker
          providers={kanbanProviders}
          withEffort={false}
          onUseDefault={noop}
          onChange={noop}
          onDismiss={noop}
        />
      </div>
    </HermesProvider>
  </HermesProvider>
);
