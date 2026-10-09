import type { ReactNode } from "react";
import { Button } from "./components/Button/Button";
import { Spinner } from "./components/Spinner/Spinner";
import { StateMessage } from "./components/StateMessage/StateMessage";
import { PlatformScope, type AppleDevice, type Platform } from "./platform";
import "./screen.css";

/**
 * Internal helpers shared by the screen cards (MCP, Plugins). Not exported
 * from the package: each screen draws its own states through them.
 */

/** A positioned frame that fills its parent, so a `Sheet` inside covers the whole screen. */
export function ScreenFrame({
  platform,
  children,
}: {
  platform: Platform;
  children: ReactNode;
}) {
  return (
    <PlatformScope platform={platform}>
      <div className="h-screen">{children}</div>
    </PlatformScope>
  );
}

/** Centres its content in the body of a screen. */
export function ScreenCenter({ children }: { children: ReactNode }) {
  return <div className="h-screen__center">{children}</div>;
}

/**
 * The body of a screen that is not loaded yet: a 36px spinner, or a
 * StateMessage with Retry. Flutter's MCP screens use a filled Retry, the
 * Plugins tabs an outlined one.
 */
export function ScreenState({
  state,
  failedTitle,
  unsupportedTitle,
  retryVariant = "filled",
  onRetry,
}: {
  state: "loading" | "failed" | "unsupported";
  failedTitle: string;
  unsupportedTitle?: string;
  retryVariant?: "filled" | "outlined";
  onRetry?: () => void;
}) {
  return (
    <ScreenCenter>
      {state === "loading" ? (
        <Spinner size={36} />
      ) : state === "unsupported" ? (
        <StateMessage title={unsupportedTitle ?? failedTitle} />
      ) : (
        <StateMessage
          title={failedTitle}
          action={
            <Button variant={retryVariant} onClick={onRetry}>
              Retry
            </Button>
          }
        />
      )}
    </ScreenCenter>
  );
}

/** Screens pushed over the chat always draw a back button, even in a preview without a handler. */
export const noop = () => {};

/** The device a screen's settings bar and groups follow: a phone is touch, a desktop a Mac unless told otherwise. */
export function screenDevice(
  layout: "phone" | "desktop",
  device?: AppleDevice,
): AppleDevice {
  return layout === "phone" ? "touch" : (device ?? "mac");
}

/** From 900px: a 380px list, a 1px divider and the pane beside it, as the app's list-detail `Row`. */
export function ScreenSplit({
  list,
  pane,
}: {
  list: ReactNode;
  pane: ReactNode;
}) {
  return (
    <div className="h-screen__split">
      <div className="h-screen__split-list">{list}</div>
      <div className="h-screen__split-pane">{pane}</div>
    </div>
  );
}
