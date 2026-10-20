# IslandQuestAlert

A lightweight, dependency-free World of Warcraft **Retail** addon for Island Expedition quest/rescue alerts, elapsed completion times, and Tell Me a Tale item receipts. It scans with the world map closed, shows **ISLAND QUEST DETECTED!**, and plays the raid warning sound on the Master channel.

**Detection is conditional on what the game exposes. This is not a guaranteed island-wide rescue radar.** Public map APIs do not establish that every Helping Hand NPC has an enumerable marker. This build includes diagnostics so actual expedition data can be used to identify missing marker types. The Lua was tested against mocked APIs, not inside a running WoW client.

## Install and update with WowUp

In WowUp, select your Retail client, open **Get Addons → Install from URL**, and paste:

```text
https://github.com/teegles/IslandQuestAlert
```

WowUp installs the attached ZIP from a tagged release and can track subsequent releases. This follows [WowUp's GitHub installation requirements](https://wowup.io/guide/get-addons/overview). For manual installation, download `IslandQuestAlert-<version>.zip` from [Releases](https://github.com/teegles/IslandQuestAlert/releases); GitHub's **Source code** archives have a different folder structure.

## Installation on Linux

Exit WoW. Copy the `IslandQuestAlert` directory into your actual Retail installation:

```text
World of Warcraft/
└── _retail_/
    └── Interface/
        └── AddOns/
            └── IslandQuestAlert/
                ├── IslandQuestAlert.toc
                ├── TaleItems.lua
                ├── IslandQuestAlert.lua
                ├── README.md
                └── API_RESEARCH.md
```

For example, replace the placeholder with your Wine/Lutris/Bottles installation path:

```bash
WOW_RETAIL='/path/to/World of Warcraft/_retail_'
mkdir -p "$WOW_RETAIL/Interface/AddOns"
cp -r ./IslandQuestAlert "$WOW_RETAIL/Interface/AddOns/"
```

If using the ZIP, extract it **into AddOns**, retaining its single `IslandQuestAlert/` directory. Avoid nesting `IslandQuestAlert/IslandQuestAlert/`. Directory and file case matter on Linux. Start WoW, enable IslandQuestAlert in AddOns, then run `/iqa test`.

The TOC targets Retail interface **120105** (12.1.5). On a later patch, check the client interface with `/dump select(4, GetBuildInfo())`; update the TOC after checking compatibility. Do not install this in Classic.

## Commands

| Command | Action |
| --- | --- |
| `/iqa test` | Display the alert for eight seconds; play sound if enabled. Drag it to reposition. |
| `/iqa debug` | Toggle automatic diagnostic chat and a saved 400-line log. Off by default. |
| `/iqa status` | Show scanning state, elapsed time, map IDs, settings, and qualifying objectives. |
| `/iqa time` | Show the current elapsed time and last recorded expedition result. |
| `/iqa sound` | Toggle sound. On by default. Respects WoW's Master volume/mute settings. |
| `/iqa reset` | Clear expedition detections; still-available objectives can alert again. |
| `/iqa repeat` | Toggle repeating every 30 seconds while continuously detectable. Off by default. |
| `/iqa interval 2` | Polling interval in seconds; default 2, accepted range 0.5–60. |
| `/iqa snapshot` | With debug enabled, capture current quest/map fields and classification decisions. |
| `/iqa dump` | Show copyable diagnostic text. Ctrl+A, Ctrl+C; Escape closes. |
| `/iqa allow TYPE ID` | Explicitly enable a diagnosed `quest`, `poi`, `vignette`, or `npc` numeric ID. |
| `/iqa deny TYPE ID` | Remove that explicit allowlist entry; normal recognition still applies. |

Example syntax only: `/iqa allow quest 12345`. **12345 is a placeholder, not a verified rescue quest ID.** Allowlist only IDs you have confirmed in diagnostic output. A wrong entry can intentionally re-enable an unrelated objective.

Settings, frame position, log, timer/last result and expedition deduplication are saved per character in `WTF/Account/<account>/<realm>/<character>/SavedVariables/IslandQuestAlert.lua`. Save occurs on logout or `/reload`; do not edit SavedVariables while the game is running.

## What causes an alert

- An exposed available quest start on the current island map, excluding map indicators, meta quests, combat allies, world quests, threats and generic bonus objectives.
- A matching rescue name in quest, area POI, or visible, living vignette data. Four English fallbacks are included: Royston P. Crutchley III, Grubby Beard, Manape and Longpaws. Helping Hand's achievement criteria labels are also read at runtime for additional/localized NPC names. Those labels are names only; criteria asset IDs are never assumed to be NPC IDs.
- A recognized rescue NPC exposed through your target, mouseover, or a visible nameplate. **This fallback indicates a nearby NPC; it cannot confirm that the rescue is still available.** Nameplates are optional, and disabling them reduces this fallback's coverage.
- An explicitly allowed objective ID, subject to basic source visibility/type filters.

Unknown area POIs, vignettes, task quests and bonus objectives are diagnostic-only. The addon does not infer a quest from yellow-looking artwork, a reward quest ID, or words such as “rescue.” Rares, Azerite and standard expedition indicators are excluded by default. Unknown objectives can therefore be missed; this is deliberate until their data is identified.

Coordinates are percentages on the displayed UI map and appear only when returned for the objective. NPC-only detection has no coordinates; the player's position is never substituted for an NPC's position. Alerts discovered together are queued and displayed for eight seconds each.

A quest ID is deduplicated across quest sources. A recognized rescue name is deduplicated across sources. Allowed area POI/vignette/NPC IDs each use their own identity. If Blizzard supplies an unrelated quest title and a separate NPC marker without a public link between them, those can produce two alerts; the addon cannot safely infer that they are one objective. It does not contain a verified quest-to-rescue database.

## Expedition lifecycle and limitations

The addon recognizes all eleven released island instance IDs: Un'gol Ruins, Havenswood, Jorundall, Verdant Wilds, Whispering Reef, Rotting Mire, Dread Chain, Molten Cay, Skittering Hollow, Snowblossom Village and Crestfall. Detection uses `IsInInstance()` plus `GetInstanceInfo()` result 8, independently of localized zone names. These instance IDs are different from UI map IDs. Scans use the player's current UI map, never the map the player is browsing.

Entry/zone events activate scanning. Quest, POI, vignette, scenario and unit events schedule a scan with a 0.2-second debounce. The configurable ticker catches changes that generate no useful event. A missing current UI map pauses scanning until it becomes available. Leaving the world stops timers; a confirmed non-island location clears the expedition. No map scans run outside a recognized island.

Seen objectives survive `/reload` inside the same island. Public APIs used here do not supply a unique expedition-run identifier. If you leave one run while offline and log directly into another run on the same island without observing an outside location, exit to a non-island location and re-enter to establish a fresh timer/session. `/iqa reset` only clears quest detections; it does not establish a new timed run. A normal observed exit followed by entry creates a fresh session. Repeat availability means “returned by these APIs on consecutive scans,” not server-confirmed quest availability.

The map need never be opened for the addon to run. However, marker data may be absent, stale, range-limited, fog-limited, or cached differently in old content. An empty API result is **not proof that no rescue exists**. No code forces the map open, changes map selection, modifies tracking settings, or scans the rendered minimap. Missing APIs/events and restricted results are logged only in debug mode.

This addon does not predict expedition loot or claim to detect every Tell Me A Tale opportunity. Item notifications report actual receipts; they do not inspect loot tables or infer hidden quest drops. It never accepts quests, interacts with NPCs, moves your character, targets units, or performs protected gameplay actions.

## Expedition timer

Timing starts when the addon first observes entry into a recognized island and includes the pre-start wait. It stops on `SCENARIO_COMPLETED`, with `C_ScenarioInfo.GetScenarioInfo().isComplete` as an event/polling fallback. A large **ISLAND COMPLETE!** notification and one chat line show `MM:SS from entry`. The completion notification is silent. `/iqa time` recalls the current timer and last result; `/iqa status` also shows elapsed time. There is no persistent timer frame.

The start timestamp survives `/reload`. Enabling/installing the addon or joining partway through an expedition measures only the observed portion. This is not Blizzard's official countdown-to-finish duration. If you leave without an observed completion, the result says **completion unconfirmed** and records time until the exit was observed. It never assumes an early exit is a success. Completion does not distinguish victory from defeat. Duplicate completion events and later departure cannot change a frozen result. `/iqa reset` clears objective detections without restarting the timer.

## Tell Me a Tale item alerts

Receiving one of the twenty quest-starter items shows **TELL ME A TALE ITEM!**, its item link/name and quantity, plays the configured sound, and prints one receipt line. Matching uses exact item IDs (listed in [TaleItems.lua](TaleItems.lua)), independently of client language. Cached localized names are preferred over English fallback names.

Item detection is event-driven and remains enabled outside islands to catch return rewards. Personal `CHAT_MSG_LOOT` messages are checked against your player GUID; `BAG_UPDATE_DELAYED` provides a carried-inventory fallback. Matching quantities from the two sources are paired for 15 seconds, in either order. Existing carried items establish a baseline on login/reload and do not generate alerts. Bag counts are kept across normal loading transitions. Item and finish notifications survive departure; queued quest-marker alerts are discarded on exit.

These are receipt notifications for every matching item, including duplicates. They do not assert that its quest is missing from your achievement progress, accept it, or turn it in. The carried-inventory fallback can also alert when you retrieve an item from a bank or mailbox; it cannot infer acquisition provenance. A temporary unavailable inventory result or exceptionally delayed events can limit detection/deduplication. An item gained and consumed entirely between bag events requires a personal loot message to be detected.

## In-game validation and marker discovery

1. Outside an expedition, run `/iqa test`, move the frame, and check sound. `/iqa status` should show scanning disabled.
2. Enter an expedition with `/iqa debug` enabled. Run `/iqa status` and confirm the instance and UI map IDs. Keep the world map closed and run `/iqa snapshot` to establish a baseline.
3. When a rescue/quest appears, run `/iqa snapshot` again. If safe, hover or manually target its NPC to expose the nearby-unit fallback. The log includes NPC IDs for target/mouseover/nameplate units.
4. Check whether an alert occurred automatically. Repeated scans should not re-alert unless repeat is on. `/reload` should preserve the seen objective; `/iqa reset` should allow another alert.
5. For a missing alert, record the exact NPC name, island, approximate location, and which marker you saw. Optionally open the map **once for diagnosis**, then take another snapshot to compare with the closed-map data. This comparison tests whether the client populates a source only after opening the map.
6. Run `/iqa dump` and copy the output before the ring log rolls over. A snapshot prints raw scalar quest/POI/vignette fields, including IDs, names, marker flags and atlas metadata. Decision lines explain why each candidate was allowed or ignored. The snapshot is limited to the current map and currently exposed units; it cannot recover hidden server data.
7. If a numeric task/POI/vignette ID is confirmed to represent the rescue, allow it using the corresponding command and repeat the closed-map test. Unknown generic bonus objectives are never enabled en masse.
8. Leave the expedition and check that scanning stops. Toggle debug off for normal farming.

Diagnostic logging can be verbose, particularly for nameplates. It is intentionally silent when disabled. The saved log persists after debug is turned off and may contain character/NPC/quest names.

For the new features, compare `/iqa time` before and after `/reload`, finish an island and confirm one frozen result, then leave and check that result remains available. Receiving a listed item should generate one alert despite both chat and bag events. Existing items and other players' loot should not. Confirm item alerts also appear during the return transition. An early exit should say completion unconfirmed.

## Local verification

From the addon directory:

```bash
luac5.1 -p TaleItems.lua IslandQuestAlert.lua
lua5.1 tests/run.lua
```

The mock suite covers entry/exit on all eleven instance IDs, unrelated-objective filtering, cross-source deduplication, reload persistence, asynchronous quest names, missing-map recovery, repeat timing, sound settings and diagnostic export. It also covers completion vs. exit, timer persistence, all twenty item IDs, personal loot filtering, localized stack messages, duplicate receipts and rewards during return loading. Tests are not loaded by the TOC. Actual marker availability, visuals, sound playback, achievement localization, and modern client restrictions still require the in-game procedure above.

See [API_RESEARCH.md](API_RESEARCH.md) for checked signatures, Blizzard source links, and the boundaries of closed-map detection.

## Building a release

Run `python3 scripts/package.py` to create `dist/IslandQuestAlert-<version>.zip`. The package includes only the addon and public documentation. The GitHub workflow tests and builds each push; pushing a `v<TOC version>` tag publishes an installable ZIP. Update `RELEASE_NOTES.md` and `CHANGELOG.md` before tagging. The repository is MIT-licensed.
