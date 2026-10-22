import { Button } from "../Button/Button";
import { NoticeDisclosure } from "../AgentNoticeCard/NoticeDisclosure";

/** One thing the operation asks the user to connect, enable or skip. */
export interface ConnectorOperationTarget {
  /** Display name and identity of the target ("Calendar"); unique within the operation. */
  name: string;
  /** `connector`, `mcp`, `plugin` or `skill`. Only a connector or an MCP server can be completed in the app. */
  kind: string;
  /** What Hermes wants done: `authorize`, `connect`, `enable`, `reconnect`, `install`… */
  action: string;
  /** Where the target stands: `pending`, `initiated`, `failed`, `expired`, `connected`… Shown after the action ("authorize · initiated"). */
  state: string;
  /** The target is already taken care of; it then cannot be skipped. */
  resolved?: boolean;
  /** A line of detail from Hermes. */
  detail?: string;
  /** Instructions for the user, such as "Continue in the browser to approve access.". */
  instructions?: string;
  /** The address to open in a browser. Only an `https://` address without credentials counts; its host is shown as "Browser destination". */
  connectUrl?: string;
  /** The target needs credentials typed on the server, which the app cannot take: it then cannot be completed here. */
  needsCredentials?: boolean;
}

/** One operation Hermes started that needs the user's connections. */
export interface ConnectorOperation {
  /** Targets in the order Hermes listed them. Empty shows "No connection targets reported.". */
  targets: ConnectorOperationTarget[];
  /** The operation ended; the card is a settled reference item with its controls disabled. */
  settled?: boolean;
  /** Why it ended (`user`, `timeout`…), shown as "Settlement: …". */
  settledBy?: string;
}

export interface ConnectorOperationCardProps {
  /** The operation to show. */
  operation: ConnectorOperation;
  /** The user may not act on it from here (another chat or the whole connection owns it): no Open, Skip or Continue, and "Read-only operation." in the details. */
  readOnly?: boolean;
  /** All answers are in and Hermes has not confirmed yet: the header reads "Awaiting final status" and the controls are disabled. */
  awaitingFinalStatus?: boolean;
  /** A response is being sent: the header reads "Sending response" and the controls are disabled. */
  pending?: boolean;
  /** Why the last response failed, such as "The server refused this response.". */
  error?: string;
  /** Whether Open connection is allowed for a target right now (default: yes). */
  canOpen?: (targetName: string) => boolean;
  /** Whether Skip is allowed for a target right now (default: yes). */
  canSkip?: (targetName: string) => boolean;
  /** Start open, to preview the details. */
  defaultOpen?: boolean;
  /** Called with the target name when the user presses "Open connection". The button only shows when this is set. */
  onOpen?: (targetName: string) => void;
  /** Called with the target name when the user presses "Skip". The button only shows when this is set. */
  onSkip?: (targetName: string) => void;
  /** Called when the user presses "Continue", which answers the operation. The button only shows when this is set. */
  onContinue?: () => void;
  /** Called when the card is opened (not when it closes). */
  onDetails?: () => void;
}

const COMPLETABLE_KINDS = ["connector", "mcp"];
const COMPLETABLE_ACTIONS = ["authorize", "connect", "enable", "reconnect"];
const OPEN_STATES = ["pending", "initiated"];

function canCompleteHere(target: ConnectorOperationTarget) {
  return (
    COMPLETABLE_KINDS.includes(target.kind) &&
    COMPLETABLE_ACTIONS.includes(target.action) &&
    !target.needsCredentials
  );
}

function supportsSkip(target: ConnectorOperationTarget) {
  return (
    ["connector", "mcp", "plugin", "skill"].includes(target.kind) &&
    target.resolved !== true &&
    (OPEN_STATES.includes(target.state) ||
      (COMPLETABLE_KINDS.includes(target.kind) &&
        ["failed", "expired"].includes(target.state)))
  );
}

/** The host of an `https://` address with no credentials, which is all the app opens in a browser. */
function browserHost(url: string | undefined): string | null {
  if (!url || !/^https:\/\//i.test(url)) return null;
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
 * Hermes needs the user to connect something (a connector, an MCP server) or
 * to enable or skip it, and waits for the answer. The collapsed tile reads
 * "Connection operation" (or "Awaiting final status", "Sending response",
 * "Settled"); opened, it lists each target with its action and state, any
 * instructions, the browser destination, and "Open connection" and "Skip"
 * buttons, then "Continue" to answer. While the user can act the app lists it
 * under "Needs you"; settled or read-only operations are reference items.
 */
export function ConnectorOperationCard({
  operation,
  readOnly = false,
  awaitingFinalStatus = false,
  pending = false,
  error,
  canOpen,
  canSkip,
  defaultOpen = false,
  onOpen,
  onSkip,
  onContinue,
  onDetails,
}: ConnectorOperationCardProps) {
  const enabled =
    !readOnly && !operation.settled && !awaitingFinalStatus && !pending;
  const status = operation.settled
    ? "Settled"
    : awaitingFinalStatus
      ? "Awaiting final status"
      : pending
        ? "Sending response"
        : "Connection operation";
  return (
    <NoticeDisclosure
      defaultOpen={defaultOpen}
      onToggle={(open) => {
        if (open) onDetails?.();
      }}
      title={<span className="h-notice-clamp2">{status}</span>}
    >
      <div className="h-notice-text">
        {readOnly ? <div>Read-only operation.</div> : null}
        {operation.targets.length === 0 ? (
          <div>No connection targets reported.</div>
        ) : null}
        {operation.targets.map((target) => {
          const host = browserHost(target.connectUrl);
          const completable = canCompleteHere(target);
          const browserOpens =
            completable && OPEN_STATES.includes(target.state) && host != null;
          return (
            <div key={target.name} className="h-notice-block">
              <div>{target.name}</div>
              <div>
                {target.action} · {target.state}
              </div>
              {target.detail ? <div>{target.detail}</div> : null}
              {target.instructions ? <div>{target.instructions}</div> : null}
              {!completable ? (
                <div>This target cannot be completed in this app.</div>
              ) : null}
              {browserOpens && !readOnly ? (
                <div>Browser destination: {host}</div>
              ) : null}
              {!readOnly &&
              target.connectUrl &&
              !browserOpens &&
              completable ? (
                <div>Browser opening unavailable.</div>
              ) : null}
              <div className="h-notice-actions">
                {!readOnly && browserOpens && onOpen ? (
                  <Button
                    variant="text"
                    disabled={!(enabled && (canOpen?.(target.name) ?? true))}
                    onClick={() => onOpen(target.name)}
                  >
                    Open connection
                  </Button>
                ) : null}
                {!readOnly && supportsSkip(target) && onSkip ? (
                  <Button
                    variant="text"
                    disabled={!(enabled && (canSkip?.(target.name) ?? true))}
                    onClick={() => onSkip(target.name)}
                  >
                    Skip
                  </Button>
                ) : null}
              </div>
            </div>
          );
        })}
        {error ? <div>{error}</div> : null}
        {operation.settledBy ? (
          <div>Settlement: {operation.settledBy}</div>
        ) : null}
        {!readOnly && onContinue ? (
          <div>
            <Button variant="text" disabled={!enabled} onClick={onContinue}>
              Continue
            </Button>
          </div>
        ) : null}
      </div>
    </NoticeDisclosure>
  );
}
