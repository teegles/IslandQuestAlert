local ADDON, ns = ...
local taleItems = ns.taleItems
local driver = CreateFrame("Frame")
local db, ticker, pending, active, mapID, instanceID, session
local candidates, decisions, requested, failures, plates = {}, {}, {}, {}, {}
local queue, displayUntil, currentNotification = {}, 0, nil
local bagCounts, receiptCredits, lootLines = {}, {}, {}
local worldReady, itemsInitialized = false, false

-- Instance IDs (GetInstanceInfo result 8), NOT UI map IDs.
local islands = {
    [1813] = "Un'gol Ruins", [1814] = "Havenswood", [1879] = "Jorundall",
    [1882] = "Verdant Wilds", [1883] = "Whispering Reef", [1892] = "Rotting Mire",
    [1893] = "Dread Chain", [1897] = "Molten Cay", [1898] = "Skittering Hollow",
    [1907] = "Snowblossom Village", [2124] = "Crestfall",
}
local rescueNames = {}
local achievementProgress = {}
local refreshProgress, progressReason
local function normalize(s)
    return type(s) == "string" and s:lower():gsub("[%s%p]", "") or ""
end
local function addRescueName(name)
    if type(name) == "string" and name ~= "" then rescueNames[normalize(name)] = name end
end
for _, name in ipairs({"Royston P. Crutchley III", "Grubby Beard", "Manape", "Longpaws"}) do
    addRescueName(name)
end
local function chat(s) DEFAULT_CHAT_FRAME:AddMessage("|cffffff00IQA:|r " .. s) end
local function log(s)
    if not db or not db.debug then return end
    local line = date("%H:%M:%S") .. " " .. s
    db.log[#db.log + 1] = line
    if #db.log > 400 then table.remove(db.log, 1) end
    chat(s)
end
local function changed(key, s)
    if decisions[key] ~= s then decisions[key] = s; log(s) end
end
-- Missing APIs, transient errors and restricted values are diagnostic-only.
local function call(namespace, method, ...)
    local fn = namespace and namespace[method]
    if type(fn) ~= "function" then
        changed("missing:" .. method, "Unavailable API: " .. method)
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        changed("error:" .. method, "API error: " .. method .. " " .. tostring(a))
        return nil
    end
    if issecretvalue and (issecretvalue(a) or issecretvalue(b) or issecretvalue(c) or issecretvalue(d)) then
        changed("secret:" .. method, "Restricted result: " .. method)
        return nil
    end
    return a, b, c, d
end
local function scalar(v)
    if issecretvalue and issecretvalue(v) then return "<restricted>" end
    if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    return "-"
end
-- Read the player's own achievement view (including account credit as reported
-- by Blizzard). Never use inspection/comparison data or infer credit from loot.
refreshProgress = function()
    for _, id in ipairs({13132, 13127}) do
        local _, _, _, complete = call(_G, "GetAchievementInfo", id)
        local state = {complete = complete, byName = {}, loaded = 0, completed = 0}
        local total = call(_G, "GetAchievementNumCriteria", id)
        if type(total) == "number" then
            for index = 1, total do
                local name, _, done = call(_G, "GetAchievementCriteriaInfo", id, index)
                if type(name) == "string" and name ~= "" then
                    if id == 13132 then addRescueName(name) end
                    if type(done) == "boolean" then
                        local key = normalize(name)
                        -- If labels ever collide, require all copies to be complete.
                        if state.byName[key] == nil or not done then state.byName[key] = done end
                        state.loaded = state.loaded + 1
                        if done then state.completed = state.completed + 1 end
                    end
                end
            end
        end
        achievementProgress[id] = state
        changed("progress:" .. id, "Achievement " .. id .. " complete=" .. scalar(complete)
            .. " criteria=" .. state.completed .. "/" .. state.loaded .. " completed/loaded")
    end
