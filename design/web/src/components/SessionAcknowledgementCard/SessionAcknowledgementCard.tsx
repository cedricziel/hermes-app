import { DisclosureTile } from "../../disclosureTile";

/** What a session acknowledgement signalled. Hermes only reports `vibe` today. */
export type SessionAcknowledgement = "vibe";

export interface SessionAcknowledgementCardProps {
  /** The acknowledgement the session reported. Without one the card draws nothing. */
  acknowledgement?: SessionAcknowledgement | null;
  /** Start open, to preview the details. */
  defaultOpen?: boolean;
  /** Called when the card is opened (not when it closes). */
  onDetails?: () => void;
}

/**
 * A reference-tier tile in the Activity panel's "This session" list saying
 * the agent acknowledged the session (a reaction-style signal with no text of
 * its own). Collapsed it reads "Session acknowledgement"; opened it adds one
 * explanatory line.
 */
export function SessionAcknowledgementCard({
  acknowledgement,
  defaultOpen = false,
  onDetails,
}: SessionAcknowledgementCardProps) {
  if (!acknowledgement) return null;
  return (
    <DisclosureTile
      defaultOpen={defaultOpen}
      onToggle={(open) => {
        if (open) onDetails?.();
      }}
      title="Session acknowledgement"
    >
      <div className="h-notice-text">
        An acknowledgement was reported for this session.
      </div>
    </DisclosureTile>
  );
}
