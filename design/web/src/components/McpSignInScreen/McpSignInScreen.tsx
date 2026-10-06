import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { Spinner } from "../Spinner/Spinner";
import { usePlatform, type Platform } from "../../platform";
import { noop, ScreenFrame } from "../../screen";
import "./McpSignInScreen.css";

export interface McpSignInScreenProps {
  /** The OAuth server being signed in to; the title reads "Sign in to grafana". */
  server: string;
  /**
   * `waiting`: a spinner, "Waiting for you to approve", Open the browser
   * again and Cancel; the screen closes by itself once Hermes reports the
   * sign-in approved. `failed`: "Could not sign in" with `failure`, Try
   * again and Close. `expired`: Hermes dropped the flow; Try again and Close.
   */
  phase?: "waiting" | "failed" | "expired";
  /** `failed`: why, from Hermes: "The provider denied access." */
  failure?: string;
  /** The authorization address. Without it (Hermes has not sent it yet) "Open the browser again" is disabled. */
  authorizationUrl?: string;
  /** `waiting`: the browser did not open, so the address is shown with a Copy button. */
  browserFailed?: boolean;
  /** `waiting`: Hermes sent an address that is not a web address; the app will not open it and says so. */
  addressRefused?: boolean;
  /** Try again is starting a new flow: it spins and both buttons are disabled. */
  starting?: boolean;
  onBack?: () => void;
  onOpenBrowser?: () => void;
  onCopyAddress?: () => void;
  onCancel?: () => void;
  onTryAgain?: () => void;
  onClose?: () => void;
  /** The spinner is the activity indicator under `apple`, with a chevron back labelled "MCP servers" on a phone. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * Waits while the user approves a sign-in to an OAuth MCP server in the
 * browser. Hermes runs the flow and keeps the token; the app only opens the
 * authorization address and watches. A centred 420px column under the app
 * bar; the same on phone and desktop. Fills its parent; give it a size.
 */
export function McpSignInScreen({
  server,
  phase = "waiting",
  failure,
  authorizationUrl,
  browserFailed = false,
  addressRefused = false,
  starting = false,
  onBack,
  onOpenBrowser,
  onCopyAddress,
  onCancel,
  onTryAgain,
  onClose,
  platform,
}: McpSignInScreenProps) {
  const resolved = usePlatform(platform);
  const body =
    phase === "waiting" ? (
      <>
        <Spinner size={36} label="Waiting" />
        <div className="h-title-md h-mcp-signin__title">
          Waiting for you to approve
        </div>
        <div className="h-body-md">
          Approve the sign-in in your browser. It finishes on your Hermes
          server, so this screen closes by itself.
        </div>
        {addressRefused ? (
          <div className="h-body-sm h-muted h-mcp-signin__note">
            Hermes sent an address this app will not open, because it is not a
            web address. Cancel and try again, or check the server.
          </div>
        ) : browserFailed && authorizationUrl ? (
          <div className="h-mcp-signin__note">
            <div className="h-body-sm h-muted">
              Could not open the browser. Open this address yourself:
            </div>
            <div className="h-mcp-signin__url">{authorizationUrl}</div>
            <Button variant="text" icon="content_copy" onClick={onCopyAddress}>
              Copy address
            </Button>
          </div>
        ) : null}
        <div className="h-mcp-signin__buttons">
          <Button
            variant="outlined"
            disabled={!authorizationUrl || addressRefused}
            onClick={onOpenBrowser}
          >
            Open the browser again
          </Button>
          <Button variant="text" onClick={onCancel}>
            Cancel
          </Button>
        </div>
      </>
    ) : (
      <>
        <Icon name="error" size={40} className="h-mcp-signin__error" />
        <div className="h-title-md h-mcp-signin__title">
          {phase === "failed" ? "Could not sign in" : "The sign-in expired"}
        </div>
        <div className="h-body-md">
          {phase === "failed"
            ? (failure ?? `Signing in to ${server} failed.`)
            : "Hermes dropped it. Start it again to get a new link."}
        </div>
        <div className="h-mcp-signin__buttons">
          <Button disabled={starting} onClick={onTryAgain}>
            {starting ? (
              <Spinner size={18} color="var(--h-muted)" label="Starting" />
            ) : (
              "Try again"
            )}
          </Button>
          <Button variant="text" disabled={starting} onClick={onClose}>
            Close
          </Button>
        </div>
      </>
    );
  return (
    <ScreenFrame platform={resolved}>
      <ListDetailLayout
        layout="list"
        title={`Sign in to ${server}`}
        onBack={onBack ?? noop}
        backLabel="MCP servers"
        list={
          <div className="h-screen__center">
            <div className="h-mcp-signin">{body}</div>
          </div>
        }
      />
    </ScreenFrame>
  );
}
