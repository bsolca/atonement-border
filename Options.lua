-- AtonementBorder Options Panel
-- Interface > AddOns > AtonementBorder

local addonName, AB = ...

-- Local references for performance
local CreateFrame = CreateFrame
local Settings = Settings

--------------------------------------------------------------------------------
-- Color Picker Helper (polling approach - bypasses flaky callback system)
--------------------------------------------------------------------------------

local pickerState = nil
local pollFrame = CreateFrame("Frame")
pollFrame:Hide()

local function GetPickerRGBA()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local a = 1
    if ColorPickerFrame.GetColorAlpha then
        a = ColorPickerFrame:GetColorAlpha()
    elseif OpacitySliderFrame then
        a = 1 - (OpacitySliderFrame:GetValue() or 0)
    end
    return r, g, b, a
end

local function UpdateFromPicker()
    if not pickerState then return end

    local r, g, b, a = GetPickerRGBA()

    -- Only update if color changed
    local last = pickerState.lastColor
    if last and last.r == r and last.g == g and last.b == b and last.a == a then
        return
    end
    pickerState.lastColor = { r = r, g = g, b = b, a = a }

    -- Update config and save
    local colors = AB:GetConfig("colors")
    if colors then
        colors[pickerState.key] = { r = r, g = g, b = b, a = a }
        AB:SetConfig("colors", colors)
    end

    -- Update swatch
    if pickerState.swatch and pickerState.swatch.colorTex then
        pickerState.swatch.colorTex:SetColorTexture(r, g, b, a)
    end
end

pollFrame:SetScript("OnUpdate", function(self)
    if not ColorPickerFrame:IsShown() then
        UpdateFromPicker()  -- Capture final color before clearing state
        self:Hide()
        pickerState = nil
        AB:UpdateAllFrames()
        if AB.optionsPanelFrame and AB.optionsPanelFrame:IsShown() then
            AB.optionsPanelFrame:RefreshFromConfig()
        end
        return
    end
    UpdateFromPicker()
end)

local function OnCancel()
    if not pickerState then return end

    local orig = pickerState.original
    local colors = AB:GetConfig("colors")
    if colors then
        colors[pickerState.key] = { r = orig.r, g = orig.g, b = orig.b, a = orig.a }
    end

    if pickerState.swatch and pickerState.swatch.colorTex then
        pickerState.swatch.colorTex:SetColorTexture(orig.r, orig.g, orig.b, orig.a)
    end

    AB:UpdateAllFrames()
end

local function OpenColorPicker(colorKey, swatchRef, currentColor)
    local r, g, b, a = currentColor.r, currentColor.g, currentColor.b, currentColor.a or 1

    -- Single source of truth
    pickerState = {
        key = colorKey,
        swatch = swatchRef,
        original = { r = r, g = g, b = b, a = a }
    }

    -- Open picker (noop callbacks - we poll instead)
    local noop = function() end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = true,
            opacity = 1 - a,
            swatchFunc = noop,
            opacityFunc = noop,
            cancelFunc = OnCancel,
        })
    else
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.cancelFunc = OnCancel
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end

    -- Start polling on next frame (avoid stale initial values)
    C_Timer.After(0, function()
        if pickerState then
            pollFrame:Show()
        end
    end)
end

--------------------------------------------------------------------------------
-- Widget Factory Functions
--------------------------------------------------------------------------------

local function CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    header:SetText(text)
    return header
end

local function CreateCheckbox(parent, label, tooltip, configKey, yOffset)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    checkbox.Text:SetText(label)
    checkbox.configKey = configKey

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        AB:SetConfig(configKey, checked)
        AB:UpdateAllFrames()
    end)

    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)

    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return checkbox
end

local function CreateSlider(parent, label, tooltip, configKey, minVal, maxVal, step, yOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(250, 50)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)

    local sliderLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sliderLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    sliderLabel:SetText(label)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -4)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.configKey = configKey

    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))

    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    slider.valueText = valueText

    -- Throttle updates to avoid excessive SetConfig calls during drag
    local lastUpdate = 0
    local UPDATE_THROTTLE = 0.1

    slider:SetScript("OnValueChanged", function(self, value)
        local now = GetTime()
        local displayValue
        if step >= 1 then
            displayValue = string.format("%d", value)
        else
            displayValue = string.format("%.1f", value)
        end
        valueText:SetText(displayValue)

        -- Throttle actual config updates
        if now - lastUpdate >= UPDATE_THROTTLE then
            lastUpdate = now
            AB:SetConfig(configKey, value)
            AB:UpdateAllFrames()
        end
    end)

    -- Always save on mouse up
    slider:SetScript("OnMouseUp", function(self)
        local value = self:GetValue()
        AB:SetConfig(configKey, value)
        AB:UpdateAllFrames()
    end)

    slider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)

    slider:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    container.slider = slider
    return container
