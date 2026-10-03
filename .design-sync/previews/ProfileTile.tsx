import { HermesProvider, ProfileTile } from "@hermes-app/ui";

const pane = { width: 600 } as const;
const noop = () => {};

export const Profiles = () => (
  <div style={pane}>
    <ProfileTile
      active
      onChangeModel={noop}
      profile={{ name: "default", model: "hermes-4", skillCount: 58 }}
    />
    <ProfileTile
      onChangeModel={noop}
      profile={{
        name: "work",
        displayName: "Work assistant",
        description: "Day job: tickets, reviews and the on-call rota",
        skillCount: 12,
      }}
    />
  </div>
);

export const NoModel = () => (
  <div style={pane}>
    <ProfileTile profile={{ name: "scratch", skillCount: 0 }} />
  </div>
);

export const LongText = () => (
  <div style={{ width: 380 }}>
    <ProfileTile
      active
      onChangeModel={noop}
      profile={{
        name: "research",
        displayName: "Long-running research assistant for papers",
        description: "Reads papers, keeps notes and writes summaries",
        model: "meta-llama/llama-4-maverick-17b-128e-instruct-long-context",
        skillCount: 31,
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <ProfileTile
        active
        onChangeModel={noop}
        profile={{ name: "default", model: "hermes-4", skillCount: 58 }}
      />
      <ProfileTile
        onChangeModel={noop}
        profile={{
          name: "work",
          displayName: "Work assistant",
          description: "Day job",
          model: "openai/gpt-5.1",
          skillCount: 12,
        }}
      />
    </div>
  </HermesProvider>
);

/** iOS (left): a compact row with a trailing checkmark and no tune button. Mac (right) keeps the Material tile. */
export const AppleRows = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 20 }}>
    <div style={{ width: 390, border: "1px solid var(--h-border)" }}>
      <ProfileTile
        layout="phone"
        active
        profile={{ name: "default", model: "hermes-4", skillCount: 58 }}
      />
      <ProfileTile
        layout="phone"
        profile={{
          name: "work",
          displayName: "Work assistant",
          description: "Day job: tickets and reviews",
          skillCount: 12,
        }}
      />
    </div>
    <div style={{ width: 390, border: "1px solid var(--h-border)" }}>
      <ProfileTile
        active
        onChangeModel={noop}
        profile={{ name: "default", model: "hermes-4", skillCount: 58 }}
      />
    </div>
  </HermesProvider>
);
