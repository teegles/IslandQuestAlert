local _, ns = ...
local Stats = {}
ns.Stats = Stats
local db, history, panel, page = nil, nil, nil, 1
local PAGE_SIZE, RETURN_WINDOW = 12, 120

local function duration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function runByID(id)
    -- IDs correspond to append-only history indices; records are never pruned.
    return id and history and history.runs[id]
end
function Stats.Init(saved)
    db = saved
    db.stats = db.stats or {version = 1, since = time(), runs = {}, receipts = {}}
    history = db.stats
end
function Stats.Begin(session, name, difficulty)
    if not history or session.endedAt then return end
    if runByID(session.statsRunID) then
        history.activeRunID = session.statsRunID
        runByID(session.statsRunID).lastObservedAt = time()
        return
    end
    local id = #history.runs + 1
    local run = {id = id, instanceID = session.instanceID, name = name,
        difficulty = difficulty, startedAt = session.startedAt, lastObservedAt = time(), joinedLate = session.startedAt < history.since}
    history.runs[id] = run
    history.activeRunID = id
    session.statsRunID = id
    Stats.Refresh()
end
function Stats.Finish(session, result)
    local run = runByID(session.statsRunID)
    if not run or run.endedAt then return end
    run.endedAt, run.elapsed, run.reason = result.endedAt, result.elapsed, result.reason
    history.recentRunID = run.id
    history.activeRunID = nil
    Stats.Refresh()
end
function Stats.Suspend()
    local run = history and runByID(history.activeRunID)
    if run and not run.endedAt then run.lastObservedAt = time() end
end
function Stats.Leave()
    if not history then return end
    local run = runByID(history.activeRunID)
    if run and not run.endedAt then
        -- Logging back in outside an island cannot reveal when the old run ended.
        run.reason = "interrupted"
        run.endedAt = run.lastObservedAt or run.startedAt
        run.elapsed = math.max(0, run.endedAt - run.startedAt)
    end
    history.activeRunID = nil
    Stats.Refresh()
end
local function associate()
    local run = runByID(history.activeRunID)
    if run and not run.endedAt then return run.id, "during run" end
    run = runByID(history.recentRunID)
    if run and run.reason == "completed" and time() - run.endedAt >= 0 and time() - run.endedAt <= RETURN_WINDOW then
        return run.id, "after completion (inferred)"
    end
    return nil, "outside/unassigned"
end
function Stats.RecordItem(itemID, name, count, status, source)
    if not history then return end
    local runID, association = associate()
    history.receipts[#history.receipts + 1] = {at = time(), itemID = itemID, name = name,
        count = count, status = status, source = source, runID = runID, association = association}
    Stats.Refresh()
end
function Stats.ConfirmLoot(itemID, count)
    -- Bag updates can precede the personal loot line. Upgrade matching records
    -- rather than logging that same receipt twice. Pairing is limited to 15s.
    if not history then return end
    for i = #history.receipts, 1, -1 do
        local receipt = history.receipts[i]
        if time() - receipt.at > 15 then break end
        if receipt.itemID == itemID and receipt.source == "bag" and count > 0 then
            local available = receipt.count - (receipt.lootConfirmed or 0)
            local confirmed = math.min(available, count)
            receipt.lootConfirmed = (receipt.lootConfirmed or 0) + confirmed
            count = count - confirmed
        end
    end
    Stats.Refresh()
end
function Stats.Summary()
    local result = {started = 0, completed = 0, left = 0, interrupted = 0, needed = 0, unknown = 0,
        alreadyComplete = 0, streak = 0, withNeeded = {}, totalSeconds = 0, unassigned = 0}
    if not history then return result end
    local lastNeededRun = 0
    result.started = #history.runs
    for _, receipt in ipairs(history.receipts) do
        if receipt.status == "needed" then
            result.needed = result.needed + receipt.count
            if receipt.runID then
                result.withNeeded[receipt.runID] = true
                lastNeededRun = math.max(lastNeededRun, receipt.runID)
            end
        elseif receipt.status == "complete" then result.alreadyComplete = result.alreadyComplete + receipt.count
        else result.unknown = result.unknown + receipt.count end
        if not receipt.runID then result.unassigned = result.unassigned + receipt.count end
    end
    for _, run in ipairs(history.runs) do
        if run.reason == "completed" then
            result.completed = result.completed + 1
            result.totalSeconds = result.totalSeconds + run.elapsed
            if run.id > lastNeededRun then result.streak = result.streak + 1 end
        elseif run.reason == "left" then result.left = result.left + 1
        elseif run.reason == "interrupted" then result.interrupted = result.interrupted + 1 end
    end
    return result
end
local function receiptText(receipt)
    local status = receipt.status == "needed" and "NEEDED" or
        (receipt.status == "complete" and "already completed" or "progress unknown")
    local source = receipt.source == "loot" and "personal loot" or "inventory increase"
    if receipt.source == "bag" and receipt.lootConfirmed then
        source = source .. "; personal loot confirmed " .. receipt.lootConfirmed .. "/" .. receipt.count
    end
    return string.format("    [%s] %s x%d - %s; %s", status, receipt.name, receipt.count, source, receipt.association)
