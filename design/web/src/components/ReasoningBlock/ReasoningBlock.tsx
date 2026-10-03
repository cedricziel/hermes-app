import { useState } from "react";
import { Icon } from "../Icon/Icon";
import { cx, usePlatform, type Platform } from "../../platform";
import "./ReasoningBlock.css";

export interface ReasoningBlockProps {
  /** What the model reasoned, as plain text. */
  text: string;
  /** The reply is still being written: the header reads `Thinking…` instead of `Reasoning`. */
  active?: boolean;
  /** Open on first render, to show the reasoning text. Folded by default. */
  defaultOpen?: boolean;
  /** Overrides the header text (`Reasoning`, or `Thinking…` while `active`). */
  label?: string;
  /** `apple`: the header toggle is at least 44px tall, the iOS minimum tap target. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * The model's reasoning before its answer, folded behind a quiet
 * "Reasoning ⌄" header that opens to the text beside a thin left rule.
 * Sits in the assistant's column above the reply.
 */
export function ReasoningBlock({
  text,
  active = false,
  defaultOpen = false,
  label,
  platform,
}: ReasoningBlockProps) {
  const [open, setOpen] = useState(defaultOpen);
  const apple = usePlatform(platform) === "apple";
  return (
    <div
      className={cx("h-reasoning-block", apple && "h-reasoning-block--apple")}
    >
      <button
        type="button"
        className="h-reasoning-block__header"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        <Icon name="psychology" size={16} />
        <span className="h-reasoning-block__label">
          {label ?? (active ? "Thinking…" : "Reasoning")}
        </span>
        <Icon name={open ? "expand_less" : "expand_more"} size={18} />
      </button>
      {open ? <div className="h-reasoning-block__body">{text}</div> : null}
    </div>
  );
}
