import { HermesProvider, PluginRow } from "@hermes-app/ui";

const pane = { width: 400 } as const;
const divider = {
  height: 1,
  background: "var(--h-border)",
} as const;

export const Installed = () => (
  <div style={pane}>
    <PluginRow
      selected
      plugin={{
        name: "netbox",
        version: "1.0.0",
        description:
          "Query and update NetBox from the agent: look up devices, prefixes, VLANs and cables, reserve addresses and keep the source of truth in sync.",
        authRequired: true,
        status: "enabled",
      }}
    />
    <div style={divider} />
    <PluginRow
      plugin={{
        name: "kanban",
        version: "1.0.0",
        description: "About kanban",
        bundled: true,
        status: "enabled",
      }}
    />
    <div style={divider} />
    <PluginRow
      plugin={{
        name: "gmail-triage",
        version: "1.0.0",
        description: "About gmail-triage",
        status: "disabled",
      }}
    />
    <div style={divider} />
    <PluginRow
      plugin={{
        name: "idle-plugin",
        version: "1.0.0",
        description: "About idle-plugin",
        status: "inactive",
      }}
    />
    <div style={divider} />
    <PluginRow
      plugin={{
        name: "old",
        version: "1.0.0",
        description: "About old",
        removedReason: "unsafe network call",
        status: "enabled",
      }}
    />
  </div>
);

export const Catalog = () => (
  <div style={pane}>
    <PluginRow
      variant="catalog"
      plugin={{
        name: "hermes-plugin-chrome-profiles",
        maintainer: "Acme",
        description: "Switch Chrome profiles from the agent",
        commit: "a3f9c21",
        official: true,
      }}
    />
    <div style={divider} />
    <PluginRow
      variant="catalog"
      selected
      plugin={{
        name: "hermes-snapcompact",
        maintainer: "someone",
        description: "About hermes-snapcompact",
        commit: "a3f9c21",
        installed: true,
        updateAvailable: true,
      }}
    />
    <div style={divider} />
    <PluginRow
      variant="catalog"
      installing
      plugin={{
        name: "hermes-plugin-weather",
        maintainer: "someone",
        description: "Forecasts.",
        commit: "a3f9c21",
      }}
    />
  </div>
);

export const LongName = () => (
  <div style={pane}>
    <PluginRow
      plugin={{
        name: "a-plugin-with-a-really-long-name-that-does-not-fit",
        version: "1.0.0",
        description: "Short.",
        status: "enabled",
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <PluginRow
        selected
        plugin={{
          name: "netbox",
          version: "1.0.0",
          description:
            "Query and update NetBox from the agent: look up devices, prefixes, VLANs and cables.",
          authRequired: true,
          status: "enabled",
        }}
      />
      <div style={divider} />
      <PluginRow
        plugin={{
          name: "gmail-triage",
          version: "1.0.0",
          description: "About gmail-triage",
          status: "disabled",
        }}
      />
      <div style={divider} />
      <PluginRow
        variant="catalog"
        plugin={{
          name: "hermes-plugin-weather",
          maintainer: "someone",
          description: "Forecasts.",
          commit: "a3f9c21",
        }}
      />
    </div>
  </HermesProvider>
);

const weather = {
  name: "hermes-plugin-weather",
  version: "0.4.2",
  description: "Forecasts and severe weather alerts for the places you name.",
  status: "enabled" as const,
  removable: true,
};
const netbox = {
  name: "netbox",
  version: "1.0.0",
  description: "Query and update NetBox from the agent.",
  status: "disabled" as const,
  removable: true,
};
const phone = {
  position: "relative",
  width: 390,
  height: 420,
  overflow: "hidden",
  borderRadius: 14,
} as const;

/** iPhone: an installed plugin swiped from the trailing edge shows Remove in red; the catalog's Install spins with the activity indicator. */
export const AppleSwipe = () => (
  <HermesProvider platform="apple" style={{ width: 390 }}>
    <PluginRow plugin={weather} swipeRevealed />
    <div style={divider} />
    <PluginRow plugin={netbox} />
    <div style={divider} />
    <PluginRow
      variant="catalog"
      installing
      plugin={{
        name: "hermes-plugin-github",
        maintainer: "Nous Research",
        description: "Issues, pull requests and reviews from the agent.",
        commit: "a3f9c21",
        official: true,
      }}
    />
  </HermesProvider>
);

/** iPhone: a long press on an installed plugin opens Disable and Remove in an action sheet. */
export const AppleActionSheet = () => (
  <HermesProvider platform="apple" style={phone}>
    <PluginRow plugin={weather} actionSheetOpen />
    <div style={divider} />
    <PluginRow plugin={netbox} />
  </HermesProvider>
);

export const AppleSwipeDark = () => (
  <HermesProvider platform="apple" theme="dark" style={{ width: 390 }}>
    <PluginRow plugin={weather} />
    <div style={divider} />
    <PluginRow plugin={netbox} swipeRevealed />
  </HermesProvider>
);
