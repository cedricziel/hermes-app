import { GroupedListView, GroupedSection, GroupedSwitchRow, HermesProvider } from "@hermes-app/ui";
import type { ReactNode } from "react";

type Look = "iphone" | "mac" | "material";

/** iPhone and Material at phone width, the Mac at a narrow window's width. */
const frame = (look: Look) =>
  ({
    width: look === "mac" ? 520 : 390,
    border: "1px solid var(--h-border)",
    borderRadius: 14,
    overflow: "hidden",
  }) as const;

/** iPhone and Material panels side by side and the Mac panel under them, each a `GroupedListView`. */
const Compare = ({
  theme = "light",
  children,
}: {
  theme?: "light" | "dark";
  children: (look: Look) => ReactNode;
}) => (
  <HermesProvider
    theme={theme}
    style={{
      display: "flex",
      flexWrap: "wrap",
      gap: 8,
      padding: 8,
      width: 804,
      boxSizing: "border-box",
      alignItems: "flex-start",
    }}
  >
    {(["iphone", "material", "mac"] as const).map((look) => (
      <HermesProvider
        key={look}
        theme={theme}
        platform={look === "material" ? "material" : "apple"}
        typeRamp={look === "mac" ? "default" : undefined}
        style={frame(look)}
      >
        <GroupedListView device={look === "mac" ? "mac" : "touch"}>
          {children(look)}
        </GroupedListView>
      </HermesProvider>
    ))}
  </HermesProvider>
);

const noop = () => {};

/** The notification settings: switches with subtitles, one turned off, one that cannot change, footers explaining them. */
export const Settings = () => (
  <Compare>
    {() => (
      <>
        <GroupedSection footer="Replies show a preview; requests only say that Hermes is waiting.">
          <GroupedSwitchRow
            title="Notify me"
            warning="Turn on notifications for Hermes in system settings."
            checked
            onChange={noop}
          />
        </GroupedSection>
        <GroupedSection>
          <GroupedSwitchRow title="Scheduled tasks" checked onChange={noop} />
          <GroupedSwitchRow
            title="Live Activities"
            subtitle="Not available on this device"
            checked={false}
            disabled
          />
        </GroupedSection>
      </>
    )}
  </Compare>
);

/** A row that opens details beside the list and keeps its own switch (MCP servers), selected. */
export const OpensDetails = () => (
  <Compare>
    {() => (
      <GroupedSection>
        <GroupedSwitchRow
          title="github"
          subtitle="Remote · OAuth · 2 tools"
          checked
          onChange={noop}
          onClick={noop}
          selected
        />
        <GroupedSwitchRow
          title="linear"
          subtitle="Remote · 9 tools · Off"
          checked={false}
          onChange={noop}
          onClick={noop}
        />
      </GroupedSection>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {() => (
      <GroupedSection header="Apple">
        <GroupedSwitchRow
          title="apple-notes"
          subtitle="Read and write Notes · Bundled"
          checked
          onChange={noop}
        />
        <GroupedSwitchRow
          title="imessage"
          subtitle="Send messages · Hub · used 3 times"
          checked={false}
          onChange={noop}
        />
      </GroupedSection>
    )}
  </Compare>
);