end
progressReason = function(id, name, fallbackName)
    local state = achievementProgress[id]
    if not state then return nil end
    if state.complete == true then return "achievement already complete (" .. id .. ")" end
    if state.byName[normalize(name)] == true or (fallbackName and state.byName[normalize(fallbackName)] == true) then
        return "achievement criterion already complete (" .. id .. ")"
    end
end
local function coords(x, y)
    if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return string.format("%.1f, %.1f", x * 100, y * 100)
    end
    return nil
end
local function xy(position)
    if position then return call(position, "GetXY") end
end
local alert = CreateFrame("Frame", "IslandQuestAlertNotification", UIParent)
alert:SetSize(640, 130)
alert:SetPoint("CENTER", 0, 160)
alert:SetFrameStrata("HIGH")
alert:SetMovable(true)
alert:SetClampedToScreen(true)
alert:EnableMouse(true)
alert:RegisterForDrag("LeftButton")
alert:SetScript("OnDragStart", function(self) self:StartMoving() end)
alert:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    db.position = {point, relativePoint, x, y}
end)
local title = alert:CreateFontString(nil, "OVERLAY")
title:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
title:SetPoint("TOP", 0, -10)
title:SetTextColor(1, 0.9, 0)
title:SetText("ISLAND QUEST DETECTED!")
local detail = alert:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
detail:SetPoint("TOP", title, "BOTTOM", 0, -12)
detail:SetWidth(620)
local hint = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("BOTTOM", 0, 6)
hint:SetText("Drag to move")
alert:Hide()
local function notificationText(objective)
    local text = objective.name or (objective.questID and "Quest " .. objective.questID) or "Rescue NPC"
    local location = coords(objective.x, objective.y)
    if location then text = text .. "\n" .. location .. " (map " .. objective.mapID .. ")" end
    return text
end
local function showNext()
    local objective = table.remove(queue, 1)
    currentNotification = objective
    if not objective then alert:Hide(); return end
    title:SetText(objective.title or "ISLAND QUEST DETECTED!")
    detail:SetText(notificationText(objective))
    alert:Show()
    displayUntil = GetTime() + 8
