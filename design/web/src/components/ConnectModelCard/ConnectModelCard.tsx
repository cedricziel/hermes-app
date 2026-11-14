import { Banner } from "../Banner/Banner";
import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import "./ConnectModelCard.css";

/**
 * `connect`: nothing is connected for the profile. `reconnect`: the default
 * model's provider lost its key. `loading`: a provider is connected but its
 * model list is not ready.
 */
export type ConnectModelCardKind = "connect" | "reconnect" | "loading";

export interface ConnectModelCardProps {
  kind: ConnectModelCardKind;
  /** The chat's profile; "default" on a server without profiles. */
  profile: string;
  /** The default model that lost its provider (`reconnect`). */
  modelName?: string;
  /** "Connect a model" and "Reconnect" open Model providers; "Check again" reads the chat's model options again and leads nowhere. */
  onPress?: () => void;
}

const copy: Record<
  ConnectModelCardKind,
  { icon: string; title: string; action: string }
> = {
  connect: {
    icon: "tune",
    title: "Connect a model to start chatting",
    action: "Connect a model",
  },
  reconnect: {
    icon: "lock",
    title: "Reconnect your model's provider",
    action: "Reconnect",
  },
  loading: {
    icon: "hourglass_empty",
    title: "Hermes is loading your models",
    action: "Check again",
  },
};

/**
 * The card that replaces the welcome view's starter prompts while the profile
 * has no usable model (the app's `ConnectModelCard`): a bordered surface with
 * no shadow, a 36px icon tile, a title, the body and one full-width filled
 * button. At most 420px wide; on a Mac or a wide window it is centred in the
 * welcome area. Pass it to `WelcomeView`'s `card`.
 */
export function ConnectModelCard({
  kind,
  profile,
  modelName = "",
  onPress,
}: ConnectModelCardProps) {
  const { icon, title, action } = copy[kind];
  const body =
    kind === "connect"
      ? `Your Hermes server has no model provider for ${profile} yet.`
      : kind === "reconnect"
        ? `New chats in ${profile} use ${modelName}, but its provider's key is missing or no longer works.`
        : "A provider is connected, but its model list isn't ready yet.";
  return (
    <section className="h-connect-card">
      <span className="h-connect-card__tile">
        <Icon name={icon} size={20} />
      </span>
      <h3 className="h-connect-card__title">{title}</h3>
      <p className="h-connect-card__body">{body}</p>
      <Button variant="filled" fullWidth onClick={onPress}>
        {action}
      </Button>
    </section>
  );
}

export interface ProviderReplyFailureProps {
  /** The error the reply failed with. */
  message: string;
  onCheckProviders?: () => void;
}

/**
 * A reply that failed with the model provider's error (a bad key, no
 * credit): the error as an error banner, and under it an outlined "Check model
 * providers" that opens the default model's provider.
 */
export function ProviderReplyFailure({
  message,
  onCheckProviders,
}: ProviderReplyFailureProps) {
  return (
    <div className="h-connect-failure">
      <Banner
        tone="error"
        icon="error"
        title="The reply failed"
        detail={message}
      />
      <div>
        <Button variant="outlined" compact onClick={onCheckProviders}>
          Check model providers
        </Button>
      </div>
    </div>
  );
}
