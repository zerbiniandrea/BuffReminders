local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Pet Display (pet category only)
-- ============================================================================
-- Display mode (generic vs expanded), pet labels (toggle + scale + per-class
-- segmented bar). Includes the live preview that follows the dropdown.

local L = BR.L
local Components = BR.Components

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local UpdateDisplay = BR.Display.Update

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP

local tinsert = table.insert

BR.Options.BuffSections = BR.Options.BuffSections or {}

local function Build(ctx, layout)
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Options.PetDisplay"] or L["Tab.DisplayBehavior"])
    layout:Space(COMPONENT_GAP)

    local updatePetDisplayModePreview
    local petDisplayModeHolder = Components.Dropdown(parent, {
        label = L["Options.PetDisplay"],
        width = 120,
        get = function()
            return BR.Config.Get("defaults.petDisplayMode", "generic")
        end,
        options = {
            {
                value = "generic",
                label = L["Options.PetDisplay.Generic"],
                desc = L["Options.PetDisplay.GenericDesc"],
            },
            {
                value = "expanded",
                label = L["Options.PetDisplay.Summon"],
                desc = L["Options.PetDisplay.SummonDesc"],
            },
        },
        tooltip = {
            title = L["Options.PetDisplay.Mode"],
            desc = L["Options.PetDisplay.Mode.Desc"],
        },
        onChange = function(val)
            BR.Config.Set("defaults.petDisplayMode", val)
            if updatePetDisplayModePreview then
                updatePetDisplayModePreview(val)
            end
        end,
    })
    layout:Add(petDisplayModeHolder, nil, COMPONENT_GAP)

    local PP_ICON = 24
    local PP_BORDER = 2
    local PP_GAP = 3
    local PP_STEP = PP_ICON + PP_GAP + PP_BORDER * 2

    local TEX_PET_GENERIC = 136082
    local TEX_PETS = { 136218, 136221, 136217 }

    local petPreviewHeight = PP_ICON + PP_BORDER * 2
    local PET_MODE_ICON_COUNT = { generic = 1, expanded = 3 }

    local petPreviewHolder = CreateFrame("Frame", nil, parent)
    petPreviewHolder:SetSize(PP_STEP, petPreviewHeight)
    petPreviewHolder:SetPoint("TOPLEFT", petDisplayModeHolder, "TOPRIGHT", 12, 0)

    local petPreviewContainer = CreateFrame("Frame", nil, petPreviewHolder)
    petPreviewContainer:SetPoint("TOPLEFT", 0, 0)
    petPreviewContainer:SetSize(3 * PP_STEP, petPreviewHeight)
    petPreviewContainer:SetAlpha(0.7)

    local function CreatePetPreviewIcon(parentFrame, texture, size)
        local f = CreateFrame("Frame", nil, parentFrame)
        f:SetSize(size, size)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()
        f.icon:SetTexture(texture)
        local z = TEXCOORD_INSET
        f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        f.border = f:CreateTexture(nil, "BACKGROUND")
        f.border:SetColorTexture(0, 0, 0, 1)
        f.border:SetPoint("TOPLEFT", -PP_BORDER, PP_BORDER)
        f.border:SetPoint("BOTTOMRIGHT", PP_BORDER, -PP_BORDER)
        return f
    end

    local allPetPreviewFrames = {}

    local genericFrame = CreatePetPreviewIcon(petPreviewContainer, TEX_PET_GENERIC, PP_ICON)
    genericFrame:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", 0, 0)
    genericFrame:Hide()
    allPetPreviewFrames[#allPetPreviewFrames + 1] = genericFrame

    local expandedPetFrames = {}
    for i = 1, 3 do
        local f = CreatePetPreviewIcon(petPreviewContainer, TEX_PETS[i], PP_ICON)
        f:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", (i - 1) * PP_STEP, 0)
        f:Hide()
        expandedPetFrames[i] = f
        allPetPreviewFrames[#allPetPreviewFrames + 1] = f
    end

    local PET_MODE_FRAMES = {
        generic = { genericFrame },
        expanded = expandedPetFrames,
    }
    updatePetDisplayModePreview = function(mode)
        for _, f in ipairs(allPetPreviewFrames) do
            f:Hide()
        end
        local shown = PET_MODE_FRAMES[mode]
        if shown then
            for _, f in ipairs(shown) do
                f:Show()
            end
        end
        petPreviewHolder:SetWidth((PET_MODE_ICON_COUNT[mode] or 1) * PP_STEP)
    end

    updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))

    function petPreviewHolder:Refresh()
        updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))
    end
    tinsert(BR.RefreshableComponents, petPreviewHolder)

    local petLabelsHolder = Components.Checkbox(parent, {
        label = L["Options.PetLabels"],
        get = function()
            return BR.Config.Get("defaults.petLabels", true)
        end,
        tooltip = {
            title = L["Options.PetLabels"],
            desc = L["Options.PetLabels.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.petLabels", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(petLabelsHolder, nil, COMPONENT_GAP)

    local petLabelScaleHolder = Components.NumericStepper(petLabelsHolder, {
        label = L["Options.PetLabels.SizePct"],
        labelWidth = 36,
        min = 50,
        max = 200,
        step = 10,
        get = function()
            return BR.Config.Get("defaults.petLabelScale", 100)
        end,
        enabled = function()
            return BR.Config.Get("defaults.petLabels", true)
        end,
        onChange = function(val)
            BR.Config.Set("defaults.petLabelScale", val)
        end,
    })
    petLabelScaleHolder:SetPoint("LEFT", petLabelsHolder, "LEFT", 90, 0)

    local function classColor(cls)
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then
            return { c.r, c.g, c.b }
        end
        return { 0.5, 0.5, 0.5 }
    end

    local petClassBar, petClassButtons = Components.CreateSegmentedBar(petLabelsHolder, {
        toggleDefs = {
            {
                key = "HUNTER",
                label = "H",
                tooltip = { title = L["Class.Hunter"] },
                color = classColor("HUNTER"),
            },
            {
                key = "WARLOCK",
                label = "W",
                tooltip = { title = L["Class.Warlock"] },
                color = classColor("WARLOCK"),
            },
            {
                key = "DEATHKNIGHT",
                label = "D",
                tooltip = { title = L["Class.DeathKnight"] },
                color = classColor("DEATHKNIGHT"),
            },
            { key = "MAGE", label = "M", tooltip = { title = L["Class.Mage"] }, color = classColor("MAGE") },
        },
        getState = function(key)
            local vis = BR.profile.defaults.petLabelClasses
            return not vis or vis[key] ~= false
        end,
        setState = function(key)
            if not BR.profile.defaults.petLabelClasses then
                BR.profile.defaults.petLabelClasses = {
                    HUNTER = true,
                    WARLOCK = true,
                    DEATHKNIGHT = true,
                    MAGE = true,
                }
            end
            BR.profile.defaults.petLabelClasses[key] = not BR.profile.defaults.petLabelClasses[key]
        end,
        onChange = function()
            UpdateDisplay()
        end,
    })
    petClassBar:SetPoint("LEFT", petLabelScaleHolder, "RIGHT", 8, 0)

    local function isPetLabelsEnabled()
        return BR.Config.Get("defaults.petLabels", true)
    end
    petClassBar:SetBarDisabled(not isPetLabelsEnabled())

    local petClassBarRefreshHolder = CreateFrame("Frame", nil, petLabelsHolder)
    petClassBarRefreshHolder:SetSize(1, 1)
    function petClassBarRefreshHolder:Refresh()
        petClassBar:SetBarDisabled(not isPetLabelsEnabled())
        for _, btn in ipairs(petClassButtons) do
            btn.UpdateVisual()
        end
    end
    tinsert(BR.RefreshableComponents, petClassBarRefreshHolder)
    layout:Space(SECTION_GAP)
end

BR.Options.BuffSections.PetDisplay = Build
