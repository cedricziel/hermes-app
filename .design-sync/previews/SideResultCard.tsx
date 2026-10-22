import { SideResultCard, HermesProvider } from "@hermes-app/ui";

const col = { width: 420, display: "flex", flexDirection: "column" } as const;

/** Both kinds collapsed: the title alone. */
export const Compact = () => (
  <div style={col}>
    <SideResultCard
      result={{
        kind: "background",
        text: "Nightly backup finished: 3 snapshots pruned, 14.2 GiB freed.",
      }}
    />
    <SideResultCard
      result={{
        kind: "btw",
        question: "What changed?",
        text: "Only the retention policy: keep-daily went from 7 to 14.",
      }}
    />
  </div>
);

/** Opened: the question (side questions only), then the reported text. */
export const Expanded = () => (
  <div style={col}>
    <SideResultCard
      defaultOpen
      result={{
        kind: "btw",
        question: "What changed?",
        text: "Only the retention policy: keep-daily went from 7 to 14.",
      }}
    />
    <SideResultCard
      defaultOpen
      result={{
        kind: "background",
        text: "Nightly backup finished: 3 snapshots pruned, 14.2 GiB freed.",
      }}
    />
  </div>
);

/** A result with no text reports so, and a missing result draws a plain line. */
export const EmptyAndUnavailable = () => (
  <div style={col}>
    <SideResultCard defaultOpen result={{ kind: "background", text: "" }} />
    <SideResultCard result={null} />
  </div>
);

/** Long output scrolls inside a 240px box. */
export const LongResult = () => (
  <div style={col}>
    <SideResultCard
      defaultOpen
      result={{
        kind: "btw",
        text: Array.from(
          { length: 30 },
          () => "Reported side output wraps and scrolls on narrow windows.",
        ).join("\n"),
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", padding: 16, borderRadius: 14 }}
  >
    <div style={{ ...col, padding: 8 }}>
      <SideResultCard
        defaultOpen
        result={{
          kind: "btw",
          question: "What changed?",
          text: "Only the retention policy: keep-daily went from 7 to 14.",
        }}
      />
    </div>
  </HermesProvider>
);
