local _, ns = ...

ns.ui = {}

local rows = {}       -- name -> row
local rowOrder = {}
local container

-- Cache of member data so we can rebuild when display mode changes.
local memberData = {} -- name -> { class = ..., spells = {{id,cd},...}, active = {[id]=endTime} }

local ROW_HEIGHT = 28
local NAME_WIDTH = 90
local PADDING = 10

-- Tunable sizes live in saved variables; these are the defaults / fallbacks.
local DEFAULT_ICON_SIZE = 24
local DEFAULT_BAR_WIDTH = 140
local DEFAULT_BAR_HEIGHT = 18
local DEFAULT_SPELL_GAP = 2

local function IconSize()  return (PartyPulseDB and PartyPulseDB.iconSize)  or DEFAULT_ICON_SIZE end
local function BarWidth()  return (PartyPulseDB and PartyPulseDB.barWidth)  or DEFAULT_BAR_WIDTH end
local function BarHeight() return (PartyPulseDB and PartyPulseDB.barHeight) or DEFAULT_BAR_HEIGHT end
local function SpellGap()  return (PartyPulseDB and PartyPulseDB.spellGap)  or DEFAULT_SPELL_GAP end
local function NameOffsetX() return (PartyPulseDB and PartyPulseDB.nameOffsetX) or 0 end
local function NameOffsetY() return (PartyPulseDB and PartyPulseDB.nameOffsetY) or 0 end
local function RowGap()            return (PartyPulseDB and PartyPulseDB.rowGap) or 4 end
local function ShowSpellName()     return not (PartyPulseDB and PartyPulseDB.showSpellName == false) end
local function NameFontSize()      return (PartyPulseDB and PartyPulseDB.nameFontSize) or 12 end
local function SpellNameFontSize() return (PartyPulseDB and PartyPulseDB.spellNameFontSize) or 11 end
local function TimeFontSize()      return (PartyPulseDB and PartyPulseDB.timeFontSize) or 11 end
local function BarUseClassColor()  return not (PartyPulseDB and PartyPulseDB.barUseClassColor == false) end
local function BarInvert()         return PartyPulseDB and PartyPulseDB.barInvert == true end
local function ShowReadyText()     return not (PartyPulseDB and PartyPulseDB.showReadyText == false) end
local function ReadyText()         return (PartyPulseDB and PartyPulseDB.readyText) or "Ready" end
local function CooldownFormat()    return (PartyPulseDB and PartyPulseDB.cooldownFormat) or "%.1f" end
local function ShowCooldownText()  return not (PartyPulseDB and PartyPulseDB.showCooldownText == false) end
local function WidgetOffsetX()     return (PartyPulseDB and PartyPulseDB.widgetOffsetX) or 90 end
local function WidgetOffsetY()     return (PartyPulseDB and PartyPulseDB.widgetOffsetY) or 0 end
local function IconBorderShown()   return not (PartyPulseDB and PartyPulseDB.iconBorderShown == false) end
local function IconBorderThick()   return (PartyPulseDB and PartyPulseDB.iconBorderThickness) or 1 end

local function ColorOr(key, dr, dg, db, da)
    local c = PartyPulseDB and PartyPulseDB[key]
    if c then return c.r or dr, c.g or dg, c.b or db, c.a or da end
    return dr, dg, db, da
end

local function DisplayMode()
    return (PartyPulseDB and PartyPulseDB.displayMode) or "icons"
end

local function ShowName()
    return PartyPulseDB and PartyPulseDB.showName == true
end

local function NamePosition()
    return (PartyPulseDB and PartyPulseDB.namePosition) or "left"
end

local NAME_HEIGHT = 14

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
        container:SetBackdropColor(ColorOr("bgColor", 0, 0, 0, 0.5))
        container:SetBackdropBorderColor(ColorOr("borderColor", 1, 1, 1, 1))
    else
        container:SetBackdrop(nil)
    end
end

