import { BotScreenCard, HermesProvider } from "@hermes-app/ui";

const column = { width: 380 } as const;

const command = "sudo apt-get install -y tigervnc-standalone-server xfce4";

const lines = [
  "Reading package lists...",
  "Building dependency tree...",
  "The following NEW packages will be installed:",
  "Unpacking tigervnc-standalone-server (1.12.0+dfsg-9) ...",
  "Setting up xfce4-session (4.18.1-1) ...",
];

/** The gateway host without the desktop: the command to run by hand and Install on Server, which has Hermes run it. */
export const NotInstalledInstallOnServer = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard
        state="not_installed"
        command={command}
        canInstall
        onCopyCommand={() => {}}
        onInstall={() => {}}
      />
    </div>
  </HermesProvider>
);

/** While the install runs: the package manager's latest lines, a spinner and that it keeps going if the card is closed. */
export const Installing = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard state="installing" installLines={lines} />
    </div>
  </HermesProvider>
);

/** `display.install` was refused, with the server's own words. */
export const InstallCouldNotStart = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard
        state="not_installed"
        command={command}
        canInstall
        installResult="refused"
        installMessage="an install is already running for this profile"
        onInstall={() => {}}
      />
    </div>
  </HermesProvider>
);

/** The user cancelled the sudo password question. */
export const InstallCancelled = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard
        state="not_installed"
        command={command}
        canInstall
        installResult="cancelled"
        onInstall={() => {}}
      />
    </div>
  </HermesProvider>
);

/** The server has no sudo: the command to run there by hand, without sudo, and no Install on Server. */
export const InstallNoSudo = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard
        state="not_installed"
        command="apt-get install -y tigervnc-standalone-server xfce4"
        installResult="no_sudo"
        onCopyCommand={() => {}}
      />
    </div>
  </HermesProvider>
);

/** The package manager failed: its last lines, and Install on Server again. */
export const InstallFailed = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard
        state="not_installed"
        command={command}
        canInstall
        installResult="failed"
        installLines={[
          "E: Unable to locate package tigervnc-standalone-server",
          "E: Package xfce4 has no installation candidate",
        ]}
        onInstall={() => {}}
      />
    </div>
  </HermesProvider>
);

/** No done broadcast within 20 minutes and the status does not say installed. */
export const InstallMayStillRun = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard
        state="not_installed"
        command={command}
        canInstall
        installResult="may_still_run"
        onInstall={() => {}}
      />
    </div>
  </HermesProvider>
);

/** A person holds the lease under a viewer id this app does not hold (another device, or this one before the app restarted): Hand back to Hermes, which the app asks to confirm first. */
export const SomeoneInControlHandBackToHermes = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard state="controlled" canForce onForceHandBack={() => {}} />
    </div>
  </HermesProvider>
);

/** This device holds the lease, so the card says so and offers nothing to force. */
export const YouInControl = () => (
  <HermesProvider>
    <div style={column}>
      <BotScreenCard state="controlled" byYou />
    </div>
  </HermesProvider>
);
