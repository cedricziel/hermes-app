import { BotRow, HermesProvider } from "@hermes-app/ui";

const pane = { width: 480 } as const;

const bots = [
  {
    id: "telegram",
    name: "Telegram",
    description: "Run Hermes from Telegram.",
    enabled: true,
    configured: true,
  },
  {
    id: "discord",
    name: "Discord",
    description: "Chat with Hermes on a Discord server.",
    enabled: false,
    configured: true,
  },
  { id: "whatsapp", name: "WhatsApp", enabled: false, configured: false },
  {
    id: "slack",
    name: "Slack",
    enabled: true,
    configured: true,
    errorMessage: "Invalid bot token",
  },
];

export const Platforms = () => (
  <div style={pane}>
    {bots.map((b) => (
      <BotRow key={b.id} bot={b} />
    ))}
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390 }}>
    {bots.slice(0, 3).map((b) => (
      <BotRow key={b.id} bot={b} />
    ))}
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: "8px 0", borderRadius: 14 }}>
    <div style={pane}>
      {bots.map((b) => (
        <BotRow key={b.id} bot={b} />
      ))}
    </div>
  </HermesProvider>
);
