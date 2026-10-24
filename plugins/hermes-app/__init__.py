"""Hermes App's outbound messaging platform."""

from pathlib import Path


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
        validate_target_ref_fn=lambda target: target == "inbox",
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


def _messaging_hint(session_info):
    # Rendered once for a new session; Hermes freezes it with the prompt.
    from hermes_cli.config import load_config_readonly

    platforms = load_config_readonly().get("platforms") or {}
    config = platforms.get("hermes_app") or {}
    if config.get("enabled") is not True:
        return ""
    return (
        "Hermes App messaging is available on this installation. When the user "
        "asks you to message them in Hermes App, load the skill "
        "hermes-app:messaging. Use `hermes send --to hermes_app:inbox --file PATH` "
        "to deliver UTF-8 text. Each send creates a new saved chat in the current "
        "profile; the user can open it and reply. Hermes App announces it the next "
        "time it checks, within about a minute while it is open; it is not an "
        "instant push to a closed phone. Do not claim delivery unless the command "
        "succeeds."
    )
