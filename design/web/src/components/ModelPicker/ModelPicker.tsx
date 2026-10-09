import { useState } from "react";
import { GroupedChoiceRow } from "../GroupedChoiceRow/GroupedChoiceRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import type { ModelChoice } from "../ModelSlotRow/ModelSlotRow";
import { Sheet } from "../Sheet/Sheet";
import { SettingsSearchField } from "../SettingsSearchField/SettingsSearchField";
import { metricsClass } from "../../grouped";
import {
  cx,
  DeviceScope,
  PlatformScope,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./ModelPicker.css";

/** A model the server offers. */
export interface ModelPickerModel {
  /** The model's id, shown as the row title: "claude-opus-4", "openai/gpt-5.1". */
  id: string;
  /** The reasoning efforts it takes, as Hermes names them: "none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra". Leave out for a model without effort. */
  efforts?: string[];
}

/** A provider and its models: one group of the picker. */
export interface ModelPickerProvider {
  /** The provider's id, which a `ModelChoice` names. */
  id: string;
  /** The group header: "Anthropic", "OpenRouter". */
  label: string;
  models: ModelPickerModel[];
}

export interface ModelPickerProps {
  /** The providers in the server's order, each with its models. */
  providers: ModelPickerProvider[];
  /** The current pick (`provider` and `model` ids, `effort`), checked in the list. Null or left out: nothing, or "Use the profile's default" when `onUseDefault` is set. */
  selected?: ModelChoice | null;
  /** A model or an effort was picked; the picker updates its own checks too. Without `withEffort` the app closes the picker. */
  onChange?: (choice: ModelChoice) => void;
  /** Show "Reasoning effort" for a picked model that takes one (Chat, Kanban). Off for a profile's default model, which keeps no effort. */
  withEffort?: boolean;
  /** The heading: "Model", or a helper slot's name such as "Compression". */
  title?: string;
  /** A muted line under the title, footer-sized: "Applies to new chats." */
  note?: string;
  /** Adds "Use the profile’s default" as its own group first (Kanban, Helper models, a job), checked while nothing is selected. The app closes the picker when it is picked. */
  onUseDefault?: () => void;
  /** The search text to start with, for previews. The field shows only with more than 8 models. */
  query?: string;
  /** The search text changed. */
  onQueryChange?: (query: string) => void;
  /**
   * `phone`: a bottom sheet with a drag handle, at most 75% of the screen.
   * `desktop` (from 900px): a 440px dialog with 28px corners. `inline`: the
   * panel's content alone, for a catalog cell. The sheet and dialog are the
   * Material ones on every platform, as in the app; they cover the nearest
   * positioned ancestor.
   */
  presentation?: "phone" | "desktop" | "inline";
  /**
   * The content follows the platform. `apple` + `touch`: title 17px
   * semibold, the search field under it, uppercase 13px provider headers, a
   * blue check after the picked model, effort pills with 8px corners.
   * `apple` + `mac`: title 13px bold with the search field beside it,
   * 11px semibold headers, compact rows, 24px pills. `material`: title 18px
   * semibold, a 44px pill search field, a radio before each model, round
   * pills. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
  /** The scrim was clicked or Escape pressed. */
  onDismiss?: () => void;
}

/** More models than this get a search field, as in the app. */
const searchAbove = 8;

/** What the dashboard calls an effort (the app's `effortLabel`). */
export function effortLabel(effort: string) {
  if (effort === "none") return "Off";
  if (effort === "xhigh") return "Extra High";
  return effort.charAt(0).toUpperCase() + effort.slice(1);
}

/** Providers whose name matches keep every model; the others keep the models whose id matches. */
function matching(providers: ModelPickerProvider[], search: string) {
  const query = search.toLowerCase();
  if (!query) return providers;
  return providers.flatMap((provider) => {
    if (provider.label.toLowerCase().includes(query)) return [provider];
    const models = provider.models.filter((m) =>
      m.id.toLowerCase().includes(query),
    );
    return models.length ? [{ ...provider, models }] : [];
  });
}

/**
 * The model picker the chat composer's model pill, the Kanban task form,
 * Profiles and Helper models open (`showModelPicker`): a title, a search
 * field once there are more than 8 models, then one group per provider of
 * choice rows (a trailing check on Apple, a leading radio on Material),
 * optionally led by "Use the profile’s default". Under the list, pinned
 * above a hairline, "Reasoning effort" offers the picked model's efforts
 * as pills that wrap, the picked one raised and outlined. A search with no
 * hit says "No models match “…”".
 */
export function ModelPicker({
  providers,
  selected: initialSelected = null,
  onChange,
  withEffort = true,
  title = "Model",
  note,
  onUseDefault,
  query: initialQuery = "",
  onQueryChange,
  presentation = "phone",
  platform,
  device,
  onDismiss,
}: ModelPickerProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const mac = chrome === "mac";
  const [selected, setSelected] = useState(initialSelected);
  const [query, setQuery] = useState(initialQuery);

  const modelOf = (choice: ModelChoice | null) =>
    providers
      .find((p) => p.id === choice?.provider)
      ?.models.find((m) => m.id === choice?.model);
  const pick = (choice: ModelChoice) => {
    setSelected(choice);
    onChange?.(choice);
  };
  const efforts = withEffort ? (modelOf(selected)?.efforts ?? []) : [];
  const modelCount = providers.reduce((n, p) => n + p.models.length, 0);
  const trimmed = query.trim();
  const shown = matching(providers, trimmed);

  const search =
    modelCount > searchAbove ? (
      <SettingsSearchField
        query={query}
        hint="Search models"
        onChange={(q) => {
          setQuery(q);
          onQueryChange?.(q);
        }}
      />
    ) : null;

  const content = (
    <div className={cx("h-model-picker", `h-model-picker--${chrome}`)}>
      <div className="h-model-picker__head">
        <div className="h-model-picker__title-row">
          <h2 className="h-model-picker__title">{title}</h2>
          {mac ? search : null}
        </div>
        {note ? <p className="h-model-picker__note">{note}</p> : null}
        {!mac && search ? (
          <div className="h-model-picker__search">{search}</div>
        ) : null}
      </div>
      <div className="h-model-picker__list">
        {onUseDefault && !trimmed ? (
          <GroupedSection dividerIndent="choice">
            <GroupedChoiceRow
              title="Use the profile’s default"
              checked={!selected}
              onSelect={() => {
                setSelected(null);
                onUseDefault();
              }}
            />
          </GroupedSection>
        ) : null}
        {shown.map((provider) => (
          <GroupedSection
            key={provider.id}
            header={provider.label}
            dividerIndent="choice"
          >
            {provider.models.map((model) => (
              <GroupedChoiceRow
                key={model.id}
                title={model.id}
                checked={
                  selected?.provider === provider.id &&
                  selected.model === model.id
                }
                onSelect={() => {
                  const effort = selected?.effort;
                  pick({
                    provider: provider.id,
                    model: model.id,
                    effort:
                      withEffort && effort && model.efforts?.includes(effort)
                        ? effort
                        : undefined,
                  });
                }}
              />
            ))}
          </GroupedSection>
        ))}
        {shown.length === 0 ? (
          <p className="h-model-picker__empty">No models match “{trimmed}”</p>
        ) : null}
      </div>
      {selected && efforts.length ? (
        <div className="h-model-picker__effort">
          <h3 className="h-model-picker__effort-header">Reasoning effort</h3>
          <div
            className="h-model-picker__pills"
            role="group"
            aria-label="Reasoning effort"
          >
            {efforts.map((effort) => (
              <button
                key={effort}
                type="button"
                aria-pressed={effort === selected.effort}
                className={cx(
                  "h-model-picker__pill",
                  effort === selected.effort && "h-model-picker__pill--on",
                )}
                onClick={() => pick({ ...selected, effort })}
              >
                {effortLabel(effort)}
              </button>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );

  return (
    <PlatformScope platform={resolved}>
      <DeviceScope device={device}>
        <div className={cx("h-model-picker-scope", metricsClass(chrome))}>
          {presentation === "inline" ? (
            <div className="h-model-picker-inline">{content}</div>
          ) : (
            <Sheet
              presentation={presentation === "desktop" ? "dialog" : "bottom"}
              dragHandle={presentation === "phone"}
              maxHeight="75%"
              width={440}
              padding={0}
              label={title}
              onDismiss={onDismiss}
            >
              {content}
            </Sheet>
          )}
        </div>
      </DeviceScope>
    </PlatformScope>
  );
}
