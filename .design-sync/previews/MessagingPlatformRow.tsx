import { MessagingPlatformRow, HermesProvider } from "@hermes-app/ui";

const pane = { width: 480 } as const;

const platforms = [
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
    {platforms.map((b) => (
      <MessagingPlatformRow key={b.id} messagingPlatform={b} />
    ))}
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390 }}>
    {platforms.slice(0, 3).map((b) => (
      <MessagingPlatformRow key={b.id} messagingPlatform={b} />
    ))}
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: "8px 0", borderRadius: 14 }}>
    <div style={pane}>
      {platforms.map((b) => (
        <MessagingPlatformRow key={b.id} messagingPlatform={b} />
      ))}
    </div>
  </HermesProvider>
);
