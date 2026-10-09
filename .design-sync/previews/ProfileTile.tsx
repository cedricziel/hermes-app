import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  ProfileTile,
} from "@hermes-app/ui";

const pane = {
  width: 400,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const row = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const noop = () => {};

const main = {
  name: "default",
  path: "/home/hermes/.hermes",
  model: "hermes-4",
  skillCount: 58,
};
const work = {
  name: "work",
  displayName: "Work assistant",
  description: "Day job: tickets, reviews and the on-call rota",
  model: "openai/gpt-5.1",
  skillCount: 12,
};

const Group = ({ device }: { device?: "mac" | "touch" }) => (
  <GroupedListView device={device}>
    <GroupedSection dividerIndent="tile">
      <ProfileTile active onChangeModel={noop} profile={main} />
      <ProfileTile onChangeModel={noop} profile={work} />
    </GroupedSection>
  </GroupedListView>
);

/** iPhone, Mac and Material: initials tile, description or home path, "model · skills"; checked on Apple, "Active" on Material; the tune button on Mac and Material. */
export const Profiles = () => (
  <div style={{ ...row, flexDirection: "column" }}>
    <HermesProvider platform="apple" style={pane}>
      <Group />
    </HermesProvider>
    <HermesProvider platform="apple" typeRamp="default" style={pane}>
      <Group device="mac" />
    </HermesProvider>
    <HermesProvider platform="material" style={pane}>
      <Group />
    </HermesProvider>
  </div>
);

/** No description, path, model or way to change it: label and skill count only. */
export const NoModel = () => (
  <HermesProvider platform="material" style={pane}>
    <GroupedListView>
      <GroupedSection dividerIndent="tile">
        <ProfileTile profile={{ name: "scratch", skillCount: 0 }} />
      </GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

/** Long label, description and model are cut with an ellipsis inside a narrow group. */
export const LongText = () => (
  <HermesProvider platform="material" style={{ ...pane, width: 340 }}>
    <GroupedListView>
      <GroupedSection dividerIndent="tile">
        <ProfileTile
          active
          onChangeModel={noop}
          profile={{
            name: "research",
            displayName: "Long-running research assistant for papers",
            description: "Reads papers, keeps notes and writes summaries",
            model: "meta-llama/llama-4-maverick-17b-128e-instruct",
            skillCount: 31,
          }}
        />
      </GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

export const Dark = () => (
  <div style={row}>
    <HermesProvider theme="dark" platform="apple" style={pane}>
      <Group />
    </HermesProvider>
    <HermesProvider theme="dark" platform="material" style={pane}>
      <Group />
    </HermesProvider>
  </div>
);
