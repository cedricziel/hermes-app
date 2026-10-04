import { HermesProvider, McpSignInScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const url = "https://auth.example/authorize?state=s1";

export const AppleWaiting = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpSignInScreen server="grafana" authorizationUrl={url} />
    </div>
  </HermesProvider>
);

/** The browser did not open: the address with Copy. */
export const MaterialBrowserFailed = () => (
  <div style={phone}>
    <McpSignInScreen server="grafana" authorizationUrl={url} browserFailed />
  </div>
);

export const DesktopFailed = () => (
  <div style={{ ...phone, width: 800, height: 560 }}>
    <McpSignInScreen
      server="asana"
      phase="failed"
      failure="The provider denied access."
    />
  </div>
);

export const DarkExpired = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={phone}>
      <McpSignInScreen server="grafana" phase="expired" />
    </div>
  </HermesProvider>
);