end
alert:SetScript("OnUpdate", function()
    if GetTime() >= displayUntil then showNext() end
end)
local function notify(objective, priority)
    local heading = objective.title or "ISLAND QUEST DETECTED!"
    local text = notificationText(objective)
    -- These notices stay on this player's screen/chat, just like other addon alerts.
    -- Sound/chat happen at detection, even when several objectives arrive together.
    chat(objective.chatMessage or (heading .. " " .. text:gsub("\n", " - ")))
    if db.sound and not objective.silent then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    if RaidWarningFrame and type(RaidWarningFrame.AddMessage) == "function" then
        local ok = pcall(RaidWarningFrame.AddMessage, RaidWarningFrame,
            heading .. "\n" .. text, {r = 1, g = 0.9, b = 0}, 8)
        if ok then return end
        changed("raid-warning-display", "Native raid warning unavailable; using built-in fallback frame")
    end
    -- Automatic fallback for clients/UI replacements without the standard frame.
    if priority then
        if currentNotification then table.insert(queue, 1, currentNotification) end
        table.insert(queue, 1, objective)
        showNext()
    else
        queue[#queue + 1] = objective
        if not alert:IsShown() then showNext() end
    end
end
local function discardQuestAlerts()
    local retained = {}
    for _, message in ipairs(queue) do
        if message.kind and message.kind ~= "quest" then retained[#retained + 1] = message end
    end
    queue = retained
    if not currentNotification or not currentNotification.kind or currentNotification.kind == "quest" then
        currentNotification = nil
        showNext()
    end
end
local function duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function finishExpedition(reason)
    if not session or session.endedAt then return end
    session.endedAt = time()
    session.endReason = reason
    local elapsed = math.max(0, session.endedAt - session.startedAt)
    db.lastRun = {instanceID = session.instanceID, startedAt = session.startedAt,
        endedAt = session.endedAt, elapsed = elapsed, reason = reason}
    local label = reason == "completed" and "Island complete" or "Island left (completion unconfirmed)"
    local summary = (islands[session.instanceID] or "Island") .. " - " .. duration(elapsed) .. " from entry"
    candidates = {}
    discardQuestAlerts()
    notify({kind = "finish", title = reason == "completed" and "ISLAND COMPLETE!" or "ISLAND ENDED",
        name = summary, silent = true, chatMessage = label .. ": " .. summary}, true)
    log("Timer stopped: " .. reason .. " elapsed=" .. elapsed)
end
local function checkCompletion()
    if not active or not session or session.endedAt then return end
    local _, _, _, _, _, _, _, current = GetInstanceInfo()
    if current ~= session.instanceID or not IsInInstance() then return end
    local info = call(C_ScenarioInfo, "GetScenarioInfo")
    if type(info) == "table" and not (issecretvalue and issecretvalue(info.isComplete)) and info.isComplete then
        finishExpedition("completed")
    end
end
local function itemCount(id)
    -- Count carried items only. Banks and account banks must not affect receipts.
    return call(C_Item, "GetItemCount", id, false, false, false, false)
end
local function baselineItems()
    for id in pairs(taleItems) do bagCounts[id] = itemCount(id) end
    itemsInitialized = true
end
local function receivedItem(id, count, link, source)
    if not taleItems[id] then return end
    -- Pair matching loot-chat and bag-count receipts in either event order.
    local credit = receiptCredits[id]
    if not credit or time() - credit.at > 15 then credit = {bag = 0, loot = 0}; receiptCredits[id] = credit end
    credit.at = time()
    local opposite = source == "bag" and "loot" or "bag"
    local paired = math.min(count, credit[opposite])
    credit[opposite] = credit[opposite] - paired
    count = count - paired
    if count == 0 then return end
    credit[source] = credit[source] + count
    refreshProgress()
    local name = call(C_Item, "GetItemInfo", id) or taleItems[id]
    local reason = progressReason(13127, name, taleItems[id])
    if reason then
        changed("item-progress:" .. id, "Ignored Tale item " .. id .. ": " .. reason)
        return
    end
    local text = (link or name) .. (count > 1 and (" x" .. count) or "")
    notify({kind = "item", title = "TELL ME A TALE ITEM!", name = text,
        chatMessage = "Tell Me a Tale item received: " .. text .. " - starts an achievement quest"}, true)
    log("Item receipt: id=" .. id .. " count=" .. count .. " source=" .. source)
end
local function scanItemChanges()
    if not worldReady then return end
    for id in pairs(taleItems) do
        local count = itemCount(id)
        local old = bagCounts[id]
        if type(count) == "number" then
            local increase = old and math.max(0, count - old) or 0
            bagCounts[id] = count
            if increase > 0 then receivedItem(id, increase, nil, "bag") end
        end
    end
end
local function lootMessage(text, _, _, _, _, _, _, _, _, _, lineID, playerGUID)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    local ownGUID = call(_G, "UnitGUID", "player")
    if not ownGUID or (issecretvalue and issecretvalue(playerGUID)) or playerGUID ~= ownGUID then return end
    local link = text:match("(|Hitem:[^|]+|h.-|h)")
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id or not taleItems[id] then return end
    if issecretvalue and issecretvalue(lineID) then lineID = nil end
    if lineID and lootLines[lineID] then return end
    if lineID then
        lootLines[lineID] = true
        -- A loot line ID is unique within this client session. Bound memory.
        local n = 0
        for key in pairs(lootLines) do
            n = n + 1
            if n > 100 then lootLines = {[lineID] = true}; break end
        end
    end
    local count = 1
    if type(LOOT_ITEM_SELF_MULTIPLE) == "string" then
        -- Localized format: replace placeholders before escaping Lua patterns.
        local pattern = LOOT_ITEM_SELF_MULTIPLE:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
        pattern = pattern:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            :gsub("\001", ".-"):gsub("\002", "(%%d+)")
        count = tonumber(text:match("^" .. pattern .. "$")) or 1
    end
    receivedItem(id, math.max(1, count), link, "loot")
end

local function rescueMatch(name)
    local key = normalize(name)
    if rescueNames[key] then return key end
end
local function describe(o)
    return o.source .. " key=" .. o.key .. " quest=" .. scalar(o.questID) .. " name=" .. scalar(o.name)
        .. " map=" .. scalar(o.mapID) .. " xy=" .. (coords(o.x, o.y) or "unavailable")
end
local function consider(o, allowed, reason)
    if allowed then
        local helping, tale = achievementProgress[13132], achievementProgress[13127]
        local completedReason
        if helping and tale and helping.complete == true and tale.complete == true then
            completedReason = "both farming achievements already complete"
        elseif rescueMatch(o.name) or o.key:match("^rescue:") then
            completedReason = progressReason(13132, o.name)
        elseif tale and tale.byName[normalize(o.name)] ~= nil then
            completedReason = progressReason(13127, o.name)
        end
        if completedReason then allowed, reason = false, completedReason .. "; ignored" end
    end
    changed("candidate:" .. o.key .. ":" .. o.source, describe(o) .. " => " .. reason)
    if not allowed then return end
    local old = candidates[o.key]
    if not old or (not old.x and o.x) then candidates[o.key] = o end
end
local function publicData(info)
    if type(info) ~= "table" then return false end
    if issecretvalue then
        for _, value in pairs(info) do
            if issecretvalue(value) then
                changed("restricted-fields", "Restricted map fields; skipped")
                return false
            end
        end
    end
    return true
end
local function quest(info, source, currentMap)
    if not publicData(info) then return end
    local id = info.questID
    if type(id) ~= "number" or id <= 0 then return end
    local name = info.questName or call(C_QuestLog, "GetTitleForQuestID", id)
        or call(C_TaskQuest, "GetQuestInfoByQuestID", id)
    if name == "" then name = nil end
    if not name and not requested[id] then
        requested[id] = true
        call(C_QuestLog, "RequestLoadQuestByID", id)
    end
    local matched = rescueMatch(name)
    local o = {key = matched and "rescue:" .. matched or "quest:" .. id,
        questID = id, name = name, mapID = currentMap, x = info.x, y = info.y, source = source}
    local classification = call(C_QuestInfoSystem, "GetQuestClassification", id)
    local qc = Enum and Enum.QuestClassification or {}
    local reason, allowed = "unclassified objective; diagnostics only", false
    if info.mapID and info.mapID ~= currentMap then
        reason = "different map; ignored"
    elseif info.isMapIndicatorQuest or info.isMeta or info.isCombatAllyQuest then
        reason = "map indicator/meta/combat ally; ignored"
    elseif classification and (classification == qc.WorldQuest or classification == qc.Threat) then
        reason = "world quest/threat; ignored"
    elseif db.allow.quest[id] or matched then
        allowed, reason = true, "known rescue/explicit quest allowlist"
    elseif info.isQuestStart and classification ~= qc.BonusObjective and not info.inProgress then
        allowed, reason = true, "available quest start"
    end
    consider(o, allowed, reason)
end
local function rawSummary(info)
    local fields = {}
    for k, v in pairs(info) do
        if type(v) ~= "table" and type(v) ~= "userdata" then
            fields[#fields + 1] = tostring(k) .. "=" .. scalar(v)
        end
    end
    table.sort(fields)
    return table.concat(fields, " ")
end
local function scanMap(currentMap, snapshot)
    for _, entry in ipairs({{C_QuestLog, "quest-poi"}, {C_TaskQuest, "task/bonus"}}) do
        local list = call(entry[1], "GetQuestsOnMap", currentMap) or {}
        for _, info in ipairs(list) do
            if snapshot and publicData(info) then log(entry[2] .. " raw " .. rawSummary(info)) end
            quest(info, entry[2], currentMap)
        end
        changed("count:" .. entry[2] .. currentMap, entry[2] .. " map=" .. currentMap .. " count=" .. #list)
    end
    local lines = call(C_QuestLine, "GetAvailableQuestLines", currentMap) or {}
    for _, info in ipairs(lines) do
        if publicData(info) then
            if snapshot then log("quest-line raw " .. rawSummary(info)) end
            -- Avoid modifying Blizzard's returned structures.
            quest({questID = info.questID, questName = info.questName, x = info.x, y = info.y,
                isQuestStart = true, inProgress = info.inProgress, isMeta = info.isMeta,
                isCombatAllyQuest = info.isCombatAllyQuest, mapID = info.startMapID}, "quest-line", currentMap)
        end
    end
    for _, id in ipairs(call(C_QuestLine, "GetForceVisibleQuests", currentMap) or {}) do
        local info = call(C_QuestLine, "GetQuestLineInfo", id, currentMap, false)
        if publicData(info) then
            quest({questID = id, questName = info.questName, x = info.x, y = info.y,
                isQuestStart = true, inProgress = info.inProgress, isMeta = info.isMeta,
                isCombatAllyQuest = info.isCombatAllyQuest, mapID = info.startMapID}, "force-visible", currentMap)
        end
    end
    for _, id in ipairs(call(C_AreaPoiInfo, "GetAreaPOIForMap", currentMap) or {}) do
        local info = call(C_AreaPoiInfo, "GetAreaPOIInfo", currentMap, id)
        if publicData(info) then
            local x, y = xy(info.position)
            local matched = rescueMatch(info.name)
            local allowed = matched or db.allow.poi[id]
            local o = {key = matched and "rescue:" .. matched or "poi:" .. id,
                name = info.name, x = x, y = y, mapID = currentMap, source = "area-poi:" .. id}
            if snapshot then log("area-poi raw " .. rawSummary(info)) end
            consider(o, allowed, allowed and "known rescue/explicit POI allowlist" or "unknown area POI; ignored")
        end
    end
end
local function scanVignettes(snapshot)
    for _, guid in ipairs(call(C_VignetteInfo, "GetVignettes") or {}) do
        local info = call(C_VignetteInfo, "GetVignetteInfo", guid)
        if publicData(info) then
            local position = call(C_VignetteInfo, "GetVignettePosition", guid, mapID)
            local x, y = xy(position)
            local matched = rescueMatch(info.name)
            local allowed = matched or db.allow.vignette[info.vignetteID]
            -- No generic atlas substring or rewardQuestID heuristic: rares also have these.
            local o = {key = matched and "rescue:" .. matched or "vignette:" .. scalar(info.vignetteID),
                name = info.name, x = x, y = y, mapID = mapID, source = "vignette:" .. scalar(info.vignetteID)}
            local reason = allowed and "known rescue/explicit vignette allowlist" or "unknown vignette (may be rare/Azerite); ignored"
            if info.isDead or info.inFogOfWar or not (info.onWorldMap or info.onMinimap) then
                allowed, reason = false, "dead/hidden vignette; ignored"
            elseif not position then allowed, reason = false, "vignette has no position on island map; ignored" end
            if snapshot then log("vignette raw " .. rawSummary(info)) end
            consider(o, allowed, reason)
        end
    end
end
local function scanUnit(unit)
    local name = call(_G, "UnitName", unit)
    local guid = call(_G, "UnitGUID", unit)
    if not guid then return end
    local matched = rescueMatch(name)
    local npcID = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local allowed = matched or (npcID and db.allow.npc[npcID])
    local o = {key = matched and "rescue:" .. matched or "npc:" .. scalar(npcID),
        name = name, mapID = mapID, source = "unit:" .. unit .. ":" .. scalar(npcID)}
    if call(_G, "UnitIsDeadOrGhost", unit) then allowed = false end
    consider(o, allowed, allowed and "known rescue NPC nearby (availability unconfirmed)" or "unmatched/dead unit; ignored")
end
local function scan(snapshot)
    if not active then return end
    checkCompletion()
    if not mapID or (session and session.endedAt) then return end
    local _, _, _, _, _, _, _, current = GetInstanceInfo()
    if current ~= instanceID or not IsInInstance() then return end
    refreshProgress()
    candidates = {}
    log("Scan map=" .. mapID .. " instance=" .. instanceID)
    scanMap(mapID, snapshot)
    scanVignettes(snapshot)
    scanUnit("target"); scanUnit("mouseover")
    for unit in pairs(plates) do scanUnit(unit) end
    local now = time()
    for key, o in pairs(candidates) do
        local seen = session.seen[key]
        if not seen then
            session.seen[key] = {lastAlert = now, since = now}
            notify(o); log("ALERT " .. describe(o))
        elseif db.repeatAlert and seen.since and now - seen.since >= 30 and now - seen.lastAlert >= 30 then
            seen.lastAlert = now
            notify(o); log("REPEAT " .. describe(o))
        else
            changed("suppressed:" .. key, "Already alerted: " .. key)
        end
    end
    for key, seen in pairs(session.seen) do
        if not candidates[key] then seen.since = nil
        elseif not seen.since then seen.since = now end
    end
end
local function schedule()
    if not active or pending then return end
    pending = C_Timer.NewTimer(0.2, function() pending = nil; scan() end)
end
local function stop()
    if ticker then ticker:Cancel(); ticker = nil end
    if pending then pending:Cancel(); pending = nil end
    active = false
    candidates, plates = {}, {}
    discardQuestAlerts()
end
local updateLocation
local function startTicker()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(db.interval, function()
        -- Recheck the actual instance; never scan a stale island map after leaving.
        local _, _, _, _, _, _, _, current = GetInstanceInfo()
        if current == instanceID and IsInInstance() then
            local currentMap = call(C_Map, "GetBestMapForUnit", "player")
            if currentMap ~= mapID then
                mapID = currentMap
                if mapID then call(C_QuestLine, "RequestQuestLinesForMap", mapID) end
            end
            if not mapID then candidates = {} end
            scan()
        else
            updateLocation()
        end
    end)
end
updateLocation = function()
    if not db then return end
    local _, _, _, _, _, _, _, current = GetInstanceInfo()
    if not islands[current] or not IsInInstance() then
        if session then finishExpedition("left") end
        if active then log("Left Island Expedition") end
        stop()
        db.session, session, mapID, instanceID = nil, nil, nil, nil
        return
    end
    if session and session.instanceID ~= current then finishExpedition("left") end
    instanceID = current
    if not db.session or db.session.instanceID ~= current then
        db.session = {instanceID = current, seen = {}, startedAt = time()}
        decisions, requested = {}, {}
    end
    session = db.session
    session.startedAt = session.startedAt or time() -- Upgrade an existing v1.0 session.
    active = true
    mapID = call(C_Map, "GetBestMapForUnit", "player")
    refreshProgress()
    changed("location", "Island detected: " .. islands[current] .. " instance=" .. current .. " map=" .. scalar(mapID))
    if mapID then call(C_QuestLine, "RequestQuestLinesForMap", mapID) end
    startTicker()
    schedule()
end
local function dump()
    if not IslandQuestAlertDiagnostics then
        local frame = CreateFrame("Frame", "IslandQuestAlertDiagnostics", UIParent, "BackdropTemplate")
        frame:SetSize(760, 480); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"}); frame:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT")
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 16, -16); label:SetText("IQA diagnostics - Ctrl+A, Ctrl+C to copy; Escape to close")
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -48); scroll:SetPoint("BOTTOMRIGHT", -38, 16)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(690); edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
            local offset = scroll:GetVerticalScroll()
            y = -y
            if y < offset then scroll:SetVerticalScroll(y)
            elseif y + height > offset + scroll:GetHeight() then scroll:SetVerticalScroll(y + height - scroll:GetHeight()) end
        end)
        scroll:SetScrollChild(edit); frame.edit = edit
        tinsert(UISpecialFrames, "IslandQuestAlertDiagnostics")
    end
    local _, _, _, interface = GetBuildInfo()
    local header = "IslandQuestAlert 1.2.0 interface=" .. scalar(interface) .. " locale=" .. GetLocale()
        .. " active=" .. tostring(active) .. " instance=" .. scalar(instanceID) .. " map=" .. scalar(mapID)
    IslandQuestAlertDiagnostics.edit:SetText(header .. "\n" .. table.concat(db.log, "\n"))
    IslandQuestAlertDiagnostics:Show()
