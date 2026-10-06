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

/** iPhone: the custom task card, search, category chips and the templates. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <BlueprintGalleryScreen blueprints={blueprints} />
    </div>
  </HermesProvider>
);

/** Android: the Daily category picked. */
export const MaterialPhone = () => (
  <div style={phone}>
    <BlueprintGalleryScreen blueprints={blueprints} category="daily" />
  </div>
);

/** Desktop window: 260px cards side by side. */
export const Desktop = () => (
  <div
    style={{
      width: 800,
      height: 480,
      border: "1px solid var(--h-border)",
      overflow: "hidden",
    }}
  >
    <BlueprintGalleryScreen blueprints={blueprints} />
  </div>
);

const half = { ...phone, width: 380, height: 300 } as const;

/** Loading the templates, and a failed load with Retry; the custom card is there in both. */
export const LoadingAndFailed = () => (
  <div style={{ display: "flex", gap: 20 }}>
    <div style={half}>
      <BlueprintGalleryScreen state="loading" />
    </div>
    <div style={half}>
      <BlueprintGalleryScreen state="error" />
    </div>
  </div>
);

/** A search with no match. Dark. */
export const NoMatchDark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={{ ...phone, height: 420 }}>
      <BlueprintGalleryScreen blueprints={blueprints} query="backup" />
    </div>
  </HermesProvider>
);
