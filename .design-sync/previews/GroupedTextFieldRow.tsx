import { GroupedListView, GroupedSection, GroupedTextFieldRow, HermesProvider } from "@hermes-app/ui";
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

/** A job form: a one-line name beside its label on Apple (floating label on Material), a multi-line prompt and a monospace cron line, with a footer. */
export const JobForm = () => (
  <Compare>
    {() => (
      <>
        <GroupedSection header="Job">
          <GroupedTextFieldRow label="Name" defaultValue="Nightly backup" />
          <GroupedTextFieldRow
            label="Prompt"
            hint="What should Hermes do?"
            rows={3}
          />
        </GroupedSection>
        <GroupedSection
          header="Schedule"
          footer="Minute, hour, day of month, month, day of week."
        >
          <GroupedTextFieldRow label="Cron" defaultValue="0 3 * * *" monospace />
        </GroupedSection>
      </>
    )}
  </Compare>
);

/** Empty fields show their hint; an MCP server's URL. */
export const Empty = () => (
  <Compare>
    {() => (
      <GroupedSection header="Server">
        <GroupedTextFieldRow label="Name" hint="github" />
        <GroupedTextFieldRow label="URL" hint="https://" type="url" />
      </GroupedSection>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {() => (
      <GroupedSection header="Task">
        <GroupedTextFieldRow label="Title" defaultValue="Migrate webhooks" />
        <GroupedTextFieldRow label="Body" hint="Details" rows={2} />
      </GroupedSection>
    )}
  </Compare>
);
