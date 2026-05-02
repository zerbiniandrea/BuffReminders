local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local LSM = BR.LSM

local SetBuffSound = BR.Helpers.SetBuffSound
local BuffGroups = BR.BuffGroups

local tinsert = table.insert
local tsort = table.sort

local PlaySoundFile = PlaySoundFile

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DROPDOWN_EXTRA = BR.Options.Constants.DROPDOWN_EXTRA

local soundAlertDialog = nil

-- Build buff options (every buff that doesn't already have a sound assigned).
local function BuildBuffOptions()
    local db = BR.profile
    local opts = {}
    local seenGroups = {}
    for _, category in ipairs(BR.Options.StaticCategories) do
        for _, buff in ipairs(BR.BUFF_TABLES[category] or {}) do
            local key = buff.groupId or buff.key
            if buff.groupId then
                if seenGroups[buff.groupId] then
                    key = nil -- skip duplicate group entries
                else
                    seenGroups[buff.groupId] = true
                end
            end
            if key and not (db.buffSounds and db.buffSounds[key]) then
                local name
                if buff.groupId then
                    local groupInfo = BuffGroups[buff.groupId]
                    name = groupInfo and groupInfo.displayName or buff.name
                else
                    name = buff.name
                end
                tinsert(opts, { label = name, value = key })
            end
        end
    end

    if db.customBuffs then
        for key, customBuff in pairs(db.customBuffs) do
            if not (db.buffSounds and db.buffSounds[key]) then
                local name = customBuff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(customBuff.spellID))
                tinsert(opts, { label = name, value = key })
            end
        end
    end

    tsort(opts, function(a, b)
        return a.label < b.label
    end)
    return opts
end

-- Build sound options from LSM
local function BuildSoundOptions()
    local soundList = LSM:List("sound")
    local opts = {}
    for _, name in ipairs(soundList) do
        if name ~= "None" then
            tinsert(opts, { label = name, value = name })
        end
    end
    return opts
end

local function Show(refreshCallback, editBuffKey, editSoundName, editBuffName)
    -- Destroy and recreate: dropdown scroll support depends on option count at creation time
    if soundAlertDialog then
        soundAlertDialog:Hide()
        soundAlertDialog:SetParent(nil)
    end

    local isEditing = editBuffKey ~= nil
    local DIALOG_WIDTH = 360
    local MARGIN = 16

    local dialog = CreatePanel(nil, DIALOG_WIDTH, 1, {
        level = 200,
        dialog = true,
    })

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(isEditing and L["Options.Sound.EditTitle"] or L["Options.Sound.Title"])

    local closeBtn = CreateButton(dialog, "x", function()
        dialog:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(dialog, { x = MARGIN, y = -36 })

    -- State for selections
    local selectedBuffKey = editBuffKey
    local selectedSoundName = editSoundName

    local buffOpts
    if isEditing then
        -- When editing, show only the current buff (locked)
        buffOpts = { { label = editBuffName or editBuffKey, value = editBuffKey } }
    else
        buffOpts = BuildBuffOptions()
    end

    local buffDropdown = Components.Dropdown(dialog, {
        label = L["Options.Sound.SelectBuff"],
        width = 200,
        maxItems = 15,
        options = buffOpts,
        onChange = function(val)
            selectedBuffKey = val
        end,
    })
    layout:Add(buffDropdown, nil, DROPDOWN_EXTRA)

    if isEditing then
        buffDropdown:SetEnabled(false)
    end

    local soundDropdown = Components.Dropdown(dialog, {
        label = L["Options.Sound.SelectSound"],
        width = 200,
        maxItems = 15,
        options = BuildSoundOptions(),
        onChange = function(val)
            selectedSoundName = val
        end,
    })
    layout:Add(soundDropdown, nil, DROPDOWN_EXTRA)

    if editSoundName then
        soundDropdown:SetValue(editSoundName)
    end

    -- Preview + Save row
    local btnRow = CreateFrame("Frame", nil, dialog)
    btnRow:SetSize(DIALOG_WIDTH - MARGIN * 2, 22)

    local previewBtn = CreateButton(dialog, L["Options.Sound.Preview"], function()
        if selectedSoundName then
            local soundFile = LSM:Fetch("sound", selectedSoundName)
            if soundFile then
                PlaySoundFile(soundFile, "Master")
            end
        end
    end)
    previewBtn:SetSize(80, 22)
    previewBtn:SetPoint("LEFT", btnRow, "LEFT", 0, 0)

    local saveBtn = CreateButton(dialog, L["Options.Sound.Save"], function()
        if selectedBuffKey and selectedSoundName then
            SetBuffSound(selectedBuffKey, selectedSoundName)
            dialog:Hide()
            if refreshCallback then
                refreshCallback()
            end
        end
    end)
    saveBtn:SetSize(80, 22)
    saveBtn:SetPoint("RIGHT", btnRow, "RIGHT", 0, 0)

    layout:Add(btnRow, nil, COMPONENT_GAP)

    dialog:SetHeight(math.max(-layout:GetY() + MARGIN, 80))

    -- Status text for when no buffs are available (only relevant for add mode)
    if not isEditing and #buffOpts == 0 then
        local noBuffsText = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        noBuffsText:SetPoint("TOP", btnRow, "BOTTOM", 0, -6)
        noBuffsText:SetText(L["Options.Sound.NoBuffs"])
    end

    -- Sync local state from auto-selected first options
    if not isEditing then
        selectedBuffKey = buffDropdown.dropdown:GetValue()
    end
    selectedSoundName = soundDropdown.dropdown:GetValue()

    soundAlertDialog = dialog
    dialog:Show()
end

BR.Options.Dialogs.SoundAlert = { Show = Show }
