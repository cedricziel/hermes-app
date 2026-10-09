import { GroupedListView, GroupedSection, GroupedValueRow, HermesProvider } from "@hermes-app/ui";
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

/** Helper models: iOS value + chevron, the Mac pop-up button, Material label over value; one slot saving. */
export const HelperModels = () => (
  <Compare>
    {() => (
      <>
        <GroupedSection footer="Hermes runs side jobs on these models. Changes apply to new chats.">
          <GroupedValueRow title="Vision" value="Main model" onClick={noop} />
          <GroupedValueRow title="Chat titles" value="gemini-flash" onClick={noop} />
          <GroupedValueRow title="Context compression" value="gpt-5-mini" busy />
          <GroupedValueRow title="Approval checks" value="Main model" onClick={noop} />
        </GroupedSection>
        <GroupedSection header="Mixture of agents">
          <GroupedValueRow title="Preset" value="Default" />
          <GroupedValueRow title="Advisor 1" value="gpt-5.5" onClick={noop} />
          <GroupedValueRow title="Advisor 2" value="Off" onClick={noop} />
        </GroupedSection>
      </>
    )}
  </Compare>
);

/** A form's model and schedule fields, with a caption and a warning. */
export const FormFields = () => (
  <Compare>
    {() => (
      <GroupedSection header="Run">
        <GroupedValueRow
          title="Model"
          value="claude-opus-4"
          caption="anthropic"
          onClick={noop}
        />
        <GroupedValueRow
          title="Schedule"
          value="Every day at 03:00"
          warning="Runs only while the server is up"
          onClick={noop}
        />
      </GroupedSection>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {() => (
      <GroupedSection>
        <GroupedValueRow title="Vision" value="Main model" onClick={noop} />
        <GroupedValueRow title="Aggregator" value="claude-opus-4.8" onClick={noop} />
      </GroupedSection>
    )}
  </Compare>
);