-- ---- icon widget ----------------------------------------------------------
local function CreateIconWidget(parent)
    local sz = IconSize()
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(sz, sz)
    w.tex = w:CreateTexture(nil, "ARTWORK")
    w.tex:SetAllPoints()

    w.border = {}
    if IconBorderShown() and IconBorderThick() > 0 then
        local th = IconBorderThick()
        local br, bg_, bb, ba = ColorOr("iconBorderColor", 0, 0, 0, 1)
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local tex = w:CreateTexture(nil, "OVERLAY")
            tex:SetColorTexture(br, bg_, bb, ba)
            if side == "TOP" then
                tex:SetPoint("TOPLEFT"); tex:SetPoint("TOPRIGHT"); tex:SetHeight(th)
            elseif side == "BOTTOM" then
                tex:SetPoint("BOTTOMLEFT"); tex:SetPoint("BOTTOMRIGHT"); tex:SetHeight(th)
            elseif side == "LEFT" then
                tex:SetPoint("TOPLEFT"); tex:SetPoint("BOTTOMLEFT"); tex:SetWidth(th)
            else
                tex:SetPoint("TOPRIGHT"); tex:SetPoint("BOTTOMRIGHT"); tex:SetWidth(th)
            end
            w.border[side] = tex
        end
    end

    w.cooldown = CreateFrame("Cooldown", nil, w, "CooldownFrameTemplate")
    w.cooldown:SetAllPoints()
    if w.cooldown.SetHideCountdownNumbers then
        w.cooldown:SetHideCountdownNumbers(not ShowCooldownText())
    end
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
    w:SetSize(BarWidth(), BarHeight())
    w:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    w:SetStatusBarColor(0.2, 0.8, 0.2)
    w:SetMinMaxValues(0, 1)
    w:SetValue(0)

    w.bg = w:CreateTexture(nil, "BACKGROUND")
    w.bg:SetAllPoints()
    w.bg:SetColorTexture(ColorOr("barBgColor", 0, 0, 0, 0.5))

    local fontPath = GameFontHighlightSmall:GetFont()
    w.name = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.name:SetPoint("LEFT", 4, 0)
    w.name:SetFont(fontPath, SpellNameFontSize(), "OUTLINE")
    w.name:SetTextColor(ColorOr("textColor", 1, 1, 1, 1))
    if not ShowSpellName() then w.name:Hide() end

    w.text = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.text:SetPoint("RIGHT", -4, 0)
    w.text:SetFont(fontPath, TimeFontSize(), "OUTLINE")
    w.text:SetTextColor(ColorOr("textColor", 1, 1, 1, 1))
    w.text:SetText("")

    w.kind = "bar"

    local function applyCooldownColor(self)
        if BarUseClassColor() and self._class then
            local c = RAID_CLASS_COLORS[self._class]
            if c then self:SetStatusBarColor(c.r, c.g, c.b) return end
        end
        self:SetStatusBarColor(ColorOr("barFillColor", 0.6, 0.1, 0.1, 1))
    end

    local function applyReadyColor(self)
        self:SetStatusBarColor(ColorOr("barReadyColor", 0.2, 0.8, 0.2, 1))
    end

    function w:ApplyIdle()
        self:SetScript("OnUpdate", nil)
        applyReadyColor(self)
        self:SetValue(1)
        if ShowReadyText() then
            self.text:SetText(ReadyText())
        else
            self.text:SetText("")
        end
    end

    function w:SetSpell(spellID)
        self.name:SetText(GetSpellName(spellID))
        self:ApplyIdle()
    end

    function w:SetClassColor(class)
        self._class = class
        -- idle state uses ready color; nothing to change now.
    end

    local function OnUpdate(self)
        local remaining = self.endTime - GetTime()
        if remaining <= 0 then
            self:ApplyIdle()
            return
        end
        local frac = remaining / self.duration
        if BarInvert() then frac = 1 - frac end
        self:SetValue(frac)
        if ShowCooldownText() then
            self.text:SetFormattedText(CooldownFormat(), remaining)
        else
            self.text:SetText("")
        end
    end

    function w:Trigger(cd)
        self.duration = cd
        self.endTime = GetTime() + cd
        applyCooldownColor(self)
        self:SetValue(BarInvert() and 0 or 1)
        self:SetScript("OnUpdate", OnUpdate)
    end

    return w
end

-- ---- composite icon+bar widget -------------------------------------------
local function CreateBothWidget(parent)
    local sz = IconSize()
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(sz + 4 + BarWidth(), sz)
    w.icon = CreateIconWidget(w)
    w.icon:SetPoint("LEFT")
    w.bar = CreateBarWidget(w)
    w.bar:SetPoint("LEFT", w.icon, "RIGHT", 4, 0)
    w.kind = "both"

    function w:SetSpell(spellID)
        self.icon:SetSpell(spellID)
        self.bar:SetSpell(spellID)
    end

    function w:SetClassColor(class)
        self.bar:SetClassColor(class)
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
    local nf = GameFontNormal:GetFont()
    r.name:SetFont(nf, NameFontSize(), "")

    r.widgets = {}
    r.widgetByID = {}
    return r
end

local function StacksVertically()
    local mode = DisplayMode()
    return mode == "bars" or mode == "both"
end

local function NameInline()
    return ShowName() and NamePosition() == "left"
end

local function NameAbove()
    return ShowName() and NamePosition() == "above"
end

