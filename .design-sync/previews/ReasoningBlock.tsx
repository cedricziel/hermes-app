import { HermesProvider, ReasoningBlock } from "@hermes-app/ui";

const reasoning =
  "The user wants the build folder gone. It is generated output, so deleting it is safe, but I should ask before running rm.";

export const Folded = () => <ReasoningBlock text={reasoning} />;

export const Open = () => (
  <div style={{ width: 640 }}>
    <ReasoningBlock text={reasoning} defaultOpen />
  </div>
);

export const ThinkingOpen = () => (
  <div style={{ width: 640 }}>
    <ReasoningBlock
      text="The retries all failed with the same x509 error, so the pin never changed."
      active
      defaultOpen
    />
  </div>
);

/** Apple: the toggle is 44px tall. */
export const ApplePlatform = () => (
  <HermesProvider platform="apple" style={{ width: 640 }}>
    <ReasoningBlock text={reasoning} defaultOpen />
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 640 }}
  >
    <ReasoningBlock text={reasoning} defaultOpen />
  </HermesProvider>
);
