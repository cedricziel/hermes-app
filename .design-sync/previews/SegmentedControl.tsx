import { HermesProvider, SegmentedControl } from "@hermes-app/ui";

const tabs = ["Installed", "Catalog", "Providers"];
const phone = { width: 390, borderRadius: 14, overflow: "hidden" } as const;

/** The Plugins screen's tabs: a 48px tab bar with the primary underline under the selected label. */
export const Material = () => (
  <HermesProvider style={phone}>
    <SegmentedControl labels={tabs} value={0} label="Plugins" />
  </HermesProvider>
);

/** iOS and macOS: the sliding segmented control, 16px in from the edges. */
export const Apple = () => (
  <HermesProvider platform="apple" style={phone}>
    <SegmentedControl labels={tabs} value={1} label="Plugins" />
  </HermesProvider>
);

export const MaterialDark = () => (
  <HermesProvider theme="dark" style={phone}>
    <SegmentedControl labels={["Board", "Workers"]} value={1} />
  </HermesProvider>
);

export const AppleDark = () => (
  <HermesProvider platform="apple" theme="dark" style={phone}>
    <SegmentedControl labels={tabs} value={2} label="Plugins" />
  </HermesProvider>
);

/** Apple sizes: `inline` across an iOS group row, `compact` in a Mac toolbar (12px, segments as wide as the widest). */
export const AppleSizes = () => (
  <HermesProvider
    platform="apple"
    style={{
      ...phone,
      display: "flex",
      flexDirection: "column",
      gap: 12,
      padding: 16,
    }}
  >
    <SegmentedControl
      labels={["Low", "Medium", "High"]}
      value={1}
      size="inline"
    />
    <div>
      <SegmentedControl
        labels={tabs}
        value={0}
        size="compact"
        label="Plugins"
      />
    </div>
  </HermesProvider>
);
