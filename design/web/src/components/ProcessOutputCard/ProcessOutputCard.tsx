import { DisclosureTile } from "../../disclosureTile";
import "./ProcessOutputCard.css";

export interface ProcessOutputCardProps {
  /** The background process's id as the agent named it ("worker", "build-1"). Shown in the header as `Process <id>`. */
  processId: string;
  /** Output received so far, as plain text with newlines. Empty shows "No output received." when open. */
  text?: string;
  /** The process closed: the header reads `Closed` instead of `Output received`. */
  closed?: boolean;
  /** Only the newest part of the output is kept (the app keeps the last 64 KB): adds "Earlier output omitted." under the text. */
  omitted?: boolean;
  /** The app keeps at most 16 process cards and dropped older ones: adds "Earlier process cards omitted." */
  omittedCards?: boolean;
  /** The output could not be read: draws only the line "Process output unavailable", with no header. */
  unavailable?: boolean;
  /** Start opened, to preview the output. Folded by default. */
  defaultOpen?: boolean;
  /** The details were opened (the app logs it). */
  onDetails?: () => void;
}

/**
 * The Working-tier card for the output of a process the agent started in the
 * background. Folded it is one line, `Process worker · Output received` (or
 * `· Closed`); opened it shows the output in a box that scrolls past 180px,
 * and notes when earlier output or earlier cards were dropped. Material on
 * every platform, as in the app.
 */
export function ProcessOutputCard({
  processId,
  text = "",
  closed = false,
  omitted = false,
  omittedCards = false,
  unavailable = false,
  defaultOpen = false,
  onDetails,
}: ProcessOutputCardProps) {
  if (unavailable)
    return (
      <div className="h-process-output__unavailable">
        Process output unavailable
      </div>
    );
  return (
    <DisclosureTile
      titleSize={13}
      defaultOpen={defaultOpen}
      onToggle={(open) => open && onDetails?.()}
      title={
        <span className="h-process-output__title">
          Process {processId} · {closed ? "Closed" : "Output received"}
        </span>
      }
    >
      <div className="h-process-output__details">
        {text === "" ? (
          <div>No output received.</div>
        ) : (
          <div className="h-process-output__text">{text}</div>
        )}
        {omitted ? <div>Earlier output omitted.</div> : null}
        {omittedCards ? <div>Earlier process cards omitted.</div> : null}
      </div>
    </DisclosureTile>
  );
}
