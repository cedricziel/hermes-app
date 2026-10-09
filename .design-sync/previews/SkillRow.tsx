import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  SkillRow,
  type Platform,
} from "@hermes-app/ui";

const noop = () => {};
const row = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const looks: Array<{ name: string; platform: Platform; device?: "mac" }> = [
  { name: "iPhone", platform: "apple" },
  { name: "Mac", platform: "apple", device: "mac" },
  { name: "Material", platform: "material" },
];

const skills = [
  {
    name: "apple-notes",
    description: "Read Apple Notes",
    category: "apple",
    source: "bundled" as const,
    enabled: true,
    usage: 14,
  },
  {
    name: "pr-review",
    description: "Review a pull request",
    category: "github",
    source: "agent" as const,
    enabled: true,
  },
  {
    name: "compose",
    description:
      "Manage Compose stacks across the homelab hosts and their volumes",
    category: "devops",
    source: "hub" as const,
    enabled: false,
    usage: 1,
  },
];

function Looks({ theme }: { theme?: "dark" }) {
  return (
    <div style={row}>
      {looks.map((look) => (
        <HermesProvider
          key={look.name}
          platform={look.platform}
          typeRamp={look.device ? "default" : undefined}
          theme={theme}
          style={{ width: 360, paddingTop: 8 }}
        >
          <GroupedListView device={look.device}>
            <GroupedSection header="Skills">
              {skills.map((s) => (
                <SkillRow
                  key={s.name}
                  skill={s}
                  onClick={noop}
                  onEnabledChange={noop}
                />
              ))}
            </GroupedSection>
          </GroupedListView>
        </HermesProvider>
      ))}
    </div>
  );
}

/** Skills in a group on iPhone, Mac and Material: the name over "description · source · used N times", and the switch (the Mac's small one). */
export const Installed = () => <Looks />;

/** The same rows on a single iPhone list. */
export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390, paddingTop: 8 }}>
    <GroupedListView>
      <GroupedSection header="Apple">
        <SkillRow skill={skills[0]} onEnabledChange={noop} />
      </GroupedSection>
      <GroupedSection header="DevOps">
        <SkillRow skill={skills[2]} onEnabledChange={noop} />
      </GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

export const Dark = () => <Looks theme="dark" />;
