# Changelog

## 1.3.0

- Add `/iqa` and `/iqa stats` to open an automatically tracked expedition history.
- Save every observed run, difficulty, completion time and result per character.
- Mark runs receiving Tale items whose criteria were known to be incomplete.
- Show completed-run dry streaks and needed, unknown and completed-item receipt totals.
- Link late rewards within two minutes of completion, explicitly labeled as inferred.
- Retain source information and upgrade bag receipts when personal loot is confirmed.
- Paginate history and distinguish offline interruptions from completed expeditions.

## 1.2.0

- Automatically read Helping Hand and Tell Me a Tale achievement progress.
- Suppress recognized rescues and Tale item receipts for completed criteria.
- Refresh on achievement events and stop repeats when credit is earned.
- Silence a completed achievement's recognized objectives and all quest markers when both achievements are complete.
- Show achievement completion/loaded counts in `/iqa status`.
- Preserve potential alerts when progress or a criterion mapping is unavailable.

## 1.1.1

- Use Blizzard's built-in raid-warning display automatically, with no in-game setup.
- Write quest/rescue alerts to chat as well as item and completion notifications.
- Play the same built-in raid-warning sound immediately for quest and Tale item detections.
- Keep an automatic custom-frame fallback and optional mute/diagnostic commands.

## 1.1.0

- Measure each island from observed entry and show elapsed time at scenario completion.
- Preserve timing through reload; distinguish unconfirmed exits from completion.
- Add `/iqa time` for the current and last recorded run.
- Alert on receipt of all 20 Tell Me a Tale quest-starter items, including after returning from an island.
- Pair personal loot messages with bag changes to suppress duplicate notifications.
- Preserve item and completion notifications through loading transitions.
- Package tagged GitHub releases for installation and updates through WowUp.

## 1.0.0

- Initial local build: island detection, quest/rescue notifications, filtering and diagnostics.
