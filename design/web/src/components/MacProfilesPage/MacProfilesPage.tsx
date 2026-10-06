import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { MacToolbar, MacToolbarButton } from "../MacToolbar/MacToolbar";
import type { Profile } from "../ProfileTile/ProfileTile";
import { StateMessage } from "../StateMessage/StateMessage";
import { cx, PlatformScope } from "../../platform";
import "./MacProfilesPage.css";

/** What a profile's home holds, by the screen that manages it. */
export type ProfileSection =
  "skills" | "messaging" | "plugins" | "mcp" | "helperModels";

const sections: {
  id: ProfileSection;
  label: string;
  detail: string;
  icon: string;
}[] = [
  {
    id: "skills",
    label: "Skills",
    detail: "What the agent knows how to do",
    icon: "auto_awesome",
  },
  {
    id: "messaging",
    label: "Messaging",
    detail: "Chat platforms the agent answers on",
    icon: "smart_toy",
  },
  {
    id: "plugins",
    label: "Plugins",
    detail: "Agent plugins and providers",
    icon: "extension",
  },
  {
    id: "mcp",
    label: "MCP servers",
    detail: "Tools from MCP servers",
    icon: "power",
  },
  {
    id: "helperModels",
    label: "Helper models",
    detail: "Models for side tasks",
    icon: "tune",
  },
];

/** A profile on the Mac Profiles page; `path` is its home directory. */
export interface MacProfile extends Profile {
  /** The profile's home on the server: "~/.hermes/profiles/work". */
  path?: string;
}

export interface MacProfilesPageProps {
  /** The dashboard's profiles. */
  profiles?: MacProfile[];
  /** Name of the selected profile, whose home the right side shows. */
  selected?: string;
  /** How many of each the selected profile holds. A section left out (still loading, or unreadable) shows no count. */
  counts?: Partial<Record<ProfileSection, number>>;
  /** The server's host, in the subtitle: "4 profiles on hermes.example.com". */
  host?: string;
  /** The profiles could not be loaded: "Could not load profiles" with Retry. */
  failed?: boolean;
  onSelect?: (name: string) => void;
  /** A section row was pressed: open its screen for the selected profile. */
  onOpen?: (section: ProfileSection) => void;
  /** The toolbar's New Profile button (the app asks for a name in a dialog). */
  onNewProfile?: () => void;
  onRetry?: () => void;
}

function initials(label: string) {
  const letters = label
    .split(/[\s_\-.@/:]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w.charAt(0).toUpperCase())
    .join("");
  return letters || "?";
}

function Avatar({ label, size }: { label: string; size: number }) {
  return (
    <span
      className="h-mac-profiles__avatar"
      aria-hidden
      style={{ width: size, height: size, fontSize: size * 0.42 }}
    >
      {initials(label)}
    </span>
  );
}

/**
 * The Profiles page of a Mac window (macOS only, a sidebar destination
 * instead of the pushed `ProfilesScreen`): a `MacToolbar` with New Profile,
 * the profiles in a 220px source list on the left, and the selected
 * profile's home on the right: its avatar, name and path, then a card of
 * what it holds (Skills, Messaging, Plugins, MCP servers, Helper models)
 * with a count each, every row opening that screen. Put it in a Mac
 * `AppShell`; it fills its parent.
 */
export function MacProfilesPage({
  profiles = [],
  selected,
  counts = {},
  host,
  failed = false,
  onSelect,
  onOpen,
  onNewProfile,
  onRetry,
}: MacProfilesPageProps) {
  const label = (p: Profile) => p.displayName || p.name;
  const count =
    profiles.length === 1 ? "1 profile" : `${profiles.length} profiles`;
  const profile = profiles.find((p) => p.name === selected);
  return (
    <PlatformScope platform="apple">
      <div className="h-mac-profiles">
        <MacToolbar
          title="Profiles"
          subtitle={host ? `${count} on ${host}` : count}
          border
          actions={
            <MacToolbarButton
              icon="add"
              label="New Profile"
              onClick={onNewProfile}
            />
          }
        />
        {failed && profiles.length === 0 ? (
          <div className="h-mac-profiles__state">
            <StateMessage
              title="Could not load profiles"
              action={<Button onClick={onRetry}>Retry</Button>}
            />
          </div>
        ) : (
          <div className="h-mac-profiles__body">
            <div className="h-mac-profiles__list">
              {profiles.map((p) => (
                <button
                  key={p.name}
                  type="button"
                  aria-pressed={p.name === selected}
                  className={cx(
                    "h-mac-profiles__row",
                    p.name === selected && "h-mac-profiles__row--selected",
                  )}
                  onClick={() => onSelect?.(p.name)}
                >
                  <Avatar label={label(p)} size={28} />
                  <span className="h-mac-profiles__row-text">
                    <span className="h-mac-profiles__row-title">
                      {label(p)}
                    </span>
                    {p.description ? (
                      <span className="h-mac-profiles__row-detail">
                        {p.description}
                      </span>
                    ) : null}
                  </span>
                </button>
              ))}
            </div>
            <div className="h-mac-profiles__detail">
              {profile ? (
                <div className="h-mac-profiles__home">
                  <div className="h-mac-profiles__head">
                    <Avatar label={label(profile)} size={44} />
                    <div>
                      <div className="h-title-md">{label(profile)}</div>
                      {profile.path ? (
                        <div className="h-mono h-muted h-mac-profiles__path">
                          {profile.path}
                        </div>
                      ) : null}
                    </div>
                  </div>
                  <div className="h-mac-profiles__card">
                    {sections.map((s) => (
                      <button
                        key={s.id}
                        type="button"
                        className="h-mac-profiles__section"
                        onClick={() => onOpen?.(s.id)}
                      >
                        <Icon name={s.icon} size={18} className="h-muted" />
                        <span className="h-mac-profiles__row-text">
                          <span className="h-mac-profiles__section-title">
                            {s.label}
                          </span>
                          <span className="h-mac-profiles__row-detail">
                            {s.detail}
                          </span>
                        </span>
                        {counts[s.id] !== undefined ? (
                          <span className="h-muted h-mac-profiles__count">
                            {counts[s.id]}
                          </span>
                        ) : null}
                        <Icon
                          name="chevron_right"
                          size={14}
                          className="h-muted"
                        />
                      </button>
                    ))}
                  </div>
                  <div className="h-mac-profiles__note">
                    Everything here lives in this profile's home directory.
                    Chats, schedules, memory and API keys are also per profile;
                    Kanban and sign-in are shared.
                  </div>
                </div>
              ) : null}
            </div>
          </div>
        )}
      </div>
    </PlatformScope>
  );
}
