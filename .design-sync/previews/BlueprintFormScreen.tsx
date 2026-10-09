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
    label: "Topics",
    optional: true,
    help: "Separate topics with commas",
    value: "infra, releases",
  },
];

const form = {
  title: "Morning briefing",
  profile: "work",
  description: "A short daily briefing",
  fields,
};

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 520 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;

/** iPhone: the back chevron, the title over "work", Create; the description, a time value row, choices with a blue check, an optional text field with its footer. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <BlueprintFormScreen {...form} />
  </HermesProvider>
);

/** Material: the back arrow, Create in the bar, choices with leading radios, a floating label. */
export const MaterialPhone = () => (
  <HermesProvider platform="material" style={phone}>
    <BlueprintFormScreen {...form} />
  </HermesProvider>
);

/** Mac: the toolbar with the back button and a filled Create, the groups in the 600px column. */
export const Desktop = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <BlueprintFormScreen {...form} device="mac" />
  </HermesProvider>
);

/** A slot without a time ("Choose a time", "Pick a time" under it) and a refused Create; Creating shows a spinner. */
export const Errors = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={phone}>
      <BlueprintFormScreen
        {...form}
        fields={[{ ...fields[0], value: "", error: "Pick a time" }, fields[1]]}
        error="Telegram has no home channel on the server"
      />
    </HermesProvider>
    <HermesProvider platform="material" style={phone}>
      <BlueprintFormScreen {...form} saving />
    </HermesProvider>
  </div>
);

/** Dark, iPhone and Material. */
export const Dark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        platform={platform}
        theme="dark"
        style={phone}
      >
        <BlueprintFormScreen {...form} />
      </HermesProvider>
    ))}
  </div>
);
