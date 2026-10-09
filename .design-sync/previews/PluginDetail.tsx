import { HermesProvider, PluginDetail, type Platform } from "@hermes-app/ui";

const pane = {
  width: 400,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const noop = () => {};
const handlers = {
  onEnabledChange: noop,
  onHiddenChange: noop,
  onEnableAfterInstallChange: noop,
};
const row = { display: "flex", gap: 12, alignItems: "flex-start" } as const;

const looks: Array<{ name: string; platform: Platform; device?: "mac" }> = [
  { name: "iPhone", platform: "apple" },
  { name: "Mac", platform: "apple", device: "mac" },
  { name: "Material", platform: "material" },
];

const netbox = {
  name: "netbox",
  version: "1.2.0",
  source: "git",
  description: "Query NetBox for devices and prefixes.",
  status: "enabled" as const,
  authRequired: true,
  authCommand: "hermes auth netbox",
  canUpdate: true,
  removable: true,
};

const notes = {
  name: "notes-sync",
  version: "1.2.0",
  source: "user",
  description: "Keep a folder of notes in step with memory.",
  status: "disabled" as const,
  removable: true,
};

/** An installed plugin that needs a login, with Update and Remove, on Material. */
export const Installed = () => (
  <HermesProvider style={pane}>
    <PluginDetail plugin={netbox} {...handlers} />
  </HermesProvider>
);

/** A catalog entry not installed yet: Enable after install and Install, then its facts, what it provides and the docs row. */
export const CatalogEntry = () => (
  <HermesProvider style={pane}>
    <PluginDetail
      variant="catalog"
      {...handlers}
      plugin={{
        name: "browser-tools",
        maintainer: "Nous Research",
        official: true,
        description: "Drive a headless browser.",
        commit: "a3f9c21",
        requiresHermes: ">=0.9",
        platforms: ["linux", "macos"],
        tools: ["browser_open", "browser_click"],
        env: ["BROWSER_PATH"],
        docsUrl: "https://example.com/browser-tools",
      }}
    />
  </HermesProvider>
);

/** The same plugin on iPhone, Mac and Material: the grouped sections follow the platform. */
export const Apple = () => (
  <div style={row}>
    {looks.map((look) => (
      <HermesProvider
        key={look.name}
        platform={look.platform}
        typeRamp={look.device ? "default" : undefined}
        style={{ ...pane, width: 360 }}
      >
        <PluginDetail plugin={notes} device={look.device} {...handlers} />
      </HermesProvider>
    ))}
  </div>
);

/** Dark, a change running: the switches are disabled and Update spins. */
export const Dark = () => (
  <div style={row}>
    {[looks[0], looks[2]].map((look) => (
      <HermesProvider
        key={look.name}
        platform={look.platform}
        theme="dark"
        style={pane}
      >
        <PluginDetail plugin={netbox} busy {...handlers} />
      </HermesProvider>
    ))}
  </div>
);
