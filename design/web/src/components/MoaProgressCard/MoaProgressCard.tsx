import { BusyBar } from "../BusyBar/BusyBar";
import { DisclosureTile } from "../SessionStatusCard/DisclosureTile";
import "./MoaProgressCard.css";

/** One answer a Mixture-of-agents advisor gave. */
export interface MoaReference {
  /** The advisor's label as Hermes sent it (a model name). Empty reads "Advisor reference". */
  label: string;
  /** What the advisor answered. */
  text: string;
}

export interface MoaProgressCardProps {
  /** The phase while the turn is live: `Advisors` (default), `Aggregating`, or whatever Hermes reports. Ignored once `live` is false. */
  phase?: string;
  /** Model that combines the advisors' answers, shown under the title once known. */
  aggregator?: string;
  /** Advisor answers received so far. Counts show only with a valid `total` (done is not negative and not above total). */
  done?: number;
  /** Advisor answers expected. */
  total?: number;
  /** The turn is still running (default). When false the header reads `Finished` and the bar goes away. */
  live?: boolean;
  /** The advisors' answers, in the order received. */
  references?: MoaReference[];
  /** False when the answers can no longer be shown (the app reconnected and lost them): opened, the card says "Reference details unavailable." */
  referencesAvailable?: boolean;
  /** Start opened, to preview the references. Folded by default. */
  defaultOpen?: boolean;
  /** The details were opened (the app logs it). */
  onDetails?: () => void;
}

/**
 * The Working-tier card for a Mixture-of-agents turn: several advisor models
 * answer, then an aggregator combines them. The header reads
 * `Advisor progress · <phase>` (or `Finished`), then `N / M references`, the
 * aggregator's name and, while live with known counts, a progress bar.
 * Opened it lists each advisor's label and answer. Material on every
 * platform, as in the app.
 */
export function MoaProgressCard({
  phase = "Advisors",
  aggregator,
  done,
  total,
  live = true,
  references = [],
  referencesAvailable = true,
  defaultOpen = false,
  onDetails,
}: MoaProgressCardProps) {
  const counts =
    done !== undefined && total !== undefined && done >= 0 && total >= done;
  const fraction =
    done !== undefined &&
    total !== undefined &&
    done >= 0 &&
    total > 0 &&
    done <= total
      ? done / total
      : null;
  return (
    <DisclosureTile
      defaultOpen={defaultOpen}
      onOpen={onDetails}
      title={
        <span className="h-moa-progress__title">
          <span className="h-moa-progress__line">
            Advisor progress · {live ? phase : "Finished"}
          </span>
          {counts ? (
            <span>
              {done} / {total} references
            </span>
          ) : null}
          {aggregator ? (
            <span className="h-moa-progress__line">
              Aggregator: {aggregator}
            </span>
          ) : null}
          {live && fraction !== null ? (
            <BusyBar value={fraction} label="Advisor answers received" />
          ) : null}
        </span>
      }
    >
      <div className="h-moa-progress__details">
        {!referencesAvailable ? (
          <div className="h-moa-progress__note">
            Reference details unavailable.
          </div>
        ) : references.length === 0 ? (
          <div className="h-moa-progress__note">
            No reference answers received yet.
          </div>
        ) : (
          references.map((reference, i) => (
            <div key={i} className="h-moa-progress__reference">
              <div>
                {reference.label === "" ? "Advisor reference" : reference.label}
              </div>
              <div className="h-moa-progress__text">{reference.text}</div>
            </div>
          ))
        )}
      </div>
    </DisclosureTile>
  );
}
