import { BlueprintCard, HermesProvider } from "@hermes-app/ui";

const wrap = {
  width: 560,
  display: "flex",
  flexWrap: "wrap",
  gap: 12,
} as const;

const card = { width: 260 } as const;

/** Gallery cards: title, description cut after three lines, the schedule in words. */
export const Templates = () => (
  <div style={wrap}>
    <div style={card}>
      <BlueprintCard
        blueprint={{
          key: "morning-brief",
          title: "Morning briefing",
          description: "A short daily briefing",
          category: "daily",
          schedule: "daily at 08:00",
        }}
      />
    </div>
    <div style={card}>
      <BlueprintCard
        blueprint={{
          key: "mail",
          title: "Important mail",
          description:
            "Check the inbox for urgent mail from people you work with and summarize what needs an answer today, with links to each thread and a suggested reply for the most pressing ones.",
          category: "email",
          schedule: "every hour",
        }}
      />
    </div>
  </div>
);

/** The full-width "Custom task" card above the gallery. */
export const Custom = () => (
  <div style={{ width: 532 }}>
    <BlueprintCard
      variant="custom"
      blueprint={{
        key: "custom",
        title: "Custom task",
        description: "Start from scratch",
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{
      padding: 16,
      borderRadius: 14,
      display: "flex",
      flexDirection: "column",
      gap: 12,
      width: 560,
    }}
  >
    <BlueprintCard
      variant="custom"
      blueprint={{
        key: "custom",
        title: "Custom task",
        description: "Start from scratch",
      }}
    />
    <div style={card}>
      <BlueprintCard
        blueprint={{
          key: "morning-brief",
          title: "Morning briefing",
          description: "A short daily briefing",
          schedule: "daily at 08:00",
        }}
      />
    </div>
  </HermesProvider>
);
