import { useState, type ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { cx } from "../../platform";
import "./MacSourceList.css";

/**
 * The Mac sidebar as a source list (the app's `mac_source_list.dart`,
 * `MacThreadRow` and `thread_sections.dart`): 28px rows with a 6px radius, a
 * 10% fill when selected and 5% under the pointer, and chats in sections by
 * when they were last active. Internal to ThreadSidebar and ShellNavigation.
 */

/** The sections a Mac sidebar sorts its chats into, in this order: pinned chats, then by when they were last active. Empty sections are left out. */
export type ThreadSection =
  "pinned" | "today" | "previous-7-days" | "previous-30-days" | "older";

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
  return (Object.keys(sectionLabels) as ThreadSection[]).flatMap((section) => {
    const items = bySection.get(section);
    return items ? [{ section, threads: items }] : [];
  });
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

function MacRowButton({
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

export interface MacThreadListProps<T> {
  threads: T[];
  selectedId: string | null;
  /** The day sections count back from. */
  now: Date;
  defaultFolded?: ThreadSection[];
  hoveredId?: string;
  rowRef: (id: string) => (el: HTMLDivElement | null) => void;
  onSelect?: (id: string) => void;
  onArchive: (id: string) => void;
  /** Opens a chat's menu; `toggle` closes it again when it is already open on that chat. */
  onMenu: (id: string, toggle: boolean) => void;
}

/**
 * The chats under section headers that fold away on a click (the chevron
 * shows on hover, turned while folded). Each chat is a source-list row whose
 * Archive (chats the dashboard holds) and More show under the pointer; More
 * and a right-click open its menu.
 */
export function MacThreadList<
  T extends SectionedThread & { title: string; remote?: boolean },
>({
  threads,
  selectedId,
  now,
  defaultFolded,
  hoveredId,
  rowRef,
  onSelect,
  onArchive,
  onMenu,
}: MacThreadListProps<T>) {
  const [folded, setFolded] = useState(
    () => new Set<ThreadSection>(defaultFolded),
  );
  const toggle = (section: ThreadSection) =>
    setFolded((prev) => {
      const next = new Set(prev);
      if (!next.delete(section)) next.add(section);
      return next;
    });
  return groupThreads(threads, now).map(({ section, threads: items }) => {
    const isFolded = folded.has(section);
    return (
      <div key={section}>
        <button
          type="button"
          className="h-mac-section"
          aria-expanded={!isFolded}
          onClick={() => toggle(section)}
        >
          <span className="h-mac-section__label">{sectionLabels[section]}</span>
          <Icon
            name="expand_more"
            size={14}
            className={cx(
              "h-mac-section__chevron",
              isFolded && "h-mac-section__chevron--folded",
            )}
          />
        </button>
        {isFolded
          ? null
          : items.map((t) => (
              <MacSourceListRow
                key={t.id}
                label={t.title}
                selected={t.id === selectedId}
                hovered={t.id === hoveredId}
                rowRef={rowRef(t.id)}
                onClick={() => onSelect?.(t.id)}
                onContextMenu={(e) => {
                  e.preventDefault();
                  onMenu(t.id, false);
                }}
                actions={
                  <>
                    {t.remote !== false ? (
                      <MacRowButton
                        icon="archive"
                        label="Archive"
                        title="Archive"
                        onPress={() => onArchive(t.id)}
                      />
                    ) : null}
                    <MacRowButton
                      icon="more_horiz"
                      label={`More actions for ${t.title}`}
                      title="More"
                      onPress={() => onMenu(t.id, true)}
                    />
                  </>
                }
              />
            ))}
      </div>
    );
  });
}
