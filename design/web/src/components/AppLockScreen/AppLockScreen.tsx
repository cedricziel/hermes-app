import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./AppLockScreen.css";

export interface AppLockScreenProps {
  /**
   * The lock setting has been read. Before that the screen shows only the
   * lock (the app covers itself until it knows whether it is locked), then
   * "Hermes is locked" and the Unlock button.
   */
  loaded?: boolean;
  /** Unlock pressed: the app asks for Face ID, Touch ID or the device passcode. */
  onUnlock?: () => void;
  /** `apple` draws the CupertinoIcons lock. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * The screen that covers the whole app while App lock is on and the app is
 * locked (`AppLockGate` in the app): a muted 48px lock, "Hermes is locked"
 * and a filled Unlock button, centered on the page background. The app
 * stays running underneath, so a reply keeps streaming. Fills its parent.
 */
export function AppLockScreen({
  loaded = true,
  onUnlock,
  platform,
}: AppLockScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div className="h-app-lock-screen">
        <Icon name="lock" size={48} className="h-muted" />
        {loaded ? (
          <>
            <span className="h-body-md">Hermes is locked</span>
            <Button onClick={onUnlock}>Unlock</Button>
          </>
        ) : null}
      </div>
    </PlatformScope>
  );
}
