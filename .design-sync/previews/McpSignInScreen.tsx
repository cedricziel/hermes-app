import { HermesProvider, McpSignInScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const url = "https://auth.example/authorize?state=s1";

/** iPhone: waiting for the approval in the browser. */
export const AppleWaiting = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpSignInScreen server="grafana" profile="work" authorizationUrl={url} />
    </div>
  </HermesProvider>
);

/** The browser did not open: the address with Copy. */
export const MaterialBrowserFailed = () => (
  <div style={phone}>
    <McpSignInScreen
      server="grafana"
      profile="work"
      authorizationUrl={url}
      browserFailed
    />
  </div>
);

/** Mac: the provider denied access. */
export const DesktopFailed = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    style={{ ...phone, width: 800, height: 560 }}
  >
    <McpSignInScreen
      layout="desktop"
      server="asana"
      profile="work"
      phase="failed"
      failure="The provider denied access."
    />
  </HermesProvider>
);

export const DarkExpired = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={phone}>
      <McpSignInScreen server="grafana" profile="work" phase="expired" />
    </div>
  </HermesProvider>
);
