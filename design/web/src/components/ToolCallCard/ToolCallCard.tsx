import { useState, type ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import {
  ApprovalCard,
  type ApprovalCardProps,
} from "../ApprovalCard/ApprovalCard";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./ToolCallCard.css";

/** Where a tool call stands. */
export type ToolCallStatus = "running" | "completed" | "error" | "cancelled";

/** One hit of a web search. */
export interface WebSearchHit {
  title: string;
  url: string;
  /** Snippet, clamped to two lines. */
  description?: string;
}

/** One item of the agent's todo list. */
export interface TodoItem {
  content: string;
  status: "pending" | "in_progress" | "completed" | "cancelled";
}

/**
 * A tool's own view of an opened call. `terminal`: the command, its output,
 * an error and a non-zero exit code. `web_search`: the hits. `todo`: the task
 * list. `diff`: a unified diff, added lines green and removed ones red.
 */
export type ToolCallBody =
  | {
      kind: "terminal";
      command: string;
      output?: string;
      error?: string;
      exitCode?: number;
    }
  | { kind: "web_search"; hits: WebSearchHit[] }
  | { kind: "todo"; items: TodoItem[] }
  | { kind: "diff"; diff: string };

/** A tool call the agent made. */
export interface ToolCallItem {
  /** Tool name as Hermes reports it, shown monospace and bold: `terminal`, `read_file`, `mcp__github__list_prs`. */
  name: string;
  /** One-line argument summary shown muted after the name (a path, a command, a query). */
  summary?: string;
  /** Defaults to `completed`. */
  status?: ToolCallStatus;
  /** The model is still writing the call's arguments: the summary reads "Preparing…". */
  preparing?: boolean;
  /** Elapsed or final time shown on the right, already formatted: "0.4s", "12s", "1m 14s". */
  duration?: string;
  /** Generic view: what the tool was given (pretty JSON or plain text). Used when there is no `body`. */
  input?: string;
  /** Generic view: what the tool returned; labelled "Error" when the call failed. Used when there is no `body`. */
  result?: string;
  /** The tool's own view when opened, instead of the generic input and result. */
  body?: ToolCallBody;
  /** An approval that holds this call up; rendered as an ApprovalCard inside the card. */
  approval?: ApprovalCardProps;
}

export interface ToolCallStatusIconProps {
  status: ToolCallStatus;
  /** Waiting on the user: a raised hand in the warning color, whatever the status. */
  waiting?: boolean;
}

/** The status glyph of a tool call or a group of them: a spinner while running, a raised hand while waiting on the user, a green check once done, a red error mark once failed, a stop mark once cancelled. */
export function ToolCallStatusIcon({
  status,
  waiting = false,
}: ToolCallStatusIconProps) {
  if (waiting)
    return (
      <Icon
        name="front_hand"
        size={14}
        className="h-tool-status h-tool-status--waiting"
      />
    );
  switch (status) {
    case "running":
      return (
        <span
          className="h-tool-status h-tool-status--running"
          aria-label="Running"
        />
      );
    case "completed":
      return (
        <Icon
          name="check_circle"
          filled
          size={14}
          className="h-tool-status h-tool-status--done"
        />
      );
    case "error":
      return (
        <Icon
          name="error"
          filled
          size={14}
          className="h-tool-status h-tool-status--error"
        />
      );
    case "cancelled":
      return (
        <Icon
          name="block"
          size={14}
          className="h-tool-status h-tool-status--cancelled"
        />
      );
  }
}

export interface ToolCallCardProps extends ToolCallItem {
  /** Start with the details showing, to preview the opened state. */
  defaultOpen?: boolean;
  /** Overrides whether the card waits on the user (hand icon); defaults to a pending `approval`. */
  waiting?: boolean;
  /** Extra content shown under the header whether open or not, such as a custom input request card. */
  children?: ReactNode;
  /** Called with the new open state when the header is clicked. */
  onToggle?: (open: boolean) => void;
  /** `apple`: the header is 44px tall, the iOS minimum tap target (36px on `material`). Inherits the provider's platform. */
  platform?: Platform;
  className?: string;
}

function Section({ label, children }: { label?: string; children: ReactNode }) {
  return (
    <div className="h-tool-call__section">
      {label ? <div className="h-tool-call__section-label">{label}</div> : null}
      <div className="h-tool-call__section-body">{children}</div>
    </div>
  );
}

const todoIcons: Record<TodoItem["status"], string> = {
  completed: "check_box",
  in_progress: "indeterminate_check_box",
  cancelled: "disabled_by_default",
  pending: "check_box_outline_blank",
};

function diffClass(line: string, i: number) {
  if (line.startsWith("+++") || line.startsWith("---")) return "file";
  if (line.startsWith("@@")) return "hunk";
  if (line.startsWith("+")) return "add";
  if (line.startsWith("-")) return "remove";
  if (i === 0 && line.includes(" → ")) return "file";
  return null;
}

function renderBody(body: ToolCallBody) {
  switch (body.kind) {
    case "terminal": {
      const failed = body.exitCode != null && body.exitCode !== 0;
      return (
        <Section>
          <div className="h-tool-call__mono">
            <span className="h-tool-call__prompt">$ </span>
            <strong>{body.command}</strong>
          </div>
          {body.output && body.output.trim() ? (
            <div className="h-tool-call__mono h-tool-call__spaced">
              {body.output.trimEnd()}
            </div>
          ) : null}
          {body.error ? (
            <div className="h-tool-call__error h-tool-call__spaced">
              {body.error}
            </div>
          ) : null}
          {failed ? (
            <div className="h-tool-call__exit h-tool-call__spaced">
              Exit code {body.exitCode}
            </div>
          ) : null}
        </Section>
      );
    }
    case "web_search":
      return (
        <Section
          label={
            body.hits.length === 0
              ? "No results"
              : `${body.hits.length} result${body.hits.length === 1 ? "" : "s"}`
          }
        >
          {body.hits.map((hit) => (
            <div key={hit.url} className="h-tool-call__hit">
              <div className="h-tool-call__hit-title">{hit.title}</div>
              <div className="h-tool-call__hit-url">{hit.url}</div>
              {hit.description ? (
                <div className="h-tool-call__hit-description">
                  {hit.description}
                </div>
              ) : null}
            </div>
          ))}
        </Section>
      );
    case "todo":
      return (
        <Section>
          {body.items.map((item, i) => (
            <div
              key={i}
              className={`h-tool-call__todo h-tool-call__todo--${item.status}`}
            >
              <Icon
                name={todoIcons[item.status]}
                filled={item.status !== "cancelled"}
                size={15}
                className="h-tool-call__todo-icon"
              />
              <span>{item.content}</span>
            </div>
          ))}
        </Section>
      );
    case "diff": {
      const lines = body.diff
        .replace(/\x1B\[[0-9;]*m/g, "")
        .trimEnd()
        .split("\n")
        .filter((l) => !l.trimStart().startsWith("┊"));
      return (
        <Section>
          <div className="h-tool-call__mono">
            {lines.map((line, i) => {
              const kind = diffClass(line, i);
              return (
                <div
                  key={i}
                  className={kind ? `h-tool-call__diff--${kind}` : undefined}
                >
                  {line || " "}
                </div>
              );
            })}
          </div>
        </Section>
      );
    }
  }
}

/** A compact inline card for one tool the agent ran: status icon, tool name, argument summary and time in a 36px header (44px under `platform="apple"`) that opens on click to what the tool was given and returned, in the tool's own view when it has one. An approval that holds the call up shows inside the card, under the header while pending. */
export function ToolCallCard({
  name,
  summary = "",
  status = "completed",
  preparing = false,
  duration,
  input,
  result,
  body,
  approval,
  defaultOpen = false,
  waiting,
  children,
  onToggle,
  platform,
  className,
}: ToolCallCardProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const isWaiting =
    waiting ?? (!!approval && (approval.status ?? "pending") === "pending");
  const pendingApproval = approval && isWaiting;
  const details: ReactNode[] = [];
  if (body) details.push(<div key="body">{renderBody(body)}</div>);
  else {
    const inputText = (input ?? summary).trim();
    if (inputText)
      details.push(
        <Section key="input" label="Input">
          <div className="h-tool-call__mono">{inputText}</div>
        </Section>,
      );
    if (result && result.trim())
      details.push(
        <Section key="result" label={status === "error" ? "Error" : "Result"}>
          <div className="h-tool-call__mono">{result.trim()}</div>
        </Section>,
      );
  }
  if (approval && !pendingApproval)
    details.push(
      <div
        key="approval"
        className="h-tool-call__approval h-tool-call__approval--answered"
      >
        <ApprovalCard {...approval} />
      </div>,
    );
  const expandable = details.length > 0;
  const [open, setOpen] = useState(defaultOpen && expandable);
  const toggle = () => {
    if (!expandable) return;
    setOpen(!open);
    onToggle?.(!open);
  };
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className={cx("h-tool-call", apple && "h-tool-call--apple", className)}
      >
        <button
          type="button"
          className="h-tool-call__header"
          onClick={toggle}
          disabled={!expandable}
          aria-expanded={expandable ? open : undefined}
        >
          <ToolCallStatusIcon status={status} waiting={isWaiting} />
          <span className="h-tool-call__name">{name}</span>
          <span className="h-tool-call__summary">
            {preparing ? "Preparing…" : summary}
          </span>
          {duration ? (
            <span className="h-tool-call__time">{duration}</span>
          ) : null}
          {expandable ? (
            <Icon
              name="expand_more"
              size={24}
              className={[
                "h-tool-call__chevron",
                open ? "h-tool-call__chevron--open" : null,
              ]
                .filter(Boolean)
                .join(" ")}
            />
          ) : null}
        </button>
        {open ? <div className="h-tool-call__details">{details}</div> : null}
        {pendingApproval ? (
          <div className="h-tool-call__approval">
            <ApprovalCard {...approval} />
          </div>
        ) : null}
        {children ? (
          <div className="h-tool-call__approval">{children}</div>
        ) : null}
      </div>
    </PlatformScope>
  );
}
