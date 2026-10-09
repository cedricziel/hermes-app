import { type CSSProperties, type ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import {
  MacToolbar,
  MacToolbarButton,
  MacToolbarSeparator,
} from "../MacToolbar/MacToolbar";
import { Menu, MenuAnchor, useMenuState, type MenuItem } from "../Menu/Menu";
import { PillSegmentedControl } from "../PillSegmentedControl/PillSegmentedControl";
import { SegmentedControl } from "../SegmentedControl/SegmentedControl";
import {
  SettingsSearchField,
  type SettingsSearch,
} from "../SettingsSearchField/SettingsSearchField";
import { Spinner } from "../Spinner/Spinner";
import {
  cx,
  DeviceScope,
  PlatformScope,
  TRAFFIC_LIGHT_GAP,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type GroupedChrome,
  type Platform,
} from "../../platform";
import "./SettingsScaffold.css";

/** A button in a settings page's bar: an action, or with `menu` a button that opens a menu. */
export interface SettingsBarAction {
  /** Material Symbols name: "add", "more_horiz", "refresh", "filter_list". Drawn as its Cupertino pair on Apple. */
  icon: string;
  /** Accessible name and tooltip: "New skill", "More". */
  label: string;
  /** The button was clicked (an action without `menu`). */
  onClick?: () => void;
  /** Mac only: the key equivalent in the tooltip, "⌘N". */
  shortcut?: string;
  /** Makes it a menu button: the entries of the menu it opens (the MCP "Add" menu, a "…" overflow). */
  menu?: Array<MenuItem | "divider">;
  /** Called with the picked menu entry's index in `menu`. */
  onSelect?: (index: number) => void;
  /** Draws the menu open, for previews. */
  menuOpen?: boolean;
  disabled?: boolean;
}

/** A form's Save or Create in a settings page's bar. */
export interface SettingsFormAction {
  /** "Save", "Create". */
  label: string;
  onClick?: () => void;
  /** Saving: a spinner in the button's place, clicks ignored. */
  busy?: boolean;
  /** Greyed out, such as while a required field is empty. */
  disabled?: boolean;
}

/** A menu that a settings page's subtitle opens, such as the profiles a page can show. */
export interface SettingsSubtitleMenu {
  /** The button's accessible name: "Profile". */
  label: string;
  /** The menu's entries; check the current one: `{ label: "default", checked: true }`. */
  items: Array<MenuItem | "divider">;
  /** Called with the picked entry's index in `items`. */
  onSelect?: (index: number) => void;
  /** Draws the menu open, for previews. */
  open?: boolean;
}

export interface SettingsScaffoldProps {
  /** The page's title: "Plugins", "Skills", "MCP servers", "New schedule". */
  title: string;
  /** A muted line under the title. Phone: the profile, "work". Mac: profile and count, "work · 4 installed · 2 on". */
  subtitle?: string;
  /** Makes the subtitle a button that opens this menu; the subtitle then ends in a small chevron down ("default ⌄"). */
  subtitleMenu?: SettingsSubtitleMenu;
  /** A pushed page: draws the back button. iOS: a chevron with `backLabel`; Mac: a 28px chevron toolbar button (⌘[); Material: the back arrow. */
  onBack?: () => void;
  /** iOS: the title of the page underneath, beside the back chevron. Default "Chat". */
  backLabel?: string;
  /** A top-level page on a phone (no `onBack`): a menu button that opens the shell's drawer. Ignored on a Mac. */
  onOpenMenu?: () => void;
  /** A form: leads with Cancel (iOS, a 17px text button) or a close X (Material) instead of back; the Mac keeps its back button. */
  onCancel?: () => void;
  /**
   * The bar's buttons, in order, at the trailing edge: "+" for the page's
   * add action (no floating button on any platform), "…", a filter. iOS:
   * 44px icon buttons. Mac: 28px borderless toolbar buttons after the tabs
   * and search, past a separator. Material: 40px icon buttons.
   */
  actions?: SettingsBarAction[];
  /** A form's Save or Create, last in the bar. iOS: a 17px semibold text button. Mac: a small filled push button (12px, 6px corners). Material: a 16px semibold text button. */
  formAction?: SettingsFormAction;
  /** Views of the page: `["Installed", "Catalog", "Providers"]`. iOS: a segmented control under the bar. Mac: a compact segmented control in the toolbar. Material: a `PillSegmentedControl` under the bar. */
  tabs?: string[];
  /** Index of the selected tab. */
  activeTab?: number;
  onTabChange?: (index: number) => void;
  /** The page's search and its filter menu: under the bar (and the tabs) on iOS and Material, in the toolbar on a Mac. See `SettingsSearchField`. */
  search?: SettingsSearch;
  /** Mac: the page covers the whole window (pushed over the sidebar), so the toolbar leaves 78px for the traffic lights. */
  clearTrafficLights?: boolean;
  /** The page's body, usually a `GroupedListView`. Fills the rest of the height. */
  children?: ReactNode;
  /**
   * `apple` + `touch` (iPhone, iPad): a 44px bar with no divider, the
   * title (17px semibold) centred over the subtitle (12px muted). `apple` +
   * `mac`: the 52px `MacToolbar`, title (13px bold) over subtitle (11px).
   * `material`: a 56px bar with no divider, the title (18px semibold) at
   * the leading edge over the subtitle (12px muted). Inherits the provider's
   * platform; every grouped component inside follows the device.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`. Defaults to the enclosing `AppShell`'s, else `touch`. Every grouped component in the body inherits it. */
  device?: AppleDevice;
  className?: string;
  style?: CSSProperties;
}

/**
 * A settings page (Skills, Plugins, MCP servers, Messaging, Helper models,
 * Profiles, a form) with its platform's bar, tabs and search, and the body
 * under it. Mirrors the app's `SettingsScaffold`. Fills its parent's height
 * and is positioned, so a `Sheet` or `GroupedDialog` inside covers it.
 */
export function SettingsScaffold({
  title,
  subtitle,
  subtitleMenu,
  onBack,
  backLabel = "Chat",
  onOpenMenu,
  onCancel,
  actions = [],
  formAction,
  tabs,
  activeTab = 0,
  onTabChange,
  search,
  clearTrafficLights = false,
  children,
  platform,
  device,
  className,
  style,
}: SettingsScaffoldProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const subtitleNode = subtitle ? (
    subtitleMenu ? (
      <SubtitleMenuButton
        subtitle={subtitle}
        menu={subtitleMenu}
        chrome={chrome}
      />
    ) : (
      subtitle
    )
  ) : undefined;
  return (
    <PlatformScope platform={resolved}>
      <DeviceScope
        device={
          chrome === "material" ? device : chrome === "mac" ? "mac" : "touch"
        }
      >
        <div
          className={cx("h-settings", `h-settings--${chrome}`, className)}
          style={style}
        >
          {chrome === "mac" ? (
            <MacToolbar
              title={title}
              subtitle={subtitleNode}
              leadingInset={clearTrafficLights ? TRAFFIC_LIGHT_GAP : undefined}
              leading={
                onBack ? (
                  <MacToolbarButton
                    icon="chevron_left"
                    label="Back"
                    shortcut="⌘["
                    onClick={onBack}
                  />
                ) : undefined
              }
              actions={macActions({
                tabs,
                activeTab,
                onTabChange,
                title,
                search,
                actions,
                formAction,
              })}
            />
          ) : (
            <PhoneBar
              ios={chrome === "ios"}
              title={title}
              subtitle={subtitleNode}
              onBack={onBack}
              backLabel={backLabel}
              onOpenMenu={onOpenMenu}
              onCancel={onCancel}
              actions={actions}
              formAction={formAction}
            />
          )}
          {chrome !== "mac" && tabs && tabs.length > 0 ? (
            chrome === "ios" ? (
              <SegmentedControl
                labels={tabs}
                value={activeTab}
                onChange={onTabChange}
                label={title}
                platform="apple"
              />
            ) : (
              <div className="h-settings__pill-tabs">
                <PillSegmentedControl
                  labels={tabs}
                  value={activeTab}
                  onChange={onTabChange}
                  label={title}
                />
              </div>
            )
          ) : null}
          {chrome !== "mac" && search ? (
            <div className="h-settings__search">
              <SettingsSearchField {...search} />
            </div>
          ) : null}
          <div className="h-settings__body">{children}</div>
        </div>
      </DeviceScope>
    </PlatformScope>
  );
}

function macActions({
  tabs,
  activeTab,
  onTabChange,
  title,
  search,
  actions,
  formAction,
}: Pick<
  SettingsScaffoldProps,
  "tabs" | "onTabChange" | "title" | "search" | "formAction"
> & {
  activeTab: number;
  actions: SettingsBarAction[];
}) {
  const hasTabs = !!tabs && tabs.length > 0;
  if (!hasTabs && !search && actions.length === 0 && !formAction) {
    return undefined;
  }
  return (
    <>
      {hasTabs ? (
        <SegmentedControl
          labels={tabs}
          value={activeTab}
          onChange={onTabChange}
          label={title}
          platform="apple"
          size="compact"
        />
      ) : null}
      {search ? <SettingsSearchField {...search} /> : null}
      {(hasTabs || search) && actions.length > 0 ? (
        <MacToolbarSeparator />
      ) : null}
      {actions.map((action) => (
        <BarAction key={action.label} action={action} chrome="mac" />
      ))}
      {formAction ? <FormActionButton action={formAction} mac /> : null}
    </>
  );
}

function PhoneBar({
  ios,
  title,
  subtitle,
  onBack,
  backLabel,
  onOpenMenu,
  onCancel,
  actions,
  formAction,
}: {
  ios: boolean;
  title: string;
  subtitle?: ReactNode;
  onBack?: () => void;
  backLabel: string;
  onOpenMenu?: () => void;
  onCancel?: () => void;
  actions: SettingsBarAction[];
  formAction?: SettingsFormAction;
}) {
  const leading = onCancel ? (
    ios ? (
      <button
        type="button"
        className="h-settings__text-button h-settings__text-button--cancel"
        onClick={onCancel}
      >
        Cancel
      </button>
    ) : (
      <IconButton icon="close" label="Close" onClick={onCancel} />
    )
  ) : onBack ? (
    ios ? (
      <button
        type="button"
        className="h-settings__back"
        aria-label={`Back to ${backLabel}`}
        onClick={onBack}
      >
        <Icon name="arrow_back" apple="back" size={30} />
        <span className="h-settings__back-label">{backLabel}</span>
      </button>
    ) : (
      <IconButton icon="arrow_back" label="Back" onClick={onBack} />
    )
  ) : onOpenMenu ? (
    <IconButton
      icon="menu"
      label="Open navigation menu"
      size={ios ? 44 : 40}
      onClick={onOpenMenu}
    />
  ) : null;
  return (
    <header
      className={cx(
        "h-settings__bar",
        ios ? "h-settings__bar--ios" : "h-settings__bar--material",
        !ios && leading && "h-settings__bar--leading",
      )}
    >
      <div className="h-settings__leading">{leading}</div>
      <div className="h-settings__titles">
        <span className="h-settings__title">{title}</span>
        {subtitle ? (
          <span className="h-settings__subtitle">{subtitle}</span>
        ) : null}
      </div>
      <div className="h-settings__actions">
        {actions.map((action) => (
          <BarAction
            key={action.label}
            action={action}
            chrome={ios ? "ios" : "material"}
          />
        ))}
        {formAction ? <FormActionButton action={formAction} /> : null}
      </div>
    </header>
  );
}

function FormActionButton({
  action,
  mac = false,
}: {
  action: SettingsFormAction;
  mac?: boolean;
}) {
  return (
    <button
      type="button"
      className={mac ? "h-settings__mac-form-action" : "h-settings__text-button"}
      disabled={action.disabled || action.busy}
      onClick={action.onClick}
    >
      {action.busy ? (
        <Spinner size={mac ? 12 : 18} label={action.label} />
      ) : (
        action.label
      )}
    </button>
  );
}

function BarAction({
  action,
  chrome,
}: {
  action: SettingsBarAction;
  chrome: GroupedChrome;
}) {
  const [open, setOpen] = useMenuState(action.menuOpen ?? false);
  const onClick = action.menu ? () => setOpen((o) => !o) : action.onClick;
  const button =
    chrome === "mac" ? (
      <MacToolbarButton
        icon={action.icon}
        label={action.label}
        shortcut={action.shortcut}
        selected={open}
        disabled={action.disabled}
        onClick={onClick}
      />
    ) : (
      <IconButton
        icon={action.icon}
        label={action.label}
        size={chrome === "ios" ? 44 : 40}
        disabled={action.disabled}
        aria-haspopup={action.menu ? "menu" : undefined}
        aria-expanded={action.menu ? open : undefined}
        onClick={onClick}
      />
    );
  if (!action.menu) return button;
  return (
    <MenuAnchor>
      {button}
      {open ? (
        <Menu
          align="end"
          label={action.label}
          device={chrome === "mac" ? "mac" : "touch"}
          items={action.menu}
          onSelect={(_, i) => {
            setOpen(false);
            action.onSelect?.(i);
          }}
        />
      ) : null}
    </MenuAnchor>
  );
}

function SubtitleMenuButton({
  subtitle,
  menu,
  chrome,
}: {
  subtitle: string;
  menu: SettingsSubtitleMenu;
  chrome: GroupedChrome;
}) {
  const [open, setOpen] = useMenuState(menu.open ?? false);
  return (
    <MenuAnchor className="h-settings__subtitle-anchor">
      <button
        type="button"
        className="h-settings__subtitle-button"
        aria-label={`${menu.label}: ${subtitle}`}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
      >
        <span className="h-settings__subtitle-text">{subtitle}</span>
        <Icon name="expand_more" size={12} />
      </button>
      {open ? (
        <Menu
          align="start"
          label={menu.label}
          device={chrome === "mac" ? "mac" : "touch"}
          items={menu.items}
          onSelect={(_, i) => {
            setOpen(false);
            menu.onSelect?.(i);
          }}
        />
      ) : null}
    </MenuAnchor>
  );
}
