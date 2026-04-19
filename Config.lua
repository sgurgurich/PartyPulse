local _, ns = ...

ns.config = {}

local category

local DEFAULTS = {
    shown = true,
    locked = false,
    scale = 1.0,
    displayMode = "icons",
}

local SCALE_MIN, SCALE_MAX = 0.5, 2.0

local function EnsureDefaults()
    PartyPulseDB = PartyPulseDB or {}
    for k, v in pairs(DEFAULTS) do
        if PartyPulseDB[k] == nil then PartyPulseDB[k] = v end
    end
end

function ns.config.ApplyAll()
    EnsureDefaults()
    if PartyPulseDB.shown then ns.ui.Show() else ns.ui.Hide() end
    ns.ui.SetLocked(PartyPulseDB.locked)
    ns.ui.SetScale(PartyPulseDB.scale)
end

function ns.config.Open()
    if not category then return end
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(category)
    end
end

-- ---- Fine-tune subcategory (canvas) with numeric EditBoxes ----------------

local function BuildFineTunePanel()
    local f = CreateFrame("Frame", "PartyPulseFineTunePanel", UIParent)
    f:SetSize(600, 400)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Fine-tune")

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetText("Type exact values. Press Enter to apply.")

    -- Scale EditBox
    local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    scaleLabel:SetText(string.format("Scale (%.2f to %.2f):", SCALE_MIN, SCALE_MAX))

    local scaleEdit = CreateFrame("EditBox", "PartyPulseScaleEdit", f, "InputBoxTemplate")
    scaleEdit:SetSize(80, 22)
    scaleEdit:SetPoint("LEFT", scaleLabel, "RIGHT", 20, 0)
    scaleEdit:SetAutoFocus(false)

    local function ReadScale()
        scaleEdit:SetText(string.format("%.2f", PartyPulseDB.scale or 1.0))
    end

    scaleEdit:SetScript("OnShow", ReadScale)
    scaleEdit:SetScript("OnEditFocusLost", ReadScale)
    scaleEdit:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            v = math.max(SCALE_MIN, math.min(SCALE_MAX, v))
            PartyPulseDB.scale = v
            ns.ui.SetScale(v)
        end
        self:ClearFocus()
        ReadScale()
    end)

    return f
end

-- ---- Spell toggles --------------------------------------------------------

local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE",
    "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local function ClassDisplayName(class)
    local info = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]
    return info or class
end

local function RegisterSpellToggles(cat)
    local all = ns.AllTrackedSpells()
    if #all == 0 then return end

    -- Group by owning class (spec-only spells fall under their class via INTERRUPTS lookup).
    local byClass = {}
    local function classOf(spellID)
        for class, list in pairs(ns.INTERRUPTS) do
            for _, s in ipairs(list) do
                if s.id == spellID then return class end
            end
        end
        for _, entry in pairs(ns.INTERRUPTS_BY_SPEC) do
            local source = entry.replace or entry
            for _, s in ipairs(source) do
                if s.id == spellID then
                    -- Spec-only spell: attribute via class default if any spell in the entry matches a class list,
                    -- otherwise bucket under "OTHER".
                    return nil
                end
            end
        end
    end
    for _, s in ipairs(all) do
        local class = s.class or classOf(s.id) or "OTHER"
        byClass[class] = byClass[class] or {}
        table.insert(byClass[class], s)
    end

    local order = {}
    for _, c in ipairs(CLASS_ORDER) do if byClass[c] then order[#order + 1] = c end end
    if byClass.OTHER then order[#order + 1] = "OTHER" end

    for _, class in ipairs(order) do
        for _, s in ipairs(byClass[class]) do
            local key = "spell_" .. s.id
            if PartyPulseDB[key] == nil then PartyPulseDB[key] = true end

            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(s.id)
            local spellName = (info and info.name) or ("Spell " .. s.id)
            local displayName = string.format("[%s] %s", ClassDisplayName(class), spellName)

            local setting = Settings.RegisterAddOnSetting(
                cat, "PartyPulse_" .. key, key, PartyPulseDB,
                Settings.VarType.Boolean, displayName, true
            )
            setting:SetValueChangedCallback(function()
                if ns.RefreshAll then ns.RefreshAll() end
            end)
            Settings.CreateCheckbox(cat, setting,
                "Track " .. spellName .. " on your row and on party members.")
        end
    end
end

-- ---- Main panel -----------------------------------------------------------

function ns.config.Register()
    EnsureDefaults()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    category = Settings.RegisterVerticalLayoutCategory("PartyPulse")

    -- Show frame
    local shownSetting = Settings.RegisterAddOnSetting(
        category, "PartyPulse_Shown", "shown", PartyPulseDB,
        Settings.VarType.Boolean, "Show frame", DEFAULTS.shown
    )
    shownSetting:SetValueChangedCallback(function(_, value)
        if value then ns.ui.Show() else ns.ui.Hide() end
    end)
    Settings.CreateCheckbox(category, shownSetting, "Show or hide the PartyPulse frame.")

    -- Lock
    local lockedSetting = Settings.RegisterAddOnSetting(
        category, "PartyPulse_Locked", "locked", PartyPulseDB,
        Settings.VarType.Boolean, "Lock frame", DEFAULTS.locked
    )
    lockedSetting:SetValueChangedCallback(function(_, value) ns.ui.SetLocked(value) end)
    Settings.CreateCheckbox(category, lockedSetting, "Prevents the frame from being dragged.")

    -- Display mode dropdown
    local displaySetting = Settings.RegisterAddOnSetting(
        category, "PartyPulse_DisplayMode", "displayMode", PartyPulseDB,
        Settings.VarType.String, "Display mode", DEFAULTS.displayMode
    )
    displaySetting:SetValueChangedCallback(function() ns.ui.RebuildAll() end)
    local function GetDisplayOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("icons", "Icons")
        container:Add("bars",  "Bars")
        container:Add("both",  "Icons + Bars")
        return container:GetData()
    end
    Settings.CreateDropdown(category, displaySetting, GetDisplayOptions,
        "Show cooldowns as icon sweeps or horizontal bars.")

    -- Scale slider
    local scaleSetting = Settings.RegisterAddOnSetting(
        category, "PartyPulse_Scale", "scale", PartyPulseDB,
        Settings.VarType.Number, "Scale", DEFAULTS.scale
    )
    scaleSetting:SetValueChangedCallback(function(_, value) ns.ui.SetScale(value) end)
    local scaleOptions = Settings.CreateSliderOptions(SCALE_MIN, SCALE_MAX, 0.05)
    scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, scaleSetting, scaleOptions,
        "Adjust the frame scale. For an exact value, use the Fine-tune subcategory.")

    -- Spell toggles (every tracked spell across all classes/specs)
    RegisterSpellToggles(category)

    Settings.RegisterAddOnCategory(category)

    -- Fine-tune subcategory (canvas layout for custom EditBoxes)
    local fineFrame = BuildFineTunePanel()
    Settings.RegisterCanvasLayoutSubcategory(category, fineFrame, "Fine-tune")
end
