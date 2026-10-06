import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { FormSection } from "../FormSection/FormSection";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { Spinner } from "../Spinner/Spinner";
import { TextField } from "../TextField/TextField";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "../../styles/form-screen.css";

/** One slot of a blueprint's form, as the server describes it. */
export interface BlueprintFieldItem {
  /** Slot name, e.g. `time`, `deliver`. */
  name: string;
  /** The question above the input: "What time?". */
  label: string;
  /**
   * `time`: an outlined button with a clock ("08:00", or "Choose a time").
   * `choice`: a chip per option. `text`: a text field (one to three lines).
   */
  type: "time" | "choice" | "text";
  /** `choice`: the options, e.g. `origin`, `local`, `telegram`. */
  options?: string[];
  /** The value entered or picked. */
  value?: string;
  /** Muted help under the input. */
  help?: string;
  /** Adds " (optional)" after the label. */
  optional?: boolean;
  /** Red error under the input, after a failed Create: "Pick a time". */
  error?: string;
}

export interface BlueprintFormScreenProps {
  /** The blueprint's title, in the bar: "Morning briefing". */
  title: string;
  /** What the blueprint does, above the fields. */
  description?: string;
  /** The slots, top to bottom. */
  fields: BlueprintFieldItem[];
  /** The server refused the job: red text above Create task. */
  error?: string;
  /** The job is being created: a spinner in the disabled button. */
  saving?: boolean;
  /** `phone` shows the parent's title ("New scheduled task") beside the Apple back chevron. */
  layout?: "phone" | "desktop";
  /** `apple`: the chevron back button and the iOS type ramp; the form is Material on every platform, as in the app. Inherits the provider's platform. */
  platform?: Platform;
  /** A choice was picked or text typed in a slot. */
  onFieldChange?: (name: string, value: string) => void;
  /** A time slot's button pressed (the app opens the time picker). */
  onPickTime?: (name: string) => void;
  /** "Create task" pressed. */
  onCreate?: () => void;
  /** Back pressed (to the gallery). */
  onBack?: () => void;
}

/**
 * A blueprint's form, opened from the "New scheduled task" gallery: the
 * description, then one `FormSection` per slot the server describes (a time
 * button, option chips or a text field, with help and errors), and a
 * full-width "Create task" button. On `ListDetailLayout`'s `list` layout.
 * Fills its parent.
 */
export function BlueprintFormScreen({
  title,
  description,
  fields,
  error,
  saving = false,
  layout = "phone",
  platform,
  onFieldChange,
  onPickTime,
  onCreate,
  onBack,
}: BlueprintFormScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ListDetailLayout
        layout="list"
        title={title}
        onBack={onBack ?? (() => {})}
        backLabel={layout === "phone" ? "Back" : undefined}
        list={
          <div className="h-form-screen">
            {description ? (
              <div className="h-body-md">{description}</div>
            ) : null}
            {fields.map((f) => (
              <FormSection
                key={f.name}
                title={f.label}
                optional={f.optional}
                helper={f.help}
                error={f.error}
                gap={6}
              >
                {f.type === "time" ? (
                  <div>
                    <Button
                      variant="outlined"
                      icon="schedule"
                      onClick={() => onPickTime?.(f.name)}
                    >
                      {f.value || "Choose a time"}
                    </Button>
                  </div>
                ) : f.type === "choice" ? (
                  <div className="h-form-screen__chips">
                    {(f.options ?? []).map((o) => (
                      <Chip
                        key={o}
                        label={o}
                        selected={f.value === o}
                        onClick={() => onFieldChange?.(f.name, o)}
                      />
                    ))}
                  </div>
                ) : (
                  <TextField
                    value={f.value ?? ""}
                    aria-label={f.label}
                    onChange={(e) => onFieldChange?.(f.name, e.target.value)}
                    readOnly={!onFieldChange}
                  />
                )}
              </FormSection>
            ))}
            {error ? <div className="h-form-screen__error">{error}</div> : null}
            <Button fullWidth disabled={saving} onClick={onCreate}>
              {saving ? <Spinner size={18} label="Creating" /> : "Create task"}
            </Button>
          </div>
        }
      />
    </PlatformScope>
  );
}
