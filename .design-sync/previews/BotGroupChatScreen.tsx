import {
  BotGroupChatScreen,
  HermesProvider,
  type BotGroupEvent,
} from "@hermes-app/ui";

const events: BotGroupEvent[] = [
  {
    id: "1",
    author: "You",
    text: "@research collect the launch numbers",
  },
  {
    id: "2",
    author: "Research",
    text: "Here are the numbers from last quarter.",
    thread: "Topic 1",
  },
  { id: "3", author: "Analyst", activity: "Started work" },
];
const room = { name: "Launch plan", memberCount: 3, events, working: true };

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const row = { display: "flex", gap: 16, alignItems: "flex-start" } as const;

/** iPhone: "‹ Bots", the name over "3 members", "…"; a member is working, so the status card shows the limitation and Stop. */
export const IPhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <BotGroupChatScreen {...room} />
    </div>
  </HermesProvider>
);

/** Mac: the toolbar with the back button and "…", the transcript in a centred column, a draft ready to send. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <BotGroupChatScreen
        {...room}
        layout="desktop"
        draft="@writer turn this into a summary"
      />
    </div>
  </HermesProvider>
);

/** Material: the back arrow and the name at the start; dark with the room menu open (Rename, Disband). */
export const Material = () => (
  <div style={row}>
    <HermesProvider>
      <div style={phone}>
        <BotGroupChatScreen {...room} blocked working={false} />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={phone}>
        <BotGroupChatScreen {...room} menuOpen />
      </div>
    </HermesProvider>
  </div>
);

/** The room was disbanded (iPhone dark), and an idle room replying in a thread (Material). */
export const States = () => (
  <div style={row}>
    <HermesProvider platform="apple" theme="dark">
      <div style={phone}>
        <BotGroupChatScreen
          name="Weekly review"
          memberCount={2}
          state="disbanded"
        />
      </div>
    </HermesProvider>
    <HermesProvider>
      <div style={phone}>
        <BotGroupChatScreen
          name="Weekly review"
          memberCount={2}
          events={events.slice(0, 2)}
          discussionLabel="Reply in Topic 1"
        />
      </div>
    </HermesProvider>
  </div>
);
