import {
  GroupedListView,
  GroupedRow,
  GroupedSection,
  GroupedSwitchRow,
  HermesProvider,
} from "@hermes-app/ui";

const noop = () => {};
const frame = (width: number, height: number) =>
  ({
    width,
    height,
    display: "flex",
    flexDirection: "column",
    border: "1px solid var(--h-border)",
    borderRadius: 14,
    overflow: "hidden",
  }) as const;

const page = (
  <>
    <GroupedSection footer="Applies to new chats.">
      <GroupedSwitchRow title="Enabled" checked onChange={noop} />
      <GroupedSwitchRow
        title="Hide from dashboard sidebar"
        subtitle="Only affects the web dashboard"
        checked={false}
        onChange={noop}
      />
    </GroupedSection>
    <GroupedSection header="Details">
      <GroupedRow title="Version" value="v1.2.0" />
      <GroupedRow title="Source" value="user" />
    </GroupedSection>
    <GroupedSection>
      <GroupedRow
        title="Remove plugin"
        destructive
        onClick={noop}
        chevron={false}
      />
    </GroupedSection>
  </>
);

/** A wide Mac window: the groups stay in the centred 600px column with a 20px gutter. */
export const MacWide = () => (
  <HermesProvider platform="apple" typeRamp="default" style={frame(800, 360)}>
    <GroupedListView device="mac">{page}</GroupedListView>
  </HermesProvider>
);

/** iPhone and Material: a 16px gutter, the groups full width up to 640px. */
export const Phones = () => (
  <div style={{ display: "flex", gap: 12 }}>
    <HermesProvider platform="apple" style={frame(390, 480)}>
      <GroupedListView>{page}</GroupedListView>
    </HermesProvider>
    <HermesProvider style={frame(390, 480)}>
      <GroupedListView>{page}</GroupedListView>
    </HermesProvider>
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    typeRamp="default"
    style={frame(800, 360)}
  >
    <GroupedListView device="mac">{page}</GroupedListView>
  </HermesProvider>
);
