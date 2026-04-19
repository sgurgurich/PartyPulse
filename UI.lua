local _, ns = ...

ns.ui = {}

local rows = {}       -- name -> row
local rowOrder = {}   -- display order
local container

local ROW_HEIGHT = 28
local ICON_SIZE = 24
local ICON_GAP = 2
local NAME_WIDTH = 90
local PADDING = 10

local function GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.iconID end
    end
    return 134400
end

local function SavePosition(f)
    PartyPulseDB = PartyPulseDB or {}
    local point, _, relPoint, x, y = f:GetPoint(1)
    PartyPulseDB.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition(f)
    local pos = PartyPulseDB and PartyPulseDB.pos
    f:ClearAllPoints()
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", 0, 100)
    end
end

local function CreateContainer()
    local f = CreateFrame("Frame", "PartyPulseFrame", UIParent, "BackdropTemplate")
    f:SetSize(260, 60)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    RestorePosition(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.5)
    end
    return f
end

local function CreateIcon(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(ICON_SIZE, ICON_SIZE)
    holder.tex = holder:CreateTexture(nil, "ARTWORK")
    holder.tex:SetAllPoints()
    holder.cooldown = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
    holder.cooldown:SetAllPoints()
    return holder
end

local function CreateRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_HEIGHT)

    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("LEFT", 0, 0)
    r.name:SetWidth(NAME_WIDTH)
    r.name:SetJustifyH("LEFT")

    r.icons = {}     -- index -> icon frame
    r.iconByID = {}  -- spellID -> icon frame
    return r
end

local function LayoutIcons(row)
    for i, icon in ipairs(row.icons) do
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", row.name, "RIGHT", 4 + (i - 1) * (ICON_SIZE + ICON_GAP), 0)
        icon:Show()
    end
end

local function LayoutRows()
    for i, name in ipairs(rowOrder) do
        local row = rows[name]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container, "TOPLEFT", PADDING, -PADDING - (i - 1) * ROW_HEIGHT)
        row:SetWidth(container:GetWidth() - PADDING * 2)
    end
    container:SetHeight(PADDING * 2 + math.max(1, #rowOrder) * ROW_HEIGHT)
end

function ns.ui.Show()
    if not container then container = CreateContainer() end
    container:Show()
    PartyPulseDB = PartyPulseDB or {}
    PartyPulseDB.hidden = false
end

function ns.ui.Hide()
    if container then container:Hide() end
    PartyPulseDB = PartyPulseDB or {}
    PartyPulseDB.hidden = true
end

function ns.ui.Toggle()
    if container and container:IsShown() then ns.ui.Hide() else ns.ui.Show() end
end

function ns.ui.ApplySavedVisibility()
    PartyPulseDB = PartyPulseDB or {}
    if PartyPulseDB.hidden then
        ns.ui.Hide()
    else
        ns.ui.Show()
    end
end

-- spells: array of { id = spellID }
function ns.ui.SetMember(unitName, class, spells)
    if not container then ns.ui.Show() end
    local row = rows[unitName]
    if not row then
        row = CreateRow(container)
        rows[unitName] = row
        rowOrder[#rowOrder + 1] = unitName
    end

    local color = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
    local short = unitName:match("^[^-]+") or unitName
    row.name:SetText(short)
    row.name:SetTextColor(color.r, color.g, color.b)

    -- Rebuild icon set to match incoming spell list.
    for _, icon in ipairs(row.icons) do icon:Hide() end
    row.icons = {}
    row.iconByID = {}
    for i, spell in ipairs(spells) do
        local icon = CreateIcon(row)
        icon.tex:SetTexture(GetSpellIcon(spell.id))
        row.icons[i] = icon
        row.iconByID[spell.id] = icon
    end
    LayoutIcons(row)
    LayoutRows()
end

function ns.ui.TriggerCD(unitName, spellID, cd)
    local row = rows[unitName]
    if not row then return end
    local icon = row.iconByID[spellID]
    if not icon then return end
    icon.cooldown:SetCooldown(GetTime(), cd)
end

function ns.ui.RemoveMember(unitName)
    if not rows[unitName] then return end
    rows[unitName]:Hide()
    rows[unitName] = nil
    for i, name in ipairs(rowOrder) do
        if name == unitName then table.remove(rowOrder, i); break end
    end
    LayoutRows()
end

function ns.ui.HasMember(unitName)
    return rows[unitName] ~= nil
end

function ns.ui.SetLocked(locked)
    if not container then return end
    container:EnableMouse(not locked)
    if locked then
        container:RegisterForDrag()
    else
        container:RegisterForDrag("LeftButton")
    end
end

function ns.ui.SetScale(scale)
    if not container then return end
    container:SetScale(scale or 1.0)
end
