-- AtonementBorder
-- Displays colored borders on unit frames based on Atonement buff duration

local addonName, AB = ...

-- Local references for performance
local GetTime = GetTime
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local pairs = pairs
local type = type

-- Frame pool for borders
AB.borders = {}
AB.framePool = {}

-- Main event frame
local eventFrame = CreateFrame("Frame")

--------------------------------------------------------------------------------
-- Border Creation and Management
--------------------------------------------------------------------------------

-- Create a border frame for a unit frame
function AB:CreateBorder(unitFrame)
    if not unitFrame then return nil end

    local border = CreateFrame("Frame", nil, unitFrame, "BackdropTemplate")
    border:SetFrameStrata("HIGH")
    border:SetAllPoints(unitFrame)

    -- Create border textures (4 sides)
    local borderSize = self:GetConfig("borderSize")

    border.textures = {}

    -- Top border
    border.textures.top = border:CreateTexture(nil, "OVERLAY")
    border.textures.top:SetColorTexture(1, 1, 1, 1)
    border.textures.top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.textures.top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    border.textures.top:SetHeight(borderSize)

    -- Bottom border
    border.textures.bottom = border:CreateTexture(nil, "OVERLAY")
    border.textures.bottom:SetColorTexture(1, 1, 1, 1)
    border.textures.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    border.textures.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    border.textures.bottom:SetHeight(borderSize)

    -- Left border
    border.textures.left = border:CreateTexture(nil, "OVERLAY")
    border.textures.left:SetColorTexture(1, 1, 1, 1)
    border.textures.left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.textures.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    border.textures.left:SetWidth(borderSize)

    -- Right border
    border.textures.right = border:CreateTexture(nil, "OVERLAY")
    border.textures.right:SetColorTexture(1, 1, 1, 1)
    border.textures.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    border.textures.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    border.textures.right:SetWidth(borderSize)

    -- Create pulse animation group
    border.pulseAnim = border:CreateAnimationGroup()
    border.pulseAnim:SetLooping("BOUNCE")

    local fadeOut = border.pulseAnim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.3)
    fadeOut:SetDuration(self:GetConfig("pulseSpeed"))
    fadeOut:SetSmoothing("IN_OUT")

    -- Store reference
    border.unitFrame = unitFrame
    border:Hide()

    return border
end

-- Set border color
function AB:SetBorderColor(border, r, g, b, a)
    if not border or not border.textures then return end

    for _, texture in pairs(border.textures) do
        texture:SetVertexColor(r, g, b, a)
    end
end

-- Update border visibility and color based on Atonement status
function AB:UpdateBorder(border, unit)
    if not border or not unit or not UnitExists(unit) then
        if border then border:Hide() end
        return
    end

    local atonementInfo = self:GetAtonementInfo(unit)

    if not atonementInfo then
        border:Hide()
        return
    end

    -- Calculate remaining duration
    local remaining = atonementInfo.expirationTime - GetTime()

    if remaining <= 0 then
        border:Hide()
        return
    end

    -- Determine color based on duration thresholds
    local color
    local highThreshold = self:GetConfig("highThreshold")
    local lowThreshold = self:GetConfig("lowThreshold")
    local colors = self:GetConfig("colors")

    if remaining > highThreshold then
        color = colors.high
    elseif remaining > lowThreshold then
        color = colors.medium
    else
        color = colors.low
    end

    self:SetBorderColor(border, color.r, color.g, color.b, color.a)
    border:Show()

    -- Handle pulse animation for low duration
    if self:GetConfig("enablePulse") and remaining <= self:GetConfig("pulseThreshold") then
        if not border.pulseAnim:IsPlaying() then
            border.pulseAnim:Play()
        end
    else
        if border.pulseAnim:IsPlaying() then
            border.pulseAnim:Stop()
            border:SetAlpha(1)
        end
    end
end

--------------------------------------------------------------------------------
-- Atonement Detection
--------------------------------------------------------------------------------

