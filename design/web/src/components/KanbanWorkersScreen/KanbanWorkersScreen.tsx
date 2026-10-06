import { useState } from "react";
import { Button } from "../Button/Button";
import { IconButton } from "../IconButton/IconButton";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { ListRow } from "../ListRow/ListRow";
import { Menu, MenuAnchor } from "../Menu/Menu";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./KanbanWorkersScreen.css";

/** A worker process running a Kanban task. */
export interface KanbanWorkerItem {
  /** Run id, shown as "run #7". */
  runId: number | string;
  /** Task id, e.g. `t_run`. */
  taskId: string;
  /** Task title, the row's title. */
  taskTitle: string;
  /** Profile the worker runs as, e.g. `coder`. */
  profile?: string;
  /** Relative start time, e.g. "3 min ago". */
  started?: string;
  /** Relative time of the last heartbeat, e.g. "20 s ago". */
  heartbeat?: string;
}

/** What a worker row's menu asks for. */
export type KanbanWorkerAction = "inspect" | "terminate";

export interface KanbanWorkersScreenProps {
  /** The running workers; ignored while `state` is not `ready`. */
  workers?: KanbanWorkerItem[];
  /** `ready` lists the workers ("No workers are running" when empty), `loading` a spinner, `error` the reason with Retry. */
  state?: "ready" | "loading" | "error";
  /** The failure shown in the `error` state: "Could not load the workers". */
  error?: string;
  /** Run id of the worker whose menu starts open, for previews. */
  defaultMenuRun?: number | string;
  /** `apple`: chevron back button ("Kanban" beside it on an iPhone), 44px rows, iOS or Mac menus. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac` for the row menus. */
  device?: AppleDevice;
  /** `phone` shows the parent's title beside the Apple back chevron. */
  layout?: "phone" | "desktop";
  /** A worker row was pressed (the app opens its task). */
  onOpen?: (worker: KanbanWorkerItem) => void;
  /** Inspect process or Terminate picked (the app confirms Terminate). */
  onAction?: (worker: KanbanWorkerItem, action: KanbanWorkerAction) => void;
  /** Refresh or Retry pressed. */
  onRefresh?: () => void;
  /** Back pressed. */
  onBack?: () => void;
}

function subtitle(w: KanbanWorkerItem): string {
  return [
    `${w.taskId} · run #${w.runId}`,
    w.profile,
    w.started ? `started ${w.started}` : undefined,
    w.heartbeat ? `heartbeat ${w.heartbeat}` : undefined,
  ]
    .filter(Boolean)
    .join(" · ");
}

/**
 * "Active workers", from the Kanban "…" menu: one `ListRow` per running
 * worker (task title; id, run, profile, start and heartbeat) with dividers
 * and a menu (Inspect process, Terminate), a refresh button in the bar, and
 * loading, failed and empty states. Built on `ListDetailLayout` in its
 * `list` layout. Fills its parent.
 */
export function KanbanWorkersScreen({
  workers = [],
  state = "ready",
  error = "Could not load the workers",
  defaultMenuRun,
  platform,
  device,
  layout = "phone",
  onOpen,
  onAction,
  onRefresh,
  onBack,
}: KanbanWorkersScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  const [menu, setMenu] = useState(defaultMenuRun);
  const list =
    state === "loading" ? (
      <div className="h-kanban-workers-screen__center">
        <Spinner />
      </div>
    ) : state === "error" ? (
      <div className="h-kanban-workers-screen__center">
        <StateMessage
          title={error}
          action={<Button onClick={onRefresh}>Retry</Button>}
        />
      </div>
    ) : workers.length === 0 ? (
      <div className="h-kanban-workers-screen__center">
        <StateMessage title="No workers are running" />
      </div>
    ) : (
      <div className="h-kanban-workers-screen__list">
        {workers.map((w) => (
          <ListRow
            key={w.runId}
            grouped={false}
            title={w.taskTitle}
            subtitle={subtitle(w)}
            onClick={() => onOpen?.(w)}
            trailing={
              <MenuAnchor>
                <IconButton
                  icon="more_vert"
                  label={`Run #${w.runId} actions`}
                  onClick={() =>
                    setMenu(menu === w.runId ? undefined : w.runId)
                  }
                />
                {menu === w.runId ? (
                  <Menu<KanbanWorkerAction>
                    align="end"
                    label={`Run #${w.runId}`}
                    device={device}
                    style={{ minWidth: 200 }}
                    items={[
                      { label: "Inspect process", value: "inspect" },
                      { label: "Terminate", value: "terminate" },
                    ]}
                    onSelect={(item) => {
                      setMenu(undefined);
                      if (item.value) onAction?.(w, item.value);
                    }}
                  />
                ) : null}
              </MenuAnchor>
            }
          />
        ))}
      </div>
    );
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ListDetailLayout
        layout="list"
        title="Active workers"
        onBack={onBack ?? (() => {})}
        backLabel={layout === "phone" ? "Kanban" : undefined}
        actions={
          <IconButton icon="refresh" label="Refresh" onClick={onRefresh} />
        }
        list={list}
      />
    </PlatformScope>
  );
}
