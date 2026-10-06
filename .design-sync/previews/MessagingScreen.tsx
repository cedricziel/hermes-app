import { MessagingScreen, HermesProvider } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 480 } as const;
const noop = () => {};

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

export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <MessagingScreen platforms={platforms} onBack={noop} />
    </div>
  </HermesProvider>
);

export const MaterialPhone = () => (
  <div style={phone}>
    <MessagingScreen platforms={platforms} onBack={noop} />
  </div>
);

export const MaterialDesktop = () => (
  <div style={desktop}>
    <MessagingScreen layout="desktop" platforms={platforms} onBack={noop} />
  </div>
);

export const Loading = () => (
  <div style={phone}>
    <MessagingScreen state="loading" onBack={noop} />
  </div>
);

export const Failed = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <MessagingScreen state="failed" onBack={noop} />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <MessagingScreen platforms={platforms} onBack={noop} />
    </div>
  </HermesProvider>
);
