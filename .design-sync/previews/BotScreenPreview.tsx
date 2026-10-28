import { BotScreenPreview, ToolCallCard, ToolCallGroup } from "@hermes-app/ui";

const box = { width: 480 } as const;

// An invented desktop: a wallpaper, one window and a panel.
const desktop =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="192" height="120" viewBox="0 0 192 120">
      <rect width="192" height="120" fill="#2a4a6a"/>
      <rect x="28" y="14" width="136" height="12" fill="#4a4e69"/>
      <rect x="28" y="26" width="136" height="70" fill="#f2e9e4"/>
      <rect x="36" y="46" width="96" height="2" fill="#9a8c98"/>
      <rect x="36" y="66" width="96" height="2" fill="#9a8c98"/>
      <rect y="110" width="192" height="10" fill="#2b2d42"/>
    </svg>`,
  );

export const HermesInControl = () => (
  <div style={box}>
    <BotScreenPreview frameSrc={desktop} onOpen={() => {}} />
  </div>
);

export const PortraitScreen = () => (
  <div style={box}>
    <BotScreenPreview frameSrc={desktop} aspectRatio={3 / 4} />
  </div>
);

export const WaitingForTheFirstPicture = () => (
  <div style={box}>
    <BotScreenPreview onOpen={() => {}} />
  </div>
);

export const SomeoneElseInControl = () => (
  <div style={box}>
    <BotScreenPreview state="controlled" onOpen={() => {}} />
  </div>
);

export const YouInControl = () => (
  <div style={box}>
    <BotScreenPreview state="controlled" byYou />
  </div>
);

/** In the slot of a single running call's card. */
export const InAToolCallCard = () => (
  <div style={box}>
    <ToolCallCard
      name="computer_use"
      summary="click (640, 400)"
      status="running"
      preview={<BotScreenPreview frameSrc={desktop} onOpen={() => {}} />}
    />
  </div>
);

/** Under the line of a folded group, so it stays in view while folded. */
export const InAFoldedGroup = () => (
  <div style={box}>
    <ToolCallGroup
      calls={[
        { name: "computer_use", summary: "screenshot", duration: "0.4s" },
        {
          name: "computer_use",
          summary: "click (640, 400)",
          status: "running",
        },
      ]}
      preview={<BotScreenPreview frameSrc={desktop} onOpen={() => {}} />}
    />
  </div>
);
