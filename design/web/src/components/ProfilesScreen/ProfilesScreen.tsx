import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { ProfileTile, type Profile } from "../ProfileTile/ProfileTile";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import type { AppleDevice, Platform } from "../../platform";
import "../../styles/settings-state.css";

export interface ProfilesScreenProps {
  /** The dashboard's profiles, in its order. */
  profiles?: Profile[];
  /** Name of the active profile, the CLI default `hermes profile use` sets: checked on Apple, "Active" on Material. */
  active?: string;
  /** The profile the chat shows, when it differs from `active`: the group's footer says "The chat shows work. The CLI default is default." */
  shownInChat?: string;
  /** `loaded` (default), `loading` (a spinner) or `failed` ("Could not load profiles" with Retry). */
  state?: "loaded" | "loading" | "failed";
  /** A profile was picked: make it active and move the chat to it. */
  onSelect?: (name: string) => void;
  /** Lets each profile's default model be changed: a tune button on its row (Mac, Material), its long-press sheet on iOS. Leave out when models cannot be loaded. */
  onChangeModel?: (name: string) => void;
  /** iOS: the profile whose long-press sheet ("Change default model") is drawn open, for previews. */
  actionSheetProfile?: string;
  /** The bar's "+" (New Profile; the app asks for a name and description). */
  onNewProfile?: () => void;
  onRetry?: () => void;
  /** Back to the chat ("Chat" beside the iOS chevron). */
  onBack?: () => void;
  /**
   * `apple` + `touch` (iPhone): 44px bar, the title centred over "3
   * profiles", "+" at the end, an inset group of 17px rows. `apple` +
   * `mac`: the 52px toolbar and 13px rows in a centred 600px column.
   * `material`: the 56px bar, 56px rows with "Active" and a tune button.
   * Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`. Defaults to the enclosing `AppShell`'s, else `touch`. */
  device?: AppleDevice;
}

/**
 * The Profiles screen, pushed from the chat sidebar: a `SettingsScaffold`
 * with "N profiles" under the title and "+" for a new profile, and one
 * inset group of `ProfileTile`s with the active profile marked. When the
 * chat shows a different profile than the CLI default, the group's footer
 * says so. Loading and failed states centre a `Spinner` or `StateMessage`.
 */
export function ProfilesScreen({
  profiles = [],
  active,
  shownInChat,
  state = "loaded",
  onSelect,
  onChangeModel,
  actionSheetProfile,
  onNewProfile,
  onRetry,
  onBack,
  platform,
  device,
}: ProfilesScreenProps) {
  const shown = shownInChat ?? active;
  return (
    <SettingsScaffold
      title="Profiles"
      subtitle={
        state === "loaded"
          ? profiles.length === 1
            ? "1 profile"
            : `${profiles.length} profiles`
          : undefined
      }
      onBack={onBack}
      actions={[{ icon: "add", label: "New Profile", onClick: onNewProfile }]}
      platform={platform}
      device={device}
    >
      {state === "loading" ? (
        <div className="h-settings-state">
          <Spinner size={36} label="Loading profiles" />
        </div>
      ) : state === "failed" ? (
        <div className="h-settings-state">
          <StateMessage
            title="Could not load profiles"
            action={<Button onClick={onRetry}>Retry</Button>}
          />
        </div>
      ) : (
        <GroupedListView>
          <GroupedSection
            dividerIndent="tile"
            footer={
              shown === active
                ? undefined
                : `The chat shows ${shown}. The CLI default is ${active}.`
            }
          >
            {profiles.map((p) => (
              <ProfileTile
                key={p.name}
                profile={p}
                active={p.name === active}
                onClick={() => onSelect?.(p.name)}
                onChangeModel={
                  onChangeModel ? () => onChangeModel(p.name) : undefined
                }
                actionSheetOpen={actionSheetProfile === p.name}
              />
            ))}
          </GroupedSection>
        </GroupedListView>
      )}
    </SettingsScaffold>
  );
}
