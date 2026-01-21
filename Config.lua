-- AtonementBorder Configuration
-- Default settings and configuration options

local addonName, AB = ...

-- Default configuration values
AB.defaults = {
    enabled = true,
    borderSize = 2,

    -- Duration thresholds (in seconds)
    highThreshold = 5,      -- Above this = green
    lowThreshold = 2,       -- Below this = red (between low and high = yellow)

    -- Colors (RGBA)
    colors = {
        high = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },      -- Green
        medium = { r = 1.0, g = 1.0, b = 0.0, a = 1.0 },    -- Yellow
        low = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },       -- Red
        none = { r = 0.0, g = 0.0, b = 0.0, a = 0.0 },      -- Transparent (no buff)
    },

    -- Animation settings
    enablePulse = true,
    pulseThreshold = 3,     -- Start pulsing when below this duration
    pulseSpeed = 0.5,       -- Pulse cycle duration in seconds

    -- Frame support
    supportBlizzardFrames = true,

    -- Debug mode
    debug = false,
}

-- Atonement spell information
AB.ATONEMENT_SPELL_ID = 194384
AB.ATONEMENT_SPELL_NAME = "Atonement"

-- Initialize saved variables
function AB:InitializeDB()
    if not AtonementBorderDB then
        AtonementBorderDB = {}
    end

    -- Merge defaults with saved settings
    for key, value in pairs(self.defaults) do
        if AtonementBorderDB[key] == nil then
            if type(value) == "table" then
                AtonementBorderDB[key] = CopyTable(value)
            else
                AtonementBorderDB[key] = value
            end
        end
    end

    self.db = AtonementBorderDB
end

-- Get a config value
function AB:GetConfig(key)
    return self.db and self.db[key] or self.defaults[key]
end

-- Set a config value
function AB:SetConfig(key, value)
    if self.db then
        self.db[key] = value
    end
end

-- Debug print helper
function AB:Debug(...)
    if self:GetConfig("debug") then
        print("|cFF00FF00[AtonementBorder]|r", ...)
    end
end

-- Print helper
function AB:Print(...)
    print("|cFF00FF00[AtonementBorder]|r", ...)
end
