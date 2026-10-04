import { Button } from "../Button/Button";
import { ListRow } from "../ListRow/ListRow";
import { ProfileTile, type Profile } from "../ProfileTile/ProfileTile";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";

export interface ProfilesScreenProps {
  /** The dashboard's profiles, in its order. */
  profiles?: Profile[];
  /** Name of the active profile, the CLI default `hermes profile use` sets. It gets the "Active" chip (a checkmark on iOS). */
  active?: string;
  /** The profile the chat shows, when it differs from `active`: a note above the list says so. */
  shownInChat?: string;
  /** `loaded` (default), `loading` (a spinner) or `failed` ("Could not load profiles" with Retry). */
  state?: "loaded" | "loading" | "failed";
  /** A profile was picked: make it active and move the chat to it. */
  onSelect?: (name: string) => void;
  /** Shows each row's tune button, which changes that profile's default model (the app opens the model picker). Leave out when models cannot be loaded. */
  onChangeModel?: (name: string) => void;
  onRetry?: () => void;
  /** Back to the chat ("Chat" beside the iOS chevron). */
  onBack?: () => void;
  /** `phone`: iOS rows with a trailing checkmark under `apple`. `desktop`: a Mac window or a Material desktop, the rows in a centred 640px column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back, 44px bar (52px on a Mac), iOS profile rows on a phone. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * The Profiles screen, pushed from the chat sidebar: every Hermes profile as
 * a `ProfileTile`, the active one marked, with a note when the chat shows a
 * different profile than the CLI default. Loading and failed states use
 * `Spinner` and `StateMessage`.
 */
export function ProfilesScreen({
  profiles = [],
  active,
  shownInChat,
  state = "loaded",
  onSelect,
  onChangeModel,
  onRetry,
  onBack,
  layout = "phone",
  platform,
  device,
}: ProfilesScreenProps) {
  const resolved = usePlatform(platform);
  const busy = state !== "loaded";
  return (
    <ScreenFrame
      title="Profiles"
      onBack={onBack}
      backLabel="Chat"
      layout={layout}
      platform={resolved}
      device={device}
      centered={busy}
    >
      {state === "loading" ? (
        <Spinner size={36} label="Loading profiles" />
      ) : null}
      {state === "failed" ? (
        <StateMessage
          title="Could not load profiles"
          action={<Button onClick={onRetry}>Retry</Button>}
        />
      ) : null}
      {state === "loaded" ? (
        <>
          {shownInChat && shownInChat !== active ? (
            <ListRow
              grouped={false}
              icon="info"
              title={`The chat shows ${shownInChat}.`}
              subtitle={`The CLI default is ${active}.`}
            />
          ) : null}
          {profiles.map((p) => (
            <ProfileTile
              key={p.name}
              profile={p}
              active={p.name === active}
              layout={layout}
              onClick={() => onSelect?.(p.name)}
              onChangeModel={
                onChangeModel ? () => onChangeModel(p.name) : undefined
              }
            />
          ))}
        </>
      ) : null}
    </ScreenFrame>
  );
}
