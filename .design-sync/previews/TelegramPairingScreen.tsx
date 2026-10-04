import { HermesProvider, TelegramPairingScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 520 } as const;
const noop = () => {};
const link = "https://t.me/hermes_setup_bot?start=pair_7f3a9c2e41";

export const AppleWaiting = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <TelegramPairingScreen phase="waiting" link={link} onBack={noop} />
    </div>
  </HermesProvider>
);

export const MaterialWaiting = () => (
  <div style={phone}>
    <TelegramPairingScreen phase="waiting" link={link} onBack={noop} />
  </div>
);

export const Claimed = () => (
  <div style={phone}>
    <TelegramPairingScreen
      phase="claimed"
      botUsername="hermes_work_bot"
      userIds="81234567"
      onBack={noop}
    />
  </div>
);

export const AppleMacClaimed = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <TelegramPairingScreen
        layout="desktop"
        phase="claimed"
        botUsername="hermes_work_bot"
        userIds="81234567, abc"
        userIdsError="Use numeric Telegram user IDs, separated by commas"
        onBack={noop}
      />
    </div>
  </HermesProvider>
);

export const Starting = () => (
  <div style={phone}>
    <TelegramPairingScreen phase="starting" onBack={noop} />
  </div>
);

export const Failed = () => (
  <div style={phone}>
    <TelegramPairingScreen
      phase="failed"
      error="Could not reach the Telegram setup. Check that the dashboard can reach the internet."
      onBack={noop}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <TelegramPairingScreen phase="waiting" link={link} onBack={noop} />
    </div>
  </HermesProvider>
);
