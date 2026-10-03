import { useState } from "react";
import { Icon } from "../Icon/Icon";
import {
  ToolCallCard,
  ToolCallStatusIcon,
  type ToolCallItem,
  type ToolCallStatus,
} from "../ToolCallCard/ToolCallCard";
import { cx, usePlatform, type Platform } from "../../platform";
import "./ToolCallGroup.css";

export interface ToolCallGroupProps {
  /** The calls the agent made back to back, in order. One call renders as a plain ToolCallCard with no group line. */
  calls: ToolCallItem[];
  /** Start unfolded, to preview the list of cards. A call waiting on approval always keeps the group open. */
  defaultOpen?: boolean;
  /** Called with the new open state when the group line is clicked. */
  onToggle?: (open: boolean) => void;
  /** `apple`: the group line and each card header are at least 44px tall. Inherits the provider's platform. */
  platform?: Platform;
  className?: string;
}

/** A run of tool calls folded into one quiet line, "✓ Used 3 tools ›", that opens to a ToolCallCard per call. While a call runs the line names it ("Running terminal…"), and while one waits on approval it says so and stays open. */
export function ToolCallGroup({
  calls,
  defaultOpen = false,
  onToggle,
  platform,
  className,
}: ToolCallGroupProps) {
  const [opened, setOpened] = useState(defaultOpen);
  const resolved = usePlatform(platform);
  if (calls.length === 1)
    return (
      <ToolCallCard {...calls[0]} platform={resolved} className={className} />
    );

  const statusOf = (c: ToolCallItem) => c.status ?? "completed";
  const waiting = calls.filter(
    (c) => !!c.approval && (c.approval.status ?? "pending") === "pending",
  );
  const running = calls.filter((c) => statusOf(c) === "running");
  const status: ToolCallStatus = running.length
    ? "running"
    : calls.some((c) => statusOf(c) === "error")
      ? "error"
      : calls.every((c) => statusOf(c) === "cancelled")
        ? "cancelled"
        : "completed";
  const started = running.filter((c) => !c.preparing);
  const label = waiting.length
    ? `Waiting on ${waiting[0].name}`
    : started.length
      ? `Running ${started[0].name}…`
      : running.length
        ? `Preparing ${running[0].name}…`
        : `Used ${calls.length} tools`;
  const open = opened || waiting.length > 0;

  return (
    <div
      className={cx(
        "h-tool-group",
        resolved === "apple" && "h-tool-group--apple",
        className,
      )}
    >
      <button
        type="button"
        className="h-tool-group__line"
        aria-expanded={open}
        onClick={() => {
          setOpened(!open);
          onToggle?.(!open);
        }}
      >
        <ToolCallStatusIcon status={status} waiting={waiting.length > 0} />
        <span className="h-tool-group__label">{label}</span>
        <Icon
          name={open ? "expand_less" : "chevron_right"}
          size={16}
          className="h-tool-group__chevron"
        />
      </button>
      {open ? (
        <div className="h-tool-group__list">
          {calls.map((c, i) => (
            <ToolCallCard key={i} {...c} platform={resolved} />
          ))}
        </div>
      ) : null}
    </div>
  );
}
