import { AppLockScreen, HermesProvider } from "@hermes-app/ui";

const phone = {
  width: 300,
  height: 480,
  border: "1px solid var(--h-border)",
} as const;

/** Locked: Material (left) and Apple (right, the CupertinoIcons lock). */
export const Locked = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={phone}>
      <AppLockScreen />
    </div>
    <HermesProvider platform="apple">
      <div style={phone}>
        <AppLockScreen />
      </div>
    </HermesProvider>
  </div>
);

/** Before the lock setting is read: only the lock. */
export const Loading = () => (
  <div style={phone}>
    <AppLockScreen loaded={false} />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={phone}>
      <AppLockScreen />
    </div>
  </HermesProvider>
);