-- Get Atonement buff info for a unit
function AB:GetAtonementInfo(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    -- Try using C_UnitAuras API (modern API)
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local auraData = C_UnitAuras.GetAuraDataBySpellName(unit, self.ATONEMENT_SPELL_NAME, "HELPFUL")
        if auraData then
            return auraData
        end
    end

    -- Fallback: Use AuraUtil if available
    if AuraUtil and AuraUtil.FindAuraByName then
        local name, icon, count, dispelType, duration, expirationTime, source, isStealable,
              nameplateShowPersonal, spellId = AuraUtil.FindAuraByName(self.ATONEMENT_SPELL_NAME, unit, "HELPFUL")

        if name then
            return {
                name = name,
                icon = icon,
                count = count,
                dispelType = dispelType,
                duration = duration,
                expirationTime = expirationTime,
                source = source,
                spellId = spellId,
            }
        end
    end

    -- Fallback: Manual iteration (for older API compatibility)
    for i = 1, 40 do
        local name, icon, count, dispelType, duration, expirationTime, source, isStealable,
              nameplateShowPersonal, spellId

        if UnitAura then
            name, icon, count, dispelType, duration, expirationTime, source, isStealable,
            nameplateShowPersonal, spellId = UnitAura(unit, i, "HELPFUL")
        elseif UnitBuff then
            name, icon, count, dispelType, duration, expirationTime, source, isStealable,
            nameplateShowPersonal, spellId = UnitBuff(unit, i)
        end

        if not name then break end

        if spellId == self.ATONEMENT_SPELL_ID or name == self.ATONEMENT_SPELL_NAME then
            return {
                name = name,
                icon = icon,
                count = count,
                dispelType = dispelType,
                duration = duration,
                expirationTime = expirationTime,
                source = source,
                spellId = spellId,
            }
        end
    end

    -- Midnight API: Try using GetAuraDurationRemainingPercent for secret values
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not auraData then break end

            if auraData.spellId == self.ATONEMENT_SPELL_ID then
                -- If duration is a secret, try to use percentage-based API
                if auraData.duration and auraData.expirationTime then
                    return auraData
                elseif C_UnitAuras.GetAuraDurationRemainingPercent then
                    local percent = C_UnitAuras.GetAuraDurationRemainingPercent(unit, auraData.auraInstanceID)
                    if percent then
                        -- Estimate duration based on percentage (Atonement base duration is 15s)
                        local baseDuration = 15
                        local estimatedRemaining = baseDuration * percent
                        auraData.expirationTime = GetTime() + estimatedRemaining
                        auraData.duration = baseDuration
                        return auraData
                    end
                end
            end
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Blizzard CompactUnitFrame Integration
--------------------------------------------------------------------------------

-- Hook into Blizzard's CompactUnitFrame system
function AB:HookBlizzardFrames()
    if not self:GetConfig("supportBlizzardFrames") then return end

    -- Hook CompactUnitFrame_UpdateAuras
    if CompactUnitFrame_UpdateAuras then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            self:OnFrameUpdate(frame)
        end)
        self:Debug("Hooked CompactUnitFrame_UpdateAuras")
    end

    -- Hook CompactUnitFrame_UpdateAll for initial setup
    if CompactUnitFrame_UpdateAll then
        hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
            self:OnFrameUpdate(frame)
        end)
        self:Debug("Hooked CompactUnitFrame_UpdateAll")
    end

    -- Hook the frame setup function
    if CompactUnitFrame_SetUnit then
        hooksecurefunc("CompactUnitFrame_SetUnit", function(frame, unit)
            if unit then
                self:OnFrameUpdate(frame)
            else
                -- Unit cleared, hide border
                local border = self.borders[frame]
                if border then
                    border:Hide()
                end
            end
        end)
        self:Debug("Hooked CompactUnitFrame_SetUnit")
    end
end

--------------------------------------------------------------------------------
-- Third-Party Unit Frame Discovery
--------------------------------------------------------------------------------

-- Tracked third-party frames (by frame reference)
AB.trackedFrames = {}

-- Check if a unit is player, party, or raid unit
function AB:IsValidUnit(unit)
    if not unit then return false end
    -- Match player, party1-4, or raid1-40
    if unit == "player" then return true end
    return unit:match("^party%d+$") or unit:match("^raid%d+$")
end

-- Check if a frame looks like a main unit frame (not a buff icon or sub-component)
function AB:IsMainUnitFrame(frame)
    if not frame then return false end

    local width = frame:GetWidth()
    local height = frame:GetHeight()

    -- Main unit frames are typically at least 40x20 pixels
    -- Buff/debuff icons are usually smaller (20x20 or so)
    if width < 40 or height < 20 then
        return false
    end

    local name = frame:GetName() or ""

    -- Skip Blizzard default unit frames
    if name == "PlayerFrame" or name == "TargetFrame" or name == "FocusFrame"
       or name == "PetFrame" or name:match("^Boss%d") or name:match("^Arena") then
        return false
    end

    -- Skip frames that are clearly buff/debuff containers
    if name:match("Buff") or name:match("Debuff") or name:match("Aura") then
        return false
    end

    return true
end

