import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { TextField } from "../TextField/TextField";
import { cx, usePlatform, type Platform } from "../../platform";
import "./ConnectScreen.css";

/** A sign-in method the server offers, as listed by `/api/auth/providers`. */
export interface SignInProvider {
  /** Stable id of the provider. */
  id: string;
  /** Name shown on the button: "Sign in with <displayName>". */
  displayName: string;
  /** Hermes' own username and password form; labelled "Sign in with username & password" with a key icon. */
  password?: boolean;
}

export interface ConnectScreenProps {
  /**
   * `server`: the first-run "Connect to Hermes" form that asks for the
   * dashboard URL. `signin`: the "Sign in" screen for that server, with one
   * button per sign-in provider.
   */
  step: "server" | "signin";
  /** The dashboard address: the field's value on `server`, the caption under the lock on `signin`. */
  serverUrl?: string;
  /** Called as the URL field is edited (`server` step). */
  onServerUrlChange?: (url: string) => void;
  /** Connect pressed or Enter in the URL field (`server` step). */
  onConnect?: () => void;
  /** Connecting to the server: Connect shows a spinner and is disabled (`server` step). */
  connecting?: boolean;
  /** Red error line under the field (`server`) or under the providers (`signin`), e.g. "Could not reach http://10.0.0.5:9119". */
  error?: string;
  /**
   * Muted hint under the error for a private or tailnet address, e.g.
   * "Is your VPN connected?" or "No VPN is active on this device. If the
   * server is behind one, connect to it and try again." (`server` step).
   */
  vpnHint?: string;
  /** Sign-in methods the server offers (`signin` step). Empty shows "No sign-in providers are registered on this server." */
  providers?: SignInProvider[];
  /** A provider button was pressed (`signin` step). */
  onSignIn?: (provider: SignInProvider) => void;
  /** The browser sign-in is open: a spinner, "Continue in your browser…" and Cancel replace the buttons (`signin` step). */
  waitingForBrowser?: boolean;
  /** Cancel pressed while waiting for the browser. */
  onCancel?: () => void;
  /** The server is too old for app sign-in; shows the update notice instead of providers (`signin` step). */
  lacksAppSignIn?: boolean;
  /** The app bar's server button: go back to the address form (`signin` step). */
  onChangeServer?: () => void;
  /** "Read the VPN setup guide" link (`server` step). */
  onOpenVpnGuide?: () => void;
  /** "Report a bug" link at the bottom of both steps. */
  onReportBug?: () => void;
  /** `apple`: the sign-in bar is 44px tall (56px on `material`), the iOS navigation bar height. Inherits the provider's platform. */
  platform?: Platform;
}

function Spinner({ size, stroke }: { size: number; stroke: number }) {
  return (
    <span
      className="h-connect-screen__spinner"
      style={{ width: size, height: size, borderWidth: stroke }}
      role="progressbar"
      aria-label="Loading"
    />
  );
}

/**
 * The pre-sign-in screens: the "Connect to Hermes" address form shown on first
 * run, and the "Sign in" screen with the server's providers. Fills its parent
 * and centers a 420px-wide column, as on phone and desktop.
 */
export function ConnectScreen({
  step,
  serverUrl = "http://",
  onServerUrlChange,
  onConnect,
  connecting = false,
  error,
  vpnHint,
  providers = [],
  onSignIn,
  waitingForBrowser = false,
  onCancel,
  lacksAppSignIn = false,
  onChangeServer,
  onOpenVpnGuide,
  onReportBug,
  platform,
}: ConnectScreenProps) {
  const apple = usePlatform(platform) === "apple";
  const reportBug = (
    <Button variant="text" onClick={onReportBug}>
      Report a bug
    </Button>
  );

  if (step === "server") {
    return (
      <div className="h-connect-screen">
        <div className="h-connect-screen__center">
          <form
            className="h-connect-screen__column"
            onSubmit={(e) => {
              e.preventDefault();
              if (!connecting) onConnect?.();
            }}
          >
            <Icon
              name="hub"
              size={56}
              className="h-connect-screen__hero-icon"
            />
            <h1 className="h-connect-screen__headline">Connect to Hermes</h1>
            <p className="h-connect-screen__body">
              Enter the address of your hermes dashboard.
            </p>
            <p className="h-connect-screen__small">
              Behind Tailscale or WireGuard? Enter its VPN address, or run
              tailscale serve on the server for an https:// address.
            </p>
            <Button variant="text" onClick={onOpenVpnGuide}>
              Read the VPN setup guide
            </Button>
            <TextField
              className="h-connect-screen__field"
              label="Dashboard URL"
              placeholder="http://192.168.1.20:9119"
              inputMode="url"
              value={serverUrl}
              onChange={(e) => onServerUrlChange?.(e.target.value)}
            />
            {error ? (
              <>
                <p className="h-connect-screen__error">{error}</p>
                {vpnHint ? (
                  <p className="h-connect-screen__small h-connect-screen__hint">
                    {vpnHint}
                  </p>
                ) : null}
              </>
            ) : null}
            <Button
              type="submit"
              fullWidth
              disabled={connecting}
              className="h-connect-screen__primary"
            >
              {connecting ? <Spinner size={20} stroke={2} /> : "Connect"}
            </Button>
            {reportBug}
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="h-connect-screen">
      <header
        className={cx(
          "h-connect-screen__bar",
          apple && "h-connect-screen__bar--apple",
        )}
      >
        <span className="h-connect-screen__bar-title">Sign in</span>
        <IconButton
          icon="dns"
          label="Change server"
          onClick={onChangeServer}
          disabled={waitingForBrowser}
        />
      </header>
      <div className="h-connect-screen__center">
        <div className="h-connect-screen__column">
          <Icon name="lock" size={48} className="h-connect-screen__lock" />
          <p className="h-connect-screen__small h-connect-screen__url">
            {serverUrl}
          </p>
          {waitingForBrowser ? (
            <div className="h-connect-screen__waiting">
              <Spinner size={40} stroke={4} />
              <span>Continue in your browser…</span>
              <Button variant="text" onClick={onCancel}>
                Cancel
              </Button>
            </div>
          ) : lacksAppSignIn ? (
            <p className="h-connect-screen__body h-connect-screen__notice">
              This server doesn't support app sign-in. Update the Hermes
              dashboard, or sign in from its web UI.
            </p>
          ) : providers.length === 0 ? (
            <p className="h-connect-screen__body h-connect-screen__notice">
              No sign-in providers are registered on this server.
            </p>
          ) : (
            <div className="h-connect-screen__providers">
              {providers.map((p) => (
                <Button
                  key={p.id}
                  fullWidth
                  icon={p.password ? "password" : "open_in_browser"}
                  onClick={() => onSignIn?.(p)}
                >
                  {p.password
                    ? "Sign in with username & password"
                    : `Sign in with ${p.displayName}`}
                </Button>
              ))}
            </div>
          )}
          {error ? <p className="h-connect-screen__error">{error}</p> : null}
          <div className="h-connect-screen__gap" />
          {reportBug}
        </div>
      </div>
    </div>
  );
}
