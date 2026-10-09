import { Button } from "../Button/Button";
import {
  CreateGroupDialog,
  type CreateGroupDialogProps,
} from "../CreateGroupDialog/CreateGroupDialog";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedRow, GroupedTile } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { IconButton } from "../IconButton/IconButton";
import { MacToolbarButton } from "../MacToolbar/MacToolbar";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import { ScreenState } from "../../screen";
import type { ScreenLayout } from "../../screenFrame";
import {
  cx,
  useAppleDevice,
  useGroupedChrome,
  type AppleDevice,
  type GroupedChrome,
  type Platform,
} from "../../platform";
import "./BotsScreen.css";

/** A managed bot: a profile with Bot Mode metadata. */
export interface BotItem {
  /** The profile's name on the server: "writer". */
  name: string;
  /** The bot's title: "Editor". Its first letter is the row's tile. */
  title: string;
  /** The roster summary, or the profile's description: "Clear writing and careful reviews". Shown under the title; leave out to show `preview`. */
  summary?: string;
  /** The start of the bot's latest reply, shown when there is no summary. */
  preview?: string;
  /** The profile's default model: "claude-sonnet-4". Joins the profile name in the caption. */
  model?: string;
}

/** A profile on the server that is not a bot yet. */
export interface BotProfile {
  /** The profile's name: "plain". */
  name: string;
  /** Its title, when it differs from the name; the name then shows under it. */
  title?: string;
}

/** A hosted group room. */
export interface BotGroupRoom {
  id: string;
  /** "Launch plan". */
  name: string;
  /** The members' display names, in order: ["Writer", "Research", "Analyst"]. */
  members: string[];
  /** A member is working: the row's muted value reads "Working". */
  working?: boolean;
  /** The room waits for an approval or a retry: a warning line "Needs your attention". */
  needsAttention?: boolean;
}

