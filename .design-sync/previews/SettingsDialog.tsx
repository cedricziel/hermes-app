import { HermesProvider, SettingsDialog } from "@hermes-app/ui";

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

const values = {
  appearance: "system",
  notifications: true,
  dictation: "device",
  appLock: false,
} as const;

/** Mac, Settings… (⌘,): the list over the dimmed window, 13px bold title with Done, compact rows with the value muted before the chevron. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <SettingsDialog {...values} device="mac" onPick={noop} onDone={noop} />
    </div>
  </HermesProvider>
);

/** iPhone and Material: the same list in the touch dialog (centred title, Done) and the Material dialog (title at the start, no Done, and no Dictation row: the app offers it on iOS and macOS only). */
export const IPhoneAndMaterial = () => (
  <div style={row}>
    <HermesProvider platform="apple">
      <div style={phone}>
        <SettingsDialog {...values} onPick={noop} onDone={noop} />
      </div>
    </HermesProvider>
    <HermesProvider>
      <div style={phone}>
        <SettingsDialog
          appearance="dark"
          notifications={false}
          appLock
          onPick={noop}
          onDone={noop}
        />
      </div>
    </HermesProvider>
  </div>
);

/** Mac, dark. */
export const Dark = () => (
  <HermesProvider platform="apple" typeRamp="default" theme="dark">
    <div style={mac}>
      <SettingsDialog
        appearance="dark"
        notifications
        dictation="hermes"
        appLock
        device="mac"
        onPick={noop}
        onDone={noop}
      />
    </div>
  </HermesProvider>
);
