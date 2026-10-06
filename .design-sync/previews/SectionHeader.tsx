import {
  Button,
  HermesProvider,
  RadioRow,
  SectionHeader,
  Tag,
} from "@hermes-app/ui";

const pane = { width: 440 } as const;

/** `title`: opens a section of a full-width list, with a caption. */
export const Title = () => (
  <div style={pane}>
    <SectionHeader
      title="Memory provider"
      caption="Where the agent keeps long-term memory"
    />
    <RadioRow title="Built-in" subtitle="No external memory" selected />
  </div>
);

/** `overline` over a group in a padded pane, and `label` over a form control. */
export const OverlineAndLabel = () => (
  <div style={{ ...pane, display: "flex", flexDirection: "column", gap: 16 }}>
    <div>
      <SectionHeader variant="overline" title="TOOLS · 4" />
      <div className="h-body-md" style={{ marginTop: 8 }}>
        search_dashboards, query_prometheus, …
      </div>
    </div>
    <SectionHeader
      variant="label"
      title="Environment variables"
      action={
        <Button variant="text" icon="add" compact>
          Add variable
        </Button>
      }
    />
    <div>
      <SectionHeader variant="label" title="Tools" />
      <div style={{ display: "flex", gap: 6, marginTop: 6 }}>
        <Tag mono>netbox_lookup</Tag>
        <Tag mono>netbox_update</Tag>
      </div>
    </div>
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple">
    <div style={pane}>
      <SectionHeader
        title="Context engine"
        caption="How long conversations are compressed"
      />
      <div style={{ padding: "8px 16px" }}>
        <SectionHeader variant="overline" title="CREDENTIALS" />
      </div>
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <SectionHeader
        title="Memory provider"
        caption="Where the agent keeps long-term memory"
      />
      <div style={{ padding: "8px 16px" }}>
        <SectionHeader variant="overline" title="TOOLS · 2" />
      </div>
    </div>
  </HermesProvider>
);
