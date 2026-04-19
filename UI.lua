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
local BAR_WIDTH = 140
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

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then return info.name end
    end
    return tostring(spellID)
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
    return f
end

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function ns.ui.SetBackdropShown(show)
    if not container or not container.SetBackdrop then return end
    if show then
        container:SetBackdrop(BACKDROP)
        container:SetBackdropColor(0, 0, 0, 0.5)
        container:SetBackdropBorderColor(1, 1, 1, 1)
    else
        container:SetBackdrop(nil)
    end
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
-- Pure bar: no icon. Spell name on the left, remaining seconds on the right.
local function CreateBarWidget(parent)
    local w = CreateFrame("StatusBar", nil, parent)
    w:SetSize(BAR_WIDTH, ICON_SIZE - 6)
    w:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    w:SetStatusBarColor(0.2, 0.8, 0.2)
    w:SetMinMaxValues(0, 1)
    w:SetValue(0)

    w.bg = w:CreateTexture(nil, "BACKGROUND")
    w.bg:SetAllPoints()
    w.bg:SetColorTexture(0, 0, 0, 0.5)

    w.name = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.name:SetPoint("LEFT", 4, 0)

    w.text = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.text:SetPoint("RIGHT", -4, 0)
    w.text:SetText("")

    w.kind = "bar"

    function w:SetSpell(spellID)
        self.name:SetText(GetSpellName(spellID))
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
        self.duration = cd
        self.endTime = GetTime() + cd
        self:SetValue(1)
        self:SetScript("OnUpdate", OnUpdate)
    end

    return w
end

-- ---- composite icon+bar widget -------------------------------------------
local function CreateBothWidget(parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(ICON_SIZE + 4 + BAR_WIDTH, ICON_SIZE)
    w.icon = CreateIconWidget(w)
    w.icon:SetPoint("LEFT")
    w.bar = CreateBarWidget(w)
    w.bar:SetPoint("LEFT", w.icon, "RIGHT", 4, 0)
    w.kind = "both"

    function w:SetSpell(spellID)
        self.icon:SetSpell(spellID)
        self.bar:SetSpell(spellID)
    end

    function w:Trigger(cd)
        self.icon:Trigger(cd)
        self.bar:Trigger(cd)
    end

    return w
end

local function CreateWidget(parent)
    local mode = DisplayMode()
    if mode == "bars" then return CreateBarWidget(parent) end
    if mode == "both" then return CreateBothWidget(parent) end
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

local function StacksVertically()
    local mode = DisplayMode()
    return mode == "bars" or mode == "both"
end

local function LayoutWidgets(row)
    local stack = StacksVertically()
    for i, w in ipairs(row.widgets) do
        w:ClearAllPoints()
        if i == 1 then
            w:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
        elseif stack then
            w:SetPoint("TOPLEFT", row.widgets[i - 1], "BOTTOMLEFT", 0, -2)
        else
            w:SetPoint("LEFT", row.widgets[i - 1], "RIGHT", ICON_GAP, 0)
        end
        w:Show()
    end
end

local function RowHeight(nSpells)
    if StacksVertically() and nSpells > 1 then
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
    local mode = DisplayMode()
    local w
    if mode == "bars" then
        w = NAME_WIDTH + BAR_WIDTH + PADDING * 2 + 20
    elseif mode == "both" then
        w = NAME_WIDTH + ICON_SIZE + 4 + BAR_WIDTH + PADDING * 2 + 20
    else
        w = 260
    end
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
    if not container then
        container = CreateContainer()
        ns.ui.SetBackdropShown(PartyPulseDB and PartyPulseDB.showBackdrop)
    end
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
