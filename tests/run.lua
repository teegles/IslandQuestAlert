-- Run from the addon directory: lua5.1 tests/run.lua
-- No game client or external dependencies required. Tests do not load in WoW.
local now, clock, currentInstance, currentMap = 0, 1000, 0, nil
local tasks, quests, lines, forceVisible, pois, vignettes, units = {}, {}, {}, {}, {}, {}, {}
local titles, classes, timers, frames, sounds, messages, requested = {}, {}, {}, {}, 0, {}, {}
local warnings, soundCalls = {}, {}
RaidWarningFrame = {AddMessage = function(self, text, color, seconds)
    assert(self == RaidWarningFrame)
    warnings[#warnings + 1] = {text = text, color = color, seconds = seconds}
end}
local function noop() end
local frameMethods = {}
for _, name in ipairs({"SetSize", "SetPoint", "SetFrameStrata", "SetMovable", "SetClampedToScreen", "EnableMouse",
    "RegisterForDrag", "SetFont", "SetTextColor", "SetWidth", "SetFontObject", "SetMultiLine", "SetAutoFocus",
    "StartMoving", "StopMovingOrSizing", "ClearAllPoints", "SetBackdrop", "SetBackdropColor", "SetScrollChild",
    "SetVerticalScroll"}) do frameMethods[name] = noop end
function frameMethods:SetText(text) self.text = text end
function frameMethods:CreateFontString() return setmetatable({}, {__index = frameMethods}) end
function frameMethods:SetScript(event, fn) self.scripts[event] = fn end
function frameMethods:RegisterEvent(event) self.events[event] = true end
function frameMethods:UnregisterEvent(event) self.events[event] = nil end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide() self.shown = false end
function frameMethods:IsShown() return self.shown end
function CreateFrame(_, name)
    local frame = setmetatable({events = {}, scripts = {}}, {__index = frameMethods})
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
UIParent = {}; STANDARD_TEXT_FONT = "font"; SOUNDKIT = {RAID_WARNING = 8959}
UISpecialFrames = {}; tinsert = table.insert; SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, text) messages[#messages + 1] = text end}
function GetTime() return now end
function time() return clock end
function date() return "00:00:00" end
function GetInstanceInfo() return "zone", "scenario", 1, "normal", 3, 0, false, currentInstance end
function IsInInstance() return currentInstance ~= 0, "scenario" end
function GetBuildInfo() return "12.1.5", "mock", "mock", 120105 end
function GetLocale() return "enUS" end
function PlaySound(sound, channel)
    sounds = sounds + 1
    soundCalls[#soundCalls + 1] = {sound = sound, channel = channel}
end
function UnitName(unit) return units[unit] and units[unit].name end
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitIsDeadOrGhost(unit) return units[unit] and units[unit].dead end
function GetAchievementNumCriteria() return 1 end
function GetAchievementCriteriaInfo() return "Localized Rescue" end
C_Timer = {}
local function timer(delay, callback, repeating)
    local t = {due = now + delay, delay = delay, callback = callback, repeating = repeating}
    function t:Cancel() self.cancelled = true end
    timers[#timers + 1] = t
    return t
end
function C_Timer.NewTimer(d, f) return timer(d, f, false) end
function C_Timer.NewTicker(d, f) return timer(d, f, true) end
C_Map = {GetBestMapForUnit = function() return currentMap end}
C_QuestLog = {
    GetQuestsOnMap = function(id) assert(id == currentMap); return quests end,
    GetTitleForQuestID = function(id) return titles[id] end,
    RequestLoadQuestByID = function(id) requested[id] = true end,
}
C_TaskQuest = {GetQuestsOnMap = function() return tasks end, GetQuestInfoByQuestID = function(id) return titles[id] end}
C_QuestLine = {
    GetAvailableQuestLines = function() return lines end,
    GetForceVisibleQuests = function() return forceVisible end,
    GetQuestLineInfo = function(id) return titles[id] and {questID = id, questName = titles[id], startMapID = currentMap} end,
    RequestQuestLinesForMap = noop,
}
C_AreaPoiInfo = {GetAreaPOIForMap = function() local ids = {}; for id in pairs(pois) do ids[#ids + 1] = id end; return ids end,
    GetAreaPOIInfo = function(_, id) return pois[id] end}
C_VignetteInfo = {
    GetVignettes = function() local ids = {}; for id in pairs(vignettes) do ids[#ids + 1] = id end; return ids end,
    GetVignetteInfo = function(id) return vignettes[id] end,
    GetVignettePosition = function(id) return vignettes[id].position end,
}
Enum = {QuestClassification = {Normal = 7, BonusObjective = 8, WorldQuest = 10, Threat = 9}}
C_QuestInfoSystem = {GetQuestClassification = function(id) return classes[id] or 7 end}
local counts, scenarioComplete = {[163466] = 1}, false
C_Item = {GetItemCount = function(id) return counts[id] or 0 end, GetItemInfo = function() return nil end}
C_ScenarioInfo = {GetScenarioInfo = function() return {isComplete = scenarioComplete} end}
local ns = {}
assert(loadfile("TaleItems.lua"))("IslandQuestAlert", ns)
assert(loadfile("IslandQuestAlert.lua"))("IslandQuestAlert", ns)
local driver = frames[1]
local function event(name, ...) driver.scripts.OnEvent(driver, name, ...) end
local function command(s) SlashCmdList.ISLANDQUESTALERT(s) end
local function advance(seconds)
    now = now + seconds; clock = clock + seconds
    -- Run only timers present at tick start; callbacks may create timers.
    local count = #timers
    for i = 1, count do
        local t = timers[i]
        if not t.cancelled and now >= t.due then
            if t.repeating then t.due = now + t.delay else t.cancelled = true end
            t.callback()
        end
    end
end
local function seen(key) return IslandQuestAlertDB.session.seen[key] end
local function enter(id, map)
    currentInstance, currentMap = id, map
    event("PLAYER_ENTERING_WORLD", false, false); advance(0.3)
end
local function scan() event("QUEST_POI_UPDATE"); advance(0.3) end
local function seenCount()
    local n = 0; for _ in pairs(IslandQuestAlertDB.session.seen) do n = n + 1 end; return n
end
local function vector(x, y) return {GetXY = function() return x, y end} end

event("ADDON_LOADED", "IslandQuestAlert")
assert(IslandQuestAlertDB.interval == 2)
enter(0, nil)
assert(not IslandQuestAlertDB.session and sounds == 0)
enter(1893, 1031)
assert(IslandQuestAlertDB.session.instanceID == 1893)
-- Standard objectives, bonus objectives and rare vignettes stay silent.
tasks = {{questID = 1, isMapIndicatorQuest = true}, {questID = 2}, {questID = 3, isQuestStart = true}}
classes[3] = 8
titles[1], titles[2], titles[3] = "Azerite", "Standard objective", "Collect Azerite"
vignettes.rare = {vignetteID = 99, name = "Rare Monster", onWorldMap = true, position = vector(.5, .5)}
scan(); assert(seenCount() == 0 and sounds == 0)
-- A real quest start, cross-source duplicates and disappearance/reappearance.
tasks = {{questID = 100, isQuestStart = true, x = .25, y = .6, mapID = 1031}}
titles[100] = "Rescue quest"
lines = {{questID = 100, questName = "Rescue quest", startMapID = 1031}}
scan(); assert(seen("quest:100") and seenCount() == 1 and sounds == 1)
assert(warnings[#warnings].text:find("ISLAND QUEST DETECTED!", 1, true))
assert(warnings[#warnings].text:find("Rescue quest", 1, true))
assert(warnings[#warnings].text:find("25.0, 60.0", 1, true))
assert(warnings[#warnings].color.r == 1 and warnings[#warnings].color.g == .9)
assert(warnings[#warnings].seconds == 8)
assert(messages[#messages]:find("ISLAND QUEST DETECTED!", 1, true))
assert(soundCalls[#soundCalls].sound == SOUNDKIT.RAID_WARNING and soundCalls[#soundCalls].channel == "Master")
local warningCount, chatCount = #warnings, #messages
scan(); assert(sounds == 1 and #warnings == warningCount and #messages == chatCount)
tasks, lines = {}, {}; scan()
tasks = {{questID = 100, isQuestStart = true}}; scan(); assert(sounds == 1)
-- Reload boundary must retain seen keys.
local saved = IslandQuestAlertDB.session
event("PLAYER_LEAVING_WORLD"); enter(1893, 1031)
assert(IslandQuestAlertDB.session == saved and sounds == 1)
-- Missing title retries through QUEST_DATA_LOAD_RESULT without a new quest row.
tasks = {{questID = 200}}; scan(); assert(requested[200] and not seen("quest:200"))
titles[200] = "Longpaws"; event("QUEST_DATA_LOAD_RESULT", 200, true); advance(.3)
assert(seen("rescue:longpaws"))
-- The same named rescue in POI, vignette and unit data is one objective.
pois[5] = {name = "Longpaws", position = vector(.1, .2)}
vignettes.rescue = {vignetteID = 7, name = "Longpaws", onWorldMap = true, position = vector(.1, .2)}
units.target = {name = "Longpaws", guid = "Creature-0-1-2-3-12345-ABC"}
scan(); assert(seenCount() == 2)
-- Foreign map starts and world quests cannot alert.
tasks = {{questID = 300, mapID = 999, isQuestStart = true}, {questID = 301, isQuestStart = true}}
classes[301] = 10; scan(); assert(not seen("quest:300") and not seen("quest:301"))
-- Explicitly allow a diagnosed task; generic tasks stay ignored.
command("allow quest 400"); tasks = {{questID = 400}}; scan(); assert(seen("quest:400"))
-- Map unavailable pauses scans, then recovers through polling.
currentMap = nil; advance(2); assert(IslandQuestAlertDB.session == saved)
currentMap = 1031; advance(2)
-- Repeat requires continuous detectability for 30 seconds, and sound toggle is respected.
command("reset"); command("repeat"); command("sound")
scan(); local first = seen("quest:400").lastAlert
advance(29); assert(seen("quest:400").lastAlert == first)
advance(2); assert(seen("quest:400").lastAlert > first)
tasks = {}; scan(); advance(35)
tasks = {{questID = 400}}; scan(); local last = seen("quest:400").lastAlert
advance(2); assert(seen("quest:400").lastAlert == last)
-- Sound disabled also applies to the test command and queued alerts.
local silentCount = sounds
command("test"); advance(10); assert(sounds == silentCount)
-- Missing, erroring, and restricted APIs degrade without false alerts.
local oldGetPOIs = C_AreaPoiInfo.GetAreaPOIForMap
C_AreaPoiInfo.GetAreaPOIForMap = nil
local oldGetTasks = C_TaskQuest.GetQuestsOnMap
C_TaskQuest.GetQuestsOnMap = function() error("transient unavailable map data") end
scan()
C_AreaPoiInfo.GetAreaPOIForMap = oldGetPOIs
C_TaskQuest.GetQuestsOnMap = oldGetTasks
local restricted = {}
function issecretvalue(value) return value == restricted end
tasks = {{questID = 900, isQuestStart = restricted}}
scan(); assert(not seen("quest:900"))
local oldTitle = C_QuestLog.GetTitleForQuestID
C_QuestLog.GetTitleForQuestID = function() return restricted end
tasks = {{questID = 901}}; scan(); assert(not seen("quest:901"))
C_QuestLog.GetTitleForQuestID = oldTitle
issecretvalue = nil
tasks = {{questID = 400}}
-- Debug disabled: automatic scans produce zero chat output.
local before = #messages; scan(); assert(#messages == before)
command("debug"); scan(); assert(#IslandQuestAlertDB.log > 0)
command("snapshot"); command("dump"); assert(IslandQuestAlertDiagnostics.edit.text:find("interface=120105"))
-- Exiting cancels scanning and clears the expedition; next same island is fresh.
enter(0, nil); assert(not IslandQuestAlertDB.session)
local count = #messages; advance(10); assert(#messages == count)
enter(1893, 1031); assert(IslandQuestAlertDB.session ~= saved and seen("quest:400"))
-- All 11 supported island instances activate; other scenarios do not.
for _, id in ipairs({1813,1814,1879,1882,1883,1892,1893,1897,1898,1907,2124}) do
    enter(id, 1031); assert(IslandQuestAlertDB.session.instanceID == id)
end
enter(33, 1031); assert(not IslandQuestAlertDB.session)
-- A missed zone event still stops the ticker on its next location check.
enter(1893, 1031)
currentInstance, currentMap = 0, nil
advance(2); assert(not IslandQuestAlertDB.session)
local function receiptCount()
    local total = 0
    for _, text in ipairs(messages) do if text:find("Tell Me a Tale item received:", 1, true) then total = total + 1 end end
    return total
end
assert(receiptCount() == 0) -- Pre-existing Notched Coin never alerted.
-- Timer freezes once, preserves start across reload, and reset affects objectives only.
enter(1893, 1031)
local start = IslandQuestAlertDB.session.startedAt
advance(60)
event("PLAYER_LEAVING_WORLD"); enter(1893, 1031)
assert(IslandQuestAlertDB.session.startedAt == start)
command("reset"); assert(IslandQuestAlertDB.session.startedAt == start)
advance(65); event("SCENARIO_COMPLETED")
local run = IslandQuestAlertDB.lastRun
assert(run.reason == "completed" and run.elapsed >= 125 and run.elapsed < 127)
local ended = run.endedAt
advance(40); event("SCENARIO_COMPLETED"); assert(IslandQuestAlertDB.lastRun.endedAt == ended)
enter(0, nil); assert(IslandQuestAlertDB.lastRun == run)
command("time")
-- Query fallback works even with no current UI map.
enter(1813, nil); advance(30)
scenarioComplete = true; event("SCENARIO_UPDATE"); advance(.3)
assert(IslandQuestAlertDB.lastRun.reason == "completed")
scenarioComplete = false; enter(0, nil)
-- Leaving early records an unconfirmed exit, never a success.
enter(1813, 1031); advance(10); enter(0, nil)
assert(IslandQuestAlertDB.lastRun.reason == "left")
local priorRun = IslandQuestAlertDB.lastRun
event("SCENARIO_COMPLETED"); assert(IslandQuestAlertDB.lastRun == priorRun)
-- All twenty exact Tale IDs are monitored, even outside an island.
local itemTotal = 0
for id in pairs(ns.taleItems) do
    itemTotal = itemTotal + 1
    local before = receiptCount()
    counts[id] = (counts[id] or 0) + 1
    event("BAG_UPDATE_DELAYED"); event("BAG_UPDATE_DELAYED")
    assert(receiptCount() == before + 1, "Item not detected: " .. id)
end
assert(itemTotal == 20)
local before = receiptCount()
counts[999999] = 1; event("BAG_UPDATE_DELAYED"); assert(receiptCount() == before)
-- Chat verifies our GUID, supports localized stack text, and pairs bag events.
units.player = {guid = "Player-1-ME"}
LOOT_ITEM_SELF_MULTIPLE = "Ihr erhaltet Beute: %sx%d."
local nextLine = 100
local function loot(id, quantity, guid, line)
    nextLine = nextLine + 1
    local link = "|Hitem:" .. id .. ":0|h[Test Item]|h"
    local text = string.format(LOOT_ITEM_SELF_MULTIPLE, link, quantity)
    event("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, line or nextLine, guid or "Player-1-ME")
end
-- Start a fresh pairing window; previous bag-only tests must not pair here.
advance(16)
before = receiptCount()
loot(163483, 3, "Player-1-OTHER"); assert(receiptCount() == before)
loot(163483, 3); assert(receiptCount() == before + 1)
counts[163483] = counts[163483] + 3; event("BAG_UPDATE_DELAYED")
assert(receiptCount() == before + 1)
-- Reverse event order, identical event replay and ordinary bag moves.
advance(16)
before = receiptCount()
counts[163475] = counts[163475] + 2; event("BAG_UPDATE_DELAYED")
loot(163475, 2, nil, 777); loot(163475, 2, nil, 777)
assert(receiptCount() == before + 1)
event("BAG_UPDATE_DELAYED"); assert(receiptCount() == before + 1)
-- Rewards received during loading survive the return transition.
advance(16)
enter(1813, 1031); event("PLAYER_LEAVING_WORLD")
before = receiptCount()
counts[163470] = counts[163470] + 1
enter(0, nil)
assert(receiptCount() == before + 1)
loot(163470, 1); assert(receiptCount() == before + 1)
-- The default display needs no setup or custom frame; an item uses the same sound.
assert(not IslandQuestAlertNotification:IsShown())
local itemWarnings = 0
for _, warning in ipairs(warnings) do
    if warning.text:find("TELL ME A TALE ITEM!", 1, true) then itemWarnings = itemWarnings + 1 end
end
assert(itemWarnings > 0)
local nativeWarningCount = #warnings
command("reset"); assert(#warnings == nativeWarningCount)
command("sound") -- Re-enable after the earlier opt-out test.
local soundBefore = sounds
advance(16)
counts[163483] = counts[163483] + 1; event("BAG_UPDATE_DELAYED")
assert(sounds == soundBefore + 1)
assert(soundCalls[#soundCalls].sound == SOUNDKIT.RAID_WARNING and soundCalls[#soundCalls].channel == "Master")
-- Automatically fall back if a UI replacement removes or breaks the native display.
local native = RaidWarningFrame
RaidWarningFrame = nil
command("test"); assert(IslandQuestAlertNotification:IsShown())
local beforeResume = sounds
IslandQuestAlertNotification.scripts.OnUpdate()
assert(sounds == beforeResume)
RaidWarningFrame = {AddMessage = function() error("unavailable UI") end}
command("test"); assert(IslandQuestAlertNotification:IsShown())
RaidWarningFrame = native
print("PASS: quest detection, timers, completion/exit, all 20 Tale items, loot/bag deduplication, and return rewards")