end
SLASH_ISLANDQUESTALERT1 = "/iqa"
SlashCmdList.ISLANDQUESTALERT = function(message)
    if not db then return end
    local command, args = message:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "test" then notify({name = "Test rescue objective", mapID = mapID or 0, x = 0.5, y = 0.5})
    elseif command == "debug" then
        db.debug = not db.debug; decisions = {}; chat("Debug " .. (db.debug and "on" or "off"))
        if db.debug then
            for _, event in ipairs(failures) do log("Unavailable event: " .. event) end
            updateLocation(); schedule()
        end
    elseif command == "sound" then db.sound = not db.sound; chat("Sound " .. (db.sound and "on" or "off"))
    elseif command == "repeat" then db.repeatAlert = not db.repeatAlert; chat("30-second repeat " .. (db.repeatAlert and "on" or "off"))
    elseif command == "interval" then
        local n = tonumber(args)
        if not n or n < 0.5 or n > 60 then chat("Use /iqa interval 0.5 through 60 (seconds)"); return end
        db.interval = n; if active then startTicker() end; chat("Scan interval: " .. n .. " seconds")
    elseif command == "reset" then
        if session then session.seen = {} end
        decisions = {}; discardQuestAlerts(); chat("Current expedition detections cleared"); schedule()
    elseif command == "time" then
        if session then
            chat("Current island: " .. duration((session.endedAt or time()) - session.startedAt) .. " from entry"
                .. (session.endedAt and " (stopped)" or " (running)"))
        end
        if db.lastRun then
            chat("Last island: " .. (islands[db.lastRun.instanceID] or "Island") .. " - "
                .. duration(db.lastRun.elapsed) .. " from entry (" .. db.lastRun.reason .. ")")
        elseif not session then chat("No recorded expedition yet") end
    elseif command == "status" then
        chat("Scanning=" .. tostring(active == true and not (session and session.endedAt)) .. " instance=" .. scalar(instanceID)
            .. " map=" .. scalar(mapID) .. " interval=" .. db.interval .. "s sound=" .. tostring(db.sound)
            .. " repeat=" .. tostring(db.repeatAlert))
        if session then chat("Elapsed: " .. duration((session.endedAt or time()) - session.startedAt) .. " from entry") end
        refreshProgress()
        for _, entry in ipairs({{13132, "Helping Hand"}, {13127, "Tell Me a Tale"}}) do
            local progress = achievementProgress[entry[1]]
            chat(entry[2] .. ": " .. (progress.complete == true and "complete" or
                (progress.completed .. "/" .. progress.loaded .. " criteria completed/loaded")))
        end
        local count = 0
        for key, o in pairs(candidates) do count = count + 1; chat(describe(o)) end
        chat("Currently detectable qualifying objectives: " .. count)
    elseif command == "snapshot" then
        if not db.debug then chat("Enable /iqa debug first"); return end
        updateLocation(); decisions = {}; scan(true); log("Snapshot complete (empty sources may mean unavailable data)")
    elseif command == "dump" then dump()
    elseif command == "allow" or command == "deny" then
        local kind, id = args:match("^(%a+)%s+(%d+)$"); id = tonumber(id)
        if not kind or not db.allow[kind] or not id or id <= 0 then
            chat("Use /iqa allow (or deny) quest/poi/vignette/npc ID"); return
        end
        db.allow[kind][id] = command == "allow" or nil
        chat(command .. " " .. kind .. " " .. id); decisions = {}; schedule()
    else
        chat("Commands: test, debug, status, time, sound, reset, repeat, interval N, snapshot, dump, allow/deny TYPE ID")
    end
