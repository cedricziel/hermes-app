import type { ReactNode } from "react";
import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  PluginRow,
  type Platform,
} from "@hermes-app/ui";

const cell = { width: 380, paddingTop: 8 } as const;
const row = { display: "flex", gap: 12, alignItems: "flex-start" } as const;

const looks: Array<{
  name: string;
  platform: Platform;
  device?: "mac";
}> = [
  { name: "iPhone", platform: "apple" },
  { name: "Mac", platform: "apple", device: "mac" },
  { name: "Material", platform: "material" },
];

function Look({
  look,
  theme,
  children,
}: {
  look: (typeof looks)[number];
  theme?: "dark";
  children: ReactNode;
}) {
  return (
    <HermesProvider
      platform={look.platform}
      typeRamp={look.device ? "default" : undefined}
      theme={theme}
      style={cell}
    >
      <GroupedListView device={look.device}>{children}</GroupedListView>
    </HermesProvider>
  );
}

const installed = (
  <GroupedSection>
    <PluginRow
      plugin={{
        name: "netbox",
        version: "1.2.0",
        description: "Query NetBox for devices and prefixes.",
        status: "enabled",
      }}
    />
    <PluginRow
      selected
      plugin={{
        name: "notes-sync",
        version: "1.2.0",
        description: "Keep a folder of notes in step with memory.",
        status: "disabled",
      }}
    />
    <PluginRow
      plugin={{
        name: "calendar",
        version: "1.2.0",
        description: "Read and create calendar events.",
        status: "inactive",
        authRequired: true,
      }}
    />
    <PluginRow
      plugin={{
        name: "terminal",
        version: "1.2.0",
        description: "Run shell commands.",
        status: "enabled",
        bundled: true,
      }}
    />
  </GroupedSection>
);

const catalog = (
  <GroupedSection>
    <PluginRow
      variant="catalog"
      plugin={{
        name: "browser-tools",
        maintainer: "Nous Research",
        description: "Drive a headless browser.",
        official: true,
      }}
    />
    <PluginRow
      variant="catalog"
      plugin={{
        name: "notes-sync",
        maintainer: "A community author",
        description: "Keep notes in step with memory.",
        installed: true,
        updateAvailable: true,
      }}
    />
    <PluginRow
      variant="catalog"
      installing
      plugin={{
        name: "rss-reader",
        maintainer: "A community author",
        description: "Read feeds and summarise them.",
      }}
    />
  </GroupedSection>
);

/** Installed rows on iPhone, Mac and Material: "v1.2.0" after the name, "On"/"Off"/"Inactive" as muted text (with a chevron on Apple), "Needs login" as a warning, the selected row filled. */
export const Installed = () => (
  <div style={row}>
    {looks.map((look) => (
      <Look key={look.name} look={look}>
        {installed}
      </Look>
    ))}
  </div>
);

/** Catalog rows: "Official" after the name, maintainer · description, "Update available" for an installed entry, and Install as an iOS tinted pill, a Mac push button or a Material outlined pill (spinning while it installs). */
export const Catalog = () => (
  <div style={row}>
    {looks.map((look) => (
      <Look key={look.name} look={look}>
        {catalog}
      </Look>
    ))}
  </div>
);

/** A name that does not fit is cut with an ellipsis; a removed plugin warns why. */
export const LongName = () => (
  <Look look={looks[2]}>
    <GroupedSection>
      <PluginRow
        plugin={{
          name: "a-plugin-with-a-really-long-name-that-does-not-fit",
          version: "1.0.0",
          description: "Short.",
          status: "enabled",
        }}
      />
      <PluginRow
        plugin={{
          name: "old",
          version: "1.0.0",
          description: "About old",
          removedReason: "unsafe network call",
          status: "enabled",
        }}
      />
    </GroupedSection>
  </Look>
);

export const Dark = () => (
  <div style={row}>
    {looks.map((look) => (
      <Look key={look.name} look={look} theme="dark">
        {installed}
        {catalog}
      </Look>
    ))}
  </div>
);

const weather = {
  name: "hermes-plugin-weather",
  version: "0.4.2",
  description: "Forecasts and severe weather alerts for the places you name.",
  status: "enabled" as const,
  removable: true,
};
const notes = {
  name: "notes-sync",
  version: "1.2.0",
  description: "Keep a folder of notes in step with memory.",
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

/** iPhone: an installed plugin swiped from the trailing edge shows Remove in red, clipped by the group. */
export const AppleSwipe = () => (
  <Look look={looks[0]}>
    <GroupedSection>
      <PluginRow plugin={weather} swipeRevealed />
      <PluginRow plugin={notes} />
    </GroupedSection>
  </Look>
);

/** iPhone: a long press on an installed plugin opens Disable and Remove in an action sheet. */
export const AppleActionSheet = () => (
  <HermesProvider platform="apple" style={phone}>
    <GroupedListView>
      <GroupedSection>
        <PluginRow plugin={weather} actionSheetOpen />
        <PluginRow plugin={notes} />
      </GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

export const AppleSwipeDark = () => (
  <Look look={looks[0]} theme="dark">
    <GroupedSection>
      <PluginRow plugin={weather} />
      <PluginRow plugin={notes} swipeRevealed />
    </GroupedSection>
  </Look>
);
