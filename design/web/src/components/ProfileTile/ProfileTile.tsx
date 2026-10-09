import { GroupedRow, GroupedTile } from "../GroupedRow/GroupedRow";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { RowActions } from "../SwipeActions/RowActions";
import { initialsOf } from "../ThreadSidebar/MacAccount";
import {
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";

/** A Hermes profile: its own config, skills, memory and chats on the server. */
export interface Profile {
  /** Profile name on the server, e.g. "default" or "work". */
  name: string;
  /** Display name; shown instead of `name` when set: "Work assistant". */
  displayName?: string;
  /** What the profile is for: "Day job: tickets, reviews and the on-call rota". */
  description?: string;
  /** The profile's home on the server: "/home/hermes/.hermes/profiles/work". The row's subtitle when there is no `description`. */
  path?: string;
  /** Default model, e.g. "hermes-4" or "openai/gpt-5.1". */
  model?: string;
  /** Number of skills it has. */
  skillCount: number;
}

export interface ProfileTileProps {
  /** The profile to show. */
  profile: Profile;
  /** The CLI default profile: a trailing check on Apple, a muted "Active" on Material. */
  active?: boolean;
  /** The row was clicked: switch to this profile. */
  onClick?: () => void;
  /**
   * The profile's default model can be changed: a tune button at the
   * trailing edge (Mac and Material), or on iOS a "Change default model"
   * entry of the row's long-press sheet. Called when it is pressed.
   */
  onChangeModel?: () => void;
  /** iOS only, with `onChangeModel`: draws the long-press action sheet open over the screen, for previews. */
  actionSheetOpen?: boolean;
  /**
   * A row of the Profiles group (`GroupedRow`): the profile's initials in a
   * `GroupedTile`, its label, its description (or home path), and a muted
   * caption of default model and skill count. `apple`: a check marks the
   * active profile. `material`: a muted "Active" value. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` (13px row, tune button) or `touch` (iPhone, iPad: 17px row, no tune button). Inherited from the enclosing `GroupedSection`, else `touch`. */
  device?: AppleDevice;
}

/**
 * One profile in the Profiles group: initials tile, label, description or
 * home, then "model · N skills"; the active one checked (Apple) or marked
 * "Active" (Material), and a button to change its default model. Put it in
 * a `GroupedSection` with `dividerIndent="tile"`.
 */
export function ProfileTile({
  profile,
  active = false,
  onClick,
  onChangeModel,
  actionSheetOpen,
  platform,
  device,
}: ProfileTileProps) {
  const resolvedPlatform = usePlatform(platform);
  const chrome = useGroupedChrome(platform, device);
  const apple = chrome !== "material";
  const label = profile.displayName || profile.name;
  const trailing =
    (active && apple) || (onChangeModel && chrome !== "ios") ? (
      <span style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
        {active && apple ? (
          <Icon name="check" size={chrome === "mac" ? 16 : 22} label="Active" />
        ) : null}
        {onChangeModel && chrome !== "ios" ? (
          <IconButton
            icon="tune"
            label="Change default model"
            size={chrome === "mac" ? 32 : 40}
            onClick={onChangeModel}
          />
        ) : null}
      </span>
    ) : undefined;
  const row = (
    <GroupedRow
      title={label}
      subtitle={profile.description || profile.path || undefined}
      caption={[profile.model, `${profile.skillCount} skills`]
        .filter(Boolean)
        .join(" · ")}
      leading={
        <GroupedTile platform={platform} device={device}>
          {initialsOf(label)}
        </GroupedTile>
      }
      value={active && !apple ? "Active" : undefined}
      trailing={trailing}
      chevron={false}
      onClick={onClick}
      platform={platform}
      device={device}
    />
  );
  if (!onChangeModel) return row;
  return (
    <RowActions
      title={label}
      actions={[
        {
          label: "Change default model",
          icon: "tune",
          onPress: onChangeModel,
        },
      ]}
      actionSheetOpen={actionSheetOpen}
      platform={resolvedPlatform}
      device={chrome === "ios" ? "touch" : "mac"}
    >
      {row}
    </RowActions>
  );
}
