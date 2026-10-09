import { HermesProvider, PillSegmentedControl } from "@hermes-app/ui";

const column = {
  display: "flex",
  flexDirection: "column",
  gap: 16,
  width: 360,
  padding: 16,
} as const;

/** Material tabs of a settings page (Plugins, Skills) and a form's choice: the selected segment on a raised, bordered thumb. */
export const Tabs = () => (
  <HermesProvider style={column}>
    <PillSegmentedControl
      labels={["Installed", "Catalog", "Providers"]}
      value={0}
      label="Plugins"
    />
    <PillSegmentedControl labels={["Installed", "Discover"]} value={1} />
    <PillSegmentedControl labels={["Low", "Medium", "High"]} value={2} />
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={column}>
    <PillSegmentedControl
      labels={["Installed", "Catalog", "Providers"]}
      value={1}
      label="Plugins"
    />
    <PillSegmentedControl labels={["Once", "Interval", "Cron"]} value={0} />
  </HermesProvider>
);
