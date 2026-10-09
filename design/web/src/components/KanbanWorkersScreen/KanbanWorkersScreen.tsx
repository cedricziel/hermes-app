import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedMenuButtonRow } from "../GroupedRow/GroupedMenuButtonRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import type { AppleDevice, Platform } from "../../platform";
import "../../styles/settings-state.css";

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
  /** Relative start time, e.g. "12m ago". */
  started?: string;
  /** Relative time of the last heartbeat, e.g. "Just now". */
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
  /**
   * A `SettingsScaffold` page. `apple` + `touch` (iPhone): "Kanban" beside
   * the back chevron, the title centred over "2 running", 17px rows in an
   * inset group, "…" opening the iOS pull-down. `apple` + `mac`: the 52px
   * toolbar, 13px rows in a centred 600px column, the compact Mac menu.
   * `material`: the 56px bar, a vertical "⋮" and the Material popup.
   * Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`. Defaults to the enclosing `AppShell`'s, else `touch`. */
  device?: AppleDevice;
  /** A worker row was pressed (the app opens its task). */
  onOpen?: (worker: KanbanWorkerItem) => void;
  /** Inspect process or Terminate picked (the app confirms Terminate). */
  onAction?: (worker: KanbanWorkerItem, action: KanbanWorkerAction) => void;
  /** Refresh or Retry pressed. */
  onRefresh?: () => void;
  /** Back pressed. */
  onBack?: () => void;
}

/**
 * "Active workers", from the Kanban "…" menu: a `SettingsScaffold` with "N
 * running" under the title and Refresh in the bar, then one inset group
 * with a row per worker (task title; task id, run and profile; a caption of
 * start and last heartbeat) and a "…" menu (Inspect process, Terminate).
 * Loading, failed and empty states are centred. Fills its parent.
 */
export function KanbanWorkersScreen({
  workers = [],
  state = "ready",
  error = "Could not load the workers",
  defaultMenuRun,
  platform,
  device,
  onOpen,
  onAction,
  onRefresh,
  onBack,
}: KanbanWorkersScreenProps) {
  return (
    <SettingsScaffold
      title="Active workers"
      subtitle={state === "ready" ? `${workers.length} running` : undefined}
      onBack={onBack ?? (() => {})}
      backLabel="Kanban"
      actions={[{ icon: "refresh", label: "Refresh", onClick: onRefresh }]}
      platform={platform}
      device={device}
    >
      {state === "loading" ? (
        <div className="h-settings-state">
          <Spinner size={36} label="Loading workers" />
        </div>
      ) : state === "error" ? (
        <div className="h-settings-state">
          <StateMessage
            title={error}
            action={<Button onClick={onRefresh}>Retry</Button>}
          />
        </div>
      ) : workers.length === 0 ? (
        <div className="h-settings-state">
          <StateMessage title="No workers are running" />
        </div>
      ) : (
        <GroupedListView>
          <GroupedSection>
            {workers.map((w) => (
              <GroupedMenuButtonRow<KanbanWorkerAction>
                key={w.runId}
                title={w.taskTitle}
                subtitle={[w.taskId, `run #${w.runId}`, w.profile]
                  .filter(Boolean)
                  .join(" · ")}
                caption={
                  [
                    w.started && `started ${w.started}`,
                    w.heartbeat && `heartbeat ${w.heartbeat}`,
                  ]
                    .filter(Boolean)
                    .join(" · ") || undefined
                }
                menuLabel={`Run #${w.runId}`}
                menuOpen={defaultMenuRun === w.runId}
                onClick={() => onOpen?.(w)}
                onAction={(action) => onAction?.(w, action)}
                actions={[
                  { label: "Inspect process", value: "inspect" },
                  {
                    label: "Terminate",
                    value: "terminate",
                    destructive: true,
                  },
                ]}
              />
            ))}
          </GroupedSection>
        </GroupedListView>
      )}
    </SettingsScaffold>
  );
}
