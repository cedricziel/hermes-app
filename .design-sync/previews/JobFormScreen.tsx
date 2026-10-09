import { HermesProvider, JobFormScreen } from "@hermes-app/ui";
import type { JobFormScreenProps } from "@hermes-app/ui";

const base: JobFormScreenProps = {
  profile: "work",
  schedule: {
    mode: "every",
    amount: "1",
    unit: "hours",
    nextRuns: "Oct 9, 2026 3:45 AM, Oct 9, 2026 4:45 AM, Oct 9, 2026 5:45 AM",
  },
  targets: ["Local (save only)", "Origin chat", "Telegram"],
  deliverTo: "Local (save only)",
  profiles: ["work", "home"],
};

const advanced: JobFormScreenProps = {
  ...base,
  advancedOpen: true,
  advanced: { model: "claude-opus-4", modelHelper: "Anthropic" },
};

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;

/** iPhone: Cancel, "New task" over "work", Save; Name and Task, When, Delivery (Deliver results to, Profile, Start paused) and the folded Advanced row. Beside it the same form with Advanced open. */
export const ApplePhone = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={phone}>
      <JobFormScreen {...base} />
    </HermesProvider>
    <HermesProvider platform="apple" style={phone}>
      <JobFormScreen
        {...advanced}
        name="Check the status page"
        prompt="Check status.example.com and tell me when something is down."
      />
    </HermesProvider>
  </div>
);

/** Material: the close X, Save in the bar, floating labels, the pill segmented control. */
export const MaterialPhone = () => (
  <div style={pair}>
    <HermesProvider platform="material" style={phone}>
      <JobFormScreen {...base} />
    </HermesProvider>
    <HermesProvider platform="material" style={phone}>
      <JobFormScreen {...advanced} defaultOpen="deliver" />
    </HermesProvider>
  </div>
);

/** Mac: editing a job (no Profile or Start paused), the back button and a filled Save in the toolbar, pop-up buttons for the menus, a weekly schedule. */
export const MacEditing = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <JobFormScreen
      {...base}
      device="mac"
      mode="edit"
      name="Morning brief"
      prompt="Summarize my calendar for today and the overnight news on AI."
      schedule={{
        mode: "weekly",
        days: ["Mon", "Tue", "Wed", "Thu", "Fri"],
        time: "08:00",
        nextRuns: "Oct 12, 2026 8:00 AM, Oct 13, 2026 8:00 AM",
      }}
      deliverTo="Telegram"
      advancedOpen
      advanced={{ skills: "news, calendar", model: "claude-opus-4" }}
    />
  </HermesProvider>
);

/** A target with no home channel (warning line) and a refused save (red note); Saving shows a spinner in place of Save. */
export const WarningAndError = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={phone}>
      <JobFormScreen
        {...base}
        name="Daily report"
        prompt="Send me the report"
        deliverTo="Telegram"
        noHomeChannel
        error="The server refused the schedule: invalid cron expression"
        schedule={{ mode: "cron", cron: "0 25 * * *" }}
      />
    </HermesProvider>
    <HermesProvider platform="material" style={phone}>
      <JobFormScreen
        {...base}
        name="Daily report"
        deliverTo="Telegram"
        noHomeChannel
        saving
      />
    </HermesProvider>
  </div>
);

/** Dark: iPhone and Material with Advanced open. */
export const Dark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        platform={platform}
        theme="dark"
        style={phone}
      >
        <JobFormScreen {...advanced} name="Check the status page" />
      </HermesProvider>
    ))}
  </div>
);
