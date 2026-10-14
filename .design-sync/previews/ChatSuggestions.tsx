import { ChatSuggestions, HermesProvider } from "@hermes-app/ui";

const frame = {
  width: 390,
  padding: "12px 0",
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  background: "var(--h-bg)",
} as const;
const macFrame = { ...frame, width: 560 } as const;
const row = { display: "flex", gap: 16, alignItems: "flex-start" } as const;
const noop = () => {};

const teammates = [
  { title: "@research", description: "Finds sources and pulls the numbers" },
  { title: "@writer", description: "Drafts summaries and release notes" },
  { title: "@ops", description: "Runs deploys and checks the servers" },
];
const commands = [
  { title: "/model", description: "Switch the model for this chat" },
  { title: "/reasoning", description: "Set the reasoning effort" },
  { title: "/compress", description: "Summarize the history to save context" },
  { title: "/goal", description: "Keep working toward a goal across turns" },
  { title: "/stop", description: "Stop the running reply" },
];

/** Typing `@` in a group chat: the teammates above the composer, the highlighted one picked by Enter. */
export const Teammates = () => (
  <div style={row}>
    <HermesProvider platform="apple">
      <div style={frame}>
        <ChatSuggestions header="Teammates" items={teammates} selectedIndex={0} onChoose={noop} />
      </div>
    </HermesProvider>
    <HermesProvider>
      <div style={frame}>
        <ChatSuggestions header="Teammates" items={teammates} selectedIndex={1} onChoose={noop} />
      </div>
    </HermesProvider>
  </div>
);

/** Typing `/` on the Mac: slash commands in a scrolling panel capped at 180px, arrow keys moving the highlight. */
export const Commands = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={macFrame}>
      <ChatSuggestions header="Commands" items={commands} selectedIndex={3} maxHeight={180} device="mac" onChoose={noop} />
    </div>
  </HermesProvider>
);

/** Dark, commands. */
export const Dark = () => (
  <HermesProvider platform="apple" theme="dark">
    <div style={frame}>
      <ChatSuggestions header="Commands" items={commands.slice(0, 3)} selectedIndex={0} onChoose={noop} />
    </div>
  </HermesProvider>
);
