import { HermesProvider, NotificationsDialog } from "@hermes-app/ui";

const phone = {
  position: "relative",
  width: 390,
  height: 520,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;
const mac = { ...phone, width: 640, height: 420 } as const;
const row = { display: "flex", gap: 16, alignItems: "flex-start" } as const;
const noop = () => {};

const tall = { ...phone, height: 640 } as const;

/** iPhone, the system refused notifications: "Notify me" stays on with the warning line; Live Activities on. */
export const IPhonePermissionDenied = () => (
  <HermesProvider platform="apple">
    <div style={tall}>
      <NotificationsDialog
        enabled
        permissionDenied
        scheduleAlerts
        liveActivities
        onEnabledChange={noop}
        onScheduleAlertsChange={noop}
        onLiveActivitiesChange={noop}
        onDone={noop}
      />
    </div>
  </HermesProvider>
);

/** iPhone, dark: Live Activities are off for Hermes in iOS, so their row warns. */
export const IPhoneLiveActivitiesBlocked = () => (
  <HermesProvider platform="apple" theme="dark">
    <div style={tall}>
      <NotificationsDialog
        enabled
        scheduleAlerts={false}
        liveActivities={false}
        liveActivitiesBlocked
        onEnabledChange={noop}
        onScheduleAlertsChange={noop}
        onLiveActivitiesChange={noop}
        onDone={noop}
      />
    </div>
  </HermesProvider>
);

/** Mac: small toggles, 11px footers, no Live Activities group. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <NotificationsDialog
        enabled
        scheduleAlerts
        device="mac"
        onEnabledChange={noop}
        onScheduleAlertsChange={noop}
        onDone={noop}
      />
    </div>
  </HermesProvider>
);

/** Material: notifications off, so Scheduled tasks is greyed out; and dark with both on. */
export const Material = () => (
  <div style={row}>
    <HermesProvider>
      <div style={phone}>
        <NotificationsDialog
          enabled={false}
          scheduleAlerts
          onEnabledChange={noop}
          onDone={noop}
        />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={phone}>
        <NotificationsDialog
          enabled
          scheduleAlerts
          onEnabledChange={noop}
          onScheduleAlertsChange={noop}
          onDone={noop}
        />
      </div>
    </HermesProvider>
  </div>
);
