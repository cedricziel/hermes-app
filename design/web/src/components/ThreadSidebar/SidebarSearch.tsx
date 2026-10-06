import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { SegmentedControl } from "../SegmentedControl/SegmentedControl";
import { Spinner } from "../Spinner/Spinner";
import { cx } from "../../platform";
import "./SidebarSearch.css";

/**
 * What the sidebar shows for a chat search (the app's `MacSearchResults`,
 * #399, and `ThreadSearchField`/`ThreadSearchResults`). Internal to
 * ThreadSidebar.
 */

/** One chat a search found. */
export interface ThreadSearchHit {
  /** The chat's id, matched against `selectedId`. */
  id: string;
  /** The chat's title. A hit whose title holds the query is listed under "Chats", the rest under "Messages". */
  title: string;
  /** The matched text, with each match wrapped in `>>>` and `<<<` as the server marks it: "the NAS was >>>rebooting<<< after". */
  snippet?: string;
  /** When the chat was last active (ISO date), shown as "2h ago". */
  updatedAt?: string;
  /** The profile the chat belongs to. On a Mac a hit from a profile other than the sidebar's names it first ("work · …"). */
  profile?: string;
}

/** A chat search, as preview state. */
export interface ThreadSidebarSearch {
  /** The typed query; empty shows the recent searches (Mac) or the chats (elsewhere). */
  query: string;
  /** Mac: where the search looks. Default `profile`. */
  scope?: "profile" | "all-profiles";
  /** Mac: whether the "This profile | All profiles" switch shows (the server can search every profile). Default true. */
  canSearchAllProfiles?: boolean;
  /** `loading` shows a spinner, `failed` "Search failed. Check the connection."; default `done`. */
  status?: "loading" | "failed" | "done";
  /** What the search found, in the server's order. */
  hits?: ThreadSearchHit[];
  /** Mac: earlier queries, newest first, listed while the field is empty. */
  recent?: string[];
}

