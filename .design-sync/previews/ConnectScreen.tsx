import { ConnectScreen, HermesProvider } from "@hermes-app/ui";

const phone = {
  width: 360,
  height: 600,
  border: "1px solid rgba(0,0,0,0.12)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

export const ServerAddress = () => (
  <div style={phone}>
    <ConnectScreen step="server" serverUrl="http://" />
  </div>
);

export const Unreachable = () => (
  <div style={phone}>
    <ConnectScreen
      step="server"
      serverUrl="http://hermes.tail3c2a.ts.net:9119"
      error="Could not reach http://hermes.tail3c2a.ts.net:9119"
      vpnHint="No VPN is active on this device. If the server is behind one, connect to it and try again."
    />
  </div>
);

export const SignIn = () => (
  <div style={phone}>
    <ConnectScreen
      step="signin"
      serverUrl="http://192.168.1.20:9119"
      providers={[
        { id: "sso", displayName: "Company SSO" },
        { id: "basic", displayName: "Hermes", password: true },
      ]}
    />
  </div>
);

export const WaitingForBrowser = () => (
  <div style={phone}>
    <ConnectScreen
      step="signin"
      serverUrl="http://192.168.1.20:9119"
      waitingForBrowser
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...phone, border: "1px solid rgba(255,255,255,0.12)" }}>
      <ConnectScreen
        step="server"
        serverUrl="http://192.168.1.20:9119"
        connecting
      />
    </div>
  </HermesProvider>
);
