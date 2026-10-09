import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  HubSkillRow,
  type Platform,
} from "@hermes-app/ui";

const noop = () => {};
const row = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const looks: Array<{ name: string; platform: Platform; device?: "mac" }> = [
  { name: "iPhone", platform: "apple" },
  { name: "Mac", platform: "apple", device: "mac" },
  { name: "Material", platform: "material" },
];

const scraper = {
  name: "web-scraper",
  description: "Scrape pages into markdown.",
  trust: "community" as const,
  tags: ["web"],
};
const research = {
  name: "web-research",
  description:
    "Search the web and cite sources. Keeps a list of what it read and quotes the passages it relied on.",
  trust: "builtin" as const,
};
const compose = {
  name: "compose",
  description: "Manage Compose stacks.",
  trust: "trusted" as const,
};

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
            <GroupedSection header="Featured">
              <HubSkillRow skill={scraper} onClick={noop} />
              <HubSkillRow skill={compose} installed onClick={noop} />
            </GroupedSection>
            <GroupedSection header="Official">
              <HubSkillRow skill={research} onClick={noop} />
            </GroupedSection>
          </GroupedListView>
        </HermesProvider>
      ))}
    </div>
  );
}

/** Hub skills on iPhone, Mac and Material: the trust label leads the subtitle, "Installed" before the chevron of a skill the profile has. */
export const Discover = () => <Looks />;

/** A single iPhone group. */
export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390, paddingTop: 8 }}>
    <GroupedListView>
      <GroupedSection header="Results">
        <HubSkillRow skill={research} onClick={noop} />
        <HubSkillRow skill={compose} installed onClick={noop} />
      </GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

export const Dark = () => <Looks theme="dark" />;