end

local function CreateColorSwatch(parent, label, tooltip, colorKey, defaultColor, xOffset, yOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(70, 50)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

    local swatch = CreateFrame("Button", nil, container)
    swatch:SetSize(26, 26)
    swatch:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

    -- Border (black outline)
    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    -- Checkerboard background for alpha visibility (slightly inset)
    local checkerBg = swatch:CreateTexture(nil, "BORDER")
    checkerBg:SetPoint("TOPLEFT", 2, -2)
    checkerBg:SetPoint("BOTTOMRIGHT", -2, 2)
    checkerBg:SetColorTexture(0.4, 0.4, 0.4, 1)

    -- Color texture - INITIALIZE WITH DEFAULT COLOR IMMEDIATELY
    local colorTex = swatch:CreateTexture(nil, "ARTWORK")
    colorTex:SetPoint("TOPLEFT", 2, -2)
    colorTex:SetPoint("BOTTOMRIGHT", -2, 2)
    colorTex:SetColorTexture(defaultColor.r, defaultColor.g, defaultColor.b, defaultColor.a or 1)
    colorTex:Show()

    -- Highlight on hover
    local highlight = swatch:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.2)

    -- Label
    local swatchLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    swatchLabel:SetPoint("TOP", swatch, "BOTTOM", 0, -4)
    swatchLabel:SetText(label)

    -- Store references on both container and swatch for compatibility
    swatch.colorTex = colorTex
    container.swatch = swatch
    container.colorKey = colorKey
    container.defaultColor = defaultColor

    -- Public method to set color (use swatch.colorTex for direct access)
    function container:SetColor(color)
        if color and self.swatch and self.swatch.colorTex then
            self.swatch.colorTex:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        end
    end

    -- Get current color from config or default
    function container:GetColor()
        local colors = AB:GetConfig("colors")
        return colors and colors[self.colorKey] or self.defaultColor
    end

    swatch:SetScript("OnClick", function()
        local color = container:GetColor()
        OpenColorPicker(colorKey, swatch, color)
    end)

    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label .. " Color", 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)

    swatch:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return container
end

