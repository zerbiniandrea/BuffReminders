local _, BR = ...

-- ============================================================================
-- EXTERNALS PAGE (selection)
-- ============================================================================
-- "Which received buffs do I want to see". Appearance lives on the Externals tab of
-- the Categories page, matching every other category.
--
-- The ticked set is the switch: there is no separate enable toggle, so a first tick
-- starts the display.
--
-- Rows repaint through one page-wide function, not per widget: a section toggle and
-- a row checkbox each change what the other must show.

local L = BR.L
local Components = BR.Components
local BuffPanel = BR.Options.Dialogs.BuffPanel

local COL_PADDING = BR.Options.Constants.COL_PADDING
local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING
local ITEM_HEIGHT = BR.Options.Constants.ITEM_HEIGHT

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local abs = math.abs
local format = string.format

local GOLD = { 1, 0.8, 0 }

-- Section rhythm, matched to the Reminders page. That page clears a note between
-- header and rows; there is none here, so this gap is its header-to-note gap plus
-- room for the header's own descenders.
local HEADER_TO_ROWS_GAP = 22
local ROW_INDENT = 6
local INTER_SECTION_GAP = 10

local ICON_SIZE = 16
local FALLBACK_ICON = 134400

-- Slate tints matching the All Buffs rows. GLYPH_UNSET marks a tracked row that
-- stays silent. It stays at full alpha: a dim on top of it drops the marker under
-- the contrast a control needs.
local GLYPH_IDLE = { 0.62, 0.70, 0.75 }
local GLYPH_HOVER = { 0.85, 0.92, 0.97 }
local GLYPH_UNSET = { 0.42, 0.42, 0.46 }
local GLYPH_SIZE = 13
local GLYPH_GAP = 6
local SOUND_ATLAS = "chatframe-button-icon-voicechat"

-- The link width is fixed: a link that appears under the pointer must not move the
-- buff name, so the name is clamped against the reserve whether the link shows or
-- not. The reserve stays narrow, so a longer sound name is clipped and the tooltip
-- carries the full name.
local LINK_RESERVE = 66
local LINK_HEIGHT = 14
local GLYPH_TO_LINK_GAP = 7
local LINK_IDLE = { 0.55, 0.55, 0.58 }
local ROW_HOVER_ALPHA = BR.Options.Constants.ROW_HOVER_ALPHA

-- Clickable-link marker. Plain ASCII ">" so it renders in every client font - the
-- U+203A chevron is tofu in the bundled CJK faces. Kept in code so translators
-- never carry a stray marker.
local CHEVRON = " >"
local CHEVRON_WIDTH = 10

local TOGGLE_GAP = 8
local TOGGLE_HEIGHT = 14

-- The right column carries the player's own entries, which grow, so it starts lighter.
local LEFT_SECTIONS = { "personal", "groupDefensives", "minorGroupDefensives", "aggro" }
local RIGHT_SECTIONS = { "boosts", "movement", "augmentation" }

local Settings = BR.GetExternalSettings

---@type table<string, table[]> entries bucketed by section key, built once
local entriesBySection = {}
for _, entry in ipairs(BR.EXTERNALS) do
    local bucket = entriesBySection[entry.section]
    if not bucket then
        bucket = {}
        entriesBySection[entry.section] = bucket
    end
    bucket[#bucket + 1] = entry
end

local SECTION_BY_KEY = {}
for _, section in ipairs(BR.EXTERNAL_SECTIONS) do
    SECTION_BY_KEY[section.key] = section
end

---The sound model for one entry. The row glyph and the card a player's own entry
---opens both drive the same drawer row through it.
---@param GetEntry fun(): table?
---@return table
local function BuildSoundModel(GetEntry)
    local function Path(entry)
        return "externals.sounds." .. entry.key
    end

    return {
        get = function()
            local entry = GetEntry()
            local sounds = Settings().sounds
            return entry and sounds and sounds[entry.key]
        end,
        set = function(value)
            local entry = GetEntry()
            if not entry then
                return
            end
            -- The sentinel is stored on purpose: at entry level nil already means
            -- "inherit", so silence needs a value of its own.
            BR.Config.Set(Path(entry), value)
        end,
        override = {
            desc = L["Externals.Sound.Override.Desc"],
            isOn = function()
                local entry = GetEntry()
                return entry ~= nil and BR.IsExternalSoundOverridden(entry.key)
            end,
            setOn = function(on)
                local entry = GetEntry()
                if not entry then
                    return
                end
                if not on then
                    BR.Config.Set(Path(entry), nil)
                    return
                end
                -- Snapshot what the row plays today: the override then changes
                -- nothing until the player picks another sound.
                BR.Config.Set(Path(entry), BR.GetExternalEntrySound(entry) or BR.Sounds.NO_SOUND)
            end,
            effective = function()
                local entry = GetEntry()
                if not entry or entry.defaultSound == false then
                    return nil
                end
                return Settings().sound
            end,
        },
    }
end

---Pointer feedback for one row: the faint strip the list-editor pages paint, plus
---the reveal of a trailing link that only shows under the pointer. A row that wants
---a tooltip of its own sets `row.ShowTip`. Exposes `row.HoverIn` so a child that
---takes the pointer can light the row it sits on.
---@param row table
local function AddRowHover(row)
    row:EnableMouse(true)
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0)

    local function Clear(self)
        self:SetScript("OnUpdate", nil)
        hover:SetColorTexture(1, 1, 1, 0)
        if self.link and not self.link.persistent then
            self.link:SetAlpha(0)
        end
        if self.ShowTip then
            BR.HideTooltip()
        end
    end

    -- A child of the row takes the pointer and fires OnLeave on the row, and the
    -- pointer can then leave the row straight from that child - the row never hears
    -- a second OnLeave and stays lit. The watcher clears the row on its own.
    local function Watch(self)
        if self:IsMouseOver() then
            return
        end
        Clear(self)
    end

    function row.HoverIn(self)
        hover:SetColorTexture(1, 1, 1, ROW_HOVER_ALPHA)
        if self.link then
            self.link:SetAlpha(1)
        end
        self:SetScript("OnUpdate", Watch)
    end

    row:SetScript("OnEnter", function(self)
        self.HoverIn(self)
        if self.ShowTip then
            self.ShowTip(self)
        end
    end)

    row:SetScript("OnLeave", Watch)

    -- A pooled row can be hidden under the pointer, which stops OnUpdate.
    row:SetScript("OnHide", Clear)