-- Scan for unit frames by checking all frames with a "unit" attribute
function AB:ScanForUnitFrames()
    local found = 0

    -- EnumerateFrames iterates all frames in the UI
    local frame = EnumerateFrames()
    while frame do
        if frame:IsVisible() and not self.trackedFrames[frame] then
            local unit = frame.unit or (frame.GetUnit and frame:GetUnit())
            -- Only track valid units that look like main unit frames
            if unit and UnitExists(unit) and self:IsValidUnit(unit) and self:IsMainUnitFrame(frame) then
                -- This frame has a unit - track it
                self.trackedFrames[frame] = true
                self:Debug("Discovered frame:", frame:GetName() or "unnamed", "unit:", unit, "size:", frame:GetWidth(), "x", frame:GetHeight())
                found = found + 1

                -- Create border if we don't have one
                if not self.borders[frame] then
                    local border = self:CreateBorder(frame)
                    self.borders[frame] = border
                end
            end
        end
        frame = EnumerateFrames(frame)
    end

    return found
end

-- Scan for frames matching a specific name pattern
function AB:ScanFramesByPattern(pattern)
    local found = 0

    local frame = EnumerateFrames()
    while frame do
        local name = frame:GetName()
        if name and name:match(pattern) and frame:IsVisible() then
            local unit = frame.unit or (frame.GetUnit and frame:GetUnit())
            -- Only track valid units that look like main unit frames
            if unit and UnitExists(unit) and self:IsValidUnit(unit) and self:IsMainUnitFrame(frame) and not self.trackedFrames[frame] then
                self.trackedFrames[frame] = true
                self:Debug("Pattern match:", name, "unit:", unit)
                found = found + 1

                if not self.borders[frame] then
                    local border = self:CreateBorder(frame)
                    self.borders[frame] = border
                end
            end
        end
        frame = EnumerateFrames(frame)
    end

    return found
end

-- Update all tracked third-party frames
function AB:UpdateTrackedFrames()
    for frame in pairs(self.trackedFrames) do
        if frame and frame:IsVisible() then
            local unit = frame.unit or (frame.GetUnit and frame:GetUnit())
            if unit and UnitExists(unit) then
                local border = self.borders[frame]
                if border then
                    self:UpdateBorder(border, unit)
                end
            end
        else
            -- Frame no longer valid/visible, clean up
            local border = self.borders[frame]
            if border then
                border:Hide()
            end
        end
    end
end

-- Auto-scan timer for discovering new frames
local scanElapsed = 0
local SCAN_INTERVAL = 2.0  -- Scan every 2 seconds for new frames

function AB:SetupAutoScan()
    local scanFrame = CreateFrame("Frame")
    scanFrame:SetScript("OnUpdate", function(_, elapsed)
        scanElapsed = scanElapsed + elapsed
        if scanElapsed >= SCAN_INTERVAL then
            scanElapsed = 0
            AB:ScanForUnitFrames()
        end
    end)
    self:Debug("Auto-scan enabled")
end

-- Handle frame update
function AB:OnFrameUpdate(frame)
    if not frame or not frame.unit then return end
    -- Only track party/raid units
    if not self:IsValidUnit(frame.unit) then return end

    if not self:GetConfig("enabled") then
        local border = self.borders[frame]
        if border then border:Hide() end
        return
    end

    -- Get or create border for this frame
    local border = self.borders[frame]
    if not border then
        border = self:CreateBorder(frame)
        self.borders[frame] = border
    end

    -- Update the border
    self:UpdateBorder(border, frame.unit)
end

-- Update all tracked frames (Blizzard + third-party)
function AB:UpdateAllFrames()
    -- Update Blizzard frames
    for frame, border in pairs(self.borders) do
        if frame then
            local unit = frame.unit or (frame.GetUnit and frame:GetUnit())
            if unit then
                self:UpdateBorder(border, unit)
            end
        end
    end

    -- Update third-party tracked frames
    self:UpdateTrackedFrames()
end

--------------------------------------------------------------------------------
-- Update Timer
--------------------------------------------------------------------------------

local updateElapsed = 0
local UPDATE_INTERVAL = 0.1  -- Update every 100ms

local function OnUpdate(self, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed >= UPDATE_INTERVAL then
        updateElapsed = 0
        AB:UpdateAllFrames()
    end
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

function AB:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            self:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        self:HookBlizzardFrames()
        self:SetupAutoScan()
        -- Initial scan after a short delay to let other addons load their frames
        C_Timer.After(1, function()
            local found = self:ScanForUnitFrames()
            self:Debug("Initial scan found", found, "frames")
        end)
        self:Print("Loaded. Type /ab for options.")
    elseif event == "UNIT_AURA" then
        local unit = ...
        -- Find frames showing this unit and update them
        for frame, border in pairs(self.borders) do
            if frame and frame.unit == unit then
                self:UpdateBorder(border, unit)
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Delay update to allow frames to update first
        C_Timer.After(0.1, function()
            self:UpdateAllFrames()
        end)
    end
end

function AB:Initialize()
    self:InitializeDB()
    self:Debug("Initialized with saved variables")

    -- Register additional events
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    -- Set up update timer
    eventFrame:SetScript("OnUpdate", OnUpdate)
end

-- Register initial event
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    AB:OnEvent(event, ...)
end)

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------

