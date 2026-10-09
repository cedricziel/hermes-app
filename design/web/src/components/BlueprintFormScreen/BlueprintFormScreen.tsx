import { Fragment } from "react";
import { GroupedChoiceRow } from "../GroupedChoiceRow/GroupedChoiceRow";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import {
  GroupedFooter,
  GroupedSection,
} from "../GroupedSection/GroupedSection";
import { GroupedTextFieldRow } from "../GroupedTextFieldRow/GroupedTextFieldRow";
import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { type AppleDevice, type Platform } from "../../platform";

/** One slot of a blueprint's form, as the server describes it. */
export interface BlueprintFieldItem {
  /** Slot name, e.g. `time`, `deliver`. */
  name: string;
  /** The question: "What time?", "Where to deliver?". */
  label: string;
  /**
   * `time`: a value row titled with the label ("08:00", or "Choose a
   * time"). `choice`: a group headed with the label, one choice row per
   * option. `text`: a text field row (one to three lines).
   */
  type: "time" | "choice" | "text";
  /** `choice`: the options, e.g. `origin`, `local`, `telegram`. */
  options?: string[];
  /** The value entered or picked. */
  value?: string;
  /** Muted help, the slot's footer. */
  help?: string;
  /** Adds " (optional)" after the label. */
  optional?: boolean;
  /** A red note under the slot, after a failed Create: "Pick a time". */
  error?: string;
}

export interface BlueprintFormScreenProps {
  /** The blueprint's title, in the bar: "Morning briefing". */
  title: string;
  /** The profile the job goes to, the bar's subtitle: "work". */
  profile?: string;
  /** What the blueprint does, a muted note above the slots. */
  description?: string;
  /** The slots, top to bottom, each a group of its own. */
  fields: BlueprintFieldItem[];
  /** The server refused the job: a red note under the last group. */
  error?: string;
  /** The job is being created: a spinner in place of Create. */
  saving?: boolean;
  /**
   * A `SettingsScaffold` form pushed over the gallery. iPhone: the back
   * chevron, the title over the profile, "Create" trailing; choices with a
   * blue trailing check. Material: the back arrow, "Create" trailing,
   * choices with a leading radio. Mac (`device="mac"`): the toolbar with
   * the back button and a small filled Create. Inherits the provider's
   * platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`. Defaults to the enclosing `AppShell`'s, else touch. */
  device?: AppleDevice;
  /** A choice was picked or text typed in a slot. */
  onFieldChange?: (name: string, value: string) => void;
  /** A time slot's row pressed (the app opens the time picker). */
  onPickTime?: (name: string) => void;
  /** Create pressed. */
  onCreate?: () => void;
  /** Back pressed (to the gallery). */
  onBack?: () => void;
}

/**
 * A blueprint's form, opened from the "New scheduled task" gallery: the
 * description, then one `GroupedSection` per slot the server describes (a
 * time value row, choice rows or a text field row) with its help as the
 * footer and its error under it. Create is in the bar. Fills its parent.
 */
export function BlueprintFormScreen({
  title,
  profile,
  description,
  fields,
  error,
  saving = false,
  platform,
  device,
  onFieldChange,
  onPickTime,
  onCreate,
  onBack,
}: BlueprintFormScreenProps) {
  const slot = (f: BlueprintFieldItem) => {
    const label = f.optional ? `${f.label} (optional)` : f.label;
    const help = f.help || undefined;
    if (f.type === "choice") {
      return (
        <GroupedSection header={label} footer={help} dividerIndent="choice">
          {(f.options ?? []).map((o) => (
            <GroupedChoiceRow
              key={o}
              title={o}
              checked={f.value === o}
              onSelect={() => onFieldChange?.(f.name, o)}
            />
          ))}
        </GroupedSection>
      );
    }
    return (
      <GroupedSection footer={help}>
        {f.type === "time" ? (
          <GroupedValueRow
            title={label}
            value={f.value || "Choose a time"}
            onClick={() => onPickTime?.(f.name)}
          />
        ) : (
          <GroupedTextFieldRow
            label={label}
            value={f.value ?? ""}
            onChange={(v) => onFieldChange?.(f.name, v)}
          />
        )}
      </GroupedSection>
    );
  };
  return (
    <SettingsScaffold
      title={title}
      subtitle={profile}
      onBack={onBack ?? (() => {})}
      backLabel=""
      formAction={{ label: "Create", busy: saving, onClick: onCreate }}
      platform={platform}
      device={device}
    >
      <GroupedListView>
        {description ? <GroupedFooter>{description}</GroupedFooter> : null}
        {fields.map((f) => (
          <Fragment key={f.name}>
            {slot(f)}
            {f.error ? <GroupedFooter error>{f.error}</GroupedFooter> : null}
          </Fragment>
        ))}
        {error ? <GroupedFooter error>{error}</GroupedFooter> : null}
      </GroupedListView>
    </SettingsScaffold>
  );
}
