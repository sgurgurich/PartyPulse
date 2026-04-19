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

local function RegisterSpellToggles(cat, playerClass, playerSpecID)
    if not playerClass then return end
    local spells = ns.GetInterruptsFor(playerClass, playerSpecID)
    if #spells == 0 then return end

    for _, s in ipairs(spells) do
        local key = "spell_" .. s.id
        if PartyPulseDB[key] == nil then PartyPulseDB[key] = true end

        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(s.id)
        local displayName = (info and info.name) or ("Spell " .. s.id)

        local setting = Settings.RegisterAddOnSetting(
            cat, "PartyPulse_" .. key, key, PartyPulseDB,
            Settings.VarType.Boolean, displayName, true
        )
        setting:SetValueChangedCallback(function()
            if ns.RefreshSelf then ns.RefreshSelf() end
        end)
        Settings.CreateCheckbox(cat, setting, "Show " .. displayName .. " on your row.")
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

    -- Spell toggles
    local _, playerClass = UnitClass("player")
    local specIdx = GetSpecialization and GetSpecialization()
    local specID = specIdx and GetSpecializationInfo and GetSpecializationInfo(specIdx) or nil
    RegisterSpellToggles(category, playerClass, specID)

    Settings.RegisterAddOnCategory(category)

    -- Fine-tune subcategory (canvas layout for custom EditBoxes)
    local fineFrame = BuildFineTunePanel()
    Settings.RegisterCanvasLayoutSubcategory(category, fineFrame, "Fine-tune")
end
