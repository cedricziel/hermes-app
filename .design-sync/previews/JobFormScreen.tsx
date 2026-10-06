import { AppShell, HermesProvider, JobFormScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

/** Scrolls the form to its end, to show what sits below the fold. */
const scrolled = (el: HTMLDivElement | null) =>
  el?.querySelector(".h-list-detail__list")?.scrollTo(0, 10000);

const targets = ["Local (save only)", "Origin chat", "Telegram"];

/** iPhone: a new task with a daily schedule, two profiles and the Apple Start paused switch. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <JobFormScreen
        name="Morning brief"
        prompt="Summarize my calendar and the overnight news."
        schedule={{
          mode: "daily",
          time: "08:00",
          nextRuns: "tomorrow 08:00, Thu 08:00, Fri 08:00",
        }}
        targets={targets}
        deliverTo="Telegram"
        profiles={["work", "home"]}
        profile="work"
      />
    </div>
  </HermesProvider>
);

/** Android: an empty new task repeating every 30 minutes. */
export const MaterialPhone = () => (
  <div style={phone}>
    <JobFormScreen
      schedule={{ mode: "every", amount: "30", unit: "minutes" }}
      targets={targets}
      deliverTo="Local (save only)"
    />
  </div>
);

/** Mac window, scrolled to the end: editing a job (no Profile or Start paused), Advanced open with skills and a model, Save task. */
export const MacEditing = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div
      ref={scrolled}
      style={{
        width: 800,
        height: 560,
        border: "1px solid var(--h-border)",
        overflow: "hidden",
      }}
    >
      <AppShell
        layout="desktop"
        current="schedules"
        showTrafficLights
        sidebarWidth={220}
        account="Ada Lovelace"
      >
        <JobFormScreen
          mode="edit"
          name="Morning brief"
          prompt="Summarize my calendar and the overnight news."
          schedule={{
            mode: "weekly",
            days: ["Mon", "Tue", "Wed", "Thu", "Fri"],
            time: "08:00",
            nextRuns: "Mon 08:00, Tue 08:00, Wed 08:00",
          }}
          targets={targets}
          deliverTo="Telegram"
          advancedOpen
          advanced={{
            skills: "news, calendar",
            model: "claude-opus-4",
            modelHelper: "Anthropic",
          }}
        />
      </AppShell>
    </div>
  </HermesProvider>
);

/** Scrolled to the end: a target without a home channel, Advanced folded, the server's error and Save task saving. */
export const WarningAndError = () => (
  <div style={phone} ref={scrolled}>
    <JobFormScreen
      name="Check the status page"
      prompt="Check status.example.com and tell me when something is down."
      schedule={{ mode: "cron", cron: "*/30 * * * *" }}
      targets={targets}
      deliverTo="Telegram"
      noHomeChannel
      error="The schedule is not valid: */30 * * * *"
      saving
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={phone}>
      <JobFormScreen
        name="Weekly digest"
        schedule={{
          mode: "weekly",
          days: ["Fri"],
          time: "17:00",
          nextRuns: "Fri 17:00, Fri 17:00, Fri 17:00",
        }}
        targets={targets}
        deliverTo="Origin chat"
        startPaused
      />
    </div>
  </HermesProvider>
);
