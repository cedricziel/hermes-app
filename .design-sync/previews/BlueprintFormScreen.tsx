import { HermesProvider, BlueprintFormScreen } from "@hermes-app/ui";
import type { BlueprintFieldItem } from "@hermes-app/ui";

const fields: BlueprintFieldItem[] = [
  { name: "time", type: "time", label: "What time?", value: "08:00" },
  {
    name: "deliver",
    type: "choice",
    label: "Where to deliver?",
    options: ["origin", "local", "telegram"],
    value: "origin",
  },
  {
    name: "topics",
    type: "text",
    label: "Topics to cover",
    optional: true,
    help: "Separate topics with commas",
    value: "infra, releases",
  },
];

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

/** iPhone: chevron "Back", the description, a time slot, a choice slot and an optional text slot. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <BlueprintFormScreen
        title="Morning briefing"
        description="A short daily briefing"
        fields={fields}
      />
    </div>
  </HermesProvider>
);

/** Android: the same form. */
export const MaterialPhone = () => (
  <div style={phone}>
    <BlueprintFormScreen
      title="Morning briefing"
      description="A short daily briefing"
      fields={fields}
    />
  </div>
);

/** Desktop: the form 560px wide, centred. */
export const Desktop = () => (
  <div
    style={{
      width: 800,
      height: 520,
      border: "1px solid var(--h-border)",
      overflow: "hidden",
    }}
  >
    <BlueprintFormScreen
      layout="desktop"
      title="Morning briefing"
      description="A short daily briefing"
      fields={fields}
    />
  </div>
);

/** After a failed Create: slot errors, the server's error, then saving. */
export const Errors = () => (
  <div style={phone}>
    <BlueprintFormScreen
      title="Morning briefing"
      fields={[
        {
          name: "time",
          type: "time",
          label: "What time?",
          error: "Pick a time",
        },
        {
          name: "deliver",
          type: "choice",
          label: "Where to deliver?",
          options: ["origin", "local", "telegram"],
          error: "Choose where the briefing goes",
        },
      ]}
      error="No home channel is set on the server for Telegram."
      saving
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={{ ...phone, height: 480 }}>
      <BlueprintFormScreen
        title="Morning briefing"
        description="A short daily briefing"
        fields={fields}
      />
    </div>
  </HermesProvider>
);