export interface BotsScreenProps {
  /** The managed bots, in the roster's order. */
  bots?: BotItem[];
  /** Profiles that can become bots ("Add an existing profile"). */
  availableProfiles?: BotProfile[];
  /** Names of profiles being added: their Add button spins. */
  adding?: string[];
  /** The search text, matched against title, name and summary of bots and profiles. The field shows while there are bots. */
  query?: string;
  onQueryChange?: (query: string) => void;
  /** `loaded` (default); `loading` (a spinner under the bar); `failed` ("Could not load bots" with Retry); `unsupported` ("Bot Mode is not available", the server needs an update). */
  state?: "loaded" | "loading" | "failed" | "unsupported";
  /**
   * The hosted group rooms. Leave out on a server without hosted groups,
   * which drops the Groups section. With `groupsState` `loading` and no
   * rooms the section shows "Loading groups"; `failed` shows "Could not
   * load groups" with `groupsError` as its warning and Retry.
   */
  groups?: BotGroupRoom[];
  groupsState?: "loaded" | "loading" | "failed";
  /** Why the groups cannot run: "Hosted groups require a server update…". */
  groupsError?: string;
  /** Why rooms cannot run right now (no ready driver). Replaces the Groups footer and disables Create group. */
  groupsUnavailable?: string;
  /** Show the Create group dialog over the screen with these props. */
  createGroup?: CreateGroupDialogProps;
  /** A bot row was pressed: open its chat. */
  onOpenBot?: (name: string) => void;
  /** A bot's "…" (Edit bot): the app opens the edit dialog. */
  onEditBot?: (name: string) => void;
  /** A profile's Add. */
  onAddProfile?: (name: string) => void;
  onOpenGroup?: (id: string) => void;
  /** "Create group" (needs at least 2 bots). */
  onCreateGroup?: () => void;
  /** The bar's "+" (Create bot). */
  onCreateBot?: () => void;
  /** The bar's Refresh, which reloads the roster and the groups. */
  onRefresh?: () => void;
  onRetry?: () => void;
  onRetryGroups?: () => void;
  /** `phone` or `desktop`. Under `apple`, `desktop` draws the Mac window (52px toolbar with "3 bots" under the title, the search field in it, 600px column). */
  layout?: ScreenLayout;
  /** `apple`: the iOS bar and groups, or the Mac toolbar with `layout="desktop"`. `material`: the 56px bar and Material groups. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

const initial = (title: string) => title.charAt(0).toUpperCase() || "?";

/** The small Add button of a profile row (the app's `InstallButton`): a filled pill on iOS, a bordered push button on a Mac, an outlined pill on Material; a spinner while adding. */
function AddButton({
  chrome,
  busy,
  onClick,
}: {
  chrome: GroupedChrome;
  busy: boolean;
  onClick?: () => void;
}) {
  return (
    <Button
      variant={chrome === "ios" ? "filled" : "outlined"}
      compact
      disabled={busy}
      className={cx("h-bots-add", `h-bots-add--${chrome}`)}
      onClick={onClick}
    >
      {busy ? <Spinner size={chrome === "mac" ? 12 : 16} /> : "Add"}
    </Button>
  );
}

/**
 * The Bots destination (`BotModeRosterScreen`) on the clean settings look:
 * a `SettingsScaffold` "Bots" with Refresh and "+" (Create bot) in the bar
 * and "Search bots" under it (in the toolbar on a Mac, with "3 bots" as the
 * subtitle). Then inset groups: "Bots" (an initial tile, the title, the
 * summary, a caption "writer · claude-sonnet-4" and a "…" that edits the
 * bot), "Add an existing profile" (profiles with an Add button) and
 * "Groups" (hosted rooms with their members, "Working" as a muted value, a
 * "Needs your attention" warning, and a "Create group" row). Explanations
 * are the groups' footers. `createGroup` draws `CreateGroupDialog` over it.
 */
export function BotsScreen({
  bots = [],
  availableProfiles = [],
  adding = [],
  query = "",
  onQueryChange,
  state = "loaded",
  groups,
  groupsState = "loaded",
  groupsError,
  groupsUnavailable,
  createGroup,
  onOpenBot,
  onEditBot,
  onAddProfile,
  onOpenGroup,
  onCreateGroup,
  onCreateBot,
  onRefresh,
  onRetry,
  onRetryGroups,
  layout = "phone",
  platform,
  device,
}: BotsScreenProps) {
  const appleDevice = useAppleDevice(layout, device);
  const chrome = useGroupedChrome(platform, appleDevice);
  const mac = chrome === "mac";
  const ready = state === "loaded";
  const q = query.trim().toLowerCase();
  const matches = (text: string) => text.toLowerCase().includes(q);
  const shownBots = bots.filter((b) =>
    matches(`${b.title} ${b.name} ${b.summary ?? ""}`),
  );
  const shownProfiles = availableProfiles.filter((p) =>
    matches(`${p.title ?? ""} ${p.name}`),
  );
  const canCreateGroup = !groupsUnavailable && bots.length >= 2;

  return (
    <SettingsScaffold
      title="Bots"
      subtitle={mac && ready ? `${bots.length} bots` : undefined}
      search={
        ready && bots.length
          ? { query, hint: "Search bots", onChange: onQueryChange }
          : undefined
      }
      actions={[
        { icon: "refresh", label: "Refresh", onClick: onRefresh },
        {
          icon: "add",
          label: "Create bot",
          onClick: onCreateBot,
          disabled: !ready,
        },
      ]}
      platform={platform}
      device={appleDevice}
    >
      {ready ? (
        <GroupedListView>
          {bots.length === 0 ? (
            <StateMessage
              icon="smart_toy"
              title="No bots yet"
              detail="Create a specialist or add a profile you already use."
            />
          ) : shownBots.length === 0 ? (
            <StateMessage
              title="No matching bots"
              detail="Try another name or profile."
            />
          ) : (
            <GroupedSection
              header="Bots"
              dividerIndent="tile"
              footer="Each bot has its own profile, instructions and conversation."
            >
              {shownBots.map((bot) => (
                <GroupedRow
                  key={bot.name}
                  leading={<GroupedTile>{initial(bot.title)}</GroupedTile>}
                  title={bot.title}
                  subtitle={bot.summary || bot.preview || undefined}
                  caption={[bot.name, bot.model].filter(Boolean).join(" · ")}
                  onClick={onOpenBot ? () => onOpenBot(bot.name) : undefined}
                  trailing={
                    mac ? (
                      <MacToolbarButton
                        icon="more_horiz"
                        label="Edit bot"
                        onClick={() => onEditBot?.(bot.name)}
                      />
                    ) : (
                      <IconButton
                        icon="more_horiz"
                        label="Edit bot"
                        size={40}
                        onClick={() => onEditBot?.(bot.name)}
                      />
                    )
                  }
                />
              ))}
            </GroupedSection>
          )}
          {shownProfiles.length ? (
            <GroupedSection
              header="Add an existing profile"
              dividerIndent="tile"
              footer="Profiles on this server that are not bots yet."
            >
              {shownProfiles.map((p) => {
                const title = p.title || p.name;
                return (
                  <GroupedRow
                    key={p.name}
                    leading={<GroupedTile>{initial(title)}</GroupedTile>}
                    title={title}
                    subtitle={title === p.name ? undefined : p.name}
                    trailing={
                      <AddButton
                        chrome={chrome}
                        busy={adding.includes(p.name)}
                        onClick={() => onAddProfile?.(p.name)}
                      />
                    }
                  />
                );
              })}
            </GroupedSection>
          ) : null}
          {groups ? (
            <GroupedSection
              header="Groups"
              dividerIndent="tile"
              footer={
                groupsUnavailable ??
                "Bots in a group work on a task together on the server. A group has 2–6 bots, fixed when it is created."
              }
            >
              {groupsState === "loading" && groups.length === 0 ? (
                <GroupedRow
                  title="Loading groups"
                  trailing={<Spinner size={16} />}
                />
              ) : null}
              {groupsState === "failed" ? (
                <GroupedRow
                  title="Could not load groups"
                  warning={groupsError}
                  trailing={
                    <Button variant="text" compact onClick={onRetryGroups}>
                      Retry
                    </Button>
                  }
                />
              ) : null}
              {groupsState === "loaded" && groups.length === 0 ? (
                <GroupedRow
                  title="No groups yet"
                  subtitle="Create a room with 2–6 bots."
                />
              ) : null}
              {groups.map((room) => (
                <GroupedRow
                  key={room.id}
                  leading={<GroupedTile icon="groups" />}
                  title={room.name}
                  subtitle={`${room.members.length} members · ${room.members.join(", ")}`}
                  warning={
                    room.needsAttention ? "Needs your attention" : undefined
                  }
                  value={room.working ? "Working" : undefined}
                  onClick={() => onOpenGroup?.(room.id)}
                />
              ))}
              <GroupedRow
                leading={<GroupedTile icon="add" />}
                title="Create group"
                chevron={false}
                disabled={!canCreateGroup}
                onClick={onCreateGroup}
              />
            </GroupedSection>
          ) : null}
        </GroupedListView>
      ) : (
        <ScreenState
          state={state === "unsupported" ? "failed" : state}
          failedTitle={
            state === "unsupported"
              ? "Bot Mode is not available"
              : "Could not load bots"
          }
          failedDetail={
            state === "unsupported"
              ? "This server needs a Bot Mode compatible update. Chat and Messaging are still available."
              : undefined
          }
          retryVariant="outlined"
          onRetry={onRetry}
        />
      )}
      {createGroup ? <CreateGroupDialog {...createGroup} /> : null}
    </SettingsScaffold>
  );
}
