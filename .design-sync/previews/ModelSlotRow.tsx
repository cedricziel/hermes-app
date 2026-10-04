import { HermesProvider, ModelSlotRow } from "@hermes-app/ui";

const pane = { width: 480 } as const;
const noop = () => {};

export const Slots = () => (
  <div style={pane}>
    <ModelSlotRow label="Vision" mainModel="claude-opus-4" onClick={noop} />
    <ModelSlotRow
      label="Chat titles"
      choice={{ provider: "openrouter", model: "gemini-flash", effort: "low" }}
      onClick={noop}
    />
    <ModelSlotRow
      label="Context compression"
      choice={{ provider: "openai", model: "gpt-5-mini" }}
      saving
    />
  </div>
);

export const MixtureOfAgents = () => (
  <div style={pane}>
    <ModelSlotRow
      label="Advisor 1"
      choice={{ provider: "openai-codex", model: "gpt-5.5" }}
      onClick={noop}
    />
    <ModelSlotRow
      label="Advisor 2"
      off
      choice={{
        provider: "openrouter",
        model: "deepseek/deepseek-v4-pro",
        effort: "high",
      }}
      onClick={noop}
    />
    <ModelSlotRow
      label="Aggregator"
      choice={{ provider: "openrouter", model: "anthropic/claude-opus-4.8" }}
      onClick={noop}
    />
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390 }}>
    <ModelSlotRow label="Vision" mainModel="claude-opus-4" onClick={noop} />
    <ModelSlotRow
      label="Chat titles"
      choice={{
        provider: "openrouter",
        model: "gemini-flash",
        effort: "xhigh",
      }}
      saving
    />
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: "8px 0", borderRadius: 14 }}>
    <div style={pane}>
      <ModelSlotRow label="Vision" mainModel="claude-opus-4" onClick={noop} />
      <ModelSlotRow
        label="Approval checks"
        choice={{ provider: "nous", model: "" }}
        onClick={noop}
      />
    </div>
  </HermesProvider>
);
