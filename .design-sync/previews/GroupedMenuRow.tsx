import { GroupedListView, GroupedMenuRow, GroupedSection, HermesProvider } from "@hermes-app/ui";
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

/** A task's priority and delivery, closed: the picked option as the row's value. */
export const Closed = () => (
  <Compare>
    {() => (
      <GroupedSection header="Task">
        <GroupedMenuRow title="Priority" options={["Low", "Normal", "High"]} selected={1} />
        <GroupedMenuRow
          title="Deliver to"
          options={["Telegram", "Discord"]}
          placeholder="Nowhere"
          warning="No messaging platform is set up"
        />
      </GroupedSection>
    )}
  </Compare>
);

/** The menu open under the row: the iOS pull-down, the Mac menu, the Material popup, the picked option checked. */
export const Open = () => (
  <Compare>
    {() => (
      <>
        <GroupedSection header="Appearance">
          <GroupedMenuRow
            title="Theme"
            options={["System", "Light", "Dark"]}
            selected={0}
            open
          />
        </GroupedSection>
        <div style={{ height: 170 }} />
      </>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {() => (
      <GroupedSection>
        <GroupedMenuRow title="Priority" options={["Low", "Normal", "High"]} selected={2} />
      </GroupedSection>
    )}
  </Compare>
);
