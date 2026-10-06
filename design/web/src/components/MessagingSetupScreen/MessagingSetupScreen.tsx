import type { MessagingPlatform } from "../MessagingPlatformRow/MessagingPlatformRow";
import { Button } from "../Button/Button";
import { FormSection } from "../FormSection/FormSection";
import { IconButton } from "../IconButton/IconButton";
import { Spinner } from "../Spinner/Spinner";
import { TextField } from "../TextField/TextField";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import type { AppleDevice, Platform } from "../../platform";
import "./MessagingSetupScreen.css";

/** A setting a messaging platform reads from its environment. */
export interface MessagingEnvVar {
  /** Environment variable: "DISCORD_BOT_TOKEN". */
  key: string;
  /** The field's label: "Discord bot token". */
  label: string;
  /** Hint under the field: "Create it in the developer portal". */
  help?: string;
  /** Required: Save fails with "Required" while it is unset and blank. */
  required?: boolean;
  /** The dashboard already holds a value. It is never shown; the hint says "Set (1234...9999). Leave blank to keep it." and, unless required, a button can clear it. */
  isSet?: boolean;
  /** The redacted value the dashboard reports for a set variable: "1234...9999". */
  redactedValue?: string;
  /** A secret: the field hides what is typed. */
  password?: boolean;
  /** Listed under the collapsible "Advanced" section. */
  advanced?: boolean;
}

export interface MessagingSetupScreenProps {
  /** The platform being set up; its name goes in the title. Telegram adds "Set up with Telegram" above the fields. */
  messagingPlatform: Pick<MessagingPlatform, "id" | "name">;
  /** Its settings. None: "Nothing to set up for this messaging platform." */
  envVars?: MessagingEnvVar[];
  /** What is typed into each field, by key. Blank keeps a set value. */
  values?: Record<string, string>;
  /** Keys marked to be cleared on save: the field reads "Will be cleared" and its button undoes it. */
  cleared?: string[];
  /** Validation messages by key: "Required". */
  fieldErrors?: Record<string, string>;
  /** The Advanced section is open. The app opens it when an advanced variable is required and unset. */
  advancedOpen?: boolean;
  /** Why saving failed, in red above Save. */
  error?: string;
  /** Saving: a spinner in the disabled Save button. */
  saving?: boolean;
  onBack?: () => void;
  onPairTelegram?: () => void;
  onChange?: (key: string, value: string) => void;
  /** The clear (or keep) button of a set variable was pressed. */
  onToggleCleared?: (key: string) => void;
  onToggleAdvanced?: () => void;
  onSave?: () => void;
  /** `phone` or `desktop`; the form stays in a 640px column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back with "Messaging", Apple spinner. The form itself is Material everywhere, as in the app. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * The setup form of one messaging platform, pushed from the Messaging screen: a field
 * per environment variable (secrets hidden, values the dashboard holds never
 * shown), an "Advanced" `FormSection` that folds, and a full-width Save.
 * Telegram starts with "Set up with Telegram", which opens
 * `TelegramPairingScreen`.
 */
export function MessagingSetupScreen({
  messagingPlatform: target,
  envVars = [],
  values = {},
  cleared = [],
  fieldErrors = {},
  advancedOpen = false,
  error,
  saving = false,
  onBack,
  onPairTelegram,
  onChange,
  onToggleCleared,
  onToggleAdvanced,
  onSave,
  layout = "phone",
  platform,
  device,
}: MessagingSetupScreenProps) {
  const basic = envVars.filter((v) => !v.advanced);
  const advanced = envVars.filter((v) => v.advanced);
  const field = (v: MessagingEnvVar) => {
    const isCleared = cleared.includes(v.key);
    const helper = [
      isCleared
        ? "Will be cleared"
        : v.isSet
          ? `Set (${v.redactedValue ?? "hidden"}). Leave blank to keep it.`
          : undefined,
      v.help,
    ]
      .filter(Boolean)
      .join(" ");
    return (
      <div key={v.key} className="h-messaging-setup__field">
        <TextField
          label={v.label}
          type={v.password ? "password" : "text"}
          autoComplete="off"
          readOnly={isCleared}
          value={values[v.key] ?? ""}
          helper={helper || undefined}
          error={fieldErrors[v.key]}
          onChange={(e) => onChange?.(v.key, e.target.value)}
        />
        {v.isSet && !v.required ? (
          <span className="h-messaging-setup__clear">
            <IconButton
              icon={isCleared ? "undo" : "delete"}
              label={isCleared ? `Keep ${v.label}` : `Clear ${v.label}`}
              onClick={() => onToggleCleared?.(v.key)}
            />
          </span>
        ) : null}
      </div>
    );
  };
  return (
    <ScreenFrame
      title={`Set up ${target.name}`}
      onBack={onBack}
      backLabel="Messaging"
      layout={layout}
      platform={platform}
      device={device}
      centered={envVars.length === 0}
    >
      {envVars.length === 0 ? (
        <div className="h-body-md">
          Nothing to set up for this messaging platform.
        </div>
      ) : (
        <div className="h-messaging-setup">
          {target.id === "telegram" ? (
            <>
              <Button
                variant="outlined"
                icon="auto_fix_high"
                fullWidth
                onClick={onPairTelegram}
              >
                Set up with Telegram
              </Button>
              <div className="h-body-md h-messaging-setup__or">
                Or enter the details yourself.
              </div>
            </>
          ) : null}
          {basic.map(field)}
          {advanced.length > 0 ? (
            <FormSection
              title="Advanced"
              collapsible
              open={advancedOpen}
              onToggle={onToggleAdvanced}
              gap={0}
            >
              {advanced.map(field)}
            </FormSection>
          ) : null}
          {error ? (
            <div className="h-body-md h-messaging-setup__error" role="alert">
              {error}
            </div>
          ) : null}
          <div className="h-messaging-setup__save">
            <Button fullWidth disabled={saving} onClick={onSave}>
              {saving ? <Spinner size={18} label="Saving" /> : "Save"}
            </Button>
          </div>
        </div>
      )}
    </ScreenFrame>
  );
}
