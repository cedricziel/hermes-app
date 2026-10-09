import { AppLockDialog, HermesProvider } from "@hermes-app/ui";

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

/** iPhone: app lock on. */
export const IPhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <AppLockDialog enabled onChange={noop} onDone={noop} />
    </div>
  </HermesProvider>
);

/** No Face ID, Touch ID or passcode: the switch is greyed out and a note says what to set up. iPhone light and Material dark. */
export const Unavailable = () => (
  <div style={row}>
    <HermesProvider platform="apple">
      <div style={phone}>
        <AppLockDialog enabled={false} available={false} onDone={noop} />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={phone}>
        <AppLockDialog enabled={false} available={false} onDone={noop} />
      </div>
    </HermesProvider>
  </div>
);

/** Mac: the small toggle, off. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <AppLockDialog
        enabled={false}
        device="mac"
        onChange={noop}
        onDone={noop}
      />
    </div>
  </HermesProvider>
);

/** Material, light, on. */
export const Material = () => (
  <HermesProvider>
    <div style={phone}>
      <AppLockDialog enabled onChange={noop} onDone={noop} />
    </div>
  </HermesProvider>
);