end
function Stats.RenderText()
    local summary = Stats.Summary()
    local pages = math.max(1, math.ceil(#history.runs / PAGE_SIZE))
    page = math.max(1, math.min(page, pages))
    local heading = string.format("Tracking since %s\n%d started   |   %d completed   |   %d exits unconfirmed   |   %d interrupted\n"
        .. "Needed item receipts: %d   |   Progress unknown: %d   |   Already completed: %d\n"
        .. "Completed runs since a linked needed item: %d",
        date("%Y-%m-%d %H:%M", history.since), summary.started, summary.completed, summary.left, summary.interrupted,
        summary.needed, summary.unknown, summary.alreadyComplete, summary.streak)
    if summary.completed > 0 then
        heading = heading .. "\nAverage time from entry: " .. duration(summary.totalSeconds / summary.completed)
    end
    local receiptsByRun = {}
    for _, receipt in ipairs(history.receipts) do
        if receipt.runID then
            receiptsByRun[receipt.runID] = receiptsByRun[receipt.runID] or {}
            table.insert(receiptsByRun[receipt.runID], receipt)
        end
    end
    local lines = {}
    local newest = #history.runs - (page - 1) * PAGE_SIZE
    for index = newest, math.max(1, newest - PAGE_SIZE + 1), -1 do
        local run = history.runs[index]
        local state = run.reason == "completed" and "Completed" or
            (run.reason == "left" and "Exit unconfirmed" or (run.reason == "interrupted" and "Interrupted" or "In progress"))
        local elapsed = run.elapsed or math.max(0, time() - run.startedAt)
        local mark = summary.withNeeded[run.id] and "  *** NEEDED ITEM ***" or ""
        lines[#lines + 1] = string.format("#%d  %s  |  %s (%s)  |  %s  |  %s%s", run.id,
            date("%m-%d %H:%M", run.startedAt), run.name or "Island", run.difficulty or "?", state, duration(elapsed) .. (run.reason == "interrupted" and " observed" or ""), mark)
        if run.joinedLate then lines[#lines + 1] = "    Tracking began during this run; earlier item receipts are unavailable." end
        for _, receipt in ipairs(receiptsByRun[run.id] or {}) do lines[#lines + 1] = receiptText(receipt) end
        lines[#lines + 1] = ""
    end
    if #history.runs == 0 then lines[#lines + 1] = "No expeditions recorded yet. Tracking starts automatically on your next island." end
    -- Unassigned receipts stay visible, rather than falsely attaching them to a run.
    if page == 1 and summary.unassigned > 0 then
        lines[#lines + 1] = "Recent outside/unassigned item receipts (last 10):"
        local shown = 0
        for i = #history.receipts, 1, -1 do
            if not history.receipts[i].runID then
                lines[#lines + 1] = receiptText(history.receipts[i])
                shown = shown + 1
                if shown == 10 then break end
            end
        end
    end
    return heading, table.concat(lines, "\n"), string.format("Page %d / %d", page, pages)
end
function Stats.Refresh()
    if not panel or not panel:IsShown() then return end
    local heading, text, paging = Stats.RenderText()
    panel.summary:SetText(heading)
    -- Avoid resetting the user's text selection/scroll every second.
    if text ~= panel.lastText then panel.edit:SetText(text); panel.lastText = text end
    panel.paging:SetText(paging)
end
function Stats.Toggle()
    if not history then return end
    if not panel then
        panel = CreateFrame("Frame", "IslandQuestAlertStats", UIParent, "BackdropTemplate")
        panel:SetSize(820, 580); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
        panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"}); panel:SetBackdropColor(.04, .04, .04, .97)
        panel:SetMovable(true); panel:SetClampedToScreen(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
        panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16); title:SetText("IslandQuestAlert - Expedition stats")
        local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT")
        panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        panel.summary:SetPoint("TOPLEFT", 16, -48); panel.summary:SetJustifyH("LEFT"); panel.summary:SetWidth(780)
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -160); scroll:SetPoint("BOTTOMRIGHT", -38, 76)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(760); edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() panel:Hide() end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
            local offset = scroll:GetVerticalScroll()
            y = -y
            if y < offset then scroll:SetVerticalScroll(y)
            elseif y + height > offset + scroll:GetHeight() then scroll:SetVerticalScroll(y + height - scroll:GetHeight()) end
        end)
        edit:SetScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(panel.lastText or "") end
        end)
        scroll:SetScrollChild(edit); panel.edit = edit
        local previous = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        previous:SetSize(100, 24); previous:SetPoint("BOTTOMLEFT", 16, 40); previous:SetText("Newer")
        previous:SetScript("OnClick", function() page = math.max(1, page - 1); scroll:SetVerticalScroll(0); Stats.Refresh() end)
        local nextPage = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        nextPage:SetSize(100, 24); nextPage:SetPoint("BOTTOMRIGHT", -16, 40); nextPage:SetText("Older")
        nextPage:SetScript("OnClick", function() page = page + 1; scroll:SetVerticalScroll(0); Stats.Refresh() end)
        panel.paging = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        panel.paging:SetPoint("BOTTOM", 0, 46)
        local note = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        note:SetPoint("BOTTOM", 0, 12); note:SetWidth(790)
        note:SetText("Per-character history since this update. Receipts are not quest completions or drop odds. Ctrl+A/C to copy; Escape closes.")
        panel:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 1 then
                self.elapsed = 0
                if history.activeRunID then Stats.Refresh() end
            end
        end)
        tinsert(UISpecialFrames, "IslandQuestAlertStats")
        panel:Hide()
    end
    if panel:IsShown() then panel:Hide() else panel:Show(); Stats.Refresh() end
end
