import { AboutDialog, HermesProvider } from "@hermes-app/ui";

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

/** iPhone, dark and light: Version as a muted value, Report a bug with a chevron. */
export const IPhone = () => (
  <div style={row}>
    <HermesProvider platform="apple" theme="dark">
      <div style={phone}>
        <AboutDialog version="0.1.55" onReportBug={noop} onDone={noop} />
      </div>
    </HermesProvider>
    <HermesProvider platform="apple">
      <div style={phone}>
        <AboutDialog version="0.1.55" onReportBug={noop} onDone={noop} />
      </div>
    </HermesProvider>
  </div>
);

/** Mac: 13px bold title with Done, compact rows. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <AboutDialog
        version="0.1.55"
        device="mac"
        onReportBug={noop}
        onDone={noop}
      />
    </div>
  </HermesProvider>
);

/** Material: the title at the start, no Done; the version could not be read. */
export const Material = () => (
  <HermesProvider>
    <div style={phone}>
      <AboutDialog version="Unavailable" onReportBug={noop} onDone={noop} />
    </div>
  </HermesProvider>
);
