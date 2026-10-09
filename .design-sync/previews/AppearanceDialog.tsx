import { AppearanceDialog, HermesProvider } from "@hermes-app/ui";

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
const column = { ...row, flexDirection: "column" } as const;
const noop = () => {};

/** iPhone: Follow system checked with the trailing blue check; under it the Mac: the compact rows and Done in a 44px bar. */
export const Apple = () => (
  <div style={column}>
    <HermesProvider platform="apple">
      <div style={phone}>
        <AppearanceDialog mode="system" onChange={noop} onDone={noop} />
      </div>
    </HermesProvider>
    <HermesProvider platform="apple" typeRamp="default">
      <div style={{ ...mac, width: 520 }}>
        <AppearanceDialog
          mode="light"
          device="mac"
          onChange={noop}
          onDone={noop}
        />
      </div>
    </HermesProvider>
  </div>
);

/** Material: leading radios, the title at the start, no Done; light and dark. */
export const Material = () => (
  <div style={row}>
    <HermesProvider>
      <div style={phone}>
        <AppearanceDialog mode="system" onChange={noop} onDone={noop} />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={phone}>
        <AppearanceDialog mode="dark" onChange={noop} onDone={noop} />
      </div>
    </HermesProvider>
  </div>
);

/** iPhone, dark, Dark picked. */
export const Dark = () => (
  <HermesProvider platform="apple" theme="dark">
    <div style={phone}>
      <AppearanceDialog mode="dark" onChange={noop} onDone={noop} />
    </div>
  </HermesProvider>
);