local function LayoutName(row)
    row.name:ClearAllPoints()
    if not ShowName() then
        row.name:Hide()
        return
    end
    row.name:Show()
    if NameAbove() then
        row.name:SetPoint("TOPLEFT", NameOffsetX(), NameOffsetY())
        row.name:SetWidth(0)  -- let it size to text
        row.name:SetJustifyH("LEFT")
    else
        row.name:SetPoint("LEFT", NameOffsetX(), NameOffsetY())
        row.name:SetWidth(NAME_WIDTH)
        row.name:SetJustifyH("LEFT")
    end
end

local function LayoutWidgets(row)
    local stack = StacksVertically()
    local gap = SpellGap()
    local ox, oy = WidgetOffsetX(), WidgetOffsetY()
    for i, w in ipairs(row.widgets) do
        w:ClearAllPoints()
        if i == 1 then
            if NameAbove() then
                w:SetPoint("TOPLEFT", row, "TOPLEFT", ox, -NAME_HEIGHT - 2 + oy)
            else
                w:SetPoint("LEFT", row, "LEFT", ox, oy)
            end
        elseif stack then
            w:SetPoint("TOPLEFT", row.widgets[i - 1], "BOTTOMLEFT", 0, -gap)
        else
            w:SetPoint("LEFT", row.widgets[i - 1], "RIGHT", gap, 0)
        end
        w:Show()
    end
end

local function UnitHeight()
    if DisplayMode() == "bars" then return BarHeight() end
    return IconSize()
end

local function RowHeight(nSpells)
    local h
    if StacksVertically() and nSpells >= 1 then
        local unit = UnitHeight()
        h = unit * nSpells + SpellGap() * (nSpells - 1)
    else
        h = UnitHeight()
    end
    if NameAbove() then h = h + NAME_HEIGHT + 2 end
    return math.max(1, h)
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
        y = y - h - RowGap()
    end
    local totalH = math.max(1, -y + PADDING - RowGap())
    container:SetHeight(totalH)
    local mode = DisplayMode()
    local ox = math.max(0, WidgetOffsetX())
    local w
    if mode == "bars" then
        w = ox + BarWidth() + PADDING * 2 + 20
    elseif mode == "both" then
        w = ox + IconSize() + 4 + BarWidth() + PADDING * 2 + 20
    else
        w = ox + 6 * IconSize() + PADDING * 2 + 20
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
    LayoutName(row)

    for _, w in ipairs(row.widgets) do w:Hide() end
    row.widgets = {}
    row.widgetByID = {}
    for i, spell in ipairs(data.spells) do
        local w = CreateWidget(row)
        w:SetSpell(spell.id)
        if w.SetClassColor then w:SetClassColor(data.class) end
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

-- ---- test mode ------------------------------------------------------------
local TEST_MEMBERS = {
    { name = "TestDK-Test",     class = "DEATHKNIGHT" },
    { name = "TestMage-Test",   class = "MAGE" },
    { name = "TestShaman-Test", class = "SHAMAN" },
    { name = "TestDruid-Test",  class = "DRUID" },
}

local testTicker

local function EnabledSpellsFor(class)
    local out = {}
    for _, s in ipairs(ns.GetInterruptsFor(class, nil)) do
        if not ns.IsSpellEnabled or ns.IsSpellEnabled(s.id) then
            out[#out + 1] = s
        end
    end
    return out
end

local function TestIsActive()
    return testTicker ~= nil
end

local function ApplyTestMembers()
    for _, m in ipairs(TEST_MEMBERS) do
        local spells = EnabledSpellsFor(m.class)
        if #spells > 0 then
            ns.ui.SetMember(m.name, m.class, spells)
        else
            ns.ui.RemoveMember(m.name)
        end
    end
end

local function StopTestMode()
    if testTicker then testTicker:Cancel(); testTicker = nil end
    for _, m in ipairs(TEST_MEMBERS) do
        ns.ui.RemoveMember(m.name)
    end
end

local function StartTestMode()
    ApplyTestMembers()
    if testTicker then testTicker:Cancel() end
    testTicker = C_Timer.NewTicker(2.5, function()
        local m = TEST_MEMBERS[math.random(#TEST_MEMBERS)]
        local spells = EnabledSpellsFor(m.class)
        if #spells == 0 then return end
        local s = spells[math.random(#spells)]
        ns.ui.TriggerCD(m.name, s.id, s.cd)
    end)
end

function ns.ui.SetTestMode(on)
    if on then StartTestMode() else StopTestMode() end
end

-- Re-apply test member rows with current spell-enable filter (no ticker churn).
function ns.ui.RefreshTestMembers()
    if TestIsActive() then ApplyTestMembers() end
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
