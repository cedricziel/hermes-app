import {
  GroupedSection,
  HermesProvider,
  MessagingPlatformRow,
} from "@hermes-app/ui";

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
    id: "signal",
    name: "Signal",
    description: "Talk to Hermes over Signal.",
    enabled: true,
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

const rows = platforms.map((b) => (
  <MessagingPlatformRow
    key={b.id}
    messagingPlatform={b}
    onClick={noop}
    onEnabledChange={noop}
  />
));

/** iPhone: switch rows, WhatsApp's "Set Up" value and chevron, Signal on without credentials ("Needs setup" warning), Slack's error. */
export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390, padding: 16 }}>
    <GroupedSection dividerIndent="tile">{rows}</GroupedSection>
  </HermesProvider>
);

/** Material: 56px rows, 32px tiles, the outlined "Set up" pill. */
export const Platforms = () => (
  <HermesProvider platform="material" style={{ width: 420, padding: 16 }}>
    <GroupedSection dividerIndent="tile">{rows}</GroupedSection>
  </HermesProvider>
);

/** Mac: 40px rows, 24px tiles, small switches and the bordered "Set Up…" button. */
export const Mac = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    style={{ width: 520, padding: 20 }}
  >
    <GroupedSection device="mac" dividerIndent="tile">
      {rows}
    </GroupedSection>
  </HermesProvider>
);

/** Dark: iPhone and Mac. */
export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    style={{ display: "flex", gap: 16, padding: 16, alignItems: "flex-start" }}
  >
    <div style={{ width: 360 }}>
      <GroupedSection dividerIndent="tile">{rows}</GroupedSection>
    </div>
    <HermesProvider theme="dark" typeRamp="default" style={{ width: 380 }}>
      <GroupedSection device="mac" dividerIndent="tile">
        {rows}
      </GroupedSection>
    </HermesProvider>
  </HermesProvider>
);
