import {
  BlueprintCard,
  type BlueprintItem,
} from "../BlueprintCard/BlueprintCard";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import {
  GroupedFooter,
  GroupedSection,
} from "../GroupedSection/GroupedSection";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import { type AppleDevice, type Platform } from "../../platform";
import "./BlueprintGalleryScreen.css";

export interface BlueprintGalleryScreenProps {
  /** The server's blueprints; the gallery shows those matching `query` and `category`, grouped by category. */
  blueprints?: BlueprintItem[];
  /** `ready` shows the search and the groups; `loading` a spinner; `error` a "Templates" group with Retry and "The templates could not be loaded.". The "Custom task" row is there in every state. */
  state?: "ready" | "loading" | "error";
  /** The profile new jobs go to, the bar's subtitle: "work". */
  profile?: string;
  /** Search text; matches title, description and category. */
  query?: string;
  /** The category picked in the search field's filter menu; omitted is "All". */
  category?: string;
  /** Draws the filter menu open, for previews. */
  filterMenuOpen?: boolean;
  /**
   * A `SettingsScaffold` page. iPhone: "Cancel", the title over the
   * profile, the 36px search field with the category filter button inside.
   * Material: a close X and the 44px pill search field. Mac
   * (`device="mac"`): the toolbar with the back button, search field and
   * filter button. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`. Defaults to the enclosing `AppShell`'s, else touch. */
  device?: AppleDevice;
  /** "Custom task" pressed (opens the empty job form). */
  onCustom?: () => void;
  /** A blueprint row pressed (opens its form). */
  onOpen?: (blueprint: BlueprintItem) => void;
  /** Search text changed. */
  onQueryChange?: (query: string) => void;
  /** A category picked; `undefined` for "All". */
  onCategoryChange?: (category: string | undefined) => void;
  /** Retry pressed after a failed load. */
  onRetry?: () => void;
  /** Cancel, the close X or back pressed. */
  onClose?: () => void;
}

const capitalize = (s: string) => s[0].toUpperCase() + s.slice(1);

/**
 * "New scheduled task", opened by the Schedules "+": a "Custom task" row
 * (`BlueprintCard variant="custom"`) in a group of its own, then the
 * server's blueprints as `BlueprintCard` rows, one `GroupedSection` per
 * category headed with its name. The search field and its category filter
 * menu narrow them ("No templates match"). Fills its parent.
 */
export function BlueprintGalleryScreen({
  blueprints = [],
  state = "ready",
  profile,
  query = "",
  category,
  filterMenuOpen,
  platform,
  device,
  onCustom,
  onOpen,
  onQueryChange,
  onCategoryChange,
  onRetry,
  onClose,
}: BlueprintGalleryScreenProps) {
  const categories = [
    ...new Set(blueprints.map((b) => b.category).filter(Boolean)),
  ] as string[];
  const q = query.trim().toLowerCase();
  const shown = new Map<string, BlueprintItem[]>();
  for (const b of blueprints) {
    const matches =
      (!category || b.category === category) &&
      (!q ||
        [b.title, b.description, b.category].some((t) =>
          t?.toLowerCase().includes(q),
        ));
    if (!matches) continue;
    const key = b.category ?? "";
    if (!shown.has(key)) shown.set(key, []);
    shown.get(key)!.push(b);
  }
  return (
    <SettingsScaffold
      title="New scheduled task"
      subtitle={profile}
      onCancel={onClose ?? (() => {})}
      onBack={onClose ?? (() => {})}
      search={
        state === "ready"
          ? {
              query,
              hint: "Search templates",
              onChange: onQueryChange,
              filterMenuOpen,
              filters: categories.length
                ? [
                    { label: "All", selected: !category },
                    ...categories.map((c) => ({
                      label: capitalize(c),
                      selected: category === c,
                    })),
                  ]
                : undefined,
              onFilter: (i) =>
                onCategoryChange?.(i === 0 ? undefined : categories[i - 1]),
            }
          : undefined
      }
      platform={platform}
      device={device}
    >
      <GroupedListView>
        <GroupedSection dividerIndent="tile">
          <BlueprintCard
            variant="custom"
            blueprint={{
              key: "custom",
              title: "Custom task",
              description: "Start from scratch",
            }}
            onClick={onCustom}
          />
        </GroupedSection>
        {state === "error" ? (
          <GroupedSection
            header="Templates"
            footer="The templates could not be loaded."
          >
            <GroupedRow title="Retry" onClick={onRetry ?? (() => {})} />
          </GroupedSection>
        ) : state === "loading" ? (
          <div className="h-blueprint-gallery__center">
            <Spinner />
          </div>
        ) : shown.size === 0 ? (
          <GroupedFooter>No templates match</GroupedFooter>
        ) : (
          [...shown].map(([cat, rows]) => (
            <GroupedSection
              key={cat}
              header={cat ? capitalize(cat) : "Templates"}
            >
              {rows.map((b) => (
                <BlueprintCard
                  key={b.key}
                  blueprint={b}
                  onClick={() => onOpen?.(b)}
                />
              ))}
            </GroupedSection>
          ))
        )}
      </GroupedListView>
    </SettingsScaffold>
  );
}
