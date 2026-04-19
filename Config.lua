local _, ns = ...

ns.config = {}

local category

local DEFAULTS = {
    shown = true,
    locked = false,
    scale = 1.0,
    displayMode = "icons",
    showBackdrop = false,
    showName = false,
    namePosition = "left",
    nameOffsetX = 0,
    nameOffsetY = 0,
    nameFontSize = 12,
    showSpellName = true,
    spellNameFontSize = 11,
    timeFontSize = 11,
    iconSize = 24,
    barWidth = 140,
    barHeight = 18,
    spellGap = 2,
    rowGap = 4,
    testMode = false,
    barUseClassColor = true,
    barInvert = false,
    showReadyText = true,
    readyText = "Ready",
    cooldownFormat = "%.1f",
    bgColor = { r = 0, g = 0, b = 0, a = 0.5 },
    borderColor = { r = 1, g = 1, b = 1, a = 1 },
    barBgColor = { r = 0, g = 0, b = 0, a = 0.5 },
    barFillColor = { r = 0.6, g = 0.1, b = 0.1, a = 1 },
    barReadyColor = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
    textColor = { r = 1, g = 1, b = 1, a = 1 },
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
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(620, 500)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", PANEL_PAD_X, -PANEL_PAD_Y)
    header:SetText(title)

    f._cursorY = -PANEL_PAD_Y - 28
    f._rows = {}

    function f:NextY(extra)
        local y = self._cursorY
        self._cursorY = self._cursorY - (ROW_H + ROW_GAP) - (extra or 0)
        return y
    end

    function f:AddRow(rowFrame)
        self._rows[#self._rows + 1] = rowFrame
        return rowFrame
    end

    return f
end

local function RefreshAllPanelRows(panel)
    if not panel or not panel._rows then return end
    for _, r in ipairs(panel._rows) do
        if r.Refresh then r:Refresh() end
    end
end

-- ---- Row: label + slider + numeric editbox ------------------------------
local function AddSliderRow(panel, label, varKey, min, max, step, onChange, tooltip)
    local row = CreateFrame("Frame", nil, panel)
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
    local row = CreateFrame("Frame", nil, panel)
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
    local row = CreateFrame("Frame", nil, panel)
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
    local row = CreateFrame("Frame", nil, panel)
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
    local row = CreateFrame("Frame", nil, panel)
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

-- =========================================================================
--  Subcategory panels
-- =========================================================================

local function BuildMainPanel()
    local f = NewPanel("PartyPulse", category)
    AddCheckRow(f, "Test mode", "testMode", function(v) ns.ui.SetTestMode(v) end,
        "Show 4 simulated party members (DK/Mage/Shaman/Druid) with randomized cooldowns every ~2.5s.")
    AddCheckRow(f, "Show frame", "shown", function(v)
        if v then ns.ui.Show() else ns.ui.Hide() end
    end)
    AddCheckRow(f, "Lock frame", "locked", function(v) ns.ui.SetLocked(v) end,
        "Prevents the frame from being dragged.")
    AddCheckRow(f, "Show frame background", "showBackdrop", function(v) ns.ui.SetBackdropShown(v) end)
    AddDropdownRow(f, "Display mode", "displayMode", {
        { "icons", "Icons" }, { "bars", "Bars" }, { "both", "Icons + Bars" },
    }, function() ns.ui.RebuildAll() end)
    return f
end

local function BuildSizingPanel()
    local f = NewPanel("Sizing", category)
    AddSliderRow(f, "Scale",        "scale",      0.5,  2.0, 0.05, function(v) ns.ui.SetScale(v) end)
    AddSliderRow(f, "Icon size",    "iconSize",   8,   64,  1,    function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Bar width",    "barWidth",   40,  320, 1,    function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Bar height",   "barHeight",  4,   40,  1,    function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Spell spacing","spellGap", -40,   20,  1,    function() ns.ui.RebuildAll() end,
        "Spacing between cooldowns within a member's row. Can go negative for tighter or overlapping layouts.")
    AddSliderRow(f, "Row spacing",  "rowGap",    -20,  40,  1,    function() ns.ui.RebuildAll() end,
        "Spacing between party member rows. Can go negative to make bars touch or overlap.")
    f:SetScript("OnShow", function(self) RefreshAllPanelRows(self) end)
    return f
end

local function BuildTextPanel()
    local f = NewPanel("Text", category)
    AddCheckRow(f, "Show player name", "showName", function() ns.ui.RebuildAll() end)
    AddDropdownRow(f, "Player name position", "namePosition", {
        { "left", "Left of cooldowns" }, { "above", "Above cooldowns" },
    }, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Name offset X", "nameOffsetX", -300, 300, 1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Name offset Y", "nameOffsetY", -300, 300, 1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Name font size", "nameFontSize", 6, 32, 1, function() ns.ui.RebuildAll() end)
    AddCheckRow(f, "Show spell name on bars", "showSpellName", function() ns.ui.RebuildAll() end,
        "Toggle whether the spell name is drawn on each bar.")
    AddSliderRow(f, "Spell name font size", "spellNameFontSize", 6, 32, 1, function() ns.ui.RebuildAll() end)
    AddSliderRow(f, "Countdown font size",  "timeFontSize",      6, 32, 1, function() ns.ui.RebuildAll() end)
    AddDropdownRow(f, "Countdown format", "cooldownFormat", {
        { "%.1f",  "5.3"  },
        { "%d",    "5"    },
        { "%.1fs", "5.3s" },
        { "%ds",   "5s"   },
    }, function() ns.ui.RebuildAll() end)
    AddCheckRow(f, "Show \"Ready\" text when off cooldown", "showReadyText", function() ns.ui.RebuildAll() end)
    AddTextInputRow(f, "Ready text", "readyText", function() ns.ui.RebuildAll() end,
        "Shown inside the bar when the spell is off cooldown.")
    f:SetScript("OnShow", function(self) RefreshAllPanelRows(self) end)
    return f
end

local function BuildColorsPanel()
    local f = NewPanel("Colors", category)
    AddColorRow(f, "Backdrop background", "bgColor",     true, function() ns.ui.SetBackdropShown(PartyPulseDB.showBackdrop) end)
    AddColorRow(f, "Backdrop border",     "borderColor", true, function() ns.ui.SetBackdropShown(PartyPulseDB.showBackdrop) end)
    AddColorRow(f, "Bar background",      "barBgColor",  true, function() ns.ui.RebuildAll() end)
    AddCheckRow(f, "Use class color for bars", "barUseClassColor", function() ns.ui.RebuildAll() end,
        "When on, the on-cooldown fill is the owner's class color. When off, uses the override below.")
    AddColorRow(f, "Bar on-cooldown color (override)", "barFillColor", true, function() ns.ui.RebuildAll() end,
        "Used when \"Use class color for bars\" is off.")
    AddColorRow(f, "Bar ready color", "barReadyColor", true, function() ns.ui.RebuildAll() end,
        "Fill color when the spell is off cooldown.")
    AddCheckRow(f, "Invert bar direction", "barInvert", function() ns.ui.RebuildAll() end,
        "When on, bars fill from empty to full as the cooldown progresses instead of draining.")
    AddColorRow(f, "Text color",           "textColor",  true, function() ns.ui.RebuildAll() end,
        "Applies to the spell name and countdown text on bars. Player name keeps the class color.")
    f:SetScript("OnShow", function(self) RefreshAllPanelRows(self) end)
    return f
end

-- =========================================================================
--  Spells subcategory (vertical layout via Settings API)
-- =========================================================================
local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE",
    "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local function ClassDisplayName(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function RegisterSpellToggles(cat)
    local all = ns.AllTrackedSpells()
    if #all == 0 then return end

    local byClass = {}
    for _, s in ipairs(all) do
        local class = s.class or "OTHER"
        byClass[class] = byClass[class] or {}
        table.insert(byClass[class], s)
    end

    local order = {}
    for _, c in ipairs(CLASS_ORDER) do if byClass[c] then order[#order + 1] = c end end
    if byClass.OTHER then order[#order + 1] = "OTHER" end

    for _, class in ipairs(order) do
        for _, s in ipairs(byClass[class]) do
            local key = "spell_" .. s.id
            local defaultOn = not SPELL_DEFAULT_OFF[s.id]
            if PartyPulseDB[key] == nil then PartyPulseDB[key] = defaultOn end

            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(s.id)
            local spellName = (info and info.name) or ("Spell " .. s.id)
            local displayName = string.format("[%s] %s", ClassDisplayName(class), spellName)

            local setting = Settings.RegisterAddOnSetting(
                cat, "PartyPulse_" .. key, key, PartyPulseDB,
                Settings.VarType.Boolean, displayName, defaultOn
            )
            setting:SetValueChangedCallback(function()
                if ns.RefreshAll then ns.RefreshAll() end
            end)
            Settings.CreateCheckbox(cat, setting,
                "Track " .. spellName .. " on your row and on party members.")
        end
    end
end

-- =========================================================================
--  Registration
-- =========================================================================
function ns.config.Register()
    EnsureDefaults()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end

    local mainPanel = BuildMainPanel()
    category = Settings.RegisterCanvasLayoutCategory(mainPanel, "PartyPulse")
    mainPanel:SetScript("OnShow", function(self) RefreshAllPanelRows(self) end)
    Settings.RegisterAddOnCategory(category)

    Settings.RegisterCanvasLayoutSubcategory(category, BuildSizingPanel(), "Sizing")
    Settings.RegisterCanvasLayoutSubcategory(category, BuildTextPanel(),   "Text")
    Settings.RegisterCanvasLayoutSubcategory(category, BuildColorsPanel(), "Colors")

    local spellsCat = Settings.RegisterVerticalLayoutSubcategory(category, "Spells")
    RegisterSpellToggles(spellsCat)
end
