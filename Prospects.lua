local _, ns = ...
-- User-supplied farming leads, not a drop table. English name fragments only
-- suggest a group; an NPC ID is stronger evidence but never promises loot.
ns.Prospects = {
    groups = {
        {key = "pirates", name = "Pirates", words = {"pirate", "buccaneer", "southsea"}, items = {163482, 163475}},
        {key = "keepers", name = "Keepers of the Grove", words = {"keeperofthegrove", "keepersofthegrove"}, items = {163486}},
        {key = "druids", name = "Druids of the Claw", words = {"druidoftheclaw", "druidsoftheclaw"}, items = {163485}},
        {key = "nerubians", name = "Nerubians (look for Vorus'arak)", words = {"nerubian"}, items = {163484}},
        {key = "naga", name = "Naga", words = {"naga"}, items = {163480}},
        {key = "icetusk", name = "Icetusk trolls", words = {"icetusk"}, items = {163474}},
        {key = "vrykul", name = "Vrykul", words = {"vrykul", "bloodwake"}, items = {163472}},
        {key = "jinyu", name = "Jinyu", words = {"jinyu", "razorfin"}, items = {163483}},
        {key = "mantid", name = "Mantid", words = {"mantid"}, items = {163473}},
        {key = "hozen", name = "Hozen", words = {"hozen"}, items = {163466}},
    },
}
local vorus = {key = "vorusarak", name = "Vorus'arak", items = {163484}, exact = true}
function ns.Prospects.Match(name, npcID)
    if npcID == 139889 then return {vorus} end
    if type(name) ~= "string" then return {} end
    local text = name:lower():gsub("[%s%p]", "")
    local found = {}
    -- Exact English name is useful if a vignette has no creature GUID.
    if text == "vorusarak" then return {vorus} end
    for _, group in ipairs(ns.Prospects.groups) do
        for _, word in ipairs(group.words) do
            if text:find(word, 1, true) then found[#found + 1] = group; break end
        end
    end
    return found
end
