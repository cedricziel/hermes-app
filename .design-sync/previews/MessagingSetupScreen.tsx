import { MessagingSetupScreen, HermesProvider } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 520 } as const;
const noop = () => {};

const discord = { id: "discord", name: "Discord" };
const discordVars = [
  {
    key: "DISCORD_BOT_TOKEN",
    label: "Discord bot token",
    required: true,
    password: true,
    help: "Create it in the developer portal",
  },
  {
    key: "DISCORD_ALLOWED_USERS",
    label: "Allowed Discord users",
    isSet: true,
    redactedValue: "1234...9999",
  },
  {
    key: "DISCORD_HOME_CHANNEL",
    label: "Home channel",
    help: "Where Hermes posts scheduled job results",
    advanced: true,
  },
];

const telegram = { id: "telegram", name: "Telegram" };
const telegramVars = [
  {
    key: "TELEGRAM_BOT_TOKEN",
    label: "Telegram bot token",
    required: true,
    password: true,
    isSet: true,
    redactedValue: "8123...xQ4",
  },
  {
    key: "TELEGRAM_ALLOWED_USERS",
    label: "Allowed Telegram users",
    help: "Comma-separated numeric user IDs",
  },
];

export const AppleTelegram = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <MessagingSetupScreen
        messagingPlatform={telegram}
        envVars={telegramVars}
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const MaterialDiscord = () => (
  <div style={phone}>
    <MessagingSetupScreen
      messagingPlatform={discord}
      envVars={discordVars}
      values={{ DISCORD_BOT_TOKEN: "MTEx.Gk2.secret" }}
      advancedOpen
      onBack={noop}
    />
  </div>
);

export const ValidationAndClear = () => (
  <div style={phone}>
    <MessagingSetupScreen
      messagingPlatform={discord}
      envVars={discordVars}
      cleared={["DISCORD_ALLOWED_USERS"]}
      fieldErrors={{ DISCORD_BOT_TOKEN: "Required" }}
      error="Could not save the setup: the dashboard refused the token."
      onBack={noop}
    />
  </div>
);

export const AppleMacSaving = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <MessagingSetupScreen
        layout="desktop"
        messagingPlatform={discord}
        envVars={discordVars}
        values={{ DISCORD_BOT_TOKEN: "MTEx.Gk2.secret" }}
        saving
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const NothingToSetUp = () => (
  <div style={phone}>
    <MessagingSetupScreen
      messagingPlatform={{ id: "api", name: "API server" }}
      onBack={noop}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <MessagingSetupScreen
        messagingPlatform={telegram}
        envVars={telegramVars}
        onBack={noop}
      />
    </div>
  </HermesProvider>
);
