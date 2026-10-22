import { DisclosureTile } from "../../disclosureTile";

/** Where a side result came from: `background` is a task the agent ran off to the side, `btw` the answer to a side question asked mid-turn. */
export type SideResultKind = "background" | "btw";

/** A side task's finished output. */
export interface SideResult {
  /** `background` or `btw`; sets the title ("Background result" or "Side question answer"). */
  kind: SideResultKind;
  /** The result as Hermes reported it. Empty text is shown as "No result text reported". */
  text: string;
  /** The side question, for a `btw` result; shown as "Question: …" above the text. */
  question?: string;
}

export interface SideResultCardProps {
  /** The result to show. `null` draws "Side result unavailable" instead of a tile. */
  result: SideResult | null;
  /** Start open, to preview the details. */
  defaultOpen?: boolean;
  /** Called when the card is opened (not when it closes). */
  onDetails?: () => void;
}

/**
 * The outcome of a background task or a side question ("btw"), kept in the
 * Activity panel's "This session" list as a collapsed one-line tile. Opened,
 * it shows the question (when there was one) and the reported text, in a
 * box that scrolls past 240px.
 */
export function SideResultCard({
  result,
  defaultOpen = false,
  onDetails,
}: SideResultCardProps) {
  if (!result)
    return (
      <div className="h-notice-text" style={{ fontFamily: "var(--h-font)" }}>
        Side result unavailable
      </div>
    );
  return (
    <DisclosureTile
      defaultOpen={defaultOpen}
      maxBodyHeight={240}
      onToggle={(open) => {
        if (open) onDetails?.();
      }}
      title={
        result.kind === "background"
          ? "Background result"
          : "Side question answer"
      }
    >
      <div className="h-notice-text" style={{ whiteSpace: "pre-wrap" }}>
        {result.question ? <div>Question: {result.question}</div> : null}
        <div>{result.text || "No result text reported"}</div>
      </div>
    </DisclosureTile>
  );
}
