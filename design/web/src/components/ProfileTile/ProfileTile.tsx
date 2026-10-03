import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import "./ProfileTile.css";

/** A Hermes profile: its own config, skills, memory and chats on the server. */
export interface Profile {
  /** Profile name on the server, e.g. "default" or "work". */
  name: string;
  /** Display name; shown instead of `name` when set: "Work assistant". */
  displayName?: string;
  /** What the profile is for: "Day job: tickets, reviews and the on-call rota". */
  description?: string;
  /** Default model, e.g. "hermes-4" or "openai/gpt-5.1". */
  model?: string;
  /** Number of skills it has. */
  skillCount: number;
}

export interface ProfileTileProps {
  /** The profile to show. */
  profile: Profile;
  /** The chats' current profile: adds an "Active" chip. */
  active?: boolean;
  /** The row was clicked: switch to this profile. */
  onClick?: () => void;
  /** Shows a tune button that changes the profile's default model, and calls this when pressed. */
  onChangeModel?: () => void;
}

/**
 * One row of the Profiles screen: a person icon, the profile's label, a
 * subtitle of description · model · skill count, an "Active" chip on the
 * current one and a button to change its default model.
 */
export function ProfileTile({
  profile,
  active = false,
  onClick,
  onChangeModel,
}: ProfileTileProps) {
  const parts = [
    profile.description,
    profile.model,
    `${profile.skillCount} skills`,
  ].filter(Boolean);
  return (
    <div
      className="h-profile-tile"
      role="button"
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onClick?.();
        }
      }}
    >
      <Icon name="person" size={24} className="h-profile-tile__icon" />
      <div className="h-profile-tile__body">
        <div className="h-profile-tile__title">
          {profile.displayName || profile.name}
        </div>
        <div className="h-profile-tile__subtitle">{parts.join(" · ")}</div>
      </div>
      {active || onChangeModel ? (
        <div className="h-profile-tile__trailing">
          {active ? <span className="h-profile-tile__chip">Active</span> : null}
          {onChangeModel ? (
            <IconButton
              icon="tune"
              label="Change default model"
              onClick={(e) => {
                e.stopPropagation();
                onChangeModel();
              }}
            />
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
