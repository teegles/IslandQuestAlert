# Retail API investigation

Checked 2026-10-19 against Blizzard's exported Retail `live` API documentation and map provider code, mirrored in Gethe/wow-ui-source. Links below are mutable live sources, not a claim of testing a particular game binary. Research preceded implementation. The live sources establish function shapes and Blizzard's consumers; they do not establish what a BFA island server currently sends.

## Checked APIs and implementation choices

| API | Signature/result used | Scope and limitation |
| --- | --- | --- |
| `C_QuestLog.GetQuestsOnMap` | `(uiMapID)` → array of `QuestPOIMapInfo`, possibly no result | Quest POIs, not a universal list of unaccepted quest givers. |
| `C_QuestLog.GetTitleForQuestID` | `(questID)` → title or nil | Missing names are requested with `RequestLoadQuestByID(questID)`; the load-result event triggers another scan. |
| `C_TaskQuest.GetQuestsOnMap` | `(uiMapID)` → array of `QuestPOIMapInfo`, possibly no result | Task data; no assumed second map argument. |
| `C_TaskQuest.GetQuestInfoByQuestID` | `(questID)` → title, factionID, capped, displayAsObjective | Title fallback. Task status alone does not identify a rescue. |
| `C_AreaPoiInfo.GetAreaPOIForMap` | `(uiMapID)` → array of numeric area POI IDs | Not every quest giver is an area POI. |
| `C_AreaPoiInfo.GetAreaPOIInfo` | `(uiMapID, areaPoiID)` → info or no result | Uses name and `position:GetXY()`; generic icons cannot establish rescue identity. |
| `C_Map.GetBestMapForUnit` | `("player")` → UI map ID or nil | Current player map independent of the map window. |
| `C_QuestLine.GetAvailableQuestLines` | `(uiMapID)` → array of `QuestLineInfo` | Available quest lines; not all quest givers belong to one. |
| `C_QuestLine.GetForceVisibleQuests` | `(uiMapID)` → array of quest IDs | Resolve through `GetQuestLineInfo(questID, uiMapID, false)`. |
| `C_QuestLine.RequestQuestLinesForMap` | `(uiMapID)` | Explicitly requests data on entry/map change and when requested by `QUESTLINE_UPDATE`. |
| `C_VignetteInfo.GetVignettes` | `()` → array of vignette GUIDs | **Current namespace is `C_VignetteInfo`, not `C_Vignette`.** |
| `C_VignetteInfo.GetVignetteInfo` | `(vignetteGUID)` → info or nil | Name, visibility, fog and death flags; rewardQuestID is not proof of a rescue. |
| `C_VignetteInfo.GetVignettePosition` | `(vignetteGUID, uiMapID)` → vector, facing or no result | Must resolve on the player's current map. |

`QuestPOIMapInfo` uses **`questID`**, not older examples' `questId`. Relevant fields include `mapID`, `x`, `y`, `isQuestStart`, `inProgress`, `isMapIndicatorQuest`, `isCombatAllyQuest` and `isMeta`. These are structural fields, not assertions that a particular rescue will appear in a returned list.

Blizzard's quest-offer provider aggregates quest-line data, force-visible quests and tasks. It requests quest-line data and responds to `QUESTLINE_UPDATE`. `C_QuestOffer` concerns the quest-offer interaction and is not used as an invented map-marker enumeration API. Blizzard's quest POI provider consumes quest map data and listens to `QUEST_LOG_UPDATE` and `QUEST_POI_UPDATE`.

## Closed-map access: confirmed vs unconfirmed

The checked functions take map IDs or objective IDs and have no documented requirement for a visible world map. IslandQuestAlert calls them directly, with its own events and timer; it does not access `WorldMapFrame`, create hidden map canvases, or rely on Blizzard's providers being shown.

**What remains unconfirmed:** whether every Helping Hand objective appears in those results in today's Retail client, when its data becomes available, and whether previously loaded caches affect it. Blizzard's provider registration on map show is UI behavior, not evidence that the underlying server exposes every marker while that UI is hidden.

