import { useMemo, useState, type ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { Menu, MenuAnchor, useMenuState } from "../Menu/Menu";
import { cx } from "../../platform";
import "./MacSourceList.css";

/**
 * The Mac sidebar as a source list (the app's `mac_source_list.dart`,
 * `MacThreadRow` and `thread_sections.dart`): 28px rows with a 6px radius, a
 * 10% fill when selected and 5% under the pointer, and chats in sections by
 * when they were last active or, with folder grouping (#434), by folder. The
 * sectioned list and the grouping menu serve the touch and Material sidebar
 * too. Internal to ThreadSidebar and ShellNavigation.
 */

/** The sections a sidebar sorts its chats into by recency, in this order: pinned chats, then by when they were last active. Empty sections are left out. */
export type ThreadSection =
  "pinned" | "today" | "previous-7-days" | "previous-30-days" | "older";

/** How the sidebar groups its chats: by when they were last active (`recent`) or by the folder they ran in (`folder`, #434). */
export type ThreadGrouping = "recent" | "folder";

const sectionLabels: Record<ThreadSection, string> = {
  pinned: "Pinned",
  today: "Today",
  "previous-7-days": "Previous 7 days",
  "previous-30-days": "Previous 30 days",
  older: "Older",
};

const DAY = 24 * 60 * 60 * 1000;

interface SectionedThread {
  id: string;
  pinned?: boolean;
  updatedAt?: string;
  folderPath?: string;
}

interface ThreadGroup<T> {
  /** Folding key: a `ThreadSection`, `folder:<path>` or `no-folder`. */
  id: string;
  label: string;
  threads: T[];
}

/** `threads` by section as the app's `groupThreads` splits them, counting days back from local midnight of `now`; a thread without `updatedAt` counts as today's. */
function groupThreads<T extends SectionedThread>(threads: T[], now: Date) {
  const today = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
  ).getTime();
  const weekAgo = today - 7 * DAY;
  const monthAgo = today - 30 * DAY;
  const sectionOf = (t: T): ThreadSection => {
    if (t.pinned) return "pinned";
    const at = t.updatedAt ? new Date(t.updatedAt).getTime() : today;
    if (at >= today) return "today";
    if (at >= weekAgo) return "previous-7-days";
    if (at >= monthAgo) return "previous-30-days";
    return "older";
  };
  const bySection = new Map<ThreadSection, T[]>();
  for (const t of threads) {
    const section = sectionOf(t);
    let items = bySection.get(section);
    if (!items) bySection.set(section, (items = []));
    items.push(t);
  }
  return (Object.keys(sectionLabels) as ThreadSection[]).flatMap(
    (section): ThreadGroup<T>[] => {
      const items = bySection.get(section);
      return items
        ? [{ id: section, label: sectionLabels[section], threads: items }]
        : [];
    },
  );
}

/**
 * `threads` by folder as the app's `groupThreadsByFolder` splits them:
 * pinned first, then each folder in the order its first chat comes (named
 * by its last path segment, or the whole path where two share one), then
 * "No folder".
 */
function groupThreadsByFolder<T extends SectionedThread>(threads: T[]) {
  const pinned: T[] = [];
  const unassigned: T[] = [];
  const folders = new Map<string, T[]>();
  for (const t of threads) {
    if (t.pinned) pinned.push(t);
    else if (t.folderPath) {
      let items = folders.get(t.folderPath);
      if (!items) folders.set(t.folderPath, (items = []));
      items.push(t);
    } else unassigned.push(t);
  }
  const bases = new Map(
    [...folders.keys()].map((path) => [
      path,
      path.split(/[/\\]/).filter(Boolean).pop() ?? path,
    ]),
  );
  const names = new Map<string, number>();
  for (const base of bases.values())
    names.set(base, (names.get(base) ?? 0) + 1);
  const groups: ThreadGroup<T>[] = [];
  if (pinned.length)
    groups.push({ id: "pinned", label: "Pinned", threads: pinned });
  for (const [path, items] of folders)
    groups.push({
      id: `folder:${path}`,
      label: (names.get(bases.get(path)!) ?? 0) > 1 ? path : bases.get(path)!,
      threads: items,
    });
  if (unassigned.length)
    groups.push({ id: "no-folder", label: "No folder", threads: unassigned });
  return groups;
}

