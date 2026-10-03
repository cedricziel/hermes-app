import { HermesProvider, WelcomeView } from "@hermes-app/ui";
import type { StarterPromptItem } from "@hermes-app/ui";

const fromContext: StarterPromptItem[] = [
  {
    text: "Why did the scheduled job 'Nightly backup' fail on its last run?",
    source: "schedule",
  },
  {
    text: "What's blocking the Kanban task 'Rotate the staging certificates'?",
    source: "kanban",
  },
  { text: "Pick up 'Backup failure'", source: "chat" },
  { text: "Use the release-notes skill to ", source: "skill" },
];

const box = { width: 800, height: 420, border: "1px solid var(--h-border)" };

export const FromContext = () => (
  <div style={box}>
    <WelcomeView prompts={fromContext} />
  </div>
);

export const GenericWithName = () => (
  <div style={box}>
    <WelcomeView greetingName="Ada" />
  </div>
);

export const Phone = () => (
  <div style={{ width: 390, height: 620, border: "1px solid var(--h-border)" }}>
    <WelcomeView prompts={fromContext} />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={box}>
      <WelcomeView prompts={fromContext} />
    </div>
  </HermesProvider>
);
