local _, ns = ...

ns.ui = {}

local rows = {}       -- name -> row
local rowOrder = {}
local container

-- Cache of member data so we can rebuild when display mode changes.
local memberData = {} -- name -> { class = ..., spells = {{id,cd},...}, active = {[id]=endTime} }

local ROW_HEIGHT = 28
local ICON_SIZE = 24
local ICON_GAP = 2
local BAR_WIDTH = 120
local NAME_WIDTH = 90
local PADDING = 10

local function DisplayMode()
    return (PartyPulseDB and PartyPulseDB.displayMode) or "icons"
end

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

-- ---- icon widget ----------------------------------------------------------
local function CreateIconWidget(parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(ICON_SIZE, ICON_SIZE)
    w.tex = w:CreateTexture(nil, "ARTWORK")
    w.tex:SetAllPoints()
    w.cooldown = CreateFrame("Cooldown", nil, w, "CooldownFrameTemplate")
    w.cooldown:SetAllPoints()
    w.kind = "icon"
    function w:SetSpell(spellID)
        self.tex:SetTexture(GetSpellIcon(spellID))
    end
    function w:Trigger(cd)
        self.cooldown:SetCooldown(GetTime(), cd)
    end
    return w
end

-- ---- bar widget -----------------------------------------------------------
local function CreateBarWidget(parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(BAR_WIDTH + ICON_SIZE + 4, ICON_SIZE)

    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(ICON_SIZE, ICON_SIZE)
    w.icon:SetPoint("LEFT")

    w.bar = CreateFrame("StatusBar", nil, w)
    w.bar:SetPoint("LEFT", w.icon, "RIGHT", 4, 0)
    w.bar:SetSize(BAR_WIDTH, ICON_SIZE - 6)
    w.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    w.bar:SetStatusBarColor(0.2, 0.8, 0.2)
    w.bar:SetMinMaxValues(0, 1)
    w.bar:SetValue(0)

    w.bar.bg = w.bar:CreateTexture(nil, "BACKGROUND")
    w.bar.bg:SetAllPoints()
    w.bar.bg:SetColorTexture(0, 0, 0, 0.5)

    w.text = w.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.text:SetPoint("CENTER")
    w.text:SetText("")

    w.kind = "bar"

    function w:SetSpell(spellID)
        self.icon:SetTexture(GetSpellIcon(spellID))
    end

    local function OnUpdate(self)
        local remaining = self.endTime - GetTime()
        if remaining <= 0 then
            self:SetValue(0)
            self.text:SetText("")
            self:SetScript("OnUpdate", nil)
            return
        end
        self:SetValue(remaining / self.duration)
        self.text:SetFormattedText("%.1f", remaining)
    end

    function w:Trigger(cd)
        self.bar.duration = cd
        self.bar.endTime = GetTime() + cd
        self.bar:SetValue(1)
        self.bar:SetScript("OnUpdate", OnUpdate)
    end

    return w
end

local function CreateWidget(parent)
    if DisplayMode() == "bars" then return CreateBarWidget(parent) end
    return CreateIconWidget(parent)
end

-- ---- row -----------------------------------------------------------------
local function CreateRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_HEIGHT)

    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("LEFT", 0, 0)
    r.name:SetWidth(NAME_WIDTH)
    r.name:SetJustifyH("LEFT")

    r.widgets = {}
    r.widgetByID = {}
    return r
end

local function LayoutWidgets(row)
    local gap = DisplayMode() == "bars" and 4 or ICON_GAP
    for i, w in ipairs(row.widgets) do
        w:ClearAllPoints()
        local prev = i == 1 and row.name or row.widgets[i - 1]
        local anchorPoint = i == 1 and "RIGHT" or "RIGHT"
        if i == 1 then
            w:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
        else
            if DisplayMode() == "bars" then
                -- Stack bars vertically within the row for readability
                w:SetPoint("TOPLEFT", row.widgets[i - 1], "BOTTOMLEFT", 0, -2)
            else
                w:SetPoint("LEFT", row.widgets[i - 1], "RIGHT", gap, 0)
            end
        end
        w:Show()
    end
end

local function RowHeight(nSpells)
    if DisplayMode() == "bars" and nSpells > 1 then
        return ICON_SIZE + (nSpells - 1) * (ICON_SIZE + 2) + 4
    end
    return ROW_HEIGHT
end

local function LayoutRows()
    local y = -PADDING
    for _, name in ipairs(rowOrder) do
        local row = rows[name]
        local h = RowHeight(#row.widgets)
        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container, "TOPLEFT", PADDING, y)
        row:SetWidth(container:GetWidth() - PADDING * 2)
        y = y - h - 4
    end
    local totalH = math.max(1, -y + PADDING - 4)
    container:SetHeight(totalH)
    local w = DisplayMode() == "bars" and (NAME_WIDTH + ICON_SIZE + BAR_WIDTH + PADDING * 2 + 20) or 260
    container:SetWidth(w)
end

local function ApplyMember(unitName, data)
    if not container then ns.ui.Show() end
    local row = rows[unitName]
    if not row then
        row = CreateRow(container)
        rows[unitName] = row
        rowOrder[#rowOrder + 1] = unitName
    end

    local color = RAID_CLASS_COLORS[data.class] or { r = 1, g = 1, b = 1 }
    local short = unitName:match("^[^-]+") or unitName
    row.name:SetText(short)
    row.name:SetTextColor(color.r, color.g, color.b)

    for _, w in ipairs(row.widgets) do w:Hide() end
    row.widgets = {}
    row.widgetByID = {}
    for i, spell in ipairs(data.spells) do
        local w = CreateWidget(row)
        w:SetSpell(spell.id)
        row.widgets[i] = w
        row.widgetByID[spell.id] = w
    end
    LayoutWidgets(row)

    -- Re-apply any active cooldowns
    local now = GetTime()
    for id, endTime in pairs(data.active or {}) do
        local remaining = endTime - now
        if remaining > 0 then
            local w = row.widgetByID[id]
            if w then w:Trigger(remaining) end
        end
    end

    LayoutRows()
end

function ns.ui.Show()
    if not container then container = CreateContainer() end
    container:Show()
    PartyPulseDB = PartyPulseDB or {}
    PartyPulseDB.shown = true
end

function ns.ui.Hide()
    if container then container:Hide() end
    PartyPulseDB = PartyPulseDB or {}
    PartyPulseDB.shown = false
end

function ns.ui.Toggle()
    if container and container:IsShown() then ns.ui.Hide() else ns.ui.Show() end
end

function ns.ui.ApplySavedVisibility()
    PartyPulseDB = PartyPulseDB or {}
    if PartyPulseDB.shown == false then ns.ui.Hide() else ns.ui.Show() end
end

function ns.ui.SetMember(unitName, class, spells)
    memberData[unitName] = memberData[unitName] or { active = {} }
    memberData[unitName].class = class
    memberData[unitName].spells = spells
    ApplyMember(unitName, memberData[unitName])
end

function ns.ui.TriggerCD(unitName, spellID, cd)
    local data = memberData[unitName]
    if not data then return end
    data.active = data.active or {}
    data.active[spellID] = GetTime() + cd
    local row = rows[unitName]
    if not row then return end
    local w = row.widgetByID[spellID]
    if w then w:Trigger(cd) end
end

function ns.ui.RemoveMember(unitName)
    memberData[unitName] = nil
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

function ns.ui.RebuildAll()
    -- Rebuild every row under the current display mode.
    for _, name in ipairs(rowOrder) do
        if rows[name] then rows[name]:Hide() end
    end
    for name, _ in pairs(rows) do rows[name] = nil end
    wipe(rowOrder)
    for name, data in pairs(memberData) do
        ApplyMember(name, data)
    end
end
