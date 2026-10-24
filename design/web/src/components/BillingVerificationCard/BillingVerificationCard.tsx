import { Button } from "../Button/Button";
import { DisclosureTile } from "../../disclosureTile";
import "./BillingVerificationCard.css";

/** Where the billing verification stands. */
export type BillingVerificationStatus =
  "idle" | "pending" | "granted" | "refused" | "unavailable" | "failed";

/** What the server sent to verify billing access in a browser. */
export interface BillingVerificationDetails {
  /** The code to enter or compare on the verification page. */
  userCode: string;
  /** The page to open. The app only opens `https://` addresses without credentials; any other shows "Browser opening unavailable." and no Open button works. */
  verificationUrl: string;
}

export interface BillingVerificationCardProps {
  /** Defaults to `idle`. Sets the header: "Billing access", "Awaiting billing verification", "Billing access granted", "Billing access refused", "Billing verification unavailable" or "Billing verification failed". */
  status?: BillingVerificationStatus;
  /** The code and address to verify with. Present while the user has to act: the app then lists the card under "Needs you". Without them (settled or not yet asked) it is a reference card. */
  verification?: BillingVerificationDetails | null;
  /** App Lock covers the app: details are withheld and the card asks to unlock. */
  locked?: boolean;
  /** A line from the last attempt, such as "The server did not grant billing access." */
  message?: string;
  /** The server asked to wait before retrying: adds "Retry is available after the server delay." */
  retryPending?: boolean;
  /** Draws nothing when false: the server does not offer billing verification. Defaults to true. */
  supported?: boolean;
  /** Enables "Verify billing access". Defaults to true. */
  canStart?: boolean;
  /** Enables "Copy code". Defaults to true. */
  canCopyCode?: boolean;
  /** Enables "Open verification". Defaults to true when the address is a safe `https://` one. */
  canOpenVerification?: boolean;
  /** Start open, to preview the details. */
  defaultOpen?: boolean;
  /** Called when the user presses "Verify billing access". */
  onStart?: () => void;
  /** Called when the user presses "Copy code". */
  onCopyCode?: () => void;
  /** Called when the user presses "Open verification". */
  onOpenVerification?: () => void;
  /** Called when the card is opened (not when it closes). */
  onDetails?: () => void;
}

const summaries: Record<BillingVerificationStatus, string> = {
  idle: "Billing access",
  pending: "Awaiting billing verification",
  granted: "Billing access granted",
  refused: "Billing access refused",
  unavailable: "Billing verification unavailable",
  failed: "Billing verification failed",
};

/** The host of an `https://` address with no credentials, which is all the app opens in a browser. */
function browserHost(url: string): string | null {
  if (!/^https:\/\//i.test(url)) return null;
  try {
    const parsed = new URL(url);
    return parsed.username || parsed.password || !parsed.hostname
      ? null
      : parsed.hostname;
  } catch {
    return null;
  }
}

/**
 * Protected billing verification: the agent needs billing access that only the
 * user can grant, through a code and a page in the browser. A collapsed tile
 * shows the status; opened it explains that verification grants access but
 * makes no charge, shows the code and the page's host, and offers "Copy code"
 * and "Open verification". "Verify billing access" (the one filled button)
 * starts it. While a code is waiting the card is a "Needs you" item in the
 * Activity panel; settled or idle it is a reference card. The code and address
 * are never shown while App Lock is on.
 */
export function BillingVerificationCard({
  status = "idle",
  verification,
  locked = false,
  message,
  retryPending = false,
  supported = true,
  canStart = true,
  canCopyCode = true,
  canOpenVerification,
  defaultOpen = false,
  onStart,
  onCopyCode,
  onOpenVerification,
  onDetails,
}: BillingVerificationCardProps) {
  if (!supported) return null;
  const host = verification ? browserHost(verification.verificationUrl) : null;
  const canOpen = canOpenVerification ?? host != null;
  return (
    <div className="h-billing">
      <DisclosureTile
        defaultOpen={defaultOpen}
        onToggle={(open) => {
          if (open) onDetails?.();
        }}
        title={<span className="h-notice-clamp2">{summaries[status]}</span>}
      >
        <div className="h-notice-text">
          <div>
            Verification grants billing access. It does not make a charge.
          </div>
          {locked ? (
            <div>Unlock the app to receive fresh verification details.</div>
          ) : !verification ? (
            <div>No verification details received.</div>
          ) : (
            <>
              <div>{verification.userCode}</div>
              {host ? (
                <>
                  <div>Browser destination: {host}</div>
                  <div>{verification.verificationUrl}</div>
                </>
              ) : (
                <div>Browser opening unavailable.</div>
              )}
              <div className="h-notice-actions">
                <Button
                  variant="text"
                  disabled={!canCopyCode}
                  onClick={onCopyCode}
                >
                  Copy code
                </Button>
                <Button
                  variant="text"
                  disabled={!canOpen}
                  onClick={onOpenVerification}
                >
                  Open verification
                </Button>
              </div>
            </>
          )}
          {message ? <div>{message}</div> : null}
          {retryPending ? (
            <div>Retry is available after the server delay.</div>
          ) : null}
        </div>
      </DisclosureTile>
      <div className="h-billing__start">
        <Button variant="filled" disabled={!canStart} onClick={onStart}>
          Verify billing access
        </Button>
      </div>
    </div>
  );
}
