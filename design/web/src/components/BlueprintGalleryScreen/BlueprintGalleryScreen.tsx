import {
  BlueprintCard,
  type BlueprintItem,
} from "../BlueprintCard/BlueprintCard";
import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { Spinner } from "../Spinner/Spinner";
import { TextField } from "../TextField/TextField";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./BlueprintGalleryScreen.css";

export interface BlueprintGalleryScreenProps {
  /** The server's blueprints; the gallery shows those matching `query` and `category`. */
  blueprints?: BlueprintItem[];
  /** `ready` shows the search, categories and cards; `loading` a spinner; `error` "The templates could not be loaded." with Retry. The "Custom task" card is there in every state. */
  state?: "ready" | "loading" | "error";
  /** Search text; matches title, description and category. */
  query?: string;
  /** The category chip picked; omitted is "All". */
  category?: string;
  /** `apple`: the iOS type ramp; the gallery is the same on every platform, as in the app. Inherits the provider's platform. */
  platform?: Platform;
  /** "Custom task" pressed (opens the empty job form). */
  onCustom?: () => void;
  /** A blueprint card pressed (opens its form). */
  onOpen?: (blueprint: BlueprintItem) => void;
  /** Search text changed. */
  onQueryChange?: (query: string) => void;
  /** A category chip pressed; `undefined` for "All". */
  onCategoryChange?: (category: string | undefined) => void;
  /** Retry pressed after a failed load. */
  onRetry?: () => void;
  /** The close button pressed. */
  onClose?: () => void;
}

const capitalize = (s: string) => s[0].toUpperCase() + s.slice(1);

/**
 * "New scheduled task", opened by the Schedules "New" action: a full-width
 * "Custom task" `BlueprintCard`, then a search field, category chips and
 * the server's blueprints as a wrapping row of 260px `BlueprintCard`s. On
 * `ListDetailLayout`'s `list` layout. Fills its parent.
 */
export function BlueprintGalleryScreen({
  blueprints = [],
  state = "ready",
  query = "",
  category,
  platform,
  onCustom,
  onOpen,
  onQueryChange,
  onCategoryChange,
  onRetry,
  onClose,
}: BlueprintGalleryScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  const categories = [
    ...new Set(blueprints.map((b) => b.category).filter(Boolean)),
  ] as string[];
  const q = query.trim().toLowerCase();
  const shown = blueprints.filter(
    (b) =>
      (!category || b.category === category) &&
      (!q ||
        [b.title, b.description, b.category].some((t) =>
          t?.toLowerCase().includes(q),
        )),
  );
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ListDetailLayout
        layout="list"
        title="New scheduled task"
        onClose={onClose ?? (() => {})}
        list={
          <div className="h-blueprint-gallery">
            <BlueprintCard
              variant="custom"
              blueprint={{
                key: "custom",
                title: "Custom task",
                description: "Start from scratch",
              }}
              onClick={onCustom}
            />
            {state === "error" ? (
              <div className="h-blueprint-gallery__failed" role="alert">
                <span>The templates could not be loaded.</span>
                <Button variant="text" onClick={onRetry}>
                  Retry
                </Button>
              </div>
            ) : state === "loading" ? (
              <div className="h-blueprint-gallery__center">
                <Spinner />
              </div>
            ) : (
              <>
                <TextField
                  leadingIcon="search"
                  placeholder="Search templates"
                  aria-label="Search templates"
                  value={query}
                  onChange={(e) => onQueryChange?.(e.target.value)}
                  readOnly={!onQueryChange}
                />
                {categories.length ? (
                  <div className="h-blueprint-gallery__chips">
                    <Chip
                      label="All"
                      selected={!category}
                      onClick={() => onCategoryChange?.(undefined)}
                    />
                    {categories.map((c) => (
                      <Chip
                        key={c}
                        label={capitalize(c)}
                        selected={category === c}
                        onClick={() => onCategoryChange?.(c)}
                      />
                    ))}
                  </div>
                ) : null}
                {shown.length ? (
                  <div className="h-blueprint-gallery__cards">
                    {shown.map((b) => (
                      <div key={b.key} className="h-blueprint-gallery__card">
                        <BlueprintCard
                          blueprint={b}
                          onClick={() => onOpen?.(b)}
                        />
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="h-blueprint-gallery__center">
                    No templates match
                  </div>
                )}
              </>
            )}
          </div>
        }
      />
    </PlatformScope>
  );
}