SLASH_ATONEMENTBORDER1 = "/atonementborder"
SLASH_ATONEMENTBORDER2 = "/ab"

SlashCmdList["ATONEMENTBORDER"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()

    if cmd == "enable" or cmd == "on" then
        AB:SetConfig("enabled", true)
        AB:Print("Enabled")
        AB:UpdateAllFrames()
    elseif cmd == "disable" or cmd == "off" then
        AB:SetConfig("enabled", false)
        AB:Print("Disabled")
        AB:UpdateAllFrames()
    elseif cmd == "toggle" then
        local enabled = not AB:GetConfig("enabled")
        AB:SetConfig("enabled", enabled)
        AB:Print(enabled and "Enabled" or "Disabled")
        AB:UpdateAllFrames()
    elseif cmd == "debug" then
        local debug = not AB:GetConfig("debug")
        AB:SetConfig("debug", debug)
        AB:Print("Debug mode:", debug and "ON" or "OFF")
    elseif cmd == "pulse" then
        local pulse = not AB:GetConfig("enablePulse")
        AB:SetConfig("enablePulse", pulse)
        AB:Print("Pulse animation:", pulse and "ON" or "OFF")
    elseif cmd == "threshold" then
        local value = tonumber(arg)
        if value and value > 0 then
            AB:SetConfig("highThreshold", value)
            AB:Print("High threshold set to", value, "seconds")
        else
            AB:Print("Usage: /ab threshold <seconds>")
        end
    elseif cmd == "lowthreshold" then
        local value = tonumber(arg)
        if value and value > 0 then
            AB:SetConfig("lowThreshold", value)
            AB:Print("Low threshold set to", value, "seconds")
        else
            AB:Print("Usage: /ab lowthreshold <seconds>")
        end
    elseif cmd == "bordersize" then
        local value = tonumber(arg)
        if value and value > 0 and value <= 10 then
            AB:SetConfig("borderSize", value)
            AB:Print("Border size set to", value, "- reload UI to apply")
        else
            AB:Print("Usage: /ab bordersize <1-10>")
        end
    elseif cmd == "test" then
        AB:Print("Testing Atonement detection on target...")
        local info = AB:GetAtonementInfo("target")
        if info then
            local remaining = info.expirationTime - GetTime()
            AB:Print("Found Atonement! Duration remaining:", string.format("%.1f", remaining), "seconds")
        else
            AB:Print("No Atonement found on target")
        end
    elseif cmd == "scan" then
        AB:Print("Scanning for unit frames...")
        local found = AB:ScanForUnitFrames()
        AB:Print("Found", found, "new unit frames. Total tracked:", AB:CountBorders())
    elseif cmd == "status" then
        AB:Print("Status:")
        AB:Print("  Enabled:", AB:GetConfig("enabled") and "Yes" or "No")
        AB:Print("  High threshold:", AB:GetConfig("highThreshold"), "seconds (green)")
        AB:Print("  Low threshold:", AB:GetConfig("lowThreshold"), "seconds (red)")
        AB:Print("  Pulse enabled:", AB:GetConfig("enablePulse") and "Yes" or "No")
        AB:Print("  Border size:", AB:GetConfig("borderSize"))
        AB:Print("  Tracked frames:", AB:CountBorders())
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        AB:OpenOptions()
    else
        AB:Print("Commands:")
        AB:Print("  /ab options - Open settings panel")
        AB:Print("  /ab enable|disable|toggle - Enable/disable the addon")
        AB:Print("  /ab threshold <sec> - Set high threshold (green)")
        AB:Print("  /ab lowthreshold <sec> - Set low threshold (red)")
        AB:Print("  /ab bordersize <1-10> - Set border thickness")
        AB:Print("  /ab pulse - Toggle pulse animation")
        AB:Print("  /ab test - Test detection on target")
        AB:Print("  /ab scan - Scan for unit frames (third-party addons)")
        AB:Print("  /ab status - Show current settings")
        AB:Print("  /ab debug - Toggle debug mode")
    end
end

-- Helper to count active borders
function AB:CountBorders()
    local count = 0
    for _ in pairs(self.borders) do
        count = count + 1
    end
    return count
end
