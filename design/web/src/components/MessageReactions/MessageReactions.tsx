import { useState } from "react";
import { Icon } from "../Icon/Icon";
import "./MessageReactions.css";

/** An emoji reaction Hermes or a teammate reported on a message. */
export interface MessageReaction {
  /** The emoji itself, e.g. `👍`. */
  emoji: string;
  /** Who reacted: `agent`, or a teammate's handle. */
  author: string;
}

export interface MessageReactionsProps {
  /** The reactions on one message, in the order they were reported. Nothing is drawn for an empty list. */
  reactions: MessageReaction[];
  /** Start with the "Message reactions" details open, to preview that state. */
  defaultOpen?: boolean;
  /** Called with the new open state when the details header is pressed. */
  onToggle?: (open: boolean) => void;
}

/**
 * What sits under a message that has reactions (the app's `MessageReactionCard`):
 * one wrapped line of "emoji · author" pairs, then a "Message reactions"
 * disclosure that lists the authors. Used by AssistantMessage and UserMessage
 * through their `reactions` prop.
 */
export function MessageReactions({
  reactions,
  defaultOpen = false,
  onToggle,
}: MessageReactionsProps) {
  const [open, setOpen] = useState(defaultOpen);
  if (reactions.length === 0) return null;
  return (
    <div className="h-message-reactions">
      <div className="h-message-reactions__line">
        {reactions.map((reaction, i) => (
          <span key={i}>
            {reaction.emoji} · {reaction.author}
          </span>
        ))}
      </div>
      <button
        type="button"
        className="h-message-reactions__header"
        aria-expanded={open}
        onClick={() => {
          setOpen(!open);
          onToggle?.(!open);
        }}
      >
        <span className="h-message-reactions__title">Message reactions</span>
        <Icon
          name="expand_more"
          apple={false}
          size={24}
          className={
            open
              ? "h-message-reactions__chevron h-message-reactions__chevron--open"
              : "h-message-reactions__chevron"
          }
        />
      </button>
      {open ? (
        <div className="h-message-reactions__details">
          {reactions.map((reaction, i) => (
            <div key={i}>Author: {reaction.author}</div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