end

---A small text link. `SetFixedWidth` pins it to one width so a row can clamp its
---label against the reserve whether the link shows or not; a link left unpinned
---sizes to its text.
---@param parent Frame
---@param color number[]
---@param onClick function
local function CreateLink(parent, color, onClick)
    local btn = CreateFrame("Button", nil, parent)
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- The marker is a FontString of its own, not part of the label, so a label
    -- clipped by the fixed width still ends in the marker instead of losing it.
    local mark = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mark:SetText(CHEVRON)
    text:SetPoint("LEFT", 0, 0)
    mark:SetPoint("LEFT", text, "RIGHT", 0, 0)
    btn:SetFontString(text)
    btn:SetHeight(LINK_HEIGHT)
    btn.idle = color

    local function Tint(c)
        text:SetTextColor(c[1], c[2], c[3])
        mark:SetTextColor(c[1], c[2], c[3])
    end
    Tint(color)

    ---The marker's own width, floored: a FontString measures 0 until it has a font,
    ---and the link is built before the panel's typeface sweep reaches it.
    local function MarkWidth()
        local w = mark:GetStringWidth()
        return w > 0 and w or CHEVRON_WIDTH
    end

    function btn:SetFixedWidth(width)
        self.fixedWidth = width
        self:SetWidth(width)
        mark:ClearAllPoints()
        mark:SetPoint("RIGHT", 0, 0)
        text:ClearAllPoints()
        text:SetPoint("RIGHT", mark, "LEFT", 0, 0)
        text:SetWidth(width - MarkWidth())
        text:SetJustifyH("RIGHT")
        text:SetWordWrap(false)
    end

    function btn:SetIdleColor(c)
        self.idle = c
        Tint(c)
    end

    function btn:SetLabel(label)
        text:SetText(label)
        if not self.fixedWidth then
            self:SetWidth(text:GetStringWidth() + MarkWidth() + 2)
        end
    end

    function btn:SetTooltip(title, desc)
        self.tipTitle, self.tipDesc = title, desc
    end

    btn:SetScript("OnEnter", function(self)
        Tint(GLYPH_HOVER)
        -- A link revealed on hover is still clickable while invisible, so the
        -- pointer can reach it without crossing the row. Light the row from here.
        local row = self:GetParent()
        if row.HoverIn then
            row.HoverIn(row)
        end
        if self.tipTitle then
            BR.ShowTooltip(self, self.tipTitle, self.tipDesc, "ANCHOR_RIGHT")
        end
    end)
    btn:SetScript("OnLeave", function(self)
        Tint(self.idle)
        if self.tipTitle then
            BR.HideTooltip()
        end
    end)
    btn:SetScript("OnClick", onClick)
    return btn
end

---The sound controls for one row. The glyph reports state and takes no clicks; the
---link is the door, matching the All Buffs rows where gold trailing text opens the
---settings and slate glyphs only report. Both read the entry through a getter,
---because a pooled row serves a different entry on every render. A row that already
---carries a link of its own passes `withLink` false and keeps the glyph alone.
---Returns the glyph, which exposes Update() to repaint the pair and holds the link
---on `.link` for the row to anchor.
---@param row table
---@param GetEntry fun(): table?
---@param withLink? boolean
---@return table glyph
local function CreateSoundControls(row, GetEntry, withLink)
    local model = BuildSoundModel(GetEntry)

    -- A sound only means something for a buff the player tracks, so the row's own
    -- checkbox gates both controls.
    local function IsTracked()
        local entry = GetEntry()
        if not entry then
            return false
        end
        local enabled = Settings().entries
        return enabled ~= nil and enabled[entry.key] == true
    end

    ---The name this row plays, or nil when it stays silent - which includes the
    ---case where an earlier entry already registered every one of its spell IDs.
    local function PlayingLabel()
        local entry = GetEntry()
        if not entry or BR.FindExternalSoundOwner(entry) then
            return nil
        end
        return BR.Sounds.Label(BR.GetExternalEntrySound(entry))
    end

    ---Why this row sounds the way it does, and what to do about it.
    local function Describe()
        local entry = GetEntry()
        if not entry then
            return ""
        end
        local owner = BR.FindExternalSoundOwner(entry)
        if owner then
            return format(L["Externals.Sound.Claimed"], BR.GetExternalLabel(owner))
        end
        local playing = PlayingLabel()
        if playing then
            return format(L["Externals.Sound.Plays"], playing) .. "|n" .. L["Externals.Sound.Change"]
        end
        if BR.IsExternalSoundOverridden(entry.key) then
            return L["Externals.Sound.Silenced"]
        end
        if entry.defaultSound == false then
            return L["Externals.Sound.SilentByDefault"]
        end
        return L["Externals.Sound.NoAlert"]
    end

    local glyph = CreateFrame("Frame", nil, row)
    glyph:SetSize(GLYPH_SIZE, GLYPH_SIZE)
    local tex = glyph:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetAtlas(SOUND_ATLAS)

    local link
    if withLink then
        link = CreateLink(row, LINK_IDLE, function(self)
            local entry = GetEntry()
            if not entry or not IsTracked() then
                return
            end
            BuffPanel.ShowSound({
                title = BR.GetExternalLabel(entry),
                icon = C_Spell.GetSpellTexture(entry.spellIDs[1]),
                model = model,
            }, self)
        end)
        link:SetFixedWidth(LINK_RESERVE)
        glyph.link = link
    end

    function glyph.Update()
        local tracked = IsTracked()
        local playing = tracked and PlayingLabel() or nil
        -- An untracked row draws no marker at all: a control that does nothing must
        -- not look like one.
        tex:SetShown(tracked)
        local tint = playing and GLYPH_IDLE or GLYPH_UNSET
        tex:SetVertexColor(tint[1], tint[2], tint[3])

        if not link then
            return
        end
        link:SetShown(tracked)
        if not tracked then
            return
        end
        -- Gold and always shown marks the row that overrides the page sound; the
        -- muted one only reports what it inherits, so it stays a hover reveal.
        local overridden = BR.IsExternalSoundOverridden(GetEntry().key)
        link.persistent = overridden
        link:SetIdleColor(overridden and GOLD or LINK_IDLE)
        if playing then
            link:SetLabel(playing)
        elseif overridden then
            link:SetLabel(L["Externals.Sound.Silent"])
        else
            link:SetLabel(L["Externals.Sound.Link"])
        end
        link:SetTooltip(L["Externals.Sound"], Describe())
        -- Repaints run while the pointer sits on the row, so the hover state wins.
        link:SetAlpha((overridden or row:IsMouseOver()) and 1 or 0)
    end

    glyph.Update()
    return glyph
