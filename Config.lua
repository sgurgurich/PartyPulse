local _, ns = ...

ns.config = {}

local category

local DEFAULTS = {
    shown = true,
    locked = false,
    scale = 1.0,
    displayMode = "both",
    showBackdrop = false,
    showName = false,
    namePosition = "left",
    nameOffsetX = 0,
    nameOffsetY = 0,
    nameFontSize = 20,
    showSpellName = true,
    spellNameFontSize = 11,
    timeFontSize = 10,
    iconSize = 24,
    barWidth = 110,
    barHeight = 24,
    spellGap = 2,
    rowGap = 1,
    testMode = false,
    barUseClassColor = false,
    barReadyUseClassColor = true,
    barInvert = false,
    showReadyText = true,
    readyText = "Ready",
    cooldownFormat = "%.1f",
    showPlayerNameWhenReady = true,
    bgColor = { r = 0, g = 0, b = 0, a = 0.5 },
    borderColor = { r = 1, g = 1, b = 1, a = 1 },
    barBgColor = { r = 0, g = 0, b = 0, a = 0.5 },
    barFillColor = { r = 1/255, g = 5/255, b = 30/255, a = 0.6 },
    barReadyColor = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
    textColor = { r = 1, g = 1, b = 1, a = 1 },
    readyTextColor = { r = 0, g = 1, b = 0, a = 1 },
    showCooldownText = true,
    widgetOffsetX = 90,
    widgetOffsetY = 0,
    iconBorderShown = true,
    iconBorderThickness = 2,
    iconBorderColor = { r = 0, g = 0, b = 0, a = 1 },
    iconBarGap = 0,
    iconBarOffsetY = 0,
    iconOrientation = "vertical",
    verticalGrowth = "down",
    horizontalGrowth = "right",
    sortOrder = "standard",
    playerAnchor = "front",
    bgPadding = 10,
    bgBorderSize = 12,
    classColorOverrides = {},
}

-- Spells whose tracking should default to OFF instead of ON.
local SPELL_DEFAULT_OFF = {
    [49576] = true, -- Death Grip
}

local function EnsureDefaults()
    PartyPulseDB = PartyPulseDB or {}
    for k, v in pairs(DEFAULTS) do
        if PartyPulseDB[k] == nil then
            if type(v) == "table" then
                PartyPulseDB[k] = { r = v.r, g = v.g, b = v.b, a = v.a }
            else
                PartyPulseDB[k] = v
            end
        elseif type(v) == "table" and type(PartyPulseDB[k]) == "table" then
            -- backfill any missing color channel
            for ck, cv in pairs(v) do
                if PartyPulseDB[k][ck] == nil then PartyPulseDB[k][ck] = cv end
            end
        end
    end
    if not PartyPulseDB._defaultOffMigrated then
        for id in pairs(SPELL_DEFAULT_OFF) do
            PartyPulseDB["spell_" .. id] = false
        end
        PartyPulseDB._defaultOffMigrated = true
    end
    if ns.AllTrackedSpells then
        for _, s in ipairs(ns.AllTrackedSpells()) do
            local key = "spell_" .. s.id
            if PartyPulseDB[key] == nil then
                PartyPulseDB[key] = not SPELL_DEFAULT_OFF[s.id]
            end
        end
    end
end
ns.config.EnsureDefaults = EnsureDefaults

local _allPanels = {}
function ns.config.RefreshAllPanels()
    for _, p in ipairs(_allPanels) do
        if p and p._rows then
            for _, r in ipairs(p._rows) do
                if r.Refresh then r:Refresh() end
            end
        end
    end
end

function ns.config.ApplyAll()
    EnsureDefaults()
    if PartyPulseDB.shown then ns.ui.Show() else ns.ui.Hide() end
    ns.ui.SetLocked(PartyPulseDB.locked)
    ns.ui.SetScale(PartyPulseDB.scale)
    ns.ui.SetBackdropShown(PartyPulseDB.showBackdrop)
    if PartyPulseDB.testMode then ns.ui.SetTestMode(true) end
end

function ns.config.Open()
    if not category then return end
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end

-- =========================================================================
--  Canvas panel helpers
-- =========================================================================
-- All subcategories that mix sliders/edit-boxes/dropdowns/color pickers use
-- a canvas layout. We build custom rows by hand and flow them top-to-bottom.

local PANEL_PAD_X = 16
local PANEL_PAD_Y = 16
local ROW_H       = 28
local ROW_GAP     = 6
local LABEL_W     = 170
local CONTROL_X   = PANEL_PAD_X + LABEL_W + 10

