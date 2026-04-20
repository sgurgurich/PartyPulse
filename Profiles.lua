local _, ns = ...

ns.profiles = {}

local function IsProfileKey(k)
    return k ~= "pos" and k ~= "_defaultOffMigrated"
end

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, vv in pairs(v) do t[k] = deepcopy(vv) end
    return t
end

local function SnapshotCurrent()
    PartyPulseDB = PartyPulseDB or {}
    local s = {}
    for k, v in pairs(PartyPulseDB) do
        if IsProfileKey(k) then s[k] = deepcopy(v) end
    end
    return s
end

local function ClearCurrent()
    if not PartyPulseDB then return end
    for k in pairs(PartyPulseDB) do
        if IsProfileKey(k) then PartyPulseDB[k] = nil end
    end
end

local function RestoreSnapshot(s)
    ClearCurrent()
    for k, v in pairs(s or {}) do
        PartyPulseDB[k] = deepcopy(v)
    end
end

local function ReapplyAllUI()
    if ns.config and ns.config.ApplyAll then ns.config.ApplyAll() end
    if ns.ui and ns.ui.RebuildAll then ns.ui.RebuildAll() end
    if ns.RefreshAll then ns.RefreshAll() end
    if ns.config and ns.config.RefreshAllPanels then ns.config.RefreshAllPanels() end
end

function ns.profiles.Init()
    PartyPulseDB = PartyPulseDB or {}
    if ns.config and ns.config.EnsureDefaults then ns.config.EnsureDefaults() end
    if not PartyPulseProfiles or not PartyPulseProfiles.list then
        PartyPulseProfiles = {
            active = "Default",
            list = { Default = SnapshotCurrent() },
        }
    end
    if not PartyPulseProfiles.list[PartyPulseProfiles.active] then
        PartyPulseProfiles.active = next(PartyPulseProfiles.list) or "Default"
        if not PartyPulseProfiles.list[PartyPulseProfiles.active] then
            PartyPulseProfiles.list[PartyPulseProfiles.active] = SnapshotCurrent()
        end
    end
end

function ns.profiles.Active()
    return PartyPulseProfiles and PartyPulseProfiles.active
end

function ns.profiles.List()
    local out = {}
    if PartyPulseProfiles and PartyPulseProfiles.list then
        for name in pairs(PartyPulseProfiles.list) do out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

function ns.profiles.SaveCurrent()
    if not PartyPulseProfiles then return end
    PartyPulseProfiles.list[PartyPulseProfiles.active] = SnapshotCurrent()
end

function ns.profiles.Switch(name)
    if not PartyPulseProfiles or not PartyPulseProfiles.list[name] then return false, "Unknown profile" end
    if PartyPulseProfiles.active == name then return true end
    ns.profiles.SaveCurrent()
    PartyPulseProfiles.active = name
    RestoreSnapshot(PartyPulseProfiles.list[name])
    if ns.config and ns.config.EnsureDefaults then ns.config.EnsureDefaults() end
    ReapplyAllUI()
    return true
end

function ns.profiles.Add(name)
    if not name or name == "" then return false, "Invalid name" end
    if PartyPulseProfiles.list[name] then return false, "Already exists" end
    ns.profiles.SaveCurrent()
    PartyPulseProfiles.list[name] = {}
    PartyPulseProfiles.active = name
    ClearCurrent()
    if ns.config and ns.config.EnsureDefaults then ns.config.EnsureDefaults() end
    ReapplyAllUI()
    return true
end

function ns.profiles.Clone(newName)
    if not newName or newName == "" then return false, "Invalid name" end
    if PartyPulseProfiles.list[newName] then return false, "Already exists" end
    ns.profiles.SaveCurrent()
    PartyPulseProfiles.list[newName] = deepcopy(PartyPulseProfiles.list[PartyPulseProfiles.active])
    PartyPulseProfiles.active = newName
    RestoreSnapshot(PartyPulseProfiles.list[newName])
    ReapplyAllUI()
    return true
end

function ns.profiles.Remove(name)
    if not PartyPulseProfiles.list[name] then return false, "Unknown profile" end
    local count = 0
    for _ in pairs(PartyPulseProfiles.list) do count = count + 1 end
    if count <= 1 then return false, "Cannot remove the last profile" end
    PartyPulseProfiles.list[name] = nil
    if PartyPulseProfiles.active == name then
        PartyPulseProfiles.active = next(PartyPulseProfiles.list)
        RestoreSnapshot(PartyPulseProfiles.list[PartyPulseProfiles.active])
        if ns.config and ns.config.EnsureDefaults then ns.config.EnsureDefaults() end
        ReapplyAllUI()
    end
    return true
end

-- ---- Export / Import ----------------------------------------------------
-- Compact flat encoding: "PPv1:" + list of "path:type:value" separated by '|'.
-- path uses '.' as separator; literal '.' inside keys escaped as "\d".
-- Type codes: n (number), b (boolean "1"/"0"), s (string with | and : escaped).

local function esc(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("|", "\\p")
    s = s:gsub(":", "\\c")
    return s
end

local function unesc(s)
    s = s:gsub("\\c", ":")
    s = s:gsub("\\p", "|")
    s = s:gsub("\\\\", "\\")
    return s
end

local function encodeKey(k) return tostring(k):gsub("%.", "\\d") end
local function decodeKey(k) return (k:gsub("\\d", ".")) end

local function flatten(prefix, t, out)
    for k, v in pairs(t) do
        local seg = encodeKey(k)
        local path = prefix == "" and seg or (prefix .. "." .. seg)
        if type(v) == "table" then
            flatten(path, v, out)
        elseif type(v) == "number" then
            out[#out + 1] = path .. ":n:" .. tostring(v)
        elseif type(v) == "boolean" then
            out[#out + 1] = path .. ":b:" .. (v and "1" or "0")
        elseif type(v) == "string" then
            out[#out + 1] = path .. ":s:" .. esc(v)
        end
    end
end

function ns.profiles.Export(name)
    name = name or (PartyPulseProfiles and PartyPulseProfiles.active)
    if name == PartyPulseProfiles.active then ns.profiles.SaveCurrent() end
    local snap = PartyPulseProfiles.list[name]
    if not snap then return nil end
    local parts = {}
    flatten("", snap, parts)
    return "PPv1:" .. table.concat(parts, "|")
end

local function setPath(root, pathStr, value)
    local parts = {}
    for seg in string.gmatch(pathStr, "[^%.]+") do
        parts[#parts + 1] = decodeKey(seg)
    end
    if #parts == 0 then return end
    local cur = root
    for i = 1, #parts - 1 do
        if type(cur[parts[i]]) ~= "table" then cur[parts[i]] = {} end
        cur = cur[parts[i]]
    end
    cur[parts[#parts]] = value
end

function ns.profiles.Import(str, newName)
    if not str or not newName or newName == "" then return false, "Invalid input" end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    local body = str:match("^PPv1:(.+)$")
    if not body then return false, "Unrecognized format" end
    if PartyPulseProfiles.list[newName] then return false, "Name already in use" end
    local snap = {}
    for entry in string.gmatch(body, "[^|]+") do
        local path, t, v = entry:match("^([^:]+):([nbs]):(.*)$")
        if path then
            local value
            if t == "n" then value = tonumber(v)
            elseif t == "b" then value = v == "1"
            elseif t == "s" then value = unesc(v)
            end
            if value ~= nil then setPath(snap, path, value) end
        end
    end
    PartyPulseProfiles.list[newName] = snap
    return true
end
