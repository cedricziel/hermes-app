import type { ReactNode } from "react";
import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  ModelSlotRow,
  type Platform,
} from "@hermes-app/ui";

const noop = () => {};
const row = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const looks: Array<{ name: string; platform: Platform; device?: "mac" }> = [
  { name: "iPhone", platform: "apple" },
  { name: "Mac", platform: "apple", device: "mac" },
  { name: "Material", platform: "material" },
];

function Looks({ theme, children }: { theme?: "dark"; children: ReactNode }) {
  return (
    <div style={row}>
      {looks.map((look) => (
        <HermesProvider
          key={look.name}
          platform={look.platform}
          typeRamp={look.device ? "default" : undefined}
          theme={theme}
          style={{ width: 360, paddingTop: 8 }}
        >
          <GroupedListView device={look.device}>{children}</GroupedListView>
        </HermesProvider>
      ))}
    </div>
  );
}

/** Helper slots on iPhone, Mac and Material: "Main model" for auto, the short model name, and a slot saving (a spinner in the value's place). */
export const Slots = () => (
  <Looks>
    <GroupedSection footer="Hermes runs side jobs on these models. Changes apply to new chats.">
      <ModelSlotRow label="Vision" onClick={noop} />
      <ModelSlotRow
        label="Chat titles"
        choice={{
          provider: "openrouter",
          model: "gemini-flash",
          effort: "low",
        }}
        onClick={noop}
      />
      <ModelSlotRow
        label="Context compression"
        choice={{ provider: "openai", model: "gpt-5-mini" }}
        saving
      />
    </GroupedSection>
  </Looks>
);

/** Mixture-of-agents slots: an advisor switched off reads "Off", a provider-prefixed id shows its last segment. */
export const MixtureOfAgents = () => (
  <Looks>
    <GroupedSection header="Mixture of agents">
      <ModelSlotRow
        label="Advisor 1"
        choice={{ provider: "openai-codex", model: "gpt-5.5" }}
        onClick={noop}
      />
      <ModelSlotRow
        label="Advisor 2"
        off
        choice={{ provider: "openrouter", model: "deepseek/deepseek-v4-pro" }}
        onClick={noop}
      />
      <ModelSlotRow
        label="Aggregator"
        choice={{ provider: "openrouter", model: "anthropic/claude-opus-4.8" }}
        onClick={noop}
      />
    </GroupedSection>
  </Looks>
);

/** iPhone: a slot on the provider's default model and one that cannot be changed here. */
export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390, paddingTop: 8 }}>
    <GroupedListView>
      <GroupedSection>
        <ModelSlotRow
          label="Approval checks"
          choice={{ provider: "nous", model: "" }}
          onClick={noop}
        />
        <ModelSlotRow
          label="Aggregator"
          choice={{
            provider: "openrouter",
            model: "anthropic/claude-opus-4.8",
          }}
          disabled
        />
      </GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

export const Dark = () => (
  <Looks theme="dark">
    <GroupedSection>
      <ModelSlotRow label="Vision" onClick={noop} />
      <ModelSlotRow
        label="Approval checks"
        choice={{ provider: "nous", model: "" }}
        onClick={noop}
      />
    </GroupedSection>
  </Looks>
);