local function NewPanel(title, parentCategory, subName)
    local outer = CreateFrame("Frame", nil, UIParent)
    outer:SetSize(620, 500)

    local scroll = CreateFrame("ScrollFrame", nil, outer)
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -8, 4)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxv = self:GetVerticalScrollRange()
        local step = 40
        local target = cur - delta * step
        if target < 0 then target = 0 end
        if target > maxv then target = maxv end
        self:SetVerticalScroll(target)
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(620, 900)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)

    outer.content = content
    outer._scroll = scroll

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", PANEL_PAD_X, -PANEL_PAD_Y)
    header:SetText(title)

    outer._cursorY = -PANEL_PAD_Y - 28
    outer._rows = {}

    function outer:NextY(extra)
        local y = self._cursorY
        self._cursorY = self._cursorY - (ROW_H + ROW_GAP) - (extra or 0)
        return y
    end

    function outer:AddRow(rowFrame)
        self._rows[#self._rows + 1] = rowFrame
        return rowFrame
    end

    function outer:FinalizeHeight()
        local used = math.abs(self._cursorY) + PANEL_PAD_Y
        content:SetHeight(math.max(used, 400))
    end

    _allPanels[#_allPanels + 1] = outer
    return outer
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["PARTYPULSE_NAME_INPUT"] = {
    text = "%s",
    button1 = OKAY or "Okay",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnShow = function(self)
        if self.editBox then self.editBox:SetText(""); self.editBox:SetFocus() end
    end,
    OnAccept = function(self, data)
        local name = self.editBox and self.editBox:GetText() or ""
        if data and data.callback then data.callback(name) end
    end,
    EditBoxOnEnterPressed = function(self, data)
        local name = self:GetText()
        self:GetParent():Hide()
        if data and data.callback then data.callback(name) end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["PARTYPULSE_CONFIRM"] = {
    text = "%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, data)
        if data and data.callback then data.callback() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function PromptName(prompt, callback)
    StaticPopup_Show("PARTYPULSE_NAME_INPUT", prompt, nil, { callback = callback })
end
local function ConfirmAction(prompt, callback)
    StaticPopup_Show("PARTYPULSE_CONFIRM", prompt, nil, { callback = callback })
end

-- Plain button that doesn't inherit from UIPanelButtonTemplate.
-- Some Blizzard templates now call Frame:RegisterEvent() via secure hooks
-- which can trigger ADDON_ACTION_FORBIDDEN for addon children — avoid them.
local function StyledButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 120, h or 24)
    if b.SetBackdrop then
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        b:SetBackdropColor(0.18, 0.18, 0.18, 1)
        b:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    end
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 1)
    fs:SetText(text)
    b.text = fs
    b:SetScript("OnEnter",     function(s) if s.SetBackdropColor then s:SetBackdropColor(0.32, 0.32, 0.32, 1) end end)
    b:SetScript("OnLeave",     function(s) if s.SetBackdropColor then s:SetBackdropColor(0.18, 0.18, 0.18, 1) end end)
    b:SetScript("OnMouseDown", function(s) if s.SetBackdropColor then s:SetBackdropColor(0.10, 0.10, 0.10, 1) end end)
    b:SetScript("OnMouseUp",   function(s) if s.SetBackdropColor then s:SetBackdropColor(0.32, 0.32, 0.32, 1) end end)
    return b
end

-- ---- Section header (not a row — no refresh, no DB binding) --------------
local function AddSectionHeader(panel, title, extraTopGap, color, leftAlign)
    local topGap = extraTopGap or 20
    panel._cursorY = panel._cursorY - topGap

    local parent = panel.content or panel
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    if leftAlign then
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", PANEL_PAD_X, panel._cursorY)
    else
        lbl:SetPoint("TOP", parent, "TOPLEFT", PANEL_PAD_X + 290, panel._cursorY)
    end
    lbl:SetText(title)
    if color then lbl:SetTextColor(color.r, color.g, color.b) end

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("LEFT",  parent, "TOPLEFT", PANEL_PAD_X,       panel._cursorY - 22)
    line:SetPoint("RIGHT", parent, "TOPLEFT", PANEL_PAD_X + 580, panel._cursorY - 22)

    panel._cursorY = panel._cursorY - 30
end

local function RefreshAllPanelRows(panel)
    if not panel or not panel._rows then return end
    for _, r in ipairs(panel._rows) do
        if r.Refresh then r:Refresh() end
    end
end

-- ---- Row: label + slider + numeric editbox ------------------------------
local function AddSliderRow(panel, label, varKey, min, max, step, onChange, tooltip)
    local row = CreateFrame("Frame", nil, panel.content or panel)
    row:SetSize(580, ROW_H)
    row:SetPoint("TOPLEFT", PANEL_PAD_X, panel:NextY())

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetWidth(LABEL_W)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local slider = CreateFrame("Slider", nil, row, "UISliderTemplate")
    slider:SetPoint("LEFT", LABEL_W + 10, 0)
    slider:SetSize(280, 16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    edit:SetPoint("LEFT", slider, "RIGHT", 20, 0)
    edit:SetSize(60, 20)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(8)
    edit:SetTextInsets(4, 4, 2, 2)

    local isFloat = step < 1
    local fmt = isFloat and "%.2f" or "%d"
    local function clamp(v) return math.max(min, math.min(max, v)) end
    local function quant(v)
        if isFloat then return v end
        return math.floor(v + 0.5)
    end

    local suppress = false
    local function setValue(v, fromSlider)
        v = clamp(quant(v))
        suppress = true
        slider:SetValue(v)
        edit:SetText(string.format(fmt, v))
    edit:SetCursorPosition(0)
        suppress = false
        PartyPulseDB[varKey] = v
        if onChange then onChange(v) end
    end

    slider:SetScript("OnValueChanged", function(_, v)
        if suppress then return end
        setValue(v, true)
    end)

    edit:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then setValue(v) else edit:SetText(string.format(fmt, PartyPulseDB[varKey])) end
        self:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        edit:SetText(string.format(fmt, PartyPulseDB[varKey]))
        self:ClearFocus()
    end)
    edit:SetScript("OnShow", function(self)
        local v = PartyPulseDB[varKey]
        if v ~= nil then
            self:SetText(string.format(fmt, v))
            self:SetCursorPosition(0)
            self:ClearFocus()
        end
    end)

    if tooltip then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end

    function row:Refresh()
        local v = PartyPulseDB[varKey]
        if v == nil then v = DEFAULTS[varKey] end
        suppress = true
        slider:SetValue(clamp(quant(v)))
        edit:SetText(string.format(fmt, v))
    edit:SetCursorPosition(0)
        suppress = false
    end
    row:Refresh()

    panel:AddRow(row)
    return row
end

-- ---- Row: label + checkbox ----------------------------------------------
local function AddCheckRow(panel, label, varKey, onChange, tooltip)
    local row = CreateFrame("Frame", nil, panel.content or panel)
    row:SetSize(580, ROW_H)
    row:SetPoint("TOPLEFT", PANEL_PAD_X, panel:NextY())

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", 0, 0)
    cb.text:SetText(label)
    cb:SetScript("OnClick", function(self)
        PartyPulseDB[varKey] = self:GetChecked()
        if onChange then onChange(PartyPulseDB[varKey]) end
    end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end

    function row:Refresh()
        cb:SetChecked(PartyPulseDB[varKey] == true)
    end
    row:Refresh()

    panel:AddRow(row)
    return row
end

-- ---- Row: label + dropdown ----------------------------------------------
local function AddDropdownRow(panel, label, varKey, options, onChange)
    local row = CreateFrame("Frame", nil, panel.content or panel)
    row:SetSize(580, ROW_H + 4)
    row:SetPoint("TOPLEFT", PANEL_PAD_X, panel:NextY(4))

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetWidth(LABEL_W)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local dd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dd:SetPoint("LEFT", LABEL_W + 6, 0)
    dd:SetWidth(220)

    local function labelFor(value)
        for _, o in ipairs(options) do if o[1] == value then return o[2] end end
        return tostring(value)
    end

    dd:SetupMenu(function(_, rootDescription)
        for _, opt in ipairs(options) do
            local v = opt[1]
            rootDescription:CreateRadio(opt[2],
                function() return PartyPulseDB[varKey] == v end,
                function()
                    PartyPulseDB[varKey] = v
                    dd:GenerateMenu()
                    if onChange then onChange(v) end
                end)
        end
    end)

    function row:Refresh()
        dd:GenerateMenu()
    end
    row:Refresh()

    panel:AddRow(row)
    return row
end

-- ---- Row: label + free-form text input ---------------------------------
local function AddTextInputRow(panel, label, varKey, onChange, tooltip)
    local row = CreateFrame("Frame", nil, panel.content or panel)
    row:SetSize(580, ROW_H)
    row:SetPoint("TOPLEFT", PANEL_PAD_X, panel:NextY())

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetWidth(LABEL_W)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    edit:SetPoint("LEFT", LABEL_W + 10, 0)
    edit:SetSize(220, 20)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(24)
    edit:SetTextInsets(4, 4, 2, 2)

    edit:SetScript("OnEnterPressed", function(self)
        PartyPulseDB[varKey] = self:GetText() or ""
        if onChange then onChange(PartyPulseDB[varKey]) end
        self:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:SetText(PartyPulseDB[varKey] or "")
        self:SetCursorPosition(0)
        self:ClearFocus()
    end)
    edit:SetScript("OnShow", function(self)
        self:SetText(PartyPulseDB[varKey] or "")
        self:SetCursorPosition(0)
        self:ClearFocus()
    end)

    if tooltip then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end

    function row:Refresh()
        edit:SetText(PartyPulseDB[varKey] or "")
        edit:SetCursorPosition(0)
    end
    row:Refresh()

    panel:AddRow(row)
    return row
end

-- ---- Row: label + color swatch button ----------------------------------
local function OpenColorPicker(current, hasAlpha, onChange)
    local r, g, b = current.r, current.g, current.b
    local a = current.a or 1
    local info = {
        r = r, g = g, b = b,
        opacity = a,
        hasOpacity = hasAlpha and true or false,
        swatchFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = (hasAlpha and ColorPickerFrame.GetColorAlpha) and ColorPickerFrame:GetColorAlpha() or a
            onChange({ r = nr, g = ng, b = nb, a = na })
        end,
        opacityFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a
            onChange({ r = nr, g = ng, b = nb, a = na })
        end,
        cancelFunc = function(prev)
            if prev then onChange({ r = prev.r, g = prev.g, b = prev.b, a = prev.opacity or a }) end
        end,
    }
    ColorPickerFrame:SetupColorPickerAndShow(info)
end

local function AddColorRow(panel, label, varKey, hasAlpha, onChange, tooltip)
    local row = CreateFrame("Frame", nil, panel.content or panel)
    row:SetSize(580, ROW_H)
    row:SetPoint("TOPLEFT", PANEL_PAD_X, panel:NextY())

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetWidth(LABEL_W)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(label)

    local btn = CreateFrame("Button", nil, row)
    btn:SetPoint("LEFT", LABEL_W + 10, 0)
    btn:SetSize(48, 20)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)

    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)

    local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    border:SetAllPoints()
    if border.SetBackdrop then
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end

    local hint = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", btn, "RIGHT", 8, 0)
    hint:SetText("(click to change)")

    btn:SetScript("OnClick", function()
        OpenColorPicker(PartyPulseDB[varKey], hasAlpha, function(c)
            PartyPulseDB[varKey] = c
            swatch:SetColorTexture(c.r, c.g, c.b, c.a or 1)
            if onChange then onChange(c) end
        end)
    end)

    if tooltip then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end

    function row:Refresh()
        local c = PartyPulseDB[varKey]
        if c then swatch:SetColorTexture(c.r, c.g, c.b, c.a or 1) end
    end
    row:Refresh()

    panel:AddRow(row)
    return row
end

local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE",
    "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local function ClassDisplayName(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

-- ---- Row: class color swatch with reset button --------------------------
local function CurrentClassColor(class)
    local ov = PartyPulseDB.classColorOverrides and PartyPulseDB.classColorOverrides[class]
    if ov then return ov end
    if ns.CLASS_COLOR_DEFAULTS and ns.CLASS_COLOR_DEFAULTS[class] then
        return ns.CLASS_COLOR_DEFAULTS[class]
    end
    local c = RAID_CLASS_COLORS[class]
    if c then return { r = c.r, g = c.g, b = c.b, a = 1 } end
    return { r = 1, g = 1, b = 1, a = 1 }
end

local function AddClassColorRow(panel, class, onChange)
    local row = CreateFrame("Frame", nil, panel.content or panel)
    row:SetSize(580, ROW_H)
    row:SetPoint("TOPLEFT", PANEL_PAD_X, panel:NextY())

    local c = RAID_CLASS_COLORS[class]
    local hex = c and string.format("ff%02x%02x%02x", c.r*255, c.g*255, c.b*255) or "ffffffff"
    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetWidth(LABEL_W)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(string.format("|c%s%s|r", hex, ClassDisplayName and ClassDisplayName(class) or class))

    local btn = CreateFrame("Button", nil, row)
    btn:SetPoint("LEFT", LABEL_W + 10, 0)
    btn:SetSize(48, 20)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)

    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)

    local function paint()
        local cur = CurrentClassColor(class)
        swatch:SetColorTexture(cur.r, cur.g, cur.b, 1)
    end
    paint()

    btn:SetScript("OnClick", function()
        local cur = CurrentClassColor(class)
        OpenColorPicker({ r = cur.r, g = cur.g, b = cur.b, a = 1 }, false, function(nc)
            PartyPulseDB.classColorOverrides = PartyPulseDB.classColorOverrides or {}
            PartyPulseDB.classColorOverrides[class] = { r = nc.r, g = nc.g, b = nc.b }
            paint()
            if onChange then onChange() end
        end)
    end)

    local reset = StyledButton(row, "Reset", 80, 22)
    reset:SetPoint("LEFT", btn, "RIGHT", 10, 0)
    reset:SetScript("OnClick", function()
        if PartyPulseDB.classColorOverrides then
            PartyPulseDB.classColorOverrides[class] = nil
        end
        paint()
        if onChange then onChange() end
    end)

    function row:Refresh() paint() end
    panel:AddRow(row)
    return row
