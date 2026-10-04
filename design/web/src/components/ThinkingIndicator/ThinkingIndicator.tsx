import { Spinner } from "../Spinner/Spinner";
import "./ThinkingIndicator.css";

export interface ThinkingIndicatorProps {
  /** Seconds since the reply began; shown as `12s` under a minute and `2m 5s` from a minute on. */
  elapsedSeconds: number;
  /** What the reply is doing right now, e.g. `Thinking…` (default) or `Running shell…`. */
  activity?: string;
}

/** Formats elapsed seconds the way the app does: `12s`, or `2m 5s` from a minute on. */
export function formatThinkingElapsed(seconds: number): string {
  const total = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(total / 60);
  const rest = total % 60;
  return minutes > 0 ? `${minutes}m ${rest}s` : `${rest}s`;
}

/**
 * A small spinner, the elapsed time and what the reply is doing
 * ("4s · Thinking…"), shown in the assistant's column while a reply has
 * nothing else to show yet.
 */
export function ThinkingIndicator({
  elapsedSeconds,
  activity = "Thinking…",
}: ThinkingIndicatorProps) {
  return (
    <div className="h-thinking-indicator" role="status">
      <Spinner size={12} color="currentColor" />
      <span>{`${formatThinkingElapsed(elapsedSeconds)} · ${activity}`}</span>
    </div>
  );
}
