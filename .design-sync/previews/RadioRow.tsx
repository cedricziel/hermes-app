import { HermesProvider, RadioRow, Tag } from "@hermes-app/ui";

const pane = { width: 440 } as const;

const needs = (
  <div className="h-body-md" style={{ color: "var(--h-muted)" }}>
    What it needs: <span className="h-mono">HONCHO_API_KEY</span>
  </div>
);

/** The Providers tab's memory choices: picked, ready, and one that needs setup on the server. */
export const MemoryProviders = () => (
  <div style={pane}>
    <RadioRow title="Built-in" subtitle="No external memory" />
    <RadioRow
      title="mem0"
      titleTrailing={<Tag variant="filled">Ready</Tag>}
      subtitle="Long-term memory with automatic fact extraction and search."
      selected
    />
    <RadioRow
      title="honcho"
      titleTrailing={<Tag>Needs setup</Tag>}
      subtitle="Theory-of-mind user modelling from Plastic Labs."
      disabled
    >
      {needs}
    </RadioRow>
  </div>
);

/** A plain group without tags: the context engines. */
export const ContextEngines = () => (
  <div style={pane}>
    <RadioRow
      title="compressor"
      subtitle="Summarises older turns when the context fills up."
      selected
    />
    <RadioRow
      title="lcm"
      subtitle="Lossless context management: keeps every turn retrievable."
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <RadioRow title="Built-in" subtitle="No external memory" selected />
      <RadioRow
        title="honcho"
        titleTrailing={<Tag>Unavailable</Tag>}
        subtitle="Theory-of-mind user modelling from Plastic Labs."
        disabled
      />
    </div>
  </HermesProvider>
);
