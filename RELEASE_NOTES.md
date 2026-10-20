IslandQuestAlert provides quest/rescue alerts, expedition timing, and Tell Me a Tale item notifications for WoW Retail.

- Shows a completion time measured from observed island entry; `/iqa time` recalls the last run.
- Alerts when you receive any of the 20 Tell Me a Tale starter items.
- Keeps map scanning confined to recognized Island Expeditions.
- Includes diagnostics for legacy BFA markers that public APIs may not expose.

Install through WowUp: **Get Addons → Install from URL**, then paste `https://github.com/teegles/IslandQuestAlert`.

The attached ZIP has the required `IslandQuestAlert/` addon folder. GitHub's automatically generated source archives are not the installable release.

Validation: Lua 5.1 syntax checks and mock tests under Lua 5.1 and LuaJIT passed. In-game marker availability and UI/audio playback still require Retail validation. Timing starts at observed entry, not the official countdown; joining late or enabling the addon mid-run produces a partial measurement. Item acquisition is not quest completion or guaranteed missing achievement credit.
