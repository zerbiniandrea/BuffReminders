local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTION: Pet Display (pet category only)
-- ============================================================================
-- Display mode (generic vs expanded) with a live preview. The file also exports
-- the pet label rows for Text & overlays.

local L = BR.L
local Components = BR.Components

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local UpdateDisplay = BR.Display.Update

local Helpers = BR.Options.Helpers
local LayoutSectionHeader = Helpers.LayoutSectionHeader

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local function Build(ctx, layout)
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Options.PetDisplay"] or L["Tab.DisplayBehavior"])
    layout:Space(COMPONENT_GAP)

    local updatePetDisplayModePreview
    local petDisplayModeHolder = Components.Dropdown(parent, {
        label = L["Options.PetDisplay"],
        width = 120,
        get = function()
            return BR.Config.Get("defaults.petDisplayMode")
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

    updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode"))

    function petPreviewHolder:Refresh()
        updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode"))
    end
    table.insert(BR.RefreshableComponents, petPreviewHolder)
end

---Text & overlays rows for the pet icons: the pet label row, then its class
---filter. Every key is global, because only this category draws pet labels.
local function BuildOverlays(ctx, layout)
    local parent = ctx.content

    local function isPetLabelsEnabled()
        return BR.Config.Get("defaults.petLabels") == true
    end

    local labelWidth = ctx.overlayLabelWidth

    -- The zone and the offsets move the pet *name* text only. The family and
    -- spirit-beast lines keep their relative anchors below the name.
    local petLabelOff = {
        get = function()
            return not isPetLabelsEnabled()
        end,
        set = function(off)
            BR.Config.Set("defaults.petLabels", not off)
        end,
    }
    Helpers.LayoutTextRow(layout, parent, {
        label = L["Options.PetLabels"],
        labelWidth = labelWidth,
        zone = {
            get = function()
                return select(1, BR.TextPositions.Get("petLabel"))
            end,
            set = function(zone)
                BR.Config.Set("defaults.textPositions.petLabel.zone", zone)
            end,
            off = petLabelOff,
        },
        isOff = petLabelOff.get,
        size = {
            min = 6,
            max = 32,
            suffix = "px",
            get = function()
                return BR.Config.Get("defaults.petLabelSize")
            end,
            set = function(val)
                BR.Config.Set("defaults.petLabelSize", val)
            end,
        },
        offsets = {
            min = -40,
            max = 40,
            getX = function()
                local _, x = BR.TextPositions.Get("petLabel")
                return x
            end,
            setX = function(val)
                BR.Config.Set("defaults.textPositions.petLabel.offsetX", val)
            end,
            getY = function()
                local _, _, y = BR.TextPositions.Get("petLabel")
                return y
            end,
            setY = function(val)
                BR.Config.Set("defaults.textPositions.petLabel.offsetY", val)
            end,
        },
    })

    -- One checkbox per pet class, in the class color. The row label shares the
    -- column of the other rows, so the row reads as a sibling of Pet labels.
    local PET_CLASSES = {
        { key = "HUNTER", label = L["Class.Hunter"] },
        { key = "WARLOCK", label = L["Class.Warlock"] },
        { key = "DEATHKNIGHT", label = L["Class.DeathKnight"] },
        { key = "MAGE", label = L["Class.Mage"] },
    }

    local classRow = CreateFrame("Frame", nil, parent)
    classRow:SetSize(parent:GetWidth(), 22)
    local classLabel = classRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classLabel:SetPoint("LEFT", 0, 0)
    classLabel:SetWidth(labelWidth)
    classLabel:SetJustifyH("LEFT")
    classLabel:SetText(L["Options.PetLabels.Classes"])
    -- One tooltip for the row, on its label, explains every checkbox.
    local classLabelHover = CreateFrame("Frame", nil, classRow)
    classLabelHover:SetPoint("LEFT", 0, 0)
    classLabelHover:SetSize(classLabel:GetStringWidth() + 4, 20)
    classLabelHover:EnableMouse(true)
    BR.SetupTooltip(classLabelHover, L["Options.PetLabels.Classes"], L["Options.PetLabels.Classes.Desc"])

    local function isClassShown(key)
        local vis = BR.profile.defaults.petLabelClasses
        return not vis or vis[key] ~= false
    end

    local previous
    for _, class in ipairs(PET_CLASSES) do
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class.key]
        local text = color and color:WrapTextInColorCode(class.label) or class.label
        local holder = Components.Checkbox(classRow, {
            label = text,
            holderWidth = Components.MeasureSharedLabelWidth({ class.label }, "GameFontHighlightSmall", 0) + 30,
            enabled = isPetLabelsEnabled,
            disabledReason = L["DisabledReason.PetLabelsOff"],
            get = function()
                return isClassShown(class.key)
            end,
            onChange = function(checked)
                local defaults = BR.profile.defaults
                if not defaults.petLabelClasses then
                    defaults.petLabelClasses = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true, MAGE = true }
                end
                defaults.petLabelClasses[class.key] = checked
                UpdateDisplay()
            end,
        })
        if previous then
            holder:SetPoint("LEFT", previous, "RIGHT", 10, 0)
        else
            holder:SetPoint("LEFT", classRow, "LEFT", labelWidth + 5, 0)
        end
        previous = holder
    end

    function classRow:Refresh()
        local enabled = isPetLabelsEnabled()
        classLabel:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
    end
    classRow:Refresh()
    table.insert(BR.RefreshableComponents, classRow)

    layout:Add(classRow, 22, COMPONENT_GAP)
end

BR.Options.BuffSections.PetDisplay = Build
BR.Options.BuffSections.PetOverlays = BuildOverlays