export interface MacSourceListRowProps {
  /** Material Symbols name, drawn 16px in the muted color (destinations only). */
  icon?: string;
  label: string;
  /** Muted 11px text at the trailing edge: "All profiles". */
  caption?: string;
  /** Buttons shown at the trailing edge under the pointer. */
  actions?: ReactNode;
  selected?: boolean;
  /** Draw the hover fill and the actions as if under the pointer. */
  hovered?: boolean;
  onClick?: () => void;
  onContextMenu?: (e: React.MouseEvent) => void;
  rowRef?: (el: HTMLDivElement | null) => void;
}

/** One 28px source-list row: a destination (icon, label, caption) or a chat (label, hover actions). */
export function MacSourceListRow({
  icon,
  label,
  caption,
  actions,
  selected = false,
  hovered = false,
  onClick,
  onContextMenu,
  rowRef,
}: MacSourceListRowProps) {
  return (
    <div
      ref={rowRef}
      className={cx(
        "h-mac-row",
        selected && "h-mac-row--selected",
        hovered && "h-mac-row--hovered",
      )}
      role="button"
      tabIndex={0}
      aria-current={selected ? "true" : undefined}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onClick?.();
        }
      }}
      onContextMenu={onContextMenu}
    >
      {icon ? <Icon name={icon} size={16} className="h-mac-row__icon" /> : null}
      <span className="h-mac-row__title">{label}</span>
      {caption ? <span className="h-mac-row__caption">{caption}</span> : null}
      {actions ? <span className="h-mac-row__actions">{actions}</span> : null}
    </div>
  );
}

/** A 20px button at the trailing edge of a Mac chat row (Archive, More). */
export function MacRowButton({
  icon,
  label,
  title,
  onPress,
}: {
  icon: string;
  label: string;
  title: string;
  onPress: () => void;
}) {
  return (
    <button
      type="button"
      className="h-mac-row__button"
      aria-label={label}
      title={title}
      onMouseDown={(e) => e.stopPropagation()}
      onClick={(e) => {
        e.stopPropagation();
        onPress();
      }}
    >
      <Icon name={icon} size={14} />
    </button>
  );
}

/** Which look a sectioned list takes: the Mac source list, or the touch and Material sidebar. */
export type ListVariant = "mac" | "touch" | "material";

/**
 * The "…" that picks how the chats are grouped (the app's
 * `ThreadGroupingMenu`): a menu with "Group by", then Recent and Folder with
 * the current one checked. 24px on a Mac, 44px elsewhere.
 */
function GroupingMenuButton({
  grouping,
  variant,
  defaultOpen = false,
  onChange,
}: {
  grouping: ThreadGrouping;
  variant: ListVariant;
  defaultOpen?: boolean;
  onChange?: (grouping: ThreadGrouping) => void;
}) {
  const [open, setOpen] = useMenuState(defaultOpen);
  return (
    <MenuAnchor className="h-grouping">
      <button
        type="button"
        className={cx("h-grouping__button", `h-grouping__button--${variant}`)}
        aria-label="Group chats"
        title="Group chats"
        onMouseDown={(e) => e.stopPropagation()}
        onClick={() => setOpen((o) => !o)}
      >
        <Icon name="more_horiz" size={14} />
      </button>
      {open ? (
        <Menu<ThreadGrouping>
          align="end"
          label="Group chats"
          device={variant === "mac" ? "mac" : "touch"}
          items={[
            { label: "Group by", info: true },
            {
              value: "recent",
              label: "Recent",
              checked: grouping === "recent",
            },
            {
              value: "folder",
              label: "Folder",
              checked: grouping === "folder",
            },
          ]}
          onSelect={(item) => {
            setOpen(false);
            if (item.value) onChange?.(item.value);
          }}
        />
      ) : null}
    </MenuAnchor>
  );
}