end
local locationEvents = {PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true, ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true}
driver:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        IslandQuestAlertDB = IslandQuestAlertDB or {}
        db = IslandQuestAlertDB
        if db.sound == nil then db.sound = true end
        if type(db.interval) ~= "number" or db.interval < 0.5 or db.interval > 60 then db.interval = 2 end
        db.log = db.log or {}; db.allow = db.allow or {}
        for _, kind in ipairs({"quest", "poi", "vignette", "npc"}) do db.allow[kind] = db.allow[kind] or {} end
        if db.position then
            alert:ClearAllPoints(); alert:SetPoint(db.position[1], UIParent, db.position[2], db.position[3], db.position[4])
        end
        for _, event in ipairs(failures) do log("Unavailable event: " .. event) end
        driver:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LEAVING_WORLD" then
        checkCompletion()
        worldReady = false
        stop()
    elseif event == "PLAYER_ENTERING_WORLD" then
        worldReady = true
        refreshProgress()
        if not itemsInitialized then
            baselineItems() -- Existing items on login/reload are not fresh loot.
        else
            scanItemChanges() -- Retain pre-zone counts to catch return rewards.
        end
        updateLocation()
    elseif event == "CRITERIA_UPDATE" or event == "CRITERIA_EARNED" or event == "CRITERIA_COMPLETE"
        or event == "ACHIEVEMENT_EARNED" or event == "RECEIVED_ACHIEVEMENT_LIST" then
        refreshProgress()
        schedule()
    elseif event == "BAG_UPDATE_DELAYED" then scanItemChanges()
    elseif event == "CHAT_MSG_LOOT" then lootMessage(...)
    elseif event == "SCENARIO_COMPLETED" then
        local _, _, _, _, _, _, _, current = GetInstanceInfo()
        if active and session and current == session.instanceID and IsInInstance() then finishExpedition("completed") end
    elseif locationEvents[event] then updateLocation()
    elseif active then
        log("Event " .. event .. " " .. scalar(...))
        if event == "NAME_PLATE_UNIT_ADDED" then plates[...] = true
        elseif event == "NAME_PLATE_UNIT_REMOVED" then plates[...] = nil
        elseif event == "QUESTLINE_UPDATE" and ... and mapID then
            call(C_QuestLine, "RequestQuestLinesForMap", mapID)
        end
        schedule()
    end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_DATA_LOAD_RESULT",
    "QUESTLINE_UPDATE", "AREA_POIS_UPDATED", "VIGNETTES_UPDATED", "VIGNETTE_MINIMAP_UPDATED", "SCENARIO_UPDATE",
    "SCENARIO_CRITERIA_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "CRITERIA_UPDATE",
    "SCENARIO_COMPLETED", "BAG_UPDATE_DELAYED", "CHAT_MSG_LOOT", "CRITERIA_EARNED", "CRITERIA_COMPLETE",
    "ACHIEVEMENT_EARNED", "RECEIVED_ACHIEVEMENT_LIST"}) do
    local ok = pcall(driver.RegisterEvent, driver, event)
    if not ok then failures[#failures + 1] = event end
end
-- Registration failures are reported only when diagnostics are enabled.
