import { Button } from "../Button/Button";
import { NoticeDisclosure } from "../AgentNoticeCard/NoticeDisclosure";

/** The usage Hermes reported for a session. Leave out what it did not report: missing metrics are not shown. */
export interface SessionUsageSnapshot {
  /** Model name, shown as "Model: …". */
  model?: string;
  /** Input tokens. */
  input?: number;
  /** Output tokens. */
  output?: number;
  /** Reasoning tokens. */
  reasoning?: number;
  /** Total tokens; also in the title ("Session usage · 84 tokens"). */
  total?: number;
  /** Model calls made. */
  calls?: number;
  /** Tokens currently in the context window. */
  contextUsed?: number;
  /** Size of the context window in tokens. */
  contextMax?: number;
  /** Context used as a percentage. */
  contextPercent?: number;
  /** The context figures are estimates; adds an "Estimated context" line. */
  contextEstimated?: boolean;
  /** Times the context was compressed. */
  compressions?: number;
  /** Cost in US dollars, shown as given ("Cost (USD): 0.0152"). */
  costUsd?: number;
  /** Cost status text from Hermes, such as `estimated`. */
  costStatus?: string;
}

/** How current the snapshot is: `stale` after a disconnect, `unavailable` when none has arrived. */
export type SessionUsageFreshness = "current" | "stale" | "unavailable";

export interface SessionUsageCardProps {
  /** The latest usage, or none yet. */
  snapshot?: SessionUsageSnapshot | null;
  /** How current `snapshot` is. Defaults to `current`. */
  freshness?: SessionUsageFreshness;
  /** A read is in flight: adds "Loading session usage…". */
  loading?: boolean;
  /** The last refresh failed on the connection: adds "Could not refresh session usage.". */
  failed?: boolean;
  /** Shows the "Refresh usage" button; false while disconnected or loading. Defaults to true. */
  canRefresh?: boolean;
  /** Draws nothing when false: a server without usage reporting has no card. Defaults to true. */
  shown?: boolean;
  /** Start open, to preview the details. */
  defaultOpen?: boolean;
  /** Called when the user presses "Refresh usage". */
  onRefresh?: () => void;
  /** Called when the card is opened (the app fetches fresh usage then). */
  onDetails?: () => void;
}

const metricLabels: Array<[keyof SessionUsageSnapshot, string]> = [
  ["input", "Input tokens"],
  ["output", "Output tokens"],
  ["reasoning", "Reasoning tokens"],
  ["total", "Total tokens"],
  ["calls", "Calls"],
  ["contextUsed", "Context used"],
  ["contextMax", "Context capacity"],
  ["contextPercent", "Context percent"],
  ["compressions", "Compressions"],
  ["costUsd", "Cost (USD)"],
];

/**
 * Token and cost usage of the chat's session, in the Activity panel's
 * "This session" list. The header reads "Session usage · 84 tokens" (just
 * "Session usage" without a total); opened it lists the model, every metric
 * Hermes reported, whether the context is estimated, and a "Refresh usage"
 * button. Opening it asks the server for fresh numbers.
 */
export function SessionUsageCard({
  snapshot,
  freshness = "current",
  loading = false,
  failed = false,
  canRefresh = true,
  shown = true,
  defaultOpen = false,
  onRefresh,
  onDetails,
}: SessionUsageCardProps) {
  if (!shown) return null;
  const total = snapshot?.total;
  const title =
    total == null
      ? "Session usage"
      : `Session usage · ${total.toLocaleString("en-US")} tokens`;
  return (
    <NoticeDisclosure
      defaultOpen={defaultOpen}
      onToggle={(open) => {
        if (open) onDetails?.();
      }}
      title={<span className="h-notice-clamp1">{title}</span>}
    >
      <div className="h-notice-text">
        {loading ? <div>Loading session usage…</div> : null}
        {freshness === "stale" ? <div>Stale session usage</div> : null}
        {!loading && !snapshot && freshness === "unavailable" ? (
          <div>Session usage unavailable</div>
        ) : null}
        {snapshot?.model ? <div>Model: {snapshot.model}</div> : null}
        {snapshot
          ? metricLabels.map(([key, label]) =>
              snapshot[key] == null ? null : (
                <div key={key}>
                  {label}: {String(snapshot[key])}
                </div>
              ),
            )
          : null}
        {snapshot?.contextEstimated ? <div>Estimated context</div> : null}
        {snapshot?.costStatus ? (
          <div>Cost status: {snapshot.costStatus}</div>
        ) : null}
        {failed ? <div>Could not refresh session usage.</div> : null}
        {canRefresh ? (
          <div>
            <Button variant="text" onClick={onRefresh}>
              Refresh usage
            </Button>
          </div>
        ) : null}
      </div>
    </NoticeDisclosure>
  );
}