end

-- =========================================================================
--  Subcategory panels
-- =========================================================================

local function RefreshBackdrop()
    if ns.ui.RefreshBackdrop then ns.ui.RefreshBackdrop() end
end

local function BuildInfoPanel()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(620, 720)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    header:SetPoint("TOP", 0, -24)
    header:SetText("PartyPulse")

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\PartyPulse\\logo.tga")
    logo:SetSize(320, 180)
    logo:SetPoint("TOP", header, "BOTTOM", 0, -16)

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOP", logo, "BOTTOM", 0, -24)
    desc:SetWidth(520)
    desc:SetJustifyH("CENTER")
    desc:SetSpacing(4)
    desc:SetText("A Midnight-compatible party interrupt cooldown tracker. "
        .. "Each client tracks its own casts and broadcasts them over the hidden addon channel, "
        .. "so every player sees every party member's interrupt and key CDs in real time.\n\n"
        .. "Configure display, layout, text, and colors in the tabs on the left. "
        .. "Toggle tracked spells per-class in the Spells tab.")

    local credit = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    credit:SetPoint("BOTTOM", 0, 28)
    credit:SetJustifyH("CENTER")
    credit:SetText("Created by |cffffd100theirontip|r")

    return f
end

local function BuildGeneralPanel()
    local f = NewPanel("General", category)

    AddSectionHeader(f, "Behavior", 0)
    AddCheckRow(f, "Test mode", "testMode", function(v) ns.ui.SetTestMode(v) end,
        "Show 4 simulated party members (DK/Mage/Shaman/Druid) with randomized cooldowns every ~2.5s.")

    AddSectionHeader(f, "Frame")
    AddCheckRow(f, "Show frame", "shown", function(v)
        if v then ns.ui.Show() else ns.ui.Hide() end
    end)
    AddCheckRow(f, "Lock frame", "locked", function(v) ns.ui.SetLocked(v) end,
        "Prevents the frame from being dragged.")
    AddSliderRow(f, "Scale", "scale", 0.5, 2.0, 0.05, function(v) ns.ui.SetScale(v) end)

    AddSectionHeader(f, "Display")
    AddDropdownRow(f, "Display mode", "displayMode", {
        { "icons", "Icons" }, { "bars", "Bars" }, { "both", "Icons + Bars" },
    }, function() ns.ui.RebuildAll() end)
    AddDropdownRow(f, "Sort order", "sortOrder", {
        { "standard", "Standard (group order)" },
        { "thd",      "Tank / Healer / DPS" },
        { "htd",      "Healer / Tank / DPS" },
    }, function() ns.ui.RebuildAll() end)
    AddDropdownRow(f, "Player anchor", "playerAnchor", {
        { "front", "Always in front" },
        { "back",  "Always in back" },
    }, function() ns.ui.RebuildAll() end)

    f:FinalizeHeight()
    return f