--------------------------------------------------------------------------------
-- Options Panel Creation
--------------------------------------------------------------------------------

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Atonement Border"

    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 10)

    -- Create scroll child (content frame)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(550, 600)  -- Height will contain all controls
    scrollFrame:SetScrollChild(content)

    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = current - (delta * 40)  -- 40 pixels per scroll tick
        newScroll = math.max(0, math.min(newScroll, maxScroll))
        self:SetVerticalScroll(newScroll)
    end)

    -- Title (on content frame)
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Atonement Border")

    local subtitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Displays colored borders based on Atonement buff duration")

    -- Store references to controls for refresh
    panel.controls = {}

    -- General Settings Section
    local yPos = -60
    CreateSectionHeader(content, "General Settings", yPos)
    yPos = yPos - 25

    panel.controls.enabled = CreateCheckbox(content, "Enable Addon", "Enable or disable the entire addon", "enabled", yPos)
    yPos = yPos - 28

    panel.controls.supportBlizzardFrames = CreateCheckbox(content, "Support Blizzard Frames", "Hook into Blizzard's default raid/party frames", "supportBlizzardFrames", yPos)
    yPos = yPos - 28

    panel.controls.debug = CreateCheckbox(content, "Debug Mode", "Show debug messages in chat (useful for troubleshooting)", "debug", yPos)
    yPos = yPos - 40

    -- Border Settings Section
    CreateSectionHeader(content, "Border Settings", yPos)
    yPos = yPos - 30

    panel.controls.borderSize = CreateSlider(content, "Border Thickness", "Thickness of the border in pixels (requires UI reload)", "borderSize", 1, 10, 1, yPos)
    yPos = yPos - 60

    -- Duration Thresholds Section
    CreateSectionHeader(content, "Duration Thresholds", yPos)
    yPos = yPos - 30

    panel.controls.highThreshold = CreateSlider(content, "Green Threshold (seconds)", "Atonement above this duration shows green border", "highThreshold", 0.5, 15, 0.5, yPos)
    yPos = yPos - 60

    panel.controls.lowThreshold = CreateSlider(content, "Red Threshold (seconds)", "Atonement below this duration shows red border", "lowThreshold", 0.5, 15, 0.5, yPos)
    yPos = yPos - 60

    -- Animation Section
    CreateSectionHeader(content, "Animation", yPos)
    yPos = yPos - 25

    panel.controls.enablePulse = CreateCheckbox(content, "Enable Pulse Animation", "Pulse the border when Atonement is about to expire", "enablePulse", yPos)
    yPos = yPos - 35

    panel.controls.pulseThreshold = CreateSlider(content, "Pulse Threshold (seconds)", "Start pulsing when Atonement falls below this duration", "pulseThreshold", 0.5, 15, 0.5, yPos)
    yPos = yPos - 60

    panel.controls.pulseSpeed = CreateSlider(content, "Pulse Speed (seconds)", "Duration of one pulse cycle", "pulseSpeed", 0.1, 2.0, 0.1, yPos)
    yPos = yPos - 60

    -- Border Colors Section
    CreateSectionHeader(content, "Border Colors", yPos)
    yPos = yPos - 30

    -- Pass default colors for immediate initialization (before DB is loaded)
    local defaultColors = AB.defaults.colors
    panel.controls.colorHigh = CreateColorSwatch(content, "High", "Color when Atonement duration is above green threshold", "high", defaultColors.high, 16, yPos)
    panel.controls.colorMedium = CreateColorSwatch(content, "Medium", "Color when Atonement duration is between thresholds", "medium", defaultColors.medium, 96, yPos)
    panel.controls.colorLow = CreateColorSwatch(content, "Low", "Color when Atonement duration is below red threshold", "low", defaultColors.low, 176, yPos)
    panel.controls.colorNone = CreateColorSwatch(content, "None", "Color when no Atonement buff (usually transparent)", "none", defaultColors.none, 256, yPos)

    -- Adjust content height based on final yPos
    content:SetHeight(math.abs(yPos) + 60)

    -- RefreshFromConfig: sync with saved DB values (only called when DB is ready)
    function panel:RefreshFromConfig()
        if not AB.db then return end

        -- Checkboxes
        self.controls.enabled:SetChecked(AB:GetConfig("enabled"))
        self.controls.supportBlizzardFrames:SetChecked(AB:GetConfig("supportBlizzardFrames"))
        self.controls.debug:SetChecked(AB:GetConfig("debug"))
        self.controls.enablePulse:SetChecked(AB:GetConfig("enablePulse"))

        -- Sliders
        self.controls.borderSize.slider:SetValue(AB:GetConfig("borderSize"))
        self.controls.highThreshold.slider:SetValue(AB:GetConfig("highThreshold"))
        self.controls.lowThreshold.slider:SetValue(AB:GetConfig("lowThreshold"))
        self.controls.pulseThreshold.slider:SetValue(AB:GetConfig("pulseThreshold"))
        self.controls.pulseSpeed.slider:SetValue(AB:GetConfig("pulseSpeed"))

        -- Color swatches - sync with saved values
        local colors = AB:GetConfig("colors")
        if colors then
            self.controls.colorHigh:SetColor(colors.high)
            self.controls.colorMedium:SetColor(colors.medium)
            self.controls.colorLow:SetColor(colors.low)
            self.controls.colorNone:SetColor(colors.none)
        end
    end

    -- Legacy alias for compatibility
    panel.RefreshControls = panel.RefreshFromConfig

    -- Refresh when panel is shown
    panel:SetScript("OnShow", function(self)
        self:RefreshFromConfig()
    end)

    panel.content = content
    panel.scrollFrame = scrollFrame

    return panel
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local function RegisterOptionsPanel()
    local panel = CreateOptionsPanel()

    -- Use modern Settings API (WoW 10.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        AB.optionsCategory = category
        AB.optionsCategoryID = category:GetID()
    else
        -- Legacy fallback for older clients
        InterfaceOptions_AddCategory(panel)
        AB.optionsPanel = panel
    end

    AB.optionsPanelFrame = panel
end

-- Single event handler with clear flow
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")

loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Create panel immediately (uses AB.defaults for initial colors)
        RegisterOptionsPanel()

        -- Schedule config sync after DB is guaranteed ready
        -- DB initialization happens in main file's ADDON_LOADED, which may run before or after this
        C_Timer.After(0.5, function()
            if AB.optionsPanelFrame then
                AB.optionsPanelFrame:RefreshFromConfig()
            end
        end)

        self:UnregisterAllEvents()
    end
end)

--------------------------------------------------------------------------------
-- Open Options Helper
--------------------------------------------------------------------------------

function AB:OpenOptions()
    if Settings and Settings.OpenToCategory then
        if self.optionsCategoryID then
            Settings.OpenToCategory(self.optionsCategoryID)
        elseif self.optionsCategory then
            Settings.OpenToCategory(self.optionsCategory:GetID())
        end
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel or self.optionsPanelFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel or self.optionsPanelFrame)  -- Call twice due to Blizzard bug
    end
end
