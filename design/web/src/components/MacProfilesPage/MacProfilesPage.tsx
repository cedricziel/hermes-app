import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedRow, GroupedTile } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { MacToolbar, MacToolbarButton } from "../MacToolbar/MacToolbar";
import type { Profile } from "../ProfileTile/ProfileTile";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  InitialsAvatar as Avatar,
  initialsOf,
} from "../ThreadSidebar/MacAccount";
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
export type MacProfile = Profile;

export interface MacProfilesPageProps {
  /** The dashboard's profiles. */
  profiles?: MacProfile[];
  /** Name of the selected profile, whose home the right side shows. */
  selected?: string;
  /**
   * How many of each the selected profile holds: skills, messaging
   * platforms switched on, plugins switched on, MCP servers and helper
   * model slots. A section left out (still loading, or unreadable) shows no
   * count. Every count is the selected profile's own, Messaging (#445) and
   * Plugins (#497) included.
   */
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
                <GroupedListView device="mac">
                  <GroupedSection>
                    <GroupedRow
                      title={label(profile)}
                      subtitle={profile.path || undefined}
                      monospaceSubtitle
                      caption={profile.description || undefined}
                      leading={
                        <GroupedTile>{initialsOf(label(profile))}</GroupedTile>
                      }
                    />
                  </GroupedSection>
                  <GroupedSection
                    header="In this profile"
                    dividerIndent="tile"
                    footer="Everything here lives in this profile's home directory. Chats, schedules, memory and API keys are also per profile; Kanban and sign-in are shared."
                  >
                    {sections.map((s) => (
                      <GroupedRow
                        key={s.id}
                        title={s.label}
                        subtitle={s.detail}
                        leading={<GroupedTile icon={s.icon} />}
                        value={counts[s.id]?.toString()}
                        onClick={() => onOpen?.(s.id)}
                      />
                    ))}
                  </GroupedSection>
                </GroupedListView>
              ) : null}
            </div>
          </div>
        )}
      </div>
    </PlatformScope>
  );
}
