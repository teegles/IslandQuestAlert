Install and farm: no in-game configuration is required.

- Quest/rescue and Tell Me a Tale item alerts use the same built-in raid-warning sound.
- Large yellow notices appear in Blizzard's raid-warning area and also in your chat.
- Sound and chat fire immediately at detection.
- Expedition completion times remain automatic; `/iqa time` recalls the last run.
- Existing optional mute/repeat preferences and diagnostics remain available.

In WowUp, install or update from `https://github.com/teegles/IslandQuestAlert`.

The attached ZIP contains the installable `IslandQuestAlert/` folder. Lua 5.1/LuaJIT mock tests pass, including native warning output, shared sound and automatic fallback. In-game marker availability and UI/audio playback still require Retail validation. Public APIs may not expose every Helping Hand marker.