There is no supported all-NPC enumeration or general “enumerate the quest exclamation marks rendered on the minimap” function in the investigated APIs. `C_Minimap` tracking configuration is not such an enumeration. Nearby target, mouseover and nameplate tokens provide a limited fallback. They do not reveal arbitrary distant NPCs or confirm quest availability.

The implementation therefore combines positively identifiable map offers with recognized rescue names and explicit user-confirmed IDs. Unclassified markers are inspectable, but do not cause speculative alerts. It does not change `C_QuestLog.SetMapForQuestPOIs` shared context merely to populate caches: that could affect Blizzard's or another addon's map use and would not prove rescue availability.

## Events

Quest/map activity: `QUEST_LOG_UPDATE`, `QUEST_POI_UPDATE`, `QUEST_DATA_LOAD_RESULT`, `QUESTLINE_UPDATE`, `AREA_POIS_UPDATED`, `VIGNETTES_UPDATED`, `VIGNETTE_MINIMAP_UPDATED`. Scenario, criteria, quest acceptance/turn-in and exposed-unit events provide additional scan triggers. Polling covers sources with no dependable event for this old content.

Events are registered defensively; rejected event names are reported in debug mode. API calls are checked for existence and wrapped with `pcall`. Top-level restricted results and restricted scalar fields in returned marker tables are skipped, not used to bypass client restrictions. Compatibility guards cannot prove full compatibility with future client changes.

## Sources

- [Blizzard QuestLog documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
- [Blizzard task quest documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestTaskInfoDocumentation.lua)
- [Blizzard shared quest POI structure](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestInfoSharedDocumentation.lua)
- [Blizzard area POI documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AreaPoiInfoDocumentation.lua)
- [Blizzard map documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua)
- [Blizzard quest-line documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua)
- [Blizzard vignette documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/VignetteInfoDocumentation.lua)
- [Blizzard minimap documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MinimapDocumentation.lua)
- [Blizzard quest-offer map provider](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_SharedMapDataProviders/QuestOfferDataProvider.lua)
- [Blizzard quest POI map provider](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_SharedMapDataProviders/QuestDataProvider.lua)
- [Current Retail TOC example, maintained by Masque's authors](https://github.com/SFX-WoW/Masque/blob/main/Masque.toc), declaring `120105`; the addon targets this Retail interface only.

The island instance table is intentionally explicit and can be inspected in the Lua file. Diagnostic entry logs expose the runtime `GetInstanceInfo()` and player UI map values so mismatches can be corrected without guessing localized zone names or treating an instance ID as a UI map ID.

## Timing, item receipts and WowUp (1.1.0)

[Blizzard's scenario documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ScenarioInfoDocumentation.lua) defines `C_ScenarioInfo.GetScenarioInfo()` returning a table whose `isComplete` field can be queried. `SCENARIO_COMPLETED` supplies optional questID, XP and money; no payload value is treated as a duration. Timing uses the addon-observed entry timestamp and completion timestamp, saved per character.

[Blizzard's item documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) defines `C_Item.GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank, includeAccountBank)` and `C_Item.GetItemInfo(itemInfo)`; the implementation explicitly disables the four optional count modes. Only twenty IDs are counted on bag events. [Chat event documentation](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua) places loot text at argument 1, lineID at 11 and player GUID at 12 of `CHAT_MSG_LOOT`. No other player's loot causes a personal loot notification. Stack quantities use the client's `LOOT_ITEM_SELF_MULTIPLE` format.

The exact twenty item IDs and names in `TaleItems.lua` were checked through the item links on [Tell Me a Tale's achievement page](https://www.wowhead.com/achievement=13127/tell-me-a-tale), including Notched Coin **163466**, Ancient Crypt Key **163470**, Sonic Stone **163473**, and Magical Spyglass **163475**. IDs are explicit: the code does not assume a consecutive item range. Item ownership is not evidence that its achievement quest has been completed or is still needed.

[WowUp's installation guide](https://wowup.io/guide/get-addons/overview) requires a tagged GitHub release with an attached installable ZIP. Its [packaging guide](https://wowup.io/guide/wowup/hub) requires the addon's directory at the ZIP root. `scripts/package.py` validates that layout and verifies every TOC-listed Lua file is packaged.
