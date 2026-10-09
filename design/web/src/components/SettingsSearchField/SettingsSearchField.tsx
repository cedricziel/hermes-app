import { Icon } from "../Icon/Icon";
import {
  MacToolbarButton,
  MacToolbarSearchField,
} from "../MacToolbar/MacToolbar";
import { Menu, MenuAnchor, useMenuState } from "../Menu/Menu";
import {
  cx,
  PlatformScope,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./SettingsSearchField.css";

/** One choice of a search's filter menu. */
export interface SettingsFilter {
  /** "All", "Enabled", "Bundled", "Needs login". */
  label: string;
  /** The filter in effect; the menu checks it. */
  selected?: boolean;
}

/** What a settings page searches; `SettingsScaffold`'s `search` takes the same fields. */
export interface SettingsSearch {
  /** The typed text. */
  query?: string;
  /** Called with the new text; the clear button sends "". */
  onChange?: (query: string) => void;
  /** The placeholder: "Search" (default), "Search skills", "Search catalog". */
  hint?: string;
  /**
   * The filter menu's choices, the first being the one that shows
   * everything ("All"). A filter other than the first narrows the list,
   * which marks the filter button (darker glyph on a light fill, or the
   * selected Mac toolbar button). Leave out for a search without filters.
   */
  filters?: SettingsFilter[];
  /** Called with the index of the filter picked from the menu. */
  onFilter?: (index: number) => void;
  /** Draws the filter menu open, for previews; a click on the filter button also opens it. */
  filterMenuOpen?: boolean;
}

export interface SettingsSearchFieldProps extends SettingsSearch {
  /**
   * `apple` + `touch`: a 36px field with 10px corners in the tinted
   * surface, an 18px search glyph, 17px text, a clear button while there is
   * text and the filter button inside its trailing end. `apple` + `mac`:
   * the toolbar's `MacToolbarSearchField` and, beside it, a 28px filter
   * toolbar button. `material`: a 44px pill in the tinted surface, 22px
   * glyph, 16px text, the filter button inside. Inherits the provider's
   * platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited from `SettingsScaffold` or `AppShell`, else `touch`. */
  device?: AppleDevice;
}

/**
 * The search field of a settings page, with its filter menu: Skills,
 * Plugins' catalog, MCP's catalog, the model picker. `SettingsScaffold`
 * draws it from its `search` (under the bar on iOS and Material, in the
 * Mac toolbar); use it alone in a sheet.
 */
export function SettingsSearchField({
  query = "",
  onChange,
  hint = "Search",
  filters = [],
  onFilter,
  filterMenuOpen = false,
  platform,
  device,
}: SettingsSearchFieldProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const [open, setOpen] = useMenuState(filterMenuOpen);
  const active = filters.some((f, i) => i > 0 && f.selected);
  const menu = open ? (
    <Menu
      align="end"
      label="Filter"
      platform={resolved}
      device={chrome === "mac" ? "mac" : "touch"}
      items={filters.map((f) => ({ label: f.label, checked: !!f.selected }))}
      onSelect={(_, i) => {
        setOpen(false);
        onFilter?.(i);
      }}
    />
  ) : null;
  const toggle = () => setOpen((o) => !o);
  if (chrome === "mac") {
    return (
      <PlatformScope platform="apple">
        <span className="h-settings-search h-settings-search--mac">
          <MacToolbarSearchField
            query={query}
            hint={hint}
            active={query.length > 0}
            onChange={onChange}
            onEnd={() => onChange?.("")}
          />
          {filters.length > 0 ? (
            <MenuAnchor>
              <MacToolbarButton
                icon="filter_list"
                label="Filter"
                selected={active}
                onClick={toggle}
              />
              {menu}
            </MenuAnchor>
          ) : null}
        </span>
      </PlatformScope>
    );
  }
  const ios = chrome === "ios";
  return (
    <PlatformScope platform={resolved}>
      <div
        className={cx(
          "h-settings-search",
          ios ? "h-settings-search--ios" : "h-settings-search--material",
        )}
      >
        <Icon
          name="search"
          size={ios ? 18 : 22}
          className="h-settings-search__glyph"
        />
        <input
          type="search"
          className="h-settings-search__input"
          placeholder={hint}
          value={query}
          aria-label={hint}
          onChange={(e) => onChange?.(e.target.value)}
        />
        {query ? (
          <button
            type="button"
            className="h-settings-search__clear"
            aria-label="Clear search"
            onClick={() => onChange?.("")}
          >
            <Icon name="cancel" filled size={ios ? 16 : 20} />
          </button>
        ) : null}
        {filters.length > 0 ? (
          <MenuAnchor className="h-settings-search__filter-anchor">
            <button
              type="button"
              className={cx(
                "h-settings-search__filter",
                active && "h-settings-search__filter--active",
              )}
              aria-label="Filter"
              aria-haspopup="menu"
              aria-expanded={open}
              onClick={toggle}
            >
              <Icon name="filter_list" size={ios ? 18 : 22} />
            </button>
            {menu}
          </MenuAnchor>
        ) : (
          <span className="h-settings-search__end" />
        )}
      </div>
    </PlatformScope>
  );
}
