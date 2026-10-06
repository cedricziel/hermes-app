import { useEffect, useRef, useState } from "react";
import { Icon } from "../Icon/Icon";
import { Menu, type MenuItem } from "../Menu/Menu";
import { Sheet } from "../Sheet/Sheet";
import "./MacAccount.css";

/**
 * The Mac sidebar's profile switcher and account footer (the app's
 * `MacProfileSwitcher` and `MacAccountFooter`, #402), and the Settings list
 * its "Settings…" opens (`showSettingsDialog`). Internal to ThreadSidebar
 * and AppShell.
 */

/** The first letters of up to two words of `label`, upper case; "?" without any (the app's `initialsOf`). */
export function initialsOf(label: string) {
  const letters = label
    .split(/[\s_\-.@/:]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w.charAt(0).toUpperCase())
    .join("");
  return letters || "?";
}

/** A round avatar with the initials of `label` (the app's `InitialsAvatar`). */
export function InitialsAvatar({
  label,
  size = 24,
}: {
  label: string;
  size?: number;
}) {
  return (
    <span
      className="h-initials-avatar"
      aria-hidden
      style={{ width: size, height: size, fontSize: size * 0.42 }}
    >
      {initialsOf(label)}
    </span>
  );
}

/** Closes a menu on a click elsewhere or Escape. */
export function useDismiss(open: boolean, close: () => void) {
  useEffect(() => {
    if (!open) return;
    const onDown = () => close();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && close();
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, close]);
}

/** A profile the Mac sidebar's switcher lists. */
export interface SwitcherProfile {
  /** The profile's name on the server: "default", "work". */
  name: string;
  /** Shown instead of `name` when set. */
  displayName?: string;
  /** One line under the name on the switcher card. */
  description?: string;
  /** The profile's home, under its name in the menu: "~/.hermes/profiles/work". */
  path?: string;
}

/** The Mac sidebar's profile switcher: the profiles, which one is in use, and what its menu does. */
export interface MacProfileScope {
  /** Every profile, in the server's order. */
  profiles: SwitcherProfile[];
  /** Name of the profile the sidebar works in; "Profile" shows while it is unknown. */
  current?: string;
  /** Open the menu initially, for previews. */
  defaultMenuOpen?: boolean;
  /** Another profile was picked. */
  onSwitch?: (name: string) => void;
  /** "New Profile…" (the app asks for a name in a dialog). */
  onNewProfile?: () => void;
  /** "Manage Profiles…": open the Profiles page. */
  onManage?: () => void;
}

type ProfilePick = `profile:${string}` | "new" | "manage";

/**
 * The profile the Mac sidebar works in, as a 40px card at its top: initials,
 * the name in bold over its description, and an up-down chevron. A click
 * opens a menu of every profile (the active one checked, its home under its
 * name), then "New Profile…" and "Manage Profiles…".
 */
export function MacProfileSwitcher({
  profiles,
  current,
  defaultMenuOpen = false,
  onSwitch,
  onNewProfile,
  onManage,
}: MacProfileScope) {
  const [open, setOpen] = useState(defaultMenuOpen);
  const close = useRef(() => setOpen(false)).current;
  useDismiss(open, close);
  const profile = profiles.find((p) => p.name === current);
  const label = profile ? profile.displayName || profile.name : current;
  const items: Array<MenuItem<ProfilePick> | "divider"> = [
    { label: "Profiles", info: true, heading: true },
    ...profiles.map((p) => ({
      value: `profile:${p.name}` as const,
      label: p.displayName || p.name,
      detail: p.path || undefined,
      checked: p.name === current,
    })),
    "divider",
    { value: "new", label: "New Profile…" },
    { value: "manage", label: "Manage Profiles…" },
  ];
  return (
    <div className="h-mac-switcher" onMouseDown={(e) => e.stopPropagation()}>
      <button
        type="button"
        className="h-mac-switcher__card"
        aria-label="Profile"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
      >
        <InitialsAvatar label={label ?? "Profile"} />
        <span className="h-mac-account__text">
          <span className="h-mac-account__name">{label ?? "Profile"}</span>
          {profile?.description ? (
            <span className="h-mac-account__detail">{profile.description}</span>
          ) : null}
        </span>
        <Icon name="unfold_more" size={14} className="h-mac-account__unfold" />
      </button>
      {open ? (
        <Menu
          className="h-mac-switcher__menu"
          label="Profiles"
          device="mac"
          items={items}
          onSelect={(item) => {
            setOpen(false);
            if (item.value === "new") onNewProfile?.();
            else if (item.value === "manage") onManage?.();
            else if (item.value) {
              const name = item.value.slice("profile:".length);
              if (name !== current) onSwitch?.(name);
            }
          }}
        />
      ) : null}
    </div>
  );
}

