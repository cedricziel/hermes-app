import type { CSSProperties, ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import {
  cx,
  PlatformScope,
  useAppleDevice,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./Menu.css";

/** One entry of a `Menu`. */
export interface MenuItem<T extends string = string> {
  /** The entry's text: "Rename", "Platform (12)". */
  label: string;
  /** Handed back to `onSelect`, so a caller can tell entries apart without counting: `"rename"`. */
  value?: T;
  /** Mac only: the keyboard shortcut, right-aligned and muted, as the menu bar writes it: `⇧⌘P`. */
  shortcut?: string;
  /** Material Symbols name. Leading on Material and Mac, trailing on iOS. */
  icon?: string;
  /** Makes the entry a choice: `true` draws a check (leading on Material and Mac, trailing on iOS), `false` leaves its room empty on Material and Mac. Leave it out on plain actions, which then start at the edge. */
  checked?: boolean;
  /** Drawn in the error color: Delete, Remove. */
  destructive?: boolean;
  /** Greyed out and not pickable. */
  disabled?: boolean;
  /** A line of small muted text that is not an action, such as the server address on top of the account menu. */
  info?: boolean;
}

export interface MenuProps<T extends string = string> {
  /** Entries top to bottom; `"divider"` draws a separator. */
  items: Array<MenuItem<T> | "divider">;
  /** Called with the picked entry and its index in `items`. */
  onSelect?: (item: MenuItem<T>, index: number) => void;
  /**
   * Anchors the menu to its `MenuAnchor` (or any positioned parent) and
   * lines it up with the anchor's leading (`start`) or trailing (`end`)
   * edge, 4px below it (or above, see `side`). Leave both `align` and `side`
   * out to draw the menu in the flow, or to place it yourself with `style`.
   */
  align?: "start" | "end";
  /** Opens below (default) or above the anchor; see `align`. */
  side?: "below" | "above";
  /** Fixed width in px. By default the menu fits its longest entry, at least 112px (Material), 220px (iOS) or 160px (Mac). */
  width?: number;
  /** Accessible name, e.g. "Chat actions". */
  label?: string;
  /**
   * `material`: the Material popup menu, 48px rows of 14px text on a bordered
   * card. `apple` follows `device`: on `touch` (iPhone, iPad) the iOS
   * pull-down menu, a blurred 14px-radius panel of 44px rows with 17px text,
   * hairlines between rows, icons and the check trailing; on `mac` the
   * compact Mac menu, 22px rows of 13px text with shortcuts right-aligned, a
   * 6px radius and a filled highlight under the pointer. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, which menu to draw; see `AppleDevice`. Inherited from the enclosing `AppShell`, else `mac`. */
  device?: AppleDevice;
  className?: string;
  style?: CSSProperties;
}

/**
 * An open popup menu: a thread's or the account's "…" menu, a filter or board
 * switcher, "Move to…". Draw it inside a `MenuAnchor` next to the button that
 * opens it, with `align`, instead of styling a menu of your own.
 */
export function Menu<T extends string = string>({
  items,
  onSelect,
  align,
  side,
  width,
  label,
  platform,
  device: deviceProp,
  className,
  style,
}: MenuProps<T>) {
  const resolvedPlatform = usePlatform(platform);
  const device = useAppleDevice("desktop", deviceProp);
  const variant =
    resolvedPlatform === "material"
      ? "material"
      : device === "touch"
        ? "ios"
        : "mac";
  const anchored = align !== undefined || side !== undefined;
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        role="menu"
        aria-label={label}
        className={cx(
          "h-menu",
          `h-menu--${variant}`,
          anchored && "h-menu--anchored",
          anchored && `h-menu--${align ?? "start"}`,
          anchored && `h-menu--${side ?? "below"}`,
          className,
        )}
        style={{ width, ...style }}
        onMouseDown={(e) => e.stopPropagation()}
      >
        {items.map((item, i) =>
          item === "divider" ? (
            <div key={i} role="separator" className="h-menu__divider" />
          ) : (
            <MenuRow
              key={i}
              item={item}
              variant={variant}
              onPick={() => onSelect?.(item, i)}
            />
          ),
        )}
      </div>
    </PlatformScope>
  );
}

function MenuRow<T extends string>({
  item,
  variant,
  onPick,
}: {
  item: MenuItem<T>;
  variant: "material" | "ios" | "mac";
  onPick: () => void;
}) {
  if (item.info) {
    return (
      <div className="h-menu__item h-menu__item--info" role="presentation">
        <span className="h-menu__label">{item.label}</span>
      </div>
    );
  }
  const ios = variant === "ios";
  const mac = variant === "mac";
  const check = item.checked ? (
    <Icon
      name="check"
      apple={ios ? "checkmark" : false}
      size={ios ? 18 : mac ? 14 : 20}
    />
  ) : null;
  const icon = item.icon ? (
    <Icon name={item.icon} size={mac ? 14 : 20} />
  ) : null;
  const trailing = ios ? (check ?? icon) : null;
  return (
    <button
      type="button"
      role={item.checked !== undefined ? "menuitemradio" : "menuitem"}
      aria-checked={item.checked}
      disabled={item.disabled}
      className={cx(
        "h-menu__item",
        item.destructive && "h-menu__item--destructive",
      )}
      onClick={onPick}
    >
      {!ios && item.checked !== undefined ? (
        <span className="h-menu__check">{check}</span>
      ) : null}
      {!ios ? icon : null}
      <span className="h-menu__label">{item.label}</span>
      {trailing ? <span className="h-menu__trailing">{trailing}</span> : null}
      {mac && item.shortcut ? (
        <span className="h-menu__shortcut">{item.shortcut}</span>
      ) : null}
    </button>
  );
}

export interface MenuAnchorProps {
  /** The button that opens the menu, then the open `Menu` (with `align`). */
  children?: ReactNode;
  className?: string;
  style?: CSSProperties;
}

/** Wraps a button and its open `Menu` so the menu's `align` places it against the button. Inline; adds no space of its own. */
export function MenuAnchor({ children, className, style }: MenuAnchorProps) {
  return (
    <span className={cx("h-menu-anchor", className)} style={style}>
      {children}
    </span>
  );
}
