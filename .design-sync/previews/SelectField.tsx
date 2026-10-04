import { HermesProvider, SelectField } from "@hermes-app/ui";

const column = {
  width: 340,
  display: "flex",
  flexDirection: "column",
  gap: 16,
} as const;

const tall = { ...column, minHeight: 260 } as const;

/** A chosen value, a placeholder with a helper, a mono model with a "not listed" helper, an error and a disabled field. */
export const States = () => (
  <div style={column}>
    <SelectField label="Deliver results to" value="Telegram" />
    <SelectField
      label="Model"
      placeholder="Profile default"
      helper="Leave it for the profile's model"
    />
    <SelectField
      label="Model"
      value="claude-opus-4-1-20250805"
      mono
      helper="Anthropic · Not in the server’s list"
    />
    <SelectField
      label="Profile"
      placeholder="Choose a profile"
      error="Pick the profile the task runs in"
    />
    <SelectField label="Assignee" value="Auto (triage picks)" disabled />
  </div>
);

/** Material: the dropdown open under the field, the current value checked. */
export const MenuOpen = () => (
  <div style={tall}>
    <SelectField
      label="Assignee"
      value="coder"
      options={["Auto (triage picks)", "coder", "writer", "reviewer"]}
      defaultOpen
    />
  </div>
);

/** Apple: the field looks the same (forms are Material in the app); on an iPhone (`device="touch"`) its list is the iOS pull-down. */
export const AppleMenuOpen = () => (
  <HermesProvider platform="apple">
    <div style={tall}>
      <SelectField
        label="Deliver results to"
        value="Telegram"
        options={["Local (save only)", "Origin chat", "Telegram"]}
        device="touch"
        defaultOpen
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={column}>
      <SelectField label="Deliver results to" value="Telegram" />
      <SelectField
        label="Model"
        placeholder="Profile default"
        helper="Anthropic"
      />
      <SelectField label="Profile" error="Pick a profile" />
    </div>
  </HermesProvider>
);
