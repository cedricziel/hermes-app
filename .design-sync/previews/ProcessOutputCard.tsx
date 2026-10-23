import { HermesProvider, ProcessOutputCard } from "@hermes-app/ui";

const col = { width: 640 } as const;

export const Compact = () => (
  <div style={col}>
    <ProcessOutputCard processId="worker" text="Received output" />
  </div>
);

export const Expanded = () => (
  <div style={col}>
    <ProcessOutputCard
      processId="worker"
      text={"Line one\nLine two"}
      defaultOpen
    />
  </div>
);

export const ClosedBeforeOutput = () => (
  <div style={col}>
    <ProcessOutputCard processId="worker" closed defaultOpen />
  </div>
);

/** Long output scrolls inside a 180px box, with both omission notes under it. */
export const OmittedOutput = () => (
  <div style={col}>
    <ProcessOutputCard
      processId="build-1"
      text={Array.from(
        { length: 40 },
        (_, i) => `[${String(i + 1).padStart(2, "0")}] Received output line`,
      ).join("\n")}
      omitted
      omittedCards
      defaultOpen
    />
  </div>
);

export const Unavailable = () => (
  <div style={col}>
    <ProcessOutputCard processId="worker" unavailable />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 640 }}
  >
    <ProcessOutputCard
      processId="worker"
      text={"Line one\nLine two"}
      closed
      defaultOpen
    />
  </HermesProvider>
);
