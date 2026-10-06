import { useState } from "react";
import { Button } from "../Button/Button";
import { IconButton } from "../IconButton/IconButton";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { ListRow } from "../ListRow/ListRow";
import { Menu, MenuAnchor } from "../Menu/Menu";
import type { KanbanBoardItem } from "../KanbanToolbar/KanbanToolbar";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";

/** What a board row's "…" menu asks for. */
export type KanbanBoardAction = "rename" | "export" | "archive" | "delete";

export interface KanbanBoardsScreenProps {
  /** Every board on the server, as the switcher lists them. */
  boards: KanbanBoardItem[];
  /** Slug of the board on screen: a filled check instead of an empty circle. */
  current?: string;
  /** Slug of the board whose "…" menu starts open, for previews. */
  defaultMenuBoard?: string;
  /**
   * `apple`: a chevron back button with "Kanban" beside it on an iPhone,
   * the iOS type ramp and 44px rows, iOS pull-downs or Mac menus (see
   * `device`). The rows stay a plain list and "New board" a floating
   * button, as in the app. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac` for the row menus; inherited from the enclosing `AppShell`, else `mac`. */
  device?: AppleDevice;
  /** `phone` shows the parent's title beside the Apple back chevron. */
  layout?: "phone" | "desktop";
  /** A board row was pressed: switch to it and go back to the board. */
  onSelect?: (slug: string) => void;
  /** An entry of a row's menu was picked (Archive and Delete only when there is more than one board). */
  onAction?: (slug: string, action: KanbanBoardAction) => void;
  /** "New board" pressed (the app asks for a name). */
  onCreate?: () => void;
  /** The import button in the bar pressed (the app asks for an archive path on the server). */
  onImport?: () => void;
  /** Back pressed. */
  onBack?: () => void;
}

/**
 * "Boards", opened from the board switcher's "Manage boards…": every board
 * as a `ListRow` (name, slug and task count) with a "…" menu (Rename,
 * Export…, Archive, Delete), an import button in the bar and a "New board"
 * floating button. Built on `ListDetailLayout` in its `list` layout. Fills
 * its parent.
 */
export function KanbanBoardsScreen({
  boards,
  current,
  defaultMenuBoard,
  platform,
  device,
  layout = "phone",
  onSelect,
  onAction,
  onCreate,
  onImport,
  onBack,
}: KanbanBoardsScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  const several = boards.length > 1;
  const [menu, setMenu] = useState(defaultMenuBoard);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ListDetailLayout
        layout="list"
        title="Boards"
        onBack={onBack ?? (() => {})}
        backLabel={layout === "phone" ? "Kanban" : undefined}
        actions={
          <IconButton
            icon="file_open"
            label="Import a board"
            onClick={onImport}
          />
        }
        floatingAction={
          <Button icon="add" onClick={onCreate}>
            New board
          </Button>
        }
        list={
          <div>
            {boards.map((b) => (
              <ListRow
                key={b.slug}
                grouped={false}
                icon={b.slug === current ? "check_circle" : "circle"}
                iconFilled={b.slug === current}
                title={b.name}
                subtitle={`${b.slug} · ${b.total} tasks`}
                onClick={() => onSelect?.(b.slug)}
                trailing={
                  <MenuAnchor>
                    <IconButton
                      icon="more_vert"
                      label={`${b.name} actions`}
                      onClick={() =>
                        setMenu(menu === b.slug ? undefined : b.slug)
                      }
                    />
                    {menu === b.slug ? (
                      <Menu<KanbanBoardAction>
                        align="end"
                        label={b.name}
                        device={device}
                        style={{ minWidth: 180 }}
                        items={[
                          { label: "Rename", value: "rename" },
                          { label: "Export…", value: "export" },
                          ...(several
                            ? [
                                { label: "Archive", value: "archive" as const },
                                { label: "Delete", value: "delete" as const },
                              ]
                            : []),
                        ]}
                        onSelect={(item) => {
                          setMenu(undefined);
                          if (item.value) onAction?.(b.slug, item.value);
                        }}
                      />
                    ) : null}
                  </MenuAnchor>
                }
              />
            ))}
          </div>
        }
      />
    </PlatformScope>
  );
}
