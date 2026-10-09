import { HermesProvider, BlueprintGalleryScreen } from "@hermes-app/ui";
import type { BlueprintItem } from "@hermes-app/ui";

const blueprints: BlueprintItem[] = [
  {
    key: "morning-brief",
    title: "Morning briefing",
    description: "A short daily briefing",
    category: "daily",
    schedule: "daily at 08:00",
  },
  {
    key: "mail",
    title: "Important mail",
    description: "Check for urgent mail",
    category: "email",
    schedule: "every hour",
  },
  {
    key: "standup",
    title: "Stand-up notes",
    description:
      "Collect yesterday's merged PRs and closed tasks into stand-up notes.",
    category: "daily",
    schedule: "weekdays at 09:15",
  },
];

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 520 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;

/** iPhone: Cancel, the title over "work", the search field with its category filter button, "Custom task" with a "+" tile, then a group per category. Beside it the filter menu open. */
export const ApplePhone = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={phone}>
      <BlueprintGalleryScreen blueprints={blueprints} profile="work" />
    </HermesProvider>
    <HermesProvider platform="apple" style={phone}>
      <BlueprintGalleryScreen
        blueprints={blueprints}
        profile="work"
        category="daily"
        filterMenuOpen
      />
    </HermesProvider>
  </div>
);

/** Material: the close X and the 44px pill search field; a search narrowing the list. */
export const MaterialPhone = () => (
  <div style={pair}>
    <HermesProvider platform="material" style={phone}>
      <BlueprintGalleryScreen blueprints={blueprints} profile="work" />
    </HermesProvider>
    <HermesProvider platform="material" style={phone}>
      <BlueprintGalleryScreen
        blueprints={blueprints}
        profile="work"
        query="mail"
      />
    </HermesProvider>
  </div>
);

/** Mac: the toolbar with the back button, the search field and the filter button, the groups in the 600px column. */
export const Desktop = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <BlueprintGalleryScreen
      device="mac"
      blueprints={blueprints}
      profile="work"
    />
  </HermesProvider>
);

/** Loading, and the templates failing to load (a "Templates" group with Retry). "Custom task" stays. */
export const LoadingAndFailed = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={{ ...phone, height: 420 }}>
      <BlueprintGalleryScreen state="loading" profile="work" />
    </HermesProvider>
    <HermesProvider platform="material" style={{ ...phone, height: 420 }}>
      <BlueprintGalleryScreen state="error" profile="work" />
    </HermesProvider>
  </div>
);

/** A search without matches: "No templates match". Dark, iPhone and Material. */
export const NoMatchDark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        platform={platform}
        theme="dark"
        style={{ ...phone, height: 420 }}
      >
        <BlueprintGalleryScreen
          blueprints={blueprints}
          profile="work"
          query="weather"
        />
      </HermesProvider>
    ))}
  </div>
);
