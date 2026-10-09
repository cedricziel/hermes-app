import { Children, Fragment, type ReactNode } from "react";
import {
  cx,
  DeviceScope,
  PlatformScope,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import {
  dividerIndentPx,
  metricsClass,
  type DividerIndent,
} from "../../grouped";
import "./GroupedSection.css";

export interface GroupedSectionProps {
  /**
   * The group's heading above it: "Memory provider", "Mixture of agents".
   * iOS: 13px uppercase muted. Mac: 11px semibold muted, sentence case.
   * Material: 13px semibold muted, sentence case. A section with a header
   * stands 24px (iOS) or 20px (Mac, Material) below the one before; without
   * one, 8px.
   */
  header?: string;
  /** A muted note under the group explaining it (13px; 11px on a Mac): "Changes apply from the next chat, not to one that is already running." */
  footer?: string;
  /**
   * Where the hairline separators between rows start, from the group's
   * left edge: `text` (default, the row padding: 16px, Mac 12px), `leading`
   * (past a row's leading icon: 50 / 40 / 53px), `tile` (past a
   * `GroupedTile`: 57 / 46 / 64px), `choice` (past Material's radio button,
   * 72px; the text on Apple), or a number of px.
   */
  dividerIndent?: DividerIndent;
  /** The rows: `GroupedRow`, `GroupedSwitchRow`, `GroupedChoiceRow`, `GroupedValueRow`, `GroupedMenuRow`, `GroupedTextFieldRow`, `GroupedSegmentedRow`. A separator goes between each two. */
  children?: ReactNode;
  /**
   * The group's look: a surface-colored card with a 1px border and inset
   * hairlines in the subtle border color. iOS 12px corners, Mac 10px,
   * Material 14px. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`. Inherited from an enclosing `GroupedListView`, `SettingsScaffold` or `AppShell`, else `touch`. */
  device?: AppleDevice;
  className?: string;
}

/**
 * A group of settings rows: a bordered rounded card, separators inset to
 * the rows' text, an optional `header` above it and a `footer` under it.
 * Put sections in a `GroupedListView` (a page) or a `GroupedDialog`.
 */
export function GroupedSection({
  header,
  footer,
  dividerIndent,
  children,
  platform,
  device,
  className,
}: GroupedSectionProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const rows = Children.toArray(children);
  const indent = dividerIndentPx(chrome, dividerIndent);
  return (
    <PlatformScope platform={resolved}>
      <DeviceScope device={device}>
        <section
          className={cx(
            "h-grouped-section",
            metricsClass(chrome),
            header !== undefined && "h-grouped-section--header",
            className,
          )}
        >
          {header !== undefined ? (
            <h3 className="h-grouped-section__header">{header}</h3>
          ) : null}
          <div className="h-grouped-section__card">
            {rows.map((row, i) => (
              <Fragment key={i}>
                {i > 0 ? (
                  <div
                    className="h-grouped-section__divider"
                    style={{ marginLeft: indent }}
                    role="presentation"
                  />
                ) : null}
                {row}
              </Fragment>
            ))}
          </div>
          {footer ? (
            <p className="h-grouped-section__footer">{footer}</p>
          ) : null}
        </section>
      </DeviceScope>
    </PlatformScope>
  );
}

export interface GroupedFooterProps {
  /** The note: "Hermes runs side jobs on these models." or, with `error`, why a form could not be saved. */
  children?: ReactNode;
  /** Draws the note in the error color, 12px under the group instead of 6px. */
  error?: boolean;
  platform?: Platform;
  device?: AppleDevice;
}

/**
 * A note under a group drawn apart from its `GroupedSection`, such as a
 * form's save error; set like a section's footer.
 */
export function GroupedFooter({
  children,
  error = false,
  platform,
  device,
}: GroupedFooterProps) {
  const chrome = useGroupedChrome(platform, device);
  return (
    <p
      className={cx(
        "h-grouped-footer",
        metricsClass(chrome),
        error && "h-grouped-footer--error",
      )}
      role={error ? "alert" : undefined}
    >
      {children}
    </p>
  );
}
