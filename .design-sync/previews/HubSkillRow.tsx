import { HermesProvider, HubSkillRow } from "@hermes-app/ui";

const pane = { width: 480 } as const;

const scraper = {
  name: "web-scraper",
  description: "Scrape pages into markdown.",
  trust: "community" as const,
  tags: ["web", "scraping", "markdown", "extra"],
};
const research = {
  name: "web-research",
  description:
    "Search the web and cite sources. Keeps a list of what it read and quotes the passages it relied on.",
  trust: "builtin" as const,
  tags: ["search"],
};
const compose = {
  name: "compose",
  description: "Manage Compose stacks.",
  trust: "trusted" as const,
};

export const Discover = () => (
  <div style={pane}>
    <HubSkillRow skill={research} />
    <HubSkillRow skill={scraper} />
    <HubSkillRow skill={compose} installed />
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390 }}>
    <HubSkillRow skill={scraper} />
    <HubSkillRow skill={compose} installed />
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: "8px 0", borderRadius: 14 }}>
    <div style={pane}>
      <HubSkillRow skill={research} />
      <HubSkillRow skill={compose} installed />
    </div>
  </HermesProvider>
);
