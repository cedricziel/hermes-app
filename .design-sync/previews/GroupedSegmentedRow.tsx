import { GroupedListView, GroupedRow, GroupedSection, GroupedSegmentedRow, HermesProvider } from "@hermes-app/ui";
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

/** The model picker's reasoning effort and a schedule kind: the sliding control on Apple, the pill control on Material. */
export const Effort = () => (
  <Compare>
    {() => (
      <>
        <GroupedSection header="Reasoning effort">
          <GroupedSegmentedRow labels={["Low", "Medium", "High"]} value={1} label="Reasoning effort" />
        </GroupedSection>
        <GroupedSection header="Repeat">
          <GroupedSegmentedRow labels={["Once", "Interval", "Cron"]} value={2} />
          <GroupedRow title="Every" value="day at 03:00" onClick={noop} />
        </GroupedSection>
      </>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {() => (
      <GroupedSection header="Reasoning effort">
        <GroupedSegmentedRow labels={["Minimal", "Low", "High", "Ultra"]} value={0} />
      </GroupedSection>
    )}
  </Compare>
);
