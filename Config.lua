local _, ns = ...

ns.config = {}

local categoryID

local DEFAULTS = {
    locked = false,
    scale = 1.0,
}

local function EnsureDefaults()
    PartyPulseDB = PartyPulseDB or {}
    for k, v in pairs(DEFAULTS) do
        if PartyPulseDB[k] == nil then PartyPulseDB[k] = v end
    end
end

function ns.config.ApplyAll()
    EnsureDefaults()
    ns.ui.SetLocked(PartyPulseDB.locked)
    ns.ui.SetScale(PartyPulseDB.scale)
end

function ns.config.Open()
    if categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(categoryID)
    end
end

local function RegisterSpellToggles(category, playerClass, playerSpecID)
    if not playerClass then return end
    local spells = ns.GetInterruptsFor(playerClass, playerSpecID)
    if #spells == 0 then return end

    for _, s in ipairs(spells) do
        local key = "spell_" .. s.id
        if PartyPulseDB[key] == nil then PartyPulseDB[key] = true end

        local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(s.id)
        local displayName = (spellInfo and spellInfo.name) or ("Spell " .. s.id)

        local setting = Settings.RegisterAddOnSetting(
            category,
            "PartyPulse_" .. key,
            key,
            PartyPulseDB,
            Settings.VarType.Boolean,
            displayName,
            true
        )
        setting:SetValueChangedCallback(function()
            if ns.RefreshSelf then ns.RefreshSelf() end
        end)
        Settings.CreateCheckbox(category, setting, "Show " .. displayName .. " on your row.")
    end
end

function ns.config.Register()
    EnsureDefaults()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    local category = Settings.RegisterVerticalLayoutCategory("PartyPulse")
    categoryID = category:GetID()

    local lockedSetting = Settings.RegisterAddOnSetting(
        category,
        "PartyPulse_Locked",
        "locked",
        PartyPulseDB,
        Settings.VarType.Boolean,
        "Lock frame",
        DEFAULTS.locked
    )
    lockedSetting:SetValueChangedCallback(function(_, value)
        ns.ui.SetLocked(value)
    end)
    Settings.CreateCheckbox(category, lockedSetting, "Prevents the frame from being dragged.")

    local scaleSetting = Settings.RegisterAddOnSetting(
        category,
        "PartyPulse_Scale",
        "scale",
        PartyPulseDB,
        Settings.VarType.Number,
        "Scale",
        DEFAULTS.scale
    )
    scaleSetting:SetValueChangedCallback(function(_, value)
        ns.ui.SetScale(value)
    end)
    local scaleOptions = Settings.CreateSliderOptions(0.5, 2.0, 0.05)
    scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, scaleSetting, scaleOptions, "Adjust the frame scale.")

    local _, playerClass = UnitClass("player")
    local specIdx = GetSpecialization and GetSpecialization()
    local specID = specIdx and GetSpecializationInfo and GetSpecializationInfo(specIdx) or nil
    RegisterSpellToggles(category, playerClass, specID)

    Settings.RegisterAddOnCategory(category)
end
