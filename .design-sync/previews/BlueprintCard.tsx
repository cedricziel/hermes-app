import {
  BlueprintCard,
  GroupedListView,
  GroupedSection,
  HermesProvider,
} from "@hermes-app/ui";
import type { BlueprintItem } from "@hermes-app/ui";

const morning: BlueprintItem = {
  key: "morning-brief",
  title: "Morning briefing",
  description: "A short daily briefing",
  category: "daily",
  schedule: "daily at 08:00",
};
const standup: BlueprintItem = {
  key: "standup",
  title: "Stand-up notes",
  description:
    "Collect yesterday's merged PRs and closed tasks into stand-up notes.",
  category: "daily",
  schedule: "weekdays at 09:15",
};
const custom: BlueprintItem = {
  key: "custom",
  title: "Custom task",
  description: "Start from scratch",
};

const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const touch = { width: 390, paddingBottom: 12 } as const;
const noop = () => {};

const rows = (
  <GroupedListView>
    <GroupedSection header="Daily">
      <BlueprintCard blueprint={morning} onClick={noop} />
      <BlueprintCard blueprint={standup} onClick={noop} />
    </GroupedSection>
  </GroupedListView>
);

/** Template rows in a category group: title, description, schedule, chevron. iPhone and Material. */
export const Templates = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={touch}>
      {rows}
    </HermesProvider>
    <HermesProvider platform="material" style={touch}>
      {rows}
    </HermesProvider>
  </div>
);

/** The "Custom task" row with its "+" tile, on iPhone and on a Mac. */
export const Custom = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={touch}>
      <GroupedListView>
        <GroupedSection dividerIndent="tile">
          <BlueprintCard variant="custom" blueprint={custom} onClick={noop} />
        </GroupedSection>
      </GroupedListView>
    </HermesProvider>
    <HermesProvider platform="apple" typeRamp="default" style={touch}>
      <GroupedListView device="mac">
        <GroupedSection dividerIndent="tile">
          <BlueprintCard variant="custom" blueprint={custom} onClick={noop} />
        </GroupedSection>
      </GroupedListView>
    </HermesProvider>
  </div>
);

/** Dark, iPhone and Material. */
export const Dark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        platform={platform}
        theme="dark"
        style={touch}
      >
        {rows}
      </HermesProvider>
    ))}
  </div>
);