end

---Section select-all: one click tracks the whole group, the next clears it.
---Exposes Update() so the label follows the row checkboxes.
---@param parent Frame
---@param entries table[]
local function CreateSectionToggle(parent, entries)
    local btn = CreateFrame("Button", nil, parent)
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 0, 0)
    btn:SetFontString(text)

    local function AllTracked()
        local enabled = Settings().entries
        if not enabled then
            return false
        end
        for _, entry in ipairs(entries) do
            if not enabled[entry.key] then
                return false
            end
        end
        return true
    end

    local function Tint(color)
        text:SetTextColor(color[1], color[2], color[3])
    end

    function btn.Update()
        local all = AllTracked()
        btn.tracksAll = all
        text:SetText(all and L["Externals.SelectNone"] or L["Externals.SelectAll"])
        btn:SetSize(text:GetStringWidth() + 2, TOGGLE_HEIGHT)
        Tint(GLYPH_IDLE)
    end

    btn:SetScript("OnEnter", function(self)
        Tint(GLYPH_HOVER)
        local all = btn.tracksAll
        BR.ShowTooltip(
            self,
            all and L["Externals.SelectNone"] or L["Externals.SelectAll"],
            all and L["Externals.SelectNone.Tooltip"] or L["Externals.SelectAll.Tooltip"],
            "ANCHOR_RIGHT"
        )
    end)

    btn:SetScript("OnLeave", function()
        Tint(GLYPH_IDLE)
        BR.HideTooltip()
    end)

    btn:SetScript("OnClick", function()
        local settings = Settings()
        settings.entries = settings.entries or {}
        -- nil rather than false: keeps SavedVariables free of dead keys.
        local track = not btn.tracksAll or nil
        for _, entry in ipairs(entries) do
            settings.entries[entry.key] = track
        end
        -- RefreshAll re-reads every row checkbox and runs the page repaint hook.
        Components.RefreshAll()
        BR.CallbackRegistry:TriggerEvent("ExternalsRefresh")
    end)

    btn.Update()
    return btn
end

