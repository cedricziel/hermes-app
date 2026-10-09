import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import type { KanbanBoardItem } from "../KanbanToolbar/KanbanToolbar";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import type { AppleDevice, Platform } from "../../platform";
import { GroupedMenuButtonRow } from "../GroupedRow/GroupedMenuButtonRow";

/** What a board row's "…" menu asks for. */
export type KanbanBoardAction = "rename" | "export" | "archive" | "delete";

export interface KanbanBoardsScreenProps {
  /** Every board on the server, as the switcher lists them. */
  boards: KanbanBoardItem[];
  /** Slug of the board on screen: a muted "Current" before its "…" button. */
  current?: string;
  /** Slug of the board whose "…" menu starts open, for previews. */
  defaultMenuBoard?: string;
  /**
   * A `SettingsScaffold` page. `apple` + `touch` (iPhone): "Kanban" beside
   * the back chevron, the title centred over "3 boards", 17px rows in an
   * inset group, "…" opening the iOS pull-down. `apple` + `mac`: the 52px
   * toolbar, 13px rows in a centred 600px column, the compact Mac menu.
   * `material`: the 56px bar, 56px rows, a vertical "⋮" and the Material
   * popup. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`. Defaults to the enclosing `AppShell`'s, else `touch`. */
  device?: AppleDevice;
  /** A board row was pressed: switch to it and go back to the board. */
  onSelect?: (slug: string) => void;
  /** An entry of a row's menu was picked (Archive and Delete only when there is more than one board). */
  onAction?: (slug: string, action: KanbanBoardAction) => void;
  /** The bar's "+" (New board; the app asks for a name). */
  onCreate?: () => void;
  /** The bar's import button (a folder on Apple; the app asks for an archive path on the server). */
  onImport?: () => void;
  /** Back pressed. */
  onBack?: () => void;
}

/**
 * "Boards", opened from the board switcher's "Manage boards…": a
 * `SettingsScaffold` with "N boards" under the title and Import and "+" in
 * the bar, then one inset group with a row per board (name; slug and task
 * count), "Current" on the open board and a "…" menu (Rename, Export…,
 * Archive, Delete). Fills its parent.
 */
export function KanbanBoardsScreen({
  boards,
  current,
  defaultMenuBoard,
  platform,
  device,
  onSelect,
  onAction,
  onCreate,
  onImport,
  onBack,
}: KanbanBoardsScreenProps) {
  const several = boards.length > 1;
  return (
    <SettingsScaffold
      title="Boards"
      subtitle={boards.length === 1 ? "1 board" : `${boards.length} boards`}
      onBack={onBack ?? (() => {})}
      backLabel="Kanban"
      actions={[
        { icon: "file_open", label: "Import a board", onClick: onImport },
        { icon: "add", label: "New board", onClick: onCreate },
      ]}
      platform={platform}
      device={device}
    >
      <GroupedListView>
        {boards.length > 0 ? (
          <GroupedSection>
            {boards.map((b) => (
              <GroupedMenuButtonRow<KanbanBoardAction>
                key={b.slug}
                title={b.name}
                subtitle={`${b.slug} · ${b.total} ${b.total === 1 ? "task" : "tasks"}`}
                value={b.slug === current ? "Current" : undefined}
                menuLabel={b.name}
                menuOpen={defaultMenuBoard === b.slug}
                onClick={() => onSelect?.(b.slug)}
                onAction={(action) => onAction?.(b.slug, action)}
                actions={[
                  { label: "Rename", value: "rename" },
                  { label: "Export…", value: "export" },
                  ...(several
                    ? [
                        { label: "Archive", value: "archive" as const },
                        {
                          label: "Delete",
                          value: "delete" as const,
                          destructive: true,
                        },
                      ]
                    : []),
                ]}
              />
            ))}
          </GroupedSection>
        ) : null}
      </GroupedListView>
    </SettingsScaffold>
  );
}