/** What the Mac account menu asks for. */
export type MacAccountAction = "settings" | "connection" | "sign-out";

/**
 * The signed-in user at the bottom of a Mac sidebar, over a hairline:
 * initials, the name in bold over the server's host (just the host when the
 * dashboard reports no user) and an up-down chevron. A click opens a menu
 * above it: "Signed in to the dashboard" (or "Connected to the dashboard"
 * without sign-in), Settings… (⌘,), Connection Details and, when the server
 * needs sign-in, Sign Out.
 */
export function MacAccountFooter({
  name,
  host,
  canSignOut,
  defaultMenuOpen = false,
  onAction,
}: {
  name?: string;
  host: string;
  canSignOut: boolean;
  defaultMenuOpen?: boolean;
  onAction?: (action: MacAccountAction) => void;
}) {
  const [open, setOpen] = useState(defaultMenuOpen);
  const close = useRef(() => setOpen(false)).current;
  useDismiss(open, close);
  const items: Array<MenuItem<MacAccountAction> | "divider"> = [
    {
      label: canSignOut
        ? "Signed in to the dashboard"
        : "Connected to the dashboard",
      info: true,
      heading: true,
    },
    { value: "settings", label: "Settings…", shortcut: "⌘," },
    { value: "connection", label: "Connection Details" },
    ...(canSignOut
      ? ["divider" as const, { value: "sign-out" as const, label: "Sign Out" }]
      : []),
  ];
  return (
    <div
      className="h-mac-account-footer"
      onMouseDown={(e) => e.stopPropagation()}
    >
      <button
        type="button"
        className="h-mac-account-footer__button"
        aria-label="Account"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
      >
        {name ? (
          <InitialsAvatar label={name} size={26} />
        ) : (
          <span className="h-initials-avatar" style={{ width: 26, height: 26 }}>
            <Icon name="person" size={14} />
          </span>
        )}
        <span className="h-mac-account__text">
          <span className="h-mac-account__name">{name ?? host}</span>
          {name ? <span className="h-mac-account__detail">{host}</span> : null}
        </span>
        <Icon name="unfold_more" size={14} className="h-mac-account__unfold" />
      </button>
      {open ? (
        <Menu
          className="h-mac-account-footer__menu"
          label="Account"
          device="mac"
          items={items}
          onSelect={(item) => {
            setOpen(false);
            if (item.value) onAction?.(item.value);
          }}
        />
      ) : null}
    </div>
  );
}

/** An entry of the Mac Settings list. */
export type SettingsEntry =
  "appearance" | "notifications" | "app-lock" | "about" | "change-server";

const settingsEntries: { value: SettingsEntry; label: string }[] = [
  { value: "appearance", label: "Appearance…" },
  { value: "notifications", label: "Notifications…" },
  { value: "app-lock", label: "App Lock…" },
  { value: "about", label: "About Hermes" },
  { value: "change-server", label: "Change Server…" },
];

/** The Settings list a Mac window opens from Settings… (⌘,): a dialog titled "Settings" whose entries each open their own dialog. */
export function SettingsSheet({
  onPick,
  onDismiss,
}: {
  onPick?: (entry: SettingsEntry) => void;
  onDismiss?: () => void;
}) {
  return (
    <Sheet
      presentation="dialog"
      label="Settings"
      width={320}
      padding={0}
      onDismiss={onDismiss}
    >
      <div className="h-settings-list">
        <h2 className="h-sheet__title h-settings-list__title">Settings</h2>
        {settingsEntries.map((e) => (
          <button
            key={e.value}
            type="button"
            className="h-settings-list__option"
            onClick={() => onPick?.(e.value)}
          >
            {e.label}
          </button>
        ))}
      </div>
    </Sheet>
  );
}