/** The app's `relativeTime`: "Just now", "5m ago", "3h ago", "Yesterday", "4d ago", else the date. */
export function relativeTime(iso: string | undefined, now: Date) {
  if (!iso) return "";
  const at = new Date(iso);
  const minutes = Math.floor((now.getTime() - at.getTime()) / 60000);
  if (minutes < 1) return "Just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "Yesterday";
  if (days < 7) return `${days}d ago`;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}`;
}

/** `snippet` split into plain and matched parts at its `>>>`/`<<<` marks. */
function snippetParts(snippet: string) {
  return snippet
    .split(/(>>>.*?<<<)/)
    .filter(Boolean)
    .map((part) =>
      part.startsWith(">>>") && part.endsWith("<<<")
        ? { text: part.slice(3, -3), match: true }
        : { text: part, match: false },
    );
}

function Snippet({ hit, profile }: { hit: ThreadSearchHit; profile?: string }) {
  if (!hit.snippet && !profile) return null;
  return (
    <span className="h-search-hit__snippet">
      {profile ? (
        <span className="h-search-hit__profile">{profile} · </span>
      ) : null}
      {snippetParts(hit.snippet ?? "").map((p, i) =>
        p.match ? <mark key={i}>{p.text}</mark> : <span key={i}>{p.text}</span>,
      )}
    </span>
  );
}

function Note({ children }: { children: string }) {
  return <div className="h-search-note">{children}</div>;
}

function Loading() {
  return (
    <div className="h-search-loading">
      <Spinner size={16} color="var(--h-fg)" />
    </div>
  );
}

function GroupHeader({ label, count }: { label: string; count?: number }) {
  return (
    <div className="h-search-group" role="heading" aria-level={3}>
      <span>{label}</span>
      {count !== undefined ? <span>{count}</span> : null}
    </div>
  );
}

/**
 * The Mac sidebar while a search is open: the scope switch, then the recent
 * searches for an empty query, or the hits as "Chats" (title matches) and
 * "Messages", each with a count; "No results for “q”" when nothing matched.
 */
export function MacSearchResults({
  search,
  currentProfile,
  selectedId,
  now,
  onOpen,
  onPickRecent,
  onScopeChange,
}: {
  search: ThreadSidebarSearch;
  currentProfile?: string;
  selectedId: string | null;
  now: Date;
  onOpen?: (hit: ThreadSearchHit) => void;
  onPickRecent?: (query: string) => void;
  onScopeChange?: (scope: "profile" | "all-profiles") => void;
}) {
  const {
    query,
    scope = "profile",
    canSearchAllProfiles = true,
    status = "done",
    hits = [],
    recent = [],
  } = search;
  const trimmed = query.trim();
  const onCurrent = (hit: ThreadSearchHit) =>
    !hit.profile || hit.profile === currentProfile;
  let body;
  if (!trimmed) {
    body = recent.length ? (
      <div className="h-search-list">
        <GroupHeader label="Recent searches" />
        {recent.map((q) => (
          <div
            key={q}
            className="h-mac-row"
            role="button"
            tabIndex={0}
            onClick={() => onPickRecent?.(q)}
          >
            <Icon name="history" size={14} className="h-mac-row__icon" />
            <span className="h-mac-row__title">{q}</span>
          </div>
        ))}
      </div>
    ) : (
      <Note>Search your chats by title or text.</Note>
    );
  } else if (status === "loading") {
    body = <Loading />;
  } else if (status === "failed") {
    body = <Note>Search failed. Check the connection.</Note>;
  } else if (!hits.length) {
    body = <Note>{`No results for “${trimmed}”`}</Note>;
  } else {
    const needle = trimmed.toLowerCase();
    const chats = hits.filter((h) => h.title.toLowerCase().includes(needle));
    const messages = hits.filter((h) => !chats.includes(h));
    body = (
      <div className="h-search-list">
        {(
          [
            ["Chats", chats],
            ["Messages", messages],
          ] as const
        ).map(([label, group]) =>
          group.length ? (
            <div key={label}>
              <GroupHeader label={label} count={group.length} />
              {group.map((hit) => (
                <button
                  key={`${hit.profile}-${hit.id}`}
                  type="button"
                  className={cx(
                    "h-search-hit h-search-hit--mac",
                    hit.id === selectedId &&
                      onCurrent(hit) &&
                      "h-search-hit--selected",
                  )}
                  onClick={() => onOpen?.(hit)}
                >
                  <span className="h-search-hit__head">
                    <span className="h-search-hit__title">{hit.title}</span>
                    <span className="h-search-hit__time">
                      {relativeTime(hit.updatedAt, now)}
                    </span>
                  </span>
                  <Snippet
                    hit={hit}
                    profile={onCurrent(hit) ? undefined : hit.profile}
                  />
                </button>
              ))}
            </div>
          ) : null,
        )}
      </div>
    );
  }
  return (
    <div className="h-mac-search">
      {canSearchAllProfiles ? (
        <div className="h-mac-search__scope">
          <SegmentedControl
            platform="apple"
            label="Search in"
            labels={["This profile", "All profiles"]}
            value={scope === "profile" ? 0 : 1}
            onChange={(i) =>
              onScopeChange?.(i === 0 ? "profile" : "all-profiles")
            }
          />
        </div>
      ) : null}
      <div className="h-mac-search__body">{body}</div>
    </div>
  );
}

/** The search field above the thread list on touch and Material (the app's `ThreadSearchField`): a rounded outline with a search glyph and, holding text, a clear button. */
export function ThreadSearchField({
  query,
  onChange,
}: {
  query: string;
  onChange?: (query: string) => void;
}) {
  return (
    <label className="h-thread-search-field">
      <Icon name="search" size={18} className="h-thread-search-field__icon" />
      <input
        type="search"
        placeholder="Search chats"
        value={query}
        onChange={(e) => onChange?.(e.target.value)}
      />
      {query ? (
        <IconButton
          icon="close"
          label="Clear search"
          size={32}
          tone="muted"
          onClick={() => onChange?.("")}
        />
      ) : null}
    </label>
  );
}

/** What the search found, in place of the thread list on touch and Material (the app's `ThreadSearchResults`). */
export function ThreadSearchResults({
  search,
  selectedId,
  now,
  onOpen,
}: {
  search: ThreadSidebarSearch;
  selectedId: string | null;
  now: Date;
  onOpen?: (hit: ThreadSearchHit) => void;
}) {
  const { status = "done", hits = [] } = search;
  if (status === "loading") return <Loading />;
  if (status === "failed")
    return <Note>Search failed. Check the connection.</Note>;
  if (!hits.length)
    return <Note>{`No chats match "${search.query.trim()}".`}</Note>;
  return (
    <>
      {hits.map((hit) => (
        <button
          key={hit.id}
          type="button"
          className={cx(
            "h-search-hit h-sidebar-row",
            hit.id === selectedId && "h-search-hit--selected",
          )}
          onClick={() => onOpen?.(hit)}
        >
          <span className="h-search-hit__head">
            <span className="h-search-hit__title">{hit.title}</span>
            <span className="h-search-hit__time">
              {relativeTime(hit.updatedAt, now)}
            </span>
          </span>
          <Snippet hit={hit} />
        </button>
      ))}
    </>
  );
}
