import {
  Button,
  Chip,
  FormSection,
  HermesProvider,
  ModelPill,
  SelectField,
  Switch,
  TextField,
} from "@hermes-app/ui";

const form = {
  width: 380,
  padding: 16,
  display: "flex",
  flexDirection: "column",
  gap: 20,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  background: "var(--h-bg)",
} as const;

const chips = { display: "flex", flexWrap: "wrap", gap: 8 } as const;

/** The job form's "When" section: a titled block with mode chips, a time button and a muted helper. */
export const When = () => (
  <div style={form}>
    <FormSection
      title="When"
      helper="Next runs: tomorrow 08:00, Thu 08:00, Fri 08:00"
    >
      <div style={chips}>
        <Chip label="Every" />
        <Chip label="Daily" selected />
        <Chip label="Weekly" />
        <Chip label="Once" />
        <Chip label="Cron" />
      </div>
      <div>
        <Button variant="outlined" icon="schedule">
          08:00
        </Button>
      </div>
    </FormSection>
    <FormSection>
      <SelectField label="Deliver results to" value="Telegram" />
    </FormSection>
  </div>
);

/** The Kanban task form's label-styled sections: Model (a ModelPill), Priority and Start as (choice chips). */
export const LabelSections = () => (
  <div style={form}>
    <FormSection title="Model" titleStyle="label" gap={4}>
      <div>
        <ModelPill model="claude-opus-4" effort="Medium" />
      </div>
    </FormSection>
    <FormSection title="Priority" titleStyle="label">
      <div style={chips}>
        <Chip label="Normal" selected />
        <Chip label="P1" />
        <Chip label="P2" />
        <Chip label="P3" />
      </div>
    </FormSection>
    <FormSection title="Start as" titleStyle="label">
      <div style={chips}>
        <Chip label="Triage" selected />
        <Chip label="Todo" />
      </div>
    </FormSection>
  </div>
);

/** "Advanced" folded shut (top) and open with its fields (below). */
export const Advanced = () => (
  <div style={form}>
    <FormSection title="Advanced" collapsible>
      <TextField label="Skills" />
    </FormSection>
    <FormSection title="Advanced" collapsible open>
      <TextField
        label="Skills"
        defaultValue="news, calendar"
        helper="Names, separated by commas"
      />
      <SelectField
        label="Model"
        placeholder="Profile default"
        helper="Anthropic"
      />
      <TextField
        label="Pre-run script"
        helper="A file in the profile’s scripts folder; its output is added to the prompt"
      />
    </FormSection>
  </div>
);

/** A blueprint slot: optional title, help text and an error. */
export const SlotWithError = () => (
  <div style={form}>
    <FormSection
      title="Where to deliver?"
      optional
      helper="Pick where the briefing goes"
      error="Choose one of the options"
      gap={6}
    >
      <div style={chips}>
        <Chip label="origin" />
        <Chip label="local" />
        <Chip label="telegram" />
      </div>
    </FormSection>
  </div>
);

/** Under Apple the section is unchanged; the controls inside follow the platform (Apple switch). */
export const Apple = () => (
  <HermesProvider platform="apple">
    <div style={form}>
      <FormSection title="Advanced" collapsible open gap={8}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span className="h-body-lg" style={{ flex: 1 }}>
            Start paused
          </span>
          <Switch checked={false} label="Start paused" />
        </div>
        <SelectField label="Profile" value="work" />
      </FormSection>
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={form}>
      <FormSection title="When" helper="Next runs: tomorrow 08:00">
        <div style={chips}>
          <Chip label="Every" />
          <Chip label="Daily" selected />
          <Chip label="Weekly" />
        </div>
      </FormSection>
      <FormSection title="Advanced" collapsible>
        <TextField label="Skills" />
      </FormSection>
      <FormSection title="Priority" titleStyle="label" error="Pick a priority">
        <div style={chips}>
          <Chip label="Normal" />
          <Chip label="P1" />
        </div>
      </FormSection>
    </div>
  </HermesProvider>
);
