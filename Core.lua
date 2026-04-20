local _, ns = ...

local playerClass
local playerFullName
local playerSpecID

-- name -> { class, spells = {{id, cd}, ...} }
local members = {}
-- spellID -> endTime (GetTime() seconds). Own active cooldowns, for late-join sync.
local localActive = {}

local function GetPlayerFullName()
    local name, realm = UnitFullName("player")
    realm = realm and realm ~= "" and realm or GetRealmName()
    realm = realm and realm:gsub("%s", "") or ""
    return name .. "-" .. realm
end

local function RefreshSpec()
    local idx = GetSpecialization and GetSpecialization()
    if idx and GetSpecializationInfo then
        playerSpecID = GetSpecializationInfo(idx)
    else
        playerSpecID = nil
    end
end

local function CurrentSpells()
    return ns.GetInterruptsFor(playerClass, playerSpecID)
end

local function IsSpellEnabled(spellID)
    PartyPulseDB = PartyPulseDB or {}
    local v = PartyPulseDB["spell_" .. spellID]
    return v ~= false
end
ns.IsSpellEnabled = IsSpellEnabled

local function EnabledSpells()
    local out = {}
    for _, s in ipairs(CurrentSpells()) do
        if IsSpellEnabled(s.id) then out[#out + 1] = s end
    end
    return out
end

local function EncodeSpellList(spells)
    local ids = {}
    for i, s in ipairs(spells) do ids[i] = tostring(s.id) end
    return table.concat(ids, ",")
end

local function DecodeSpellList(class, csv)
    local list = {}
    for idStr in string.gmatch(csv or "", "[^,]+") do
        local id = tonumber(idStr)
        if id then list[#list + 1] = { id = id, cd = 0 } end
    end
    for _, entry in pairs(ns.INTERRUPTS_BY_SPEC) do
        local source = entry.replace or entry
        for _, s in ipairs(source) do
            for _, out in ipairs(list) do
                if out.id == s.id and out.cd == 0 then out.cd = s.cd end
            end
        end
    end
    for _, s in ipairs(ns.INTERRUPTS[class] or {}) do
        for _, out in ipairs(list) do
            if out.id == s.id and out.cd == 0 then out.cd = s.cd end
        end
    end
    return list
end

local function BuildSyncPayload()
    local now = GetTime()
    local parts = {}
    for id, endTime in pairs(localActive) do
        local remaining = endTime - now
        if remaining > 0.5 then
            parts[#parts + 1] = string.format("%d,%d", id, math.floor(remaining))
        else
            localActive[id] = nil
        end
    end
    if #parts == 0 then return nil end
    return "SYNC:" .. table.concat(parts, ";")
end

local function AnnounceSelf()
    local spells = EnabledSpells()
    if #spells == 0 then return end
    ns.comm.Send(string.format("HELLO:%s:%s", playerClass, EncodeSpellList(spells)))
end

local function EnsureSelfRow()
    local spells = EnabledSpells()
    members[playerFullName] = { class = playerClass, spells = spells }
    ns.ui.SetMember(playerFullName, playerClass, spells)
end

function ns.RefreshSelf()
    EnsureSelfRow()
    AnnounceSelf()
end

-- Re-apply every known member with the current spell-enable filter,
-- so toggling a spell off in settings hides it on party members too.
function ns.RefreshAll()
    EnsureSelfRow()
    AnnounceSelf()
    for name, m in pairs(members) do
        if name ~= playerFullName then
            local filtered = {}
            for _, s in ipairs(m.spells) do
                if IsSpellEnabled(s.id) then filtered[#filtered + 1] = s end
            end
            ns.ui.SetMember(name, m.class, filtered)
        end
    end
    if ns.ui.RefreshTestMembers then ns.ui.RefreshTestMembers() end
end

local function HandleMessage(text, sender)
    if sender == playerFullName then return end
    local kind, rest = text:match("^([^:]+):(.*)$")
    if not kind then return end

    if kind == "HELLO" then
        local class, csv = rest:match("^([^:]+):(.*)$")
        local spells = DecodeSpellList(class, csv)
        if class and #spells > 0 then
            members[sender] = { class = class, spells = spells }
            local filtered = {}
            for _, s in ipairs(spells) do
                if IsSpellEnabled(s.id) then filtered[#filtered + 1] = s end
            end
            ns.ui.SetMember(sender, class, filtered)
            -- Reply with our own HELLO + any currently-active cooldowns (whispered)
            local mine = EnabledSpells()
            if #mine > 0 then
                ns.comm.Send(string.format("HELLO:%s:%s", playerClass, EncodeSpellList(mine)))
            end
            local sync = BuildSyncPayload()
            if sync then ns.comm.SendWhisper(sync, sender) end
        end
    elseif kind == "CD" then
        local idStr, cdStr = rest:match("^(%d+):(%d+)$")
        local spellID, cd = tonumber(idStr), tonumber(cdStr)
        if spellID and cd and members[sender] and IsSpellEnabled(spellID) then
            ns.ui.TriggerCD(sender, spellID, cd)
        end
    elseif kind == "INT" then
        local spellID = tonumber(rest)
        if spellID and members[sender] and IsSpellEnabled(spellID) then
            ns.ui.FlashSpell(sender, spellID)
        end
    elseif kind == "SYNC" then
        if not members[sender] then return end
        for pair in string.gmatch(rest, "[^;]+") do
            local idStr, remStr = pair:match("^(%d+),(%d+)$")
            local spellID, remaining = tonumber(idStr), tonumber(remStr)
            if spellID and remaining and remaining > 0 and IsSpellEnabled(spellID) then
                ns.ui.TriggerCD(sender, spellID, remaining)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        PartyPulseDB = PartyPulseDB or {}
        playerClass = select(2, UnitClass("player"))
        playerFullName = GetPlayerFullName()
        RefreshSpec()
        ns.comm.Init()
        ns.comm.OnReceive(HandleMessage)
        if ns.profiles and ns.profiles.Init then ns.profiles.Init() end
        ns.config.Register()
        ns.config.ApplyAll()
        EnsureSelfRow()
        AnnounceSelf()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        EnsureSelfRow()
        AnnounceSelf()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit ~= "player" then return end
        RefreshSpec()
        EnsureSelfRow()
        AnnounceSelf()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        if not IsSpellEnabled(spellID) then return end
        local cd = ns.GetSpellCD(playerClass, playerSpecID, spellID)
        if cd then
            localActive[spellID] = GetTime() + cd
            ns.ui.TriggerCD(playerFullName, spellID, cd)
            ns.comm.Send(string.format("CD:%d:%d", spellID, cd))
            ns.ui.FlashSpell(playerFullName, spellID)
            ns.comm.Send(string.format("INT:%d", spellID))
        end
    elseif event == "CHAT_MSG_ADDON" then
        ns.comm.Handle(...)
    elseif event == "PLAYER_LOGOUT" then
        if ns.profiles and ns.profiles.SaveCurrent then ns.profiles.SaveCurrent() end
    end
end)

SLASH_PARTYPULSE1 = "/pulse"
SLASH_PARTYPULSE2 = "/pp"
SLASH_PARTYPULSE3 = "/partypulse"
SlashCmdList.PARTYPULSE = function()
    ns.config.Open()
end
