"""Hermes App's outbound messaging platform."""

from pathlib import Path

# The hint goes only to the owner's direct surfaces. Hermes passes the session's
# platform but not its chat type, so group and channel chats on messaging
# platforms cannot be told from DMs and are left out; cron runs have no user.
_HINT_PLATFORMS = frozenset({"hermes_app", "cli", "tui", "desktop"})


def register(ctx):
    from .adapter import HermesAppAdapter, configured, parse_target, standalone_send

    ctx.register_platform(
        name="hermes_app",
        label="Hermes App",
        adapter_factory=HermesAppAdapter,
        check_fn=lambda: True,
        validate_config=configured,
        is_connected=configured,
        emoji="💬",
        max_message_length=0,
        parse_target_ref_fn=parse_target,
        validate_target_ref_fn=_validate_target,
        standalone_sender_fn=standalone_send,
        # Hermes uses this field to recognise plugin cron targets. Home
        # channels still come from config.yaml; no environment setup needed.
        cron_deliver_env_var="HERMES_APP_HOME_CHANNEL",
        platform_hint="You are chatting in Hermes App. Markdown is supported.",
    )
    ctx.register_skill(
        "messaging",
        Path(__file__).parent / "skills" / "messaging" / "SKILL.md",
        description="Send a message to the user's Hermes App inbox.",
    )
    ctx.register_system_prompt_section(
        "hermes-app.messaging", _messaging_hint, max_chars=1200,
    )


def _validate_target(target):
    if target == "inbox":
        return True
    return "Use hermes_app:inbox; other chats and sessions are not delivery targets."


def _messaging_hint(session_info):
    # Rendered once for a new session; Hermes freezes it with the prompt.
    if str((session_info or {}).get("platform") or "") not in _HINT_PLATFORMS:
        return ""
    from gateway.config import Platform, load_gateway_config

    from .adapter import configured

    config = load_gateway_config().platforms.get(Platform("hermes_app"))
    if config is None or not configured(config):
        return ""
    return (
        "Hermes App messaging is available on this installation. Only when the "
        "user explicitly asks you in this conversation to message them in Hermes "
        "App, load the skill hermes-app:messaging. Use `hermes send --to hermes_app:inbox --file PATH` "
        "to deliver UTF-8 text. Each send creates a new saved chat in the current "
        "profile; the user can open it and reply. Hermes App announces it the next "
        "time it checks, within about a minute while it is open; it is not an "
        "instant push to a closed phone. Do not claim delivery unless the command "
        "succeeds."
    )
