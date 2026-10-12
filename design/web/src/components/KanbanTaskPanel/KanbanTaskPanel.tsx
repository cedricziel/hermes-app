import { useState } from "react";
import type { ReactNode } from "react";
import { Button } from "../Button/Button";
import { GroupedTextFieldRow } from "../GroupedTextFieldRow/GroupedTextFieldRow";
import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import { GroupedMenuRow } from "../GroupedMenuRow/GroupedMenuRow";
import { Icon } from "../Icon/Icon";
import { Spinner } from "../Spinner/Spinner";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { IconButton } from "../IconButton/IconButton";
import type { KanbanTaskItem } from "../KanbanCard/KanbanCard";
import { kanbanStatusLabel } from "../KanbanStatusChips/KanbanStatusChips";
import { cx, DeviceScope, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./KanbanTaskPanel.css";

/** The task shown in the panel: a board task plus what only the detail view shows. */
export interface KanbanTaskDetailItem extends KanbanTaskItem {
  /** Description, shown as plain selectable text (Markdown is not rendered). */
  body?: string;
  /** What came out of the task (the worker's latest summary or the result typed on Complete). */
  result?: string;
  /** Model override, e.g. `claude-sonnet-5-5`; omitted shows a muted "Profile default". */
  modelOverride?: string;
  /** Reasoning effort label shown after the model, e.g. `High`. */
  reasoningEffort?: string;
}

/** A problem Hermes reports on the task ("Needs attention"). */
export interface KanbanDiagnosticItem {
  /** Short headline, e.g. "Worker has not reported in a while". */
  title: string;
  /** Optional second line. */
  detail?: string;
  /** `warning` tints the card amber, `error` red. */
  severity: "warning" | "error";
}

/** A child task under "Subtasks". */
export interface KanbanSubtaskItem {
  /** Task id, e.g. `t_child1`. */
  id: string;
  /** Child task title. */
  title: string;
  /** Child status key, shown capitalised. */
  status: string;
  /** The child's result summary, on a second line. */
  summary?: string;
}

/** A comment on the task. */
export interface KanbanCommentItem {
  /** Profile or user who wrote it, e.g. `coder`. */
  author: string;
  /** Preformatted time, e.g. `2026-05-28` or `3h ago`. */
  when?: string;
  /** Comment text. */
  body: string;
}

/** A home channel the task can post its updates to ("Notify"). */
export interface KanbanChannelItem {
  /** Channel name, e.g. `Ops chat`. */
  name: string;
  /** Platform, e.g. `telegram`, `discord`. */
  platform: string;
  /** Updates are posted there (switch on). */
  subscribed: boolean;
  /** The switch is waiting for the server (disabled). */
  switching?: boolean;
}

/** A file attached to the task. */
export interface KanbanAttachmentItem {
  /** File name, e.g. `spec.pdf`. */
  filename: string;
  /** Size in bytes, shown as `2.0 KB`. */
  size: number;
}

/** A worker run of the task. */
export interface KanbanRunItem {
  /** Run number, shown as `#7`. */
  id: number | string;
  /** Profile that ran it, e.g. `coder`; "worker" when omitted. */
  profile?: string;
  /** Still running: shows "running" and, while the task runs, a Terminate button. */
  active?: boolean;
  /** Outcome of a finished run, e.g. `completed`, `crashed`, `blocked`. */
  outcome?: string;
  /** Error or summary on a second line. */
  detail?: string;
}

/** An entry under "History". */
export interface KanbanEventItem {
  /** Event kind with spaces, e.g. `status changed`, `assigned`. */
  kind: string;
  /** Preformatted time, e.g. `2h ago`. */
  when?: string;
}

export interface KanbanTaskPanelProps {
  /** The task; omit while `state` is `loading` or `error`. */
  task?: KanbanTaskDetailItem;
  /** `ready` shows the task, `loading` a spinner, `error` "Could not load the task" with Retry. */
  state?: "ready" | "loading" | "error";
  /**
   * `dialog`: the wide-screen dialog (560px wide, 720px tall, 28px radius).
   * `sheet`: the phone bottom sheet with its drag handle. `plain`: no frame.
   */
  frame?: "dialog" | "sheet" | "plain";
  /**
   * `apple` presents the task the way iOS does. `sheet` (iPhone): a bottom
   * sheet with a 36x5 grabber, a 12px top radius and two detents, see
   * `detent`. `dialog` (iPad, Mac): a centred form sheet, 560px wide, with
   * 12px of top padding and a 12px radius. The switches are Apple toggles.
   * The panel's content is the same.
   * Inherits the provider's platform.
   */
  platform?: Platform;
  /** Apple `sheet` only: the height the sheet is drawn at. `medium` fills half the parent's height, `large` all of it (the default). A static choice: the grabber is drawn but has no gesture, so pick the detent to preview. */
  detent?: "medium" | "large";
  /** Height of the frame in px; the content scrolls inside it. Defaults to 720 for a dialog; `auto` grows to fit the content. */
  height?: number | "auto";
  /** Problems listed first under "Needs attention". */
  diagnostics?: KanbanDiagnosticItem[];
  /** Ids of the tasks this one depends on, as removable chips. */
  parents?: string[];
  /** Child tasks under "Subtasks"; the section is hidden when empty. */
  subtasks?: KanbanSubtaskItem[];
  /** Comments, oldest first. */
  comments?: KanbanCommentItem[];
  /** Notify channels; the section is hidden when empty. */
  channels?: KanbanChannelItem[];
  /** Attached files. */
  attachments?: KanbanAttachmentItem[];
  /** An upload or download is running: a progress bar and disabled file buttons. */
  transferring?: boolean;
  /** Worker runs, oldest first (shown newest first); the section is hidden when empty. */
  runs?: KanbanRunItem[];
  /** History events, oldest first (shown newest first); hidden when empty. */
  events?: KanbanEventItem[];
  /** Estimate result next to the Estimate button, e.g. "About 2 hours"; `rationale` on a line below. */
  estimate?: { summary: string; rationale?: string };
  /** The estimate is being worked out: a spinner and a disabled Estimate button. */
  estimating?: boolean;
  /** Start with the Runs section expanded. */
  defaultRunsOpen?: boolean;
  /** Start with the History section expanded. */
  defaultHistoryOpen?: boolean;
  /** Start with the "Move to…" menu open. */
  defaultMoveMenuOpen?: boolean;
  /** Pencil pressed (the app opens the title and description editor). */
  onEdit?: () => void;
  /** Assignee row pressed. */
  onAssign?: () => void;
  /** Priority row pressed. */
  onPrioritise?: () => void;
  /** A status was picked in "Move to…". */
  onMove?: (status: string) => void;
  /** Triage: Decompose pressed. */
  onDecompose?: () => void;
  /** Triage: Specify pressed. */
  onSpecify?: () => void;
  /** Running: Reclaim pressed. */
  onReclaim?: () => void;
  /** Complete pressed. */
  onComplete?: () => void;
  /** Block pressed. */
  onBlock?: () => void;
  /** Estimate pressed. */
  onEstimate?: () => void;
  /** Model row pressed (the app opens the model picker). */
  onEditModel?: () => void;
  /** "Add" dependency chip pressed. */
  onAddParent?: () => void;
  /** A dependency chip's close pressed. */
  onRemoveParent?: (id: string) => void;
  /** A comment was sent from the field. */
  onSendComment?: (text: string) => void;
  /** A Notify switch was flipped. */
  onToggleChannel?: (channel: KanbanChannelItem, on: boolean) => void;
  /** "Attach file" pressed. */
  onAttach?: () => void;
  /** An attachment's save button pressed. */
  onDownload?: (attachment: KanbanAttachmentItem) => void;
  /** An attachment's remove button pressed. */
  onRemoveAttachment?: (attachment: KanbanAttachmentItem) => void;
  /** Terminate pressed on the active run. */
  onTerminateRun?: (run: KanbanRunItem) => void;
  /** "Worker log" pressed. */
  onShowLog?: () => void;
  /** Archive pressed in the footer. */
  onArchive?: () => void;
  /** Delete pressed in the footer. */
  onDelete?: () => void;
  /** Retry pressed in the `error` state. */
  onRetry?: () => void;
}

const settableStatuses = [
  "triage",
  "todo",
  "scheduled",
  "ready",
  "blocked",
  "review",
  "done",
];

/**
 * A Kanban task's detail: id and status, title, assignee/priority/move
 * chips, the actions its status allows, description, model, dependencies,
 * comments, notify channels, attachments, runs and history. A dialog on a
 * wide screen, a bottom sheet on a phone.
 */
export function KanbanTaskPanel({
  task,
  state = "ready",
  frame = "dialog",
  platform,
  detent = "large",
  height,
  diagnostics = [],
  parents = [],
  subtasks = [],
  comments = [],
  channels = [],
  attachments = [],
  transferring = false,
  runs = [],
  events = [],
  estimate,
  estimating = false,
  defaultRunsOpen = false,
  defaultHistoryOpen = false,
  defaultMoveMenuOpen = false,
  onEdit,
  onAssign,
  onPrioritise,
  onMove,
  onDecompose,
  onSpecify,
  onReclaim,
  onComplete,
  onBlock,
  onEstimate,
  onEditModel,
  onAddParent,
  onRemoveParent,
  onSendComment,
  onToggleChannel,
  onAttach,
  onDownload,
  onRemoveAttachment,
  onTerminateRun,
  onShowLog,
  onArchive,
  onDelete,
  onRetry,
}: KanbanTaskPanelProps) {
  const [runsOpen, setRunsOpen] = useState(defaultRunsOpen);
  const [historyOpen, setHistoryOpen] = useState(defaultHistoryOpen);
  const [comment, setComment] = useState("");

  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const frameClass = cx(
    "h-kanban-task-panel",
    `h-kanban-task-panel--${frame}`,
    apple && "h-kanban-task-panel--apple",
  );
  const sized =
    apple && frame === "sheet" && height === undefined
      ? detent === "medium"
        ? "50%"
        : "100%"
      : undefined;
  const frameStyle = {
    height:
      height === "auto"
        ? undefined
        : (height ?? sized ?? (frame === "dialog" ? 720 : undefined)),
  };

  if (state !== "ready" || !task) {
    return (
      <PlatformScope platform={resolvedPlatform}>
        <div className={frameClass} style={frameStyle}>
          {frame === "sheet" ? <SheetHandle /> : null}
          <div className="h-kanban-task-panel__center">
            {state === "error" ? (
              <>
                <span>Could not load the task</span>
                <Button onClick={onRetry}>Retry</Button>
              </>
            ) : (
              <Spinner size={36} />
            )}
          </div>
        </div>
      </PlatformScope>
    );
  }

  const send = () => {
    const text = comment.trim();
    if (!text) return;
    onSendComment?.(text);
    setComment("");
  };
  const priority = task.priority ?? 0;
  const moveStatuses = settableStatuses.filter((status) => status !== task.status);

  return (
    <PlatformScope platform={resolvedPlatform}>
      <div className={frameClass} style={frameStyle}>
        {frame === "sheet" ? <SheetHandle /> : null}
        <div className="h-kanban-task-panel__scroll">
          <div className="h-kanban-task-panel__meta">
            {`${task.id} · ${kanbanStatusLabel(task.status ?? "")}`}
          </div>
          <div className="h-kanban-task-panel__title-row">
            <h2 className="h-kanban-task-panel__title">{task.title}</h2>
            <IconButton icon="edit" label="Edit" onClick={onEdit} />
          </div>
          <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
            <GroupedSection>
              <GroupedValueRow title="Assignee" value={task.assignee ?? "Unassigned"} onClick={onAssign} />
              <GroupedValueRow title="Priority" value={priority === 0 ? "Normal" : `P${priority}`} onClick={onPrioritise} />
              {task.tenant ? <GroupedValueRow title="Tenant" value={task.tenant} /> : null}
              <GroupedMenuRow title="Move to…" open={defaultMoveMenuOpen} placeholder={kanbanStatusLabel(task.status ?? "")}
                options={moveStatuses.map(kanbanStatusLabel)}
                onSelect={(index) => onMove?.(moveStatuses[index])} />
            </GroupedSection>
            {task.status !== "done" ? (
              <GroupedSection header="Actions">
                {task.status === "triage" ? <>
                  <GroupedRow title="Decompose" chevron={false} onClick={onDecompose} />
                  <GroupedRow title="Specify" chevron={false} onClick={onSpecify} />
                </> : null}
                {task.status === "running" ? <GroupedRow title="Reclaim" chevron={false} onClick={onReclaim} /> : null}
                <GroupedRow title="Complete" chevron={false} onClick={onComplete} />
                {task.status !== "blocked" ? <GroupedRow title="Block" chevron={false} onClick={onBlock} /> : null}
              </GroupedSection>
            ) : null}
            <GroupedSection className="h-kanban-task-panel__metadata" footer={estimate?.rationale}>
              <GroupedRow title="Estimate" icon="speed" chevron={false}
                disabled={estimating} onClick={onEstimate}
                subtitle={estimating ? undefined : estimate?.summary}
                trailing={estimating ? <Spinner size={16} label="Estimating" /> : undefined} />
            </GroupedSection>
          </DeviceScope>

          <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
            <div className="h-kanban-task-panel__metadata">
              {diagnostics.length ? (
                <GroupedSection header="Needs attention">
                  {diagnostics.map((d) => (
                    <GroupedRow key={d.title} title={d.title} wrapTitle subtitle={d.detail || undefined}
                      chevron={false} leading={<Icon name="warning" size={20}
                        style={{ color: d.severity === "warning" ? "var(--h-warning)" : "var(--h-error)" }} />} />
                  ))}
                </GroupedSection>
              ) : null}
              {task.body != null ? (
                <GroupedSection header="Description"><div className="h-kanban-task-panel__group-text">{task.body}</div></GroupedSection>
              ) : null}
              {task.result != null ? (
                <GroupedSection header="Result"><div className="h-kanban-task-panel__group-text">{task.result}</div></GroupedSection>
              ) : null}
              <GroupedSection header="Model">
                <GroupedRow title={task.modelOverride ?? "Profile default"}
                  subtitle={task.reasoningEffort} onClick={onEditModel} />
              </GroupedSection>
              <GroupedSection header="Depends on">
                {parents.map((id) => (
                  <GroupedRow key={id} title={id} wrapTitle chevron={false}
                    trailing={<IconButton icon="close" label={`Remove dependency ${id}`}
                      disabled={!onRemoveParent}
                      onClick={onRemoveParent ? () => onRemoveParent(id) : undefined} />} />
                ))}
                <GroupedRow title="Add" icon="add" chevron={false} onClick={onAddParent} />
              </GroupedSection>
              {subtasks.length ? (
                <GroupedSection header="Subtasks">
                  {subtasks.map((c) => (
                    <GroupedRow key={c.id} title={c.title} wrapTitle chevron={false}
                      subtitle={`${c.id} · ${kanbanStatusLabel(c.status)}${c.summary == null ? "" : `\n${c.summary}`}`} />
                  ))}
                </GroupedSection>
              ) : null}
            </div>
          </DeviceScope>

          <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
            <GroupedSection header={`Comments (${comments.length})`}>
              {comments.map((c, i) => (
                <div key={i} className="h-kanban-task-panel__comment">
                  <div className="h-kanban-task-panel__subtle">
                    {c.when ? `${c.author} · ${c.when}` : c.author}
                  </div>
                  <div className="h-kanban-task-panel__text">{c.body}</div>
                </div>
              ))}
              <div onKeyDown={(e) => { if (e.key === "Enter") send(); }}>
                <GroupedTextFieldRow label="Comment" hint="Add a comment…"
                  value={comment} onChange={setComment} />
              </div>
              <GroupedRow title="Send" icon="send" chevron={false} onClick={send} />
            </GroupedSection>
          </DeviceScope>

          {channels.length ? (
            <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
              <GroupedSection header="Notify">
                {channels.map((c) => (
                  <GroupedSwitchRow key={c.platform} title={`Post updates to ${c.name}`} wrapTitle
                    subtitle={c.platform} checked={c.subscribed} disabled={c.switching}
                    onChange={onToggleChannel ? (on) => onToggleChannel(c, on) : undefined} />
                ))}
              </GroupedSection>
            </DeviceScope>
          ) : null}

          <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
            <GroupedSection header="Attachments">
              {transferring ? (
                <div className="h-kanban-task-panel__progress" role="progressbar">
                  <div className="h-kanban-task-panel__progress-value" />
                </div>
              ) : null}
              {attachments.map((a) => (
                <GroupedRow key={a.filename} title={a.filename} wrapTitle
                  icon="attach_file" subtitle={kanbanFileSize(a.size)} trailing={<>
                    <IconButton icon="download" label={`Save ${a.filename}`}
                      disabled={transferring} onClick={() => onDownload?.(a)} />
                    <IconButton icon="close" label={`Remove ${a.filename}`}
                      disabled={transferring} onClick={() => onRemoveAttachment?.(a)} />
                  </>} />
              ))}
              <GroupedRow title="Attach file" icon="attach_file" chevron={false}
                disabled={transferring} onClick={onAttach} />
            </GroupedSection>
          </DeviceScope>

          {runs.length ? (
            <Expander
              title={`Runs (${runs.length})`}
              open={runsOpen}
              onToggle={() => setRunsOpen(!runsOpen)}
            >
              <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
                <GroupedSection>
                  {[...runs].reverse().map((r) => (
                    <div key={r.id} className="h-kanban-task-panel__activity-row"><GroupedRow wrapTitle
                      title={`#${r.id} · ${r.profile ?? "worker"} · ${r.active ? "running" : (r.outcome ?? "")}`}
                      subtitle={r.detail} trailing={r.active && task.status === "running" ? (
                        <Button variant="text" compact onClick={() => onTerminateRun?.(r)}>
                          Terminate
                        </Button>
                      ) : undefined} /></div>
                  ))}
                  <GroupedRow title="Worker log" icon="terminal" chevron={false} onClick={onShowLog} />
                </GroupedSection>
              </DeviceScope>
            </Expander>
          ) : null}
          {events.length ? (
            <Expander
              title="History"
              open={historyOpen}
              onToggle={() => setHistoryOpen(!historyOpen)}
            >
              <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
                <GroupedSection>
                  {[...events].reverse().map((e, i) => (
                    <GroupedRow key={i} title={e.kind} wrapTitle value={e.when} />
                  ))}
                </GroupedSection>
              </DeviceScope>
            </Expander>
          ) : null}

          <DeviceScope device={frame === "sheet" ? "touch" : "mac"}>
            <GroupedSection>
              <GroupedRow title="Archive" icon="archive" chevron={false} onClick={onArchive} />
              <GroupedRow title="Delete" leading={<Icon name="delete" style={{ color: "var(--h-error)" }} />} destructive chevron={false} onClick={onDelete} />
            </GroupedSection>
          </DeviceScope>
        </div>
      </div>
    </PlatformScope>
  );
}

function SheetHandle() {
  return <div className="h-kanban-task-panel__handle" aria-hidden />;
}

function Expander({
  title,
  open,
  onToggle,
  children,
}: {
  title: string;
  open: boolean;
  onToggle: () => void;
  children: ReactNode;
}) {
  return (
    <div
      className={[
        "h-kanban-task-panel__expander",
        open ? "h-kanban-task-panel__expander--open" : null,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      <button
        type="button"
        className="h-kanban-task-panel__expander-head"
        aria-expanded={open}
        onClick={onToggle}
      >
        <span>{title}</span>
        <Icon
          name={open ? "expand_less" : "expand_more"}
          apple={false}
          size={24}
        />
      </button>
      {open ? <div>{children}</div> : null}
    </div>
  );
}

function kanbanFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
