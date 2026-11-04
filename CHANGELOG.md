# Changelog

## 1.0.3+2022

### Privacy
- Passwords, PINs and OTP fields are redacted in the screen dump before it is
  sent to the AI provider (`isPassword`, `otp`, `pin`, `cvv`, `passcode` hints).
- Screen dumps, AI prompts and API bodies are no longer written to logcat in
  release builds; native log channel is debug-only.

### Safety
- Telegram remote control is owner-only: the first chat that talks to the bot
  claims ownership, every other chat is refused. `/stop` cancels a running task.
  Simple rate limit (10 commands/minute).
- Shizuku/ADB shell commands are restricted to an allowlist; anything else is
  refused instead of executed.

### Agent quality
- Screen dump now carries `role`, `hintText`, `isEnabled`, `isSelected`,
  `isPassword` and `windowType`, and is capped at 200 elements per screen.

### Sound
- Shared `SpeechFeedback` announcer: every finished, failed or cancelled task is
  spoken out loud, at full volume, in the phone's own language.
- Notification alerts moved to a dedicated `task_alerts_v2` channel (max
  importance, sound + vibration pattern).
- TTS language and rate are configurable via `voice_language` / `voice_rate`,
  and spoken feedback can be turned off with `voice_feedback_enabled = false`.
