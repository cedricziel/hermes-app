import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import {
  MessagingPlatformRow,
  type MessagingPlatform,
} from "../MessagingPlatformRow/MessagingPlatformRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { ScreenState } from "../../screen";
import type { ScreenLayout } from "../../screenFrame";
import {
  useAppleDevice,
  useGroupedChrome,
  type AppleDevice,
  type Platform,
} from "../../platform";

export interface MessagingScreenProps {
  /** The messaging platforms the dashboard knows, in its order. */
  platforms?: MessagingPlatform[];
  /** `loaded` (default), `loading` (a spinner centred under the bar) or `failed` ("Could not load messaging platforms" with Retry). */
  state?: "loaded" | "loading" | "failed";
  /** A row or its Set Up button was pressed: open its setup (`MessagingSetupScreen`). */
  onOpen?: (id: string) => void;
  /** A platform's switch was flipped. */
  onEnabledChange?: (id: string, enabled: boolean) => void;
  onRetry?: () => void;
  /** Back to the chat ("Chat" beside the iOS chevron, a 28px chevron toolbar button on a Mac, the back arrow on Material). */
  onBack?: () => void;
  /** `phone` or `desktop`. Under `apple`, `desktop` draws the Mac window (toolbar, 600px column); Material looks the same at either width, the group in a centred 640px column. */
  layout?: ScreenLayout;
  /** `apple`: the iOS bar and group, or with `layout="desktop"` the Mac toolbar and group. `material`: the 56px bar and Material group. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * The Messaging screen, pushed from the chat sidebar, on the clean settings
 * look: a `SettingsScaffold` titled "Messaging" (on a Mac with the subtitle
 * "2 of 4 on", the platforms switched on of all), then one inset
 * `GroupedSection` of `MessagingPlatformRow`s (Telegram, Discord, Slack...)
 * with the footer "Connect Hermes to Telegram, Discord, and other messaging
 * platforms." A platform without credentials offers Set Up instead of its
 * switch until its row is opened and set up.
 */
export function MessagingScreen({
  platforms = [],
  state = "loaded",
  onOpen,
  onEnabledChange,
  onRetry,
  onBack,
  layout = "phone",
  platform,
  device,
}: MessagingScreenProps) {
  const appleDevice = useAppleDevice(layout, device);
  const mac = useGroupedChrome(platform, appleDevice) === "mac";
  return (
    <SettingsScaffold
      title="Messaging"
      subtitle={
        mac && state === "loaded"
          ? `${platforms.filter((p) => p.enabled).length} of ${platforms.length} on`
          : undefined
      }
      onBack={onBack}
      platform={platform}
      device={appleDevice}
    >
      {state === "loaded" ? (
        <GroupedListView>
          <GroupedSection
            dividerIndent="tile"
            footer="Connect Hermes to Telegram, Discord, and other messaging platforms."
          >
            {platforms.map((p) => (
              <MessagingPlatformRow
                key={p.id}
                messagingPlatform={p}
                onClick={() => onOpen?.(p.id)}
                onEnabledChange={(v) => onEnabledChange?.(p.id, v)}
              />
            ))}
          </GroupedSection>
        </GroupedListView>
      ) : (
        <ScreenState
          state={state}
          failedTitle="Could not load messaging platforms"
          onRetry={onRetry}
        />
      )}
    </SettingsScaffold>
  );
}