/** The plain "Chats" heading over a Material list grouped by recency (and over an empty list), with the grouping "…". */
export function ThreadListHeading({
  grouping,
  variant,
  menuOpen,
  onGroupingChange,
}: {
  grouping: ThreadGrouping;
  variant: ListVariant;
  menuOpen?: boolean;
  onGroupingChange?: (grouping: ThreadGrouping) => void;
}) {
  return (
    <div className={cx("h-thread-heading", `h-thread-heading--${variant}`)}>
      <span className="h-thread-heading__label">Chats</span>
      <GroupingMenuButton
        grouping={grouping}
        variant={variant}
        defaultOpen={menuOpen}
        onChange={onGroupingChange}
      />
    </div>
  );
}

export interface SectionedThreadListProps<T> {
  threads: T[];
  grouping: ThreadGrouping;
  variant: ListVariant;
  /** The day recency sections count back from. */
  now: Date;
  /** Section ids folded away initially. */
  defaultFolded?: string[];
  /** Open the first header's grouping menu initially. */
  groupingMenuOpen?: boolean;
  onGroupingChange?: (grouping: ThreadGrouping) => void;
  /** Draws one chat's row. */
  renderRow: (thread: T) => ReactNode;
}

/**
 * The chats under section headers that fold away on a click (the app's
 * `_SectionedThreadList`): by recency, or by folder with each folder's count.
 * The first header carries the grouping "…". On a Mac the headers are the
 * source list's 11px bold ones whose chevron shows on hover; on touch and
 * Material 13px semibold ones with the chevron always shown.
 */
export function SectionedThreadList<T extends SectionedThread>({
  threads,
  grouping,
  variant,
  now,
  defaultFolded,
  groupingMenuOpen,
  onGroupingChange,
  renderRow,
}: SectionedThreadListProps<T>) {
  const [folded, setFolded] = useState(() => new Set<string>(defaultFolded));
  const toggle = (id: string) =>
    setFolded((prev) => {
      const next = new Set(prev);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  const folder = grouping === "folder";
  const day = now.getTime();
  const groups = useMemo(
    () =>
      folder
        ? groupThreadsByFolder(threads)
        : groupThreads(threads, new Date(day)),
    [folder, threads, day],
  );
  if (!groups.length)
    return (
      <ThreadListHeading
        grouping={grouping}
        variant={variant}
        menuOpen={groupingMenuOpen}
        onGroupingChange={onGroupingChange}
      />
    );
  return groups.map((group, index) => {
    const isFolded = folded.has(group.id);
    const count =
      folder && group.id !== "pinned" ? group.threads.length : undefined;
    return (
      <div key={group.id}>
        <div className="h-section-row">
          <button
            type="button"
            className={variant === "mac" ? "h-mac-section" : "h-thread-section"}
            aria-expanded={!isFolded}
            onClick={() => toggle(group.id)}
          >
            <span className="h-mac-section__label">{group.label}</span>
            {count !== undefined ? (
              <span className="h-section-count">{count}</span>
            ) : null}
            <Icon
              name="expand_more"
              size={14}
              className={cx(
                "h-mac-section__chevron",
                isFolded && "h-mac-section__chevron--folded",
              )}
            />
          </button>
          {index === 0 ? (
            <GroupingMenuButton
              grouping={grouping}
              variant={variant}
              defaultOpen={groupingMenuOpen}
              onChange={onGroupingChange}
            />
          ) : null}
        </div>
        {isFolded ? null : group.threads.map(renderRow)}
      </div>
    );
  });
}
