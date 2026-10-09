import { HermesProvider, Switch } from "@hermes-app/ui";

const row = { display: "flex", gap: 16, alignItems: "center" } as const;
const stage = { padding: 16, borderRadius: 14 } as const;

const Set = () => (
  <div style={row}>
    <Switch checked label="Morning brief" />
    <Switch checked={false} label="Dependency audit" />
    <Switch checked disabled label="grafana (switching)" />
    <Switch checked={false} disabled label="Completed job" />
  </div>
);

/** On, off, on while the server answers (disabled), and a completed one-shot job (disabled off). */
export const Material = () => (
  <HermesProvider style={stage}>
    <Set />
  </HermesProvider>
);

export const MaterialDark = () => (
  <HermesProvider theme="dark" style={stage}>
    <Set />
  </HermesProvider>
);

/** The iOS and macOS toggle: 51x31, a 27px thumb that keeps its size, the primary color when on. */
export const Apple = () => (
  <HermesProvider platform="apple" style={stage}>
    <Set />
  </HermesProvider>
);

export const AppleDark = () => (
  <HermesProvider platform="apple" theme="dark" style={stage}>
    <Set />
  </HermesProvider>
);

/** The Mac settings row's small toggle (`small`): 36x22, on, off and disabled. */
export const AppleSmall = () => (
  <HermesProvider platform="apple" style={stage}>
    <div style={row}>
      <Switch small checked label="Enabled" />
      <Switch small checked={false} label="Hide from dashboard sidebar" />
      <Switch small checked disabled label="Live Activities" />
    </div>
  </HermesProvider>
);
