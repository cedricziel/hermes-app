import { HermesProvider, ListRow, SudoPasswordPrompt } from "@hermes-app/ui";

const frame = {
  position: "relative",
  width: 800,
  height: 360,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;

const phone = { ...frame, width: 390, height: 520 } as const;

const behind = (
  <div style={{ padding: 16 }}>
    <ListRow title="Plan the Lisbon trip" subtitle="Yesterday" />
    <ListRow title="Why did the nightly backup fail?" subtitle="Today" />
    <ListRow title="Fix the flaky login test" subtitle="Friday" />
  </div>
);

/** Mac: the question over a screen the user moved on to after starting the install. Install stays disabled until something is typed. */
export const AppleEmpty = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      {behind}
      <SudoPasswordPrompt host="hermes.example.com" />
    </div>
  </HermesProvider>
);

/** iPhone: the typed password stays masked; Install is the bold default. */
export const ApplePhoneTyped = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      {behind}
      <SudoPasswordPrompt
        host="hermes.example.com"
        defaultValue="correct horse battery"
      />
    </div>
  </HermesProvider>
);

/** Material: an M3 dialog with an outlined password field. */
export const MaterialTyped = () => (
  <HermesProvider>
    <div style={frame}>
      {behind}
      <SudoPasswordPrompt
        host="hermes.example.com"
        defaultValue="correct horse battery"
      />
    </div>
  </HermesProvider>
);

/** Dark theme on Material. */
export const MaterialDark = () => (
  <HermesProvider theme="dark">
    <div style={frame}>
      {behind}
      <SudoPasswordPrompt host="hermes.example.com" />
    </div>
  </HermesProvider>
);
