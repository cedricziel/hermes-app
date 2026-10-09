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
  {
    id: "whatsapp",
    name: "WhatsApp",
    description: "Message Hermes on WhatsApp.",
    enabled: false,
    configured: false,
  },
  {
    id: "slack",
    name: "Slack",
    description: "Bring Hermes into a Slack workspace.",
    enabled: true,
    configured: true,
    errorMessage: "Invalid bot token",
  },
];

/** iPhone: "Chat" back chevron, the platforms in one inset group with bot tiles, WhatsApp's "Set Up" value and chevron, Slack's error line, the introduction as the group's footer. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <MessagingScreen platforms={platforms} onBack={noop} />
  </HermesProvider>
);

/** Material phone: 56px bar, the Material group with 32px tiles and WhatsApp's outlined "Set up" pill. */
export const MaterialPhone = () => (
  <HermesProvider platform="material" style={phone}>
    <MessagingScreen platforms={platforms} onBack={noop} />
  </HermesProvider>
);

/** Mac window: the toolbar with "Messaging" over "2 of 4 on", the 600px column, small switches and a bordered "Set Up…" button. */
export const MacDesktop = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <MessagingScreen layout="desktop" platforms={platforms} onBack={noop} />
  </HermesProvider>
);

/** Loading: the spinner under the Material bar. */
export const Loading = () => (
  <HermesProvider platform="material" style={phone}>
    <MessagingScreen state="loading" onBack={noop} />
  </HermesProvider>
);

/** Failed on iPhone: "Could not load messaging platforms" with Retry. */
export const Failed = () => (
  <HermesProvider platform="apple" style={phone}>
    <MessagingScreen state="failed" onBack={noop} />
  </HermesProvider>
);

/** Dark: iPhone and Material phone. */
export const Dark = () => (
  <div style={{ display: "flex", gap: 12 }}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider key={platform} theme="dark" platform={platform} style={phone}>
        <MessagingScreen platforms={platforms} onBack={noop} />
      </HermesProvider>
    ))}
  </div>
);
