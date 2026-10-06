import { ConversationWindowScreen, HermesProvider } from "@hermes-app/ui";
import type { ChatTurn } from "@hermes-app/ui";

const frame = {
  width: 800,
  height: 560,
  border: "1px solid var(--h-border)",
  borderRadius: 10,
  overflow: "hidden",
} as const;

const turns: ChatTurn[] = [
  {
    role: "user",
    text: "Find flights from Berlin to Lisbon for the second week of November.",
  },
  {
    role: "assistant",
    prose: "I'll search the fares for 9 to 16 November.",
    toolCalls: [
      {
        name: "web_search",
        summary: "BER LIS flights 9-16 November",
        status: "completed",
        duration: "2.4s",
      },
    ],
    text: "The cheapest direct flights are with **TAP**:\n\n- Out on Sunday 9 November, 07:05, €84\n- Back on Sunday 16 November, 19:40, €97\n\nEasyJet is €20 cheaper in total but lands after midnight.",
  },
  { role: "user", text: "Book the TAP ones and find a hotel in Alfama." },
];

const finished: ChatTurn[] = [
  ...turns,
  {
    role: "assistant",
    text: "I can't book for you, but here are three hotels in Alfama under €140 a night:\n\n1. **Memmo Alfama**, rooftop pool, €132\n2. **Santiago de Alfama**, €128\n3. **Palácio Belmonte**, €139 on a weekday rate",
  },
];

const streaming: ChatTurn[] = [
  ...turns,
  {
    role: "assistant",
    text: "I can't book for you, but here are three hotels in Alfama under €140 a night:\n\n1. **Memmo Alfama**, rooftop pool,",
    streaming: true,
  },
];

const chat = {
  title: "Plan the Lisbon trip",
  profile: "work",
  model: { model: "hermes-4", effort: "Medium" },
};

/** The window with a finished chat: traffic lights, the title over "work · hermes-4", Show in Main Window, Pin, Share and "…", the 680px message column and the composer. */
export const Chat = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      <ConversationWindowScreen {...chat} turns={finished} />
    </div>
  </HermesProvider>
);

/** A pinned chat: the toolbar's Unpin button draws the filled pin and stays filled. */
export const Pinned = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      <ConversationWindowScreen {...chat} turns={finished} pinned />
    </div>
  </HermesProvider>
);

/** The "…" menu open under its button: Rename…, Copy Transcript, Archive, then Delete… ⌘⌫ in red. Pin has its own button, so the menu leaves it out. */
export const MoreMenu = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      <ConversationWindowScreen {...chat} turns={finished} menuOpen />
    </div>
  </HermesProvider>
);

/** A reply streaming in: no actions under it yet, and the send button is Stop. */
export const Streaming = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      <ConversationWindowScreen {...chat} turns={streaming} replying />
    </div>
  </HermesProvider>
);

/** The chat is being fetched: the activity indicator, the title the window was opened with over the profile (the model follows once the server's list arrives), and only Show in Main Window enabled. */
export const Loading = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      <ConversationWindowScreen {...chat} model={null} state="loading" />
    </div>
  </HermesProvider>
);

/** The chat could not be opened (deleted elsewhere, or the server failed). */
export const Failed = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      <ConversationWindowScreen {...chat} state="failed" />
    </div>
  </HermesProvider>
);

/** Dark, pinned, with the "…" menu open. */
export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    typeRamp="default"
    style={{ width: "fit-content" }}
  >
    <div style={frame}>
      <ConversationWindowScreen
        {...chat}
        turns={finished}
        pinned
        menuOpen
        composerValue="Which one is closest to the tram 28 stop?"
      />
    </div>
  </HermesProvider>
);
