import { GroupedChoiceRow, GroupedListView, GroupedSection, HermesProvider } from "@hermes-app/ui";
import type { ReactNode } from "react";

type Look = "iphone" | "mac" | "material";

const frame = {
  width: 264,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

/** iPhone, Mac and Material panels side by side, each a `GroupedListView`. */
const Compare = ({
  theme = "light",
  children,
}: {
  theme?: "light" | "dark";
  children: (look: Look) => ReactNode;
}) => (
  <HermesProvider
    theme={theme}
    style={{ display: "flex", gap: 12, padding: 12, alignItems: "flex-start" }}
  >
    {(["iphone", "mac", "material"] as const).map((look) => (
      <HermesProvider
        key={look}
        theme={theme}
        platform={look === "material" ? "material" : "apple"}
        typeRamp={look === "mac" ? "default" : undefined}
        style={frame}
      >
        <GroupedListView device={look === "mac" ? "mac" : "touch"}>
          {children(look)}
        </GroupedListView>
      </HermesProvider>
    ))}
  </HermesProvider>
);

const noop = () => {};

/** The appearance's theme: three plain choices. */
export const Theme = () => (
  <Compare>
    {() => (
      <GroupedSection header="Appearance" dividerIndent="choice">
        <GroupedChoiceRow title="System" checked onSelect={noop} />
        <GroupedChoiceRow title="Light" onSelect={noop} />
        <GroupedChoiceRow title="Dark" onSelect={noop} />
      </GroupedSection>
    )}
  </Compare>
);

/** Plugins' context engine and memory provider: subtitles, meta, and an unavailable option with its warning. */
export const Providers = () => (
  <Compare>
    {() => (
      <GroupedSection
        header="Memory provider"
        footer="Where the agent keeps long-term memory."
        dividerIndent="choice"
      >
        <GroupedChoiceRow title="Built-in" subtitle="No external memory" onSelect={noop} />
        <GroupedChoiceRow
          title="holographic"
          meta="Ready"
          subtitle="Remembers things with holographic."
          checked
          onSelect={noop}
        />
        <GroupedChoiceRow
          title="vector-store"
          subtitle="Remembers things with vector-store."
          warning="Unavailable"
          disabled
        />
      </GroupedSection>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {() => (
      <GroupedSection header="Context engine" dividerIndent="choice">
        <GroupedChoiceRow title="compressor" subtitle="Summarises old turns." checked />
        <GroupedChoiceRow title="sliding-window" subtitle="Keeps the last turns." />
      </GroupedSection>
    )}
  </Compare>
);