---One row: enable checkbox, spell icon, name, sound glyph, sound link.
local function RenderRow(parent, x, y, entry, rowWidth, ctx)
    local key = entry.key
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", x, y)
    row:SetSize(rowWidth, ITEM_HEIGHT)
    AddRowHover(row)

    local soundGlyph = CreateSoundControls(row, function()
        return entry
    end, true)
    row.link = soundGlyph.link
    soundGlyph:SetPoint("RIGHT", 0, 0)
    row.link:SetPoint("RIGHT", soundGlyph, "LEFT", -GLYPH_TO_LINK_GAP, 0)
    ctx.updaters[#ctx.updaters + 1] = soundGlyph.Update

    -- holderWidth 18: the label is drawn separately, so the checkbox holder covers
    -- the box alone. A wider holder pushes the icon far to the right.
    local checkbox = Components.Checkbox(row, {
        label = "",
        holderWidth = 18,
        get = function()
            local enabled = Settings().entries
            return enabled ~= nil and enabled[key] == true
        end,
        onChange = function(checked)
            local settings = Settings()
            settings.entries = settings.entries or {}
            -- nil rather than false: keeps SavedVariables free of dead keys.
            settings.entries[key] = checked or nil
            ctx.Repaint()
            BR.CallbackRegistry:TriggerEvent("ExternalsRefresh")
        end,
    })
    checkbox:SetPoint("LEFT", 0, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    icon:SetTexture(C_Spell.GetSpellTexture(entry.spellIDs[1]) or FALLBACK_ICON)
    icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    label:SetPoint("RIGHT", row.link, "LEFT", -GLYPH_GAP, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(BR.GetExternalLabel(entry))

    return y - ITEM_HEIGHT
end

local function RenderColumn(parent, x, y, sectionKeys, colWidth, ctx)
    local rowsX = x + ROW_INDENT
    local rowWidth = colWidth - ROW_INDENT

    for i, sectionKey in ipairs(sectionKeys) do
        local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", x, y)
        header:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        header:SetText(L[SECTION_BY_KEY[sectionKey].titleKey])

        local entries = entriesBySection[sectionKey] or {}
        if #entries > 1 then
            local toggle = CreateSectionToggle(parent, entries)
            toggle:SetPoint("LEFT", header, "RIGHT", TOGGLE_GAP, 0)
            ctx.updaters[#ctx.updaters + 1] = toggle.Update
        end

        y = y - HEADER_TO_ROWS_GAP

        for _, entry in ipairs(entries) do
            y = RenderRow(parent, rowsX, y, entry, rowWidth, ctx)
        end

        if i < #sectionKeys then
            y = y - INTER_SECTION_GAP
        end
    end

    return y
end

-- ============================================================================
-- THE PLAYER'S OWN ENTRIES
-- ============================================================================
-- The buff shortcut list reads the player's auras, which return nothing during a
-- restricted context, so its empty state names that cause as well as the plain one.
--
-- A duplicate spell ID is allowed. The display packs duplicates into one icon, and
-- the sound engine gives each ID to one entry.

local CreateButton = BR.CreateButton
local ValidateSpellID = BR.Helpers.ValidateSpellID
local AuraByIndex = BR.Secret.AuraByIndex
local AuraField = BR.Secret.AuraField

local ceil = math.ceil
local type = type
local wipe = wipe

local EDITOR_LABEL_WIDTH = 52
local EDITOR_INPUT_WIDTH = 120
local EDITOR_ROW_HEIGHT = 20
local EDITOR_ROW_GAP = 6
local ACTION_BUTTON_WIDTH = 48
local DRAWER_BUTTON_HEIGHT = 22
-- The card for one of the player's entries carries a row per spell ID, so it needs
-- more width than the per-buff cards.
local ENTRY_CARD_WIDTH = 380
local ENTRY_ID_WIDTH = 66
local ENTRY_ROW_GAP = 4
local REMOVE_SIZE = 14
-- Inline icon markup for the readout line. The trailing crop numbers trim the icon
-- border, the same slice TEXCOORD_INSET takes off a texture.
local ICON_MARKUP = "|T%d:12:12:0:0:64:64:5:59:5:59|t "
local NAME_GAP = "  "
-- The picker card sizes to its content, so past this many buffs the tail is counted
-- rather than drawn.
local GRAB_LIMIT = 12
local AURA_SCAN_LIMIT = 40

-- The page builds once, so one target is enough for the shift-click hook.
local InsertLinkedSpellID
local linkHooked = false

---Every spell ID in a piece of text. A pasted spell link wins over the bare digits
---around it, so the link's trailing fields never read as extra IDs.
---@param text string?
---@return number[]
local function ParseSpellIDs(text)
    local ids, seen = {}, {}
    if not text then
        return ids
    end
    for match in text:gmatch("Hspell:(%d+)") do
        local id = tonumber(match)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    if ids[1] then
        return ids
    end
    for match in text:gmatch("%d+") do
        local id = tonumber(match)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

---One line naming what the typed IDs resolve to, and which entry already holds them.
---@param ids number[]
---@param exceptKey string?
---@return string
local function DescribeSpellIDs(ids, exceptKey)
    local parts = {}
    for _, id in ipairs(ids) do
        local valid, name, iconID = ValidateSpellID(id)
        if not valid then
            parts[#parts + 1] = "|cffff4d4d" .. format(L["Externals.Custom.Unknown"], id) .. "|r"
        else
            local owner = BR.FindExternalBySpellID(id, exceptKey)
            local suffix = ""
            if owner then
                suffix = " |cff808080(" .. format(L["Externals.Custom.AlreadyIn"], BR.GetExternalLabel(owner)) .. ")|r"
            end
            parts[#parts + 1] = format(ICON_MARKUP, iconID or FALLBACK_ICON) .. name .. suffix
        end
    end
    return table.concat(parts, NAME_GAP)
end

---Helpful auras on the player that no entry covers yet.
---@return table[]
local function CollectNewPlayerBuffs()
    local list, seen = {}, {}
    for index = 1, AURA_SCAN_LIMIT do
        local aura = AuraByIndex("player", index, "HELPFUL")
        if aura == nil then
            break
        end
        local spellID = AuraField(aura, "spellId")
        if spellID and not seen[spellID] then
            seen[spellID] = true
            if not BR.FindExternalBySpellID(spellID, nil) then
                list[#list + 1] = {
                    spellID = spellID,
                    name = AuraField(aura, "name") or BR.GetSpellName(spellID) or tostring(spellID),
                    icon = AuraField(aura, "icon") or C_Spell.GetSpellTexture(spellID) or FALLBACK_ICON,
                }
            end
        end
    end
    return list
end

---The spell ID a dragged cursor carries, or nil when the cursor holds anything else.
---API generations place the ID in different positions of the payload, so the last
---numeric field wins and a lone leading number must still resolve to a spell.
---@return number?
local function CursorSpellID()
    local kind, first, second, third = GetCursorInfo()
    if kind ~= "spell" then
        return nil
    end
    if type(third) == "number" then
        return third
    end
    if type(second) == "number" then
        return second
    end
    if type(first) == "number" and second == nil and ValidateSpellID(first) then
        return first
    end
    return nil
end

---The picker card: the buffs on the player that no entry covers, one click each.
---A card rather than a list on the page, so opening it never moves the rows.
---@param anchor table Widget the card opens beside
---@param OnPick fun(spellID: number)
local function OpenBuffPicker(anchor, OnPick)
    BuffPanel.OpenDrawer(L["Externals.Custom.GrabTitle"], nil, anchor, function(layout, body, width)
        local buffs = CollectNewPlayerBuffs()

        if not buffs[1] then
            local empty = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            empty:SetWidth(width)
            empty:SetJustifyH("LEFT")
            empty:SetText(L["Externals.Custom.GrabEmpty"])
            layout:AddText(empty, ceil(empty:GetStringHeight()), 0)
            return
        end

        local shown = math.min(#buffs, GRAB_LIMIT)
        for index = 1, shown do
            local buff = buffs[index]
            local row = CreateFrame("Button", nil, body)
            row:SetSize(width, ITEM_HEIGHT)

            local highlight = row:CreateTexture(nil, "BACKGROUND")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.06)
            highlight:Hide()
            row:SetScript("OnEnter", function()
                highlight:Show()
            end)
            row:SetScript("OnLeave", function()
                highlight:Hide()
            end)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon:SetPoint("LEFT", 0, 0)
            icon:SetTexture(buff.icon)
            icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)

            local idText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            idText:SetPoint("RIGHT", 0, 0)
            idText:SetJustifyH("RIGHT")
            idText:SetText(buff.spellID)

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
            label:SetPoint("RIGHT", idText, "LEFT", -GLYPH_GAP, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(buff.name)

            row:SetScript("OnClick", function()
                BuffPanel.HideDrawer()
                OnPick(buff.spellID)
            end)

            layout:Add(row, ITEM_HEIGHT, 0)
        end

        if #buffs > shown then
            local more = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            more:SetWidth(width)
            more:SetJustifyH("LEFT")
            more:SetText(format(L["Externals.Custom.GrabMore"], #buffs - shown))
            layout:AddText(more, LINK_HEIGHT, 0)
        end
    end)
end

---Drop one of the player's entries, and everything keyed to it.
---@param key string
---@param OnChanged function
local function DeleteEntry(key, OnChanged)
    local settings = Settings()
    if settings.custom then
        settings.custom[key] = nil
    end
    if settings.entries then
        settings.entries[key] = nil
    end
    if settings.sounds then
        settings.sounds[key] = nil
    end
    OnChanged()
end

---One spell ID an entry already holds: its icon, its name, its number, and a remove
---button. Static text, not a field. The number identifies the row, and a column of
---edit boxes reads as a form rather than a list. A wrong ID is corrected by adding
---the right one and removing this one.
---@param body table Card body
---@param width number
---@param spellID number
---@param exceptKey string Entry being edited, so it never reports itself as owner
---@param OnRemove function|nil nil hides the remove button
---@return table
local function CreateEntryIDRow(body, width, spellID, exceptKey, OnRemove)
    local row = CreateFrame("Frame", nil, body)
    row:SetSize(width, EDITOR_ROW_HEIGHT)

    local valid, name, iconID = ValidateSpellID(spellID)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", 0, 0)
    icon:SetTexture(iconID or FALLBACK_ICON)
    icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)

    local rightEdge, rightPoint, rightGap = row, "RIGHT", 0
    if OnRemove then
        local remove = CreateFrame("Button", nil, row)
        remove:SetSize(REMOVE_SIZE, REMOVE_SIZE)
        remove:SetPoint("RIGHT", 0, 0)

        local cross = remove:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cross:SetPoint("CENTER", 0, 0)
        cross:SetText("x")
        cross:SetTextColor(GLYPH_IDLE[1], GLYPH_IDLE[2], GLYPH_IDLE[3])

        remove:SetScript("OnEnter", function(self)
            cross:SetTextColor(1, 0.45, 0.45)
            BR.ShowTooltip(self, L["Externals.Custom.RemoveID"], nil, "ANCHOR_RIGHT")
        end)
        remove:SetScript("OnLeave", function()
            cross:SetTextColor(GLYPH_IDLE[1], GLYPH_IDLE[2], GLYPH_IDLE[3])
            BR.HideTooltip()
        end)
        remove:SetScript("OnClick", OnRemove)

        rightEdge, rightPoint, rightGap = remove, "LEFT", -6
    end

    local idText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    idText:SetPoint("RIGHT", rightEdge, rightPoint, rightGap, 0)
    idText:SetJustifyH("RIGHT")
    idText:SetText(spellID)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT", idText, "LEFT", -8, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)

    if not valid then
        nameText:SetText("|cffff4d4d" .. L["CustomBuff.NotFound"] .. "|r")
    else
        local owner = BR.FindExternalBySpellID(spellID, exceptKey)
        if owner then
            name = name
                .. " |cff808080("
                .. format(L["Externals.Custom.AlreadyIn"], BR.GetExternalLabel(owner))
                .. ")|r"
        end
        nameText:SetText(name)
    end

    return row
end

---The row the add button opens: the card's only field, focused on arrival. It saves
---as soon as its ID resolves, whether the player presses Enter or clicks away, so
---nothing typed is lost. Enter also reopens the card, which is what turns the row
---into a listed ID and offers a fresh field.
---@param body table Card body
---@param width number
---@param OnCommit fun(spellID: number, reopen: boolean)
---@return table
local function CreateEntryIDInput(body, width, OnCommit)
    local row = CreateFrame("Frame", nil, body)
    row:SetSize(width, EDITOR_ROW_HEIGHT)

    local editBox = CreateFrame("EditBox", nil, row)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetAutoFocus(true)
    -- Anchored before any text reaches it: an edit box laid out afterwards keeps
    -- its text hidden, with no error to say so.
    local container = BR.StyleEditBox(editBox)
    container:SetSize(ENTRY_ID_WIDTH, 18)
    container:SetPoint("LEFT", 0, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", container, "RIGHT", 8, 0)
    icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    icon:Hide()

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)

    ---@return number? spellID nil while the field holds nothing usable
    local function Describe()
        local text = editBox:GetText()
        local spellID = ParseSpellIDs(text)[1]
        local valid, name, iconID = false, nil, nil
        if spellID then
            valid, name, iconID = ValidateSpellID(spellID)
        end
        icon:SetShown(valid)
        if valid then
            icon:SetTexture(iconID or FALLBACK_ICON)
            nameText:SetText(name)
            return spellID
        end
        nameText:SetText(text ~= "" and ("|cffff4d4d" .. L["CustomBuff.NotFound"] .. "|r") or "")
        return nil
    end

    local committed = false
    local function Commit(reopen)
        if committed then
            return
        end
        local spellID = Describe()
        if not spellID then
            return
        end
        committed = true
        OnCommit(spellID, reopen)
    end

    editBox:SetScript("OnTextChanged", Describe)
    editBox:SetScript("OnEnterPressed", function(self)
        Commit(true)
        self:ClearFocus()
    end)
    editBox:HookScript("OnEditFocusLost", function()
        Commit(false)
    end)

    return row
end

---The card for one of the player's entries: a row per spell ID, then name, sound and
---delete. Anchored to the row that opened it, so the list never moves under the
---pointer. Every field applies on Enter and on focus loss, like the rest of the
---panel - there is no Save button to leave unpressed.
---
---A card sizes itself once per open, so a change to the number of rows reopens it.
---@param key string
---@param anchor table Row widget the card opens beside
---@param OnChanged function
---@param withBlankRow? boolean Draw the empty row the add button asks for
local function OpenEntryDrawer(key, anchor, OnChanged, withBlankRow)
    local def = Settings().custom and Settings().custom[key]
    if not def then
        return
    end

    local function Reopen(blank)
        OnChanged()
        OpenEntryDrawer(key, anchor, OnChanged, blank)
    end

    BuffPanel.OpenDrawer(
        BR.GetExternalLabel(def),
        C_Spell.GetSpellTexture(def.spellIDs[1]),
        anchor,
        function(layout, body, width)
            local caption = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            caption:SetText(L["Externals.Custom.SpellIDs"])
            layout:AddText(caption, LINK_HEIGHT, ENTRY_ROW_GAP)

            -- The last ID is what makes the entry an entry, so it keeps no remove
            -- button. Delete removes the whole entry instead.
            local removable = #def.spellIDs > 1
            for index, spellID in ipairs(def.spellIDs) do
                local row = CreateEntryIDRow(body, width, spellID, key, removable and function()
                    table.remove(def.spellIDs, index)
                    BuffPanel.HideDrawer()
                    Reopen(false)
                end or nil)
                layout:Add(row, EDITOR_ROW_HEIGHT, ENTRY_ROW_GAP)
            end

            if withBlankRow then
                local row = CreateEntryIDInput(body, width, function(spellID, reopen)
                    def.spellIDs[#def.spellIDs + 1] = spellID
                    if not reopen then
                        -- Focus left the field without Enter. The ID is saved, and
                        -- the card catches up the next time it opens.
                        OnChanged()
                        return
                    end
                    BuffPanel.HideDrawer()
                    Reopen(true)
                end)
                layout:Add(row, EDITOR_ROW_HEIGHT, ENTRY_ROW_GAP)
            else
                local addBtn = CreateButton(body, L["CustomBuff.AddSpellID"], function()
                    BuffPanel.HideDrawer()
                    OpenEntryDrawer(key, anchor, OnChanged, true)
                end)
                addBtn:SetSize(ENTRY_ID_WIDTH + 60, EDITOR_ROW_HEIGHT)
                layout:Add(addBtn, EDITOR_ROW_HEIGHT, COMPONENT_GAP)
            end

            local nameHolder = Components.TextInput(body, {
                label = L["Externals.Custom.Name"],
                labelWidth = BuffPanel.LABEL_WIDTH,
                width = BuffPanel.FIELD_WIDTH,
                value = def.name or "",
                onChange = function(text)
                    local name = strtrim(text or "")
                    name = name ~= "" and name or nil
                    if def.name == name then
                        return
                    end
                    def.name = name
                    OnChanged()
                end,
            })
            layout:Add(nameHolder, 20, COMPONENT_GAP)

            BuffPanel.AddSoundRow(
                layout,
                BuildSoundModel(function()
                    return { key = key, spellIDs = def.spellIDs, name = def.name, custom = true }
                end)
            )

            local deleteBtn = CreateButton(body, L["Externals.Custom.Delete"], function()
                BuffPanel.HideDrawer()
                DeleteEntry(key, OnChanged)
            end)
            deleteBtn:SetSize(width, DRAWER_BUTTON_HEIGHT)
            layout:Add(deleteBtn, DRAWER_BUTTON_HEIGHT, 0)
        end,
        ENTRY_CARD_WIDTH
    )
end

---The player's own entries: the add field, the shortcut list and the rows. Every
---widget is created once and repositioned per render, because the section's height
---moves with the row count, the shortcut list and the wrapped resolution line.
---@param parent Frame
---@param x number
---@param topY number
---@param colWidth number
---@param ctx table
---@return table
local function CreateCustomSection(parent, x, topY, colWidth, ctx)
    local rowWidth = colWidth - ROW_INDENT

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x, topY)
    frame:SetSize(colWidth, 1)

    local Render, Commit, AppendSpellID

    local function EntriesChanged()
        Render()
        ctx.Repaint()
        BR.CallbackRegistry:TriggerEvent("ExternalsRefresh")
    end

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    header:SetText(L["Externals.Custom"])

    local idInput = Components.TextInput(frame, {
        label = L["Externals.Custom.SpellID"],
        labelWidth = EDITOR_LABEL_WIDTH,
        width = EDITOR_INPUT_WIDTH,
    })
    local idBox = idInput.editBox

    local actionBtn = CreateButton(frame, L["Externals.Custom.Add"], function()
        Commit()
    end)
    actionBtn:SetSize(ACTION_BUTTON_WIDTH, EDITOR_ROW_HEIGHT)

    -- Beside the field it fills, not beside the section header: the picker is an
    -- alternative way to answer the field, so it belongs on the same row.
    local grabLink = CreateLink(frame, GLYPH_IDLE, function(self)
        OpenBuffPicker(self, function(spellID)
            AppendSpellID(spellID)
        end)
    end)
    grabLink:SetLabel(L["Externals.Custom.Grab"])
    grabLink:SetTooltip(L["Externals.Custom.Grab"], L["Externals.Custom.Grab.Tooltip"])

    local strip = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    strip:SetWidth(rowWidth)
    strip:SetJustifyH("LEFT")

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetWidth(rowWidth)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["Externals.Custom.Hint"])

    local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetWidth(rowWidth)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(L["Externals.Custom.Empty"])

    -- ------------------------------------------------------------------
    -- Rows
    -- ------------------------------------------------------------------

    local rowPool, rowCount = {}, 0

    local function CreateEntryRow()
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(rowWidth, ITEM_HEIGHT)
        AddRowHover(row)

        -- The card holds the name, the spell IDs and the sound, so the sound has no
        -- link of its own here: Edit is the row's one door.
        local glyph = CreateSoundControls(row, function()
            return row.entry
        end)
        row.glyph = glyph

        local editLink = CreateLink(row, GOLD, function(self)
            if row.entry then
                OpenEntryDrawer(row.entry.key, self, EntriesChanged)
            end
        end)
        editLink:SetLabel(L["Externals.Custom.Edit"])
        glyph:SetPoint("RIGHT", 0, 0)
        editLink:SetPoint("RIGHT", glyph, "LEFT", -GLYPH_TO_LINK_GAP, 0)

        local checkbox = Components.Checkbox(row, {
            label = "",
            holderWidth = 18,
            get = function()
                local entry = row.entry
                if not entry then
                    return false
                end
                local enabled = Settings().entries
                return enabled ~= nil and enabled[entry.key] == true
            end,
            onChange = function(checked)
                local entry = row.entry
                if not entry then
                    return
                end
                local settings = Settings()
                settings.entries = settings.entries or {}
                -- nil rather than false: keeps SavedVariables free of dead keys.
                settings.entries[entry.key] = checked or nil
                ctx.Repaint()
                BR.CallbackRegistry:TriggerEvent("ExternalsRefresh")
            end,
        })
        checkbox:SetPoint("LEFT", 0, 0)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
        label:SetPoint("RIGHT", editLink, "LEFT", -GLYPH_GAP, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)

        function row.ShowTip(self)
            local entry = self.entry
            if not entry then
                return
            end
            BR.ShowTooltip(
                self,
                BR.GetExternalLabel(entry),
                format(L["Externals.Custom.RowTooltip"], table.concat(entry.spellIDs, ", ")),
                "ANCHOR_RIGHT"
            )
        end

        function row.Fill(entry)
            row.entry = entry
            icon:SetTexture(C_Spell.GetSpellTexture(entry.spellIDs[1]) or FALLBACK_ICON)
            label:SetText(BR.GetExternalLabel(entry))
            checkbox:Refresh()
            glyph.Update()
        end

        return row
    end

    local function Acquire(pool, index, Create)
        local row = pool[index]
        if not row then
            row = Create()
            pool[index] = row
        end
        row:ClearAllPoints()
        row:Show()
        return row
    end

    -- ------------------------------------------------------------------
    -- Adding
    -- ------------------------------------------------------------------

    AppendSpellID = function(spellID)
        local text = strtrim(idBox:GetText() or "")
        idBox:SetText(text == "" and tostring(spellID) or (text .. ", " .. spellID))
    end

    Commit = function()
        local valid = {}
        for _, id in ipairs(ParseSpellIDs(idBox:GetText())) do
            if ValidateSpellID(id) then
                valid[#valid + 1] = id
            end
        end
        -- An ID the client cannot resolve is dropped rather than stored: it matches
        -- no aura and draws a nameless icon. The red line stays on screen.
        if not valid[1] then
            return
        end

        local settings = Settings()
        settings.custom = settings.custom or {}
        settings.entries = settings.entries or {}

        local key = BR.NewExternalKey(valid[1])
        settings.custom[key] = { spellIDs = valid }
        -- A new buff arrives tracked: adding it is the act of asking for it.
        settings.entries[key] = true

        idBox:SetText("")
        idBox:ClearFocus()
        EntriesChanged()
    end

    idBox:SetScript("OnTextChanged", function()
        Render()
    end)
    idBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Commit()
    end)
    idBox:SetScript("OnReceiveDrag", function()
        local spellID = CursorSpellID()
        if spellID then
            AppendSpellID(spellID)
        end
        ClearCursor()
    end)

    InsertLinkedSpellID = function(link)
        if not idBox:HasFocus() then
            return
        end
        local id = type(link) == "string" and link:match("Hspell:(%d+)")
        if id then
            AppendSpellID(tonumber(id))
        end
    end

    -- A shift-click on a spell routes through the chat link path, which is how the
    -- client delivers the link.
    if not linkHooked and type(ChatEdit_InsertLink) == "function" then
        linkHooked = true
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if InsertLinkedSpellID then
                InsertLinkedSpellID(link)
            end
        end)
    end

    -- ------------------------------------------------------------------
    -- Layout
    -- ------------------------------------------------------------------

    Render = function()
        local y = -HEADER_TO_ROWS_GAP

        idInput:ClearAllPoints()
        idInput:SetPoint("TOPLEFT", ROW_INDENT, y)
        actionBtn:ClearAllPoints()
        actionBtn:SetPoint("LEFT", idInput, "RIGHT", 6, 0)
        grabLink:ClearAllPoints()
        grabLink:SetPoint("LEFT", actionBtn, "RIGHT", 8, 0)
        y = y - EDITOR_ROW_HEIGHT - EDITOR_ROW_GAP

        local ids = ParseSpellIDs(idBox:GetText())
        strip:SetShown(ids[1] ~= nil)
        if ids[1] then
            strip:SetText(DescribeSpellIDs(ids, nil))
            strip:ClearAllPoints()
            strip:SetPoint("TOPLEFT", ROW_INDENT, y)
            y = y - ceil(strip:GetStringHeight()) - EDITOR_ROW_GAP
        end

        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", ROW_INDENT, y)
        y = y - ceil(hint:GetStringHeight()) - INTER_SECTION_GAP

        local entries = {}
        for _, entry in ipairs(BR.GetExternalEntries()) do
            if entry.custom then
                entries[#entries + 1] = entry
            end
        end

        for index = 1, rowCount do
            rowPool[index].entry = nil
            rowPool[index]:Hide()
        end
        rowCount = 0
        wipe(ctx.customUpdaters)

        emptyText:SetShown(entries[1] == nil)
        if not entries[1] then
            emptyText:ClearAllPoints()
            emptyText:SetPoint("TOPLEFT", ROW_INDENT, y)
            y = y - ceil(emptyText:GetStringHeight())
        else
            for index, entry in ipairs(entries) do
                rowCount = index
                local row = Acquire(rowPool, index, CreateEntryRow)
                row:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_INDENT, y)
                row.Fill(entry)
                ctx.customUpdaters[#ctx.customUpdaters + 1] = row.glyph.Update
                y = y - ITEM_HEIGHT
            end
        end

        frame:SetHeight(abs(y) + 4)
        ctx.SetCustomExtent(abs(topY) + abs(y) + 4)
    end

    Render()
    return { Render = Render }
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    local soundRow = CreateFrame("Frame", nil, content)
    soundRow:SetSize(contentWidth - COL_PADDING * 2, 26)

    local soundDrop = Components.Dropdown(soundRow, {
        label = L["Externals.Sound"],
        width = 200,
        maxItems = 15,
        options = BR.Sounds.BuildOptions(),
        tooltip = { title = L["Externals.Sound"], desc = L["Externals.Sound.Tooltip"] },
        get = function()
            return Settings().sound or BR.Sounds.NO_SOUND
        end,
        onChange = function(val)
            BR.Config.Set("externals.sound", val ~= BR.Sounds.NO_SOUND and val or nil)
            Components.RefreshAll()
        end,
    })
    soundDrop:SetPoint("LEFT", 0, 0)

    local preview = BR.Options.Helpers.SoundPreviewButton(soundRow, function()
        return Settings().sound
    end)
    preview:SetPoint("LEFT", soundDrop, "RIGHT", 8, 0)

    local soundHint = soundRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    soundHint:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    soundHint:SetPoint("RIGHT", 0, 0)
    soundHint:SetJustifyH("LEFT")
    soundHint:SetWordWrap(false)
    soundHint:SetText(L["Externals.Sound.Hint"])

    layout:Add(soundRow, 26, 16)

    local leftEndY, customExtent = 0, 0

    local ctx = { updaters = {}, customUpdaters = {} }
    function ctx.Repaint()
        for _, Update in ipairs(ctx.updaters) do
            Update()
        end
        for _, Update in ipairs(ctx.customUpdaters) do
            Update()
        end
    end

    ---Called by the custom section whenever its height changes.
    ---@param bottom number Distance from the content top to the section's last row
    function ctx.SetCustomExtent(bottom)
        customExtent = bottom
        content:SetHeight(math.max(abs(leftEndY), customExtent) + 16)
    end

    local colWidth = math.floor((contentWidth - COL_PADDING * 3) / 2)
    local startY = layout:GetY()
    leftEndY = RenderColumn(content, COL_PADDING, startY, LEFT_SECTIONS, colWidth, ctx)
    local rightX = COL_PADDING + colWidth + COL_PADDING
    local rightEndY = RenderColumn(content, rightX, startY, RIGHT_SECTIONS, colWidth, ctx)

    -- Last in the right column: the section grows with every buff the player adds,
    -- and from here that growth only extends the page instead of moving a row above.
    local custom = CreateCustomSection(content, rightX, rightEndY - INTER_SECTION_GAP, colWidth, ctx)

    -- Persistent hook rather than per-widget `enabled`: a glyph is a plain button,
    -- not a component holder, so RefreshAll never reaches it. A re-render of the
    -- custom section here also picks up an entry list a profile switch replaced.
    table.insert(BR.RefreshableComponents, {
        Refresh = function()
            custom.Render()
            ctx.Repaint()
        end,
    })
end

BR.Options.Pages.externals = {
    title = L["Externals.Title"],
    Build = Build,
}

-- Cohort 6.4.0 marks the page itself, 6.7.0 the player's own entries. Static
-- Register (not a provider) because nothing here finishes populating later.
BR.Options.WhatsNew.Register({ cohort = "6.4.0", pageId = "externals" })
BR.Options.WhatsNew.Register({ cohort = "6.7.0", pageId = "externals" })