end

local function BuildLayoutPanel()
    local f = NewPanel("Layout", category)

    AddSectionHeader(f, "Widget sizes", 0)
    AddSliderRow(f, "Icon size",  "iconSize",  8,  64,  1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Bar width",  "barWidth",  40, 320, 1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Bar height", "barHeight", 4,  40,  1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Icon border thickness", "iconBorderThickness", 0, 6, 1, function() ns.ui.RebuildAll() end)

    AddSectionHeader(f, "Spacing")
    AddSliderRow(f, "Spell spacing (for 2+ kick specs)", "spellGap", -40, 20, 1, function() ns.ui.RebuildAll() end,
        "Spacing between cooldowns within a member's row. Can go negative for tighter or overlapping layouts.")
    AddSliderRow(f, "Row spacing", "rowGap", -20, 40, 1, function() ns.ui.RebuildAll() end,
        "Spacing between party member rows. Can go negative to make bars touch or overlap.")

    AddSectionHeader(f, "Cooldown offset")
    AddSliderRow(f, "Cooldown offset X", "widgetOffsetX", -300, 400, 1, function() ns.ui.RebuildAll() end,
        "Horizontal offset of the icon/bar block from the row's left edge. Independent of the player-name offset.")
    AddSliderRow(f, "Cooldown offset Y", "widgetOffsetY", -200, 200, 1, function() ns.ui.RebuildAll() end,
        "Vertical offset of the icon/bar block. Independent of the player-name offset.")

    AddSectionHeader(f, "Growth direction")
    AddDropdownRow(f, "Vertical growth", "verticalGrowth", {
        { "down", "Downward (default)" },
        { "up",   "Upward" },
    }, function() ns.ui.RebuildAll() end)
    AddDropdownRow(f, "Horizontal growth", "horizontalGrowth", {
        { "right", "Rightward (default)" },
        { "left",  "Leftward" },
    }, function() ns.ui.RebuildAll() end)

    AddSectionHeader(f, "Icons mode")
    AddDropdownRow(f, "Icon orientation", "iconOrientation", {
        { "vertical",   "Vertical"   },
        { "horizontal", "Horizontal" },
    }, function() ns.ui.RebuildAll() end)

    AddSectionHeader(f, "Icons + Bars mode")
    AddSliderRow(f, "Icon-to-bar gap", "iconBarGap", -40, 40, 1, function() ns.ui.RebuildAll() end,
        "Horizontal gap between an icon and its bar in \"Icons + Bars\" mode.")
    AddSliderRow(f, "Icon-to-bar Y offset", "iconBarOffsetY", -40, 40, 1, function() ns.ui.RebuildAll() end,
        "Vertical offset of the bar relative to its icon in \"Icons + Bars\" mode.")

    f:FinalizeHeight()
    return f
end

local function BuildTextPanel()
    local f = NewPanel("Text", category)

    AddSectionHeader(f, "Player name", 0)
    AddCheckRow(f, "Show player name", "showName", function() ns.ui.RebuildAll() end)
    AddDropdownRow(f, "Player name position", "namePosition", {
        { "left", "Left of cooldowns" }, { "above", "Above cooldowns" },
    }, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Name offset X",  "nameOffsetX",  -300, 300, 1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Name offset Y",  "nameOffsetY",  -300, 300, 1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Name font size", "nameFontSize",    6,  32, 1, function() ns.ui.RebuildAll() end)

    AddSectionHeader(f, "Spell name")
    AddCheckRow(f, "Show spell name on bars", "showSpellName", function() ns.ui.RebuildAll() end,
        "Toggle whether the spell name is drawn on each bar.")
    AddSliderRow(f, "Spell name font size", "spellNameFontSize", 6, 32, 1, function() ns.ui.RebuildAll() end)

    AddSectionHeader(f, "Countdown")
    AddCheckRow(f, "Show cooldown countdown text", "showCooldownText", function() ns.ui.RebuildAll() end,
        "Shows the remaining seconds on both icons and bars. Turn off to hide the countdown text.")
    AddDropdownRow(f, "Countdown format", "cooldownFormat", {
        { "%.1f",  "5.3"  },
        { "%d",    "5"    },
        { "%.1fs", "5.3s" },
        { "%ds",   "5s"   },
    }, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Countdown font size", "timeFontSize", 6, 32, 1, function() ns.ui.RebuildAll() end)

    AddSectionHeader(f, "Ready state")
    AddCheckRow(f, "Show \"Ready\" text when off cooldown", "showReadyText", function() ns.ui.RebuildAll() end)
    AddTextInputRow(f, "Ready text", "readyText", function() ns.ui.RebuildAll() end,
        "Shown inside the bar when the spell is off cooldown.")
    AddCheckRow(f, "Show player name when Ready", "showPlayerNameWhenReady", function() ns.ui.RebuildAll() end,
        "When on, bars display the player's name instead of the spell name while the spell is off cooldown.")

    f:FinalizeHeight()
    return f
end

local function BuildColorsPanel()
    local f = NewPanel("Colors", category)

    AddSectionHeader(f, "Frame background", 0)
    AddCheckRow(f, "Show frame background", "showBackdrop", function(v) ns.ui.SetBackdropShown(v) end)
    AddColorRow(f, "Background color", "bgColor", true, RefreshBackdrop,
        "Color and transparency of the frame's background fill.")
    AddColorRow(f, "Border color", "borderColor", true, RefreshBackdrop)
    AddSliderRow(f, "Border thickness", "bgBorderSize", 0, 32, 1, RefreshBackdrop,
        "Thickness of the frame border. 0 hides the border.")
    AddSliderRow(f, "Padding", "bgPadding", 0, 40, 1, function() ns.ui.RebuildAll() end,
        "Inner padding between the frame border and the rows.")

    AddSectionHeader(f, "Bars")
    AddColorRow(f, "Bar background", "barBgColor", true, function() ns.ui.RebuildAll() end)
    AddCheckRow(f, "On-cooldown uses class color", "barUseClassColor", function() ns.ui.RebuildAll() end,
        "When on, the on-cooldown fill is the owner's class color. When off, uses the override below.")
    AddColorRow(f, "Bar on-cooldown color (override)", "barFillColor", true, function() ns.ui.RebuildAll() end,
        "Used when \"On-cooldown uses class color\" is off.")
    AddCheckRow(f, "Ready uses class color", "barReadyUseClassColor", function() ns.ui.RebuildAll() end,
        "When on, the ready-state fill is the owner's class color. When off, uses the override below.")
    AddColorRow(f, "Bar ready color (override)", "barReadyColor", true, function() ns.ui.RebuildAll() end,
        "Used when \"Ready uses class color\" is off.")
    AddCheckRow(f, "Invert bar direction", "barInvert", function() ns.ui.RebuildAll() end,
        "When on, bars fill from empty to full as the cooldown progresses instead of draining.")

    AddSectionHeader(f, "Icons")
    AddCheckRow(f, "Show icon border", "iconBorderShown", function() ns.ui.RebuildAll() end)
    AddColorRow(f, "Icon border color", "iconBorderColor", true, function() ns.ui.RebuildAll() end)

    AddSectionHeader(f, "Text")
    AddColorRow(f, "Text color", "textColor", true, function() ns.ui.RebuildAll() end,
        "Applies to the spell name and countdown text on bars. Player name keeps the class color.")
    AddColorRow(f, "Ready text color", "readyTextColor", true, function() ns.ui.RebuildAll() end,
        "Color of the \"Ready\" text shown inside bars when a spell is off cooldown.")

    f:FinalizeHeight()
    return f
end

local function BuildClassColorsPanel()
    local f = NewPanel("Class Colors", category)

    AddSectionHeader(f, "Per-class color overrides", 0)
    for _, class in ipairs(CLASS_ORDER) do
        AddClassColorRow(f, class, function() ns.ui.RebuildAll() end)
    end

    f:FinalizeHeight()
    return f
end

-- =========================================================================
--  Profiles subcategory
-- =========================================================================
local function BuildProfilesPanel()
    local f = NewPanel("Profiles", category)

    AddSectionHeader(f, "Active profile", 0)

    local ddRow = CreateFrame("Frame", nil, f.content)
    ddRow:SetSize(580, ROW_H + 4)
    ddRow:SetPoint("TOPLEFT", PANEL_PAD_X, f:NextY(4))
    local ddLbl = ddRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ddLbl:SetPoint("LEFT", 0, 0); ddLbl:SetWidth(LABEL_W); ddLbl:SetJustifyH("LEFT")
    ddLbl:SetText("Profile")
    local dd = CreateFrame("DropdownButton", nil, ddRow, "WowStyle1DropdownTemplate")
    dd:SetPoint("LEFT", LABEL_W + 6, 0); dd:SetWidth(240)
    dd:SetupMenu(function(_, root)
        for _, name in ipairs(ns.profiles.List()) do
            root:CreateRadio(name,
                function() return ns.profiles.Active() == name end,
                function() ns.profiles.Switch(name) end)
        end
    end)
    function ddRow:Refresh() dd:GenerateMenu() end
    f:AddRow(ddRow)

    local btnRow = CreateFrame("Frame", nil, f.content)
    btnRow:SetSize(580, ROW_H + 6)
    btnRow:SetPoint("TOPLEFT", PANEL_PAD_X, f:NextY(6))

    local function MakeBtn(label, x, onClick)
        local b = StyledButton(btnRow, label, 120, 24)
        b:SetPoint("LEFT", x, 0)
        b:SetScript("OnClick", onClick)
        return b
    end

    MakeBtn("New", 0, function()
        PromptName("Name for new profile:", function(name)
            if not name or name == "" then return end
            local ok, err = ns.profiles.Add(name)
            if not ok then print("|cffff6060PartyPulse:|r " .. (err or "failed")) end
        end)
    end)
    MakeBtn("Clone active", 130, function()
        PromptName("Name for cloned profile:", function(name)
            if not name or name == "" then return end
            local ok, err = ns.profiles.Clone(name)
            if not ok then print("|cffff6060PartyPulse:|r " .. (err or "failed")) end
        end)
    end)
    MakeBtn("Delete active", 260, function()
        local active = ns.profiles.Active()
        if not active then return end
        ConfirmAction("Delete profile '" .. active .. "'? This cannot be undone.", function()
            local ok, err = ns.profiles.Remove(active)
            if not ok then print("|cffff6060PartyPulse:|r " .. (err or "failed")) end
        end)
    end)
    f:AddRow(btnRow)

    AddSectionHeader(f, "Export / Import")

    local help = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", PANEL_PAD_X, f:NextY(-6))
    help:SetWidth(540); help:SetJustifyH("LEFT")
    help:SetText("Click Export to fill the box with a shareable string for the active profile. " ..
        "To import, paste a string into the box, enter a name, and click Import.")

    local BOX_H = 120
    local boxBorder = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
    boxBorder:SetSize(540, BOX_H)
    boxBorder:SetPoint("TOPLEFT", PANEL_PAD_X, f:NextY(BOX_H + 10))
    if boxBorder.SetBackdrop then
        boxBorder:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        boxBorder:SetBackdropColor(0, 0, 0, 0.5)
    end

    local boxScroll = CreateFrame("ScrollFrame", nil, boxBorder)
    boxScroll:SetPoint("TOPLEFT", 6, -6)
    boxScroll:SetPoint("BOTTOMRIGHT", -6, 6)
    boxScroll:EnableMouseWheel(true)
    boxScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxv = self:GetVerticalScrollRange()
        local target = cur - delta * 20
        if target < 0 then target = 0 end
        if target > maxv then target = maxv end
        self:SetVerticalScroll(target)
    end)

    local edit = CreateFrame("EditBox", nil, boxScroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(520)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    boxScroll:SetScrollChild(edit)
    boxScroll:SetScript("OnSizeChanged", function(_, w) edit:SetWidth(w) end)

    local box = { EditBox = edit }

    local actionRow = CreateFrame("Frame", nil, f.content)
    actionRow:SetSize(580, ROW_H + 6)
    actionRow:SetPoint("TOPLEFT", PANEL_PAD_X, f:NextY(6))

    local exportBtn = StyledButton(actionRow, "Export", 120, 24)
    exportBtn:SetPoint("LEFT", 0, 0)
    exportBtn:SetScript("OnClick", function()
        local s = ns.profiles.Export()
        if s then
            box.EditBox:SetText(s)
            box.EditBox:HighlightText()
            box.EditBox:SetFocus()
        end
    end)

    local nameLbl = actionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLbl:SetPoint("LEFT", exportBtn, "RIGHT", 20, 0); nameLbl:SetText("Import as:")

    local nameEdit = CreateFrame("EditBox", nil, actionRow, "InputBoxTemplate")
    nameEdit:SetPoint("LEFT", nameLbl, "RIGHT", 10, 0)
    nameEdit:SetSize(140, 20); nameEdit:SetAutoFocus(false); nameEdit:SetMaxLetters(32)

    local importBtn = StyledButton(actionRow, "Import", 100, 24)
    importBtn:SetPoint("LEFT", nameEdit, "RIGHT", 10, 0)
    importBtn:SetScript("OnClick", function()
        local str = box.EditBox:GetText() or ""
        local name = nameEdit:GetText() or ""
        local ok, err = ns.profiles.Import(str, name)
        if ok then
            ns.profiles.Switch(name)
            nameEdit:SetText("")
            print("|cff80ff80PartyPulse:|r imported profile '" .. name .. "'")
        else
            print("|cffff6060PartyPulse:|r import failed — " .. (err or "unknown"))
        end
    end)
    f:AddRow(actionRow)

    f:FinalizeHeight()
    return f
end

-- =========================================================================
--  Spells subcategory (canvas layout, grouped by class)
-- =========================================================================
local function BuildSpellsPanel()
    local f = NewPanel("Spells", category)
    local all = ns.AllTrackedSpells and ns.AllTrackedSpells() or {}

    local byClass = {}
    for _, s in ipairs(all) do
        local class = s.class or "OTHER"
        byClass[class] = byClass[class] or {}
        table.insert(byClass[class], s)
    end

    local order = {}
    for _, c in ipairs(CLASS_ORDER) do if byClass[c] then order[#order + 1] = c end end
    if byClass.OTHER then order[#order + 1] = "OTHER" end

    local onChange = function() if ns.RefreshAll then ns.RefreshAll() end end
    local first = true
    for _, class in ipairs(order) do
        local color = (class ~= "OTHER") and CurrentClassColor(class) or nil
        local title = (class == "OTHER") and "Other" or ClassDisplayName(class)
        AddSectionHeader(f, title, first and 0 or nil, color, true)
        first = false
        for _, s in ipairs(byClass[class]) do
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(s.id)
            local spellName = (info and info.name) or ("Spell " .. s.id)
            AddCheckRow(f, spellName, "spell_" .. s.id, onChange,
                "Track " .. spellName .. " on your row and on party members.")
        end
    end

    f:FinalizeHeight()
    return f
end

-- =========================================================================
--  Registration
-- =========================================================================
function ns.config.Register()
    EnsureDefaults()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end

    local infoPanel = BuildInfoPanel()
    category = Settings.RegisterCanvasLayoutCategory(infoPanel, "PartyPulse")
    Settings.RegisterAddOnCategory(category)

    Settings.RegisterCanvasLayoutSubcategory(category, BuildGeneralPanel(), "General")
    Settings.RegisterCanvasLayoutSubcategory(category, BuildLayoutPanel(),      "Layout")
    Settings.RegisterCanvasLayoutSubcategory(category, BuildTextPanel(),        "Text")
    Settings.RegisterCanvasLayoutSubcategory(category, BuildColorsPanel(),      "Colors")
    Settings.RegisterCanvasLayoutSubcategory(category, BuildClassColorsPanel(), "Class Colors")

    Settings.RegisterCanvasLayoutSubcategory(category, BuildSpellsPanel(),   "Spells")
    Settings.RegisterCanvasLayoutSubcategory(category, BuildProfilesPanel(), "Profiles")
end
