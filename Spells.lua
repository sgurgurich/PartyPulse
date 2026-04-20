local _, ns = ...

-- Class-default tracked spells. Each class has a list; order = display order.
ns.INTERRUPTS = {
    WARRIOR     = { { id = 6552,   cd = 15 } }, -- Pummel
    PALADIN     = { { id = 96231,  cd = 15 } }, -- Rebuke
    HUNTER      = { { id = 147362, cd = 24 } }, -- Counter Shot (MM default)
    ROGUE       = { { id = 1766,   cd = 15 } }, -- Kick
    PRIEST      = { { id = 15487,  cd = 45 } }, -- Silence
    DEATHKNIGHT = { { id = 47528,  cd = 15 }, { id = 49576, cd = 25 } }, -- Mind Freeze + Death Grip
    SHAMAN      = { { id = 57994,  cd = 12 } }, -- Wind Shear
    MAGE        = { { id = 2139,   cd = 24 } }, -- Counterspell
    WARLOCK     = { { id = 19647,  cd = 24 } }, -- Spell Lock (Felhunter)
    MONK        = { { id = 116705, cd = 15 } }, -- Spear Hand Strike
    DRUID       = { { id = 106839, cd = 15 } }, -- Skull Bash
    DEMONHUNTER = { { id = 183752, cd = 15 } }, -- Disrupt
    EVOKER      = { { id = 351338, cd = 40 } }, -- Quell
}

-- Spec overrides keyed by global specialization ID.
-- Set `replace = {...}` to swap the primary interrupt, otherwise entries are appended.
ns.INTERRUPTS_BY_SPEC = {
    [102] = { { id = 78675,  cd = 60 } },                    -- Balance Druid: + Solar Beam
    [253] = { replace = { { id = 187707, cd = 15 } } },      -- Hunter BM: Muzzle
    [255] = { replace = { { id = 187707, cd = 15 } } },      -- Hunter SV: Muzzle
    [264] = { replace = { { id = 57994,  cd = 30 } } },      -- Resto Shaman: Wind Shear 30s
}

function ns.GetInterruptsFor(class, specID)
    local out = {}
    local specEntry = specID and ns.INTERRUPTS_BY_SPEC[specID]
    if specEntry and specEntry.replace then
        for _, s in ipairs(specEntry.replace) do out[#out + 1] = s end
    else
        for _, s in ipairs(ns.INTERRUPTS[class] or {}) do out[#out + 1] = s end
        if specEntry then
            for _, s in ipairs(specEntry) do out[#out + 1] = s end
        end
    end
    return out
end

-- Returns a deduped list of every tracked spell across all classes and spec overrides.
-- Each entry: { id, cd, class }. Used by the settings panel so users can toggle any spell.
function ns.AllTrackedSpells()
    local seen = {}
    local out = {}
    local function add(s, class)
        if seen[s.id] then return end
        seen[s.id] = true
        out[#out + 1] = { id = s.id, cd = s.cd, class = class }
    end
    for class, list in pairs(ns.INTERRUPTS) do
        for _, s in ipairs(list) do add(s, class) end
    end
    for specID, entry in pairs(ns.INTERRUPTS_BY_SPEC) do
        local source = entry.replace or entry
        local class
        if GetSpecializationInfoByID then
            local _, _, _, _, _, classFile = GetSpecializationInfoByID(specID)
            class = classFile
        end
        for _, s in ipairs(source) do add(s, class) end
    end
    return out
end

function ns.GetSpellCD(class, specID, spellID)
    for _, s in ipairs(ns.GetInterruptsFor(class, specID)) do
        if s.id == spellID then return s.cd end
    end
    return nil
end
