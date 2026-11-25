local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- PIXEL GRID
-- Icon sizes, borders, gaps and anchors snap to whole screen pixels. An edge between
-- two pixels rounds either way, so without the snap a gap of N can render as N - 1
-- or N + 1 at a UI scale that is not pixel-perfect.
-- ============================================================================

local floor, max = math.floor, math.max
local GetPhysicalScreenSize = GetPhysicalScreenSize

local Pixels = {}

local lastPhysicalHeight = 1080

---Size of one screen pixel in UI units at the effective scale of a frame.
---@param frame table
---@return number
local function OnePixel(frame)
    -- The physical height reads 0 during a display mode change.
    local _, physicalHeight = GetPhysicalScreenSize()
    if physicalHeight and physicalHeight > 0 then
        lastPhysicalHeight = physicalHeight
    end
    local scale = frame:GetEffectiveScale()
    if not scale or scale <= 0 then
        return 1
    end
    return 768 / (lastPhysicalHeight * scale)
end

---@param length number UI units
---@param onePixel number
---@return boolean
local function IsOddPixels(length, onePixel)
    return floor(length / onePixel + 0.5) % 2 == 1
end

---Snap a distance to whole screen pixels, in UI units. A positive value keeps at least one
---pixel. A negative pixel count stays negative: a negative spacing overlaps the icons.
---@param value number Distance in UI units, or in screen pixels with inPixels
---@param frame table Frame whose effective scale applies
---@param inPixels? boolean The value counts screen pixels: spacing and border widths
---@return number
function Pixels.Snap(value, frame, inPixels)
    if inPixels and value < 0 then
        return floor(value + 0.5) * OnePixel(frame)
    end
    if value <= 0 then
        return 0
    end
    local onePixel = OnePixel(frame)
    if inPixels then
        return max(1, floor(value + 0.5)) * onePixel
    end
    -- The epsilon keeps a value near a half-pixel boundary on the same side across reloads.
    return max(1, floor(value / onePixel + 0.5 + 0.001)) * onePixel
end

---Round a coordinate or an offset to the nearest whole screen pixel, in UI units.
---@param value number UI units
---@param frame table Frame whose effective scale applies
---@return number
function Pixels.Round(value, frame)
    local onePixel = OnePixel(frame)
    return floor(value / onePixel + 0.5) * onePixel
end

---Offset that keeps a centered inner frame on whole pixels: half a pixel when the outer
---and inner lengths differ by an odd number of pixels, else 0.
---@param outerLength number UI units
---@param innerLength number UI units
---@param frame table Frame whose effective scale applies
---@return number
function Pixels.CenterOffset(outerLength, innerLength, frame)
    local onePixel = OnePixel(frame)
    if IsOddPixels(outerLength - innerLength, onePixel) then
        return onePixel / 2
    end
    return 0
end

---Snap one anchor offset from the UIParent center. The edges land on whole pixels when
---the half-pixel parts of the parent center and of the frame half length cancel out.
---@param offset number UI units
---@param length number Frame length on this axis, UI units
---@param centered boolean The anchor point lies in the middle of this axis
---@param parentOdd boolean The UIParent length on this axis is an odd number of pixels
---@param onePixel number
---@return number
local function AlignOffset(offset, length, centered, parentOdd, onePixel)
    local pixels = offset / onePixel
    if (centered and IsOddPixels(length, onePixel)) ~= parentOdd then
        return (floor(pixels) + 0.5) * onePixel
    end
    return floor(pixels + 0.5) * onePixel
end

---Anchor a sized container to the UIParent center so that its edges land on whole pixels.
---@param frame table
---@param point string Anchor point of the container
---@param x number Offset in UI units
---@param y number Offset in UI units
function Pixels.SetPoint(frame, point, x, y)
    local onePixel = OnePixel(frame)
    local width, height = frame:GetSize()
    local parentWidth, parentHeight = UIParent:GetSize()
    local centeredX = not point:find("LEFT") and not point:find("RIGHT")
    local centeredY = not point:find("TOP") and not point:find("BOTTOM")
    frame:SetPoint(
        point,
        UIParent,
        "CENTER",
        AlignOffset(x, width, centeredX, IsOddPixels(parentWidth, onePixel), onePixel),
        AlignOffset(y, height, centeredY, IsOddPixels(parentHeight, onePixel), onePixel)
    )
end

BR.Pixels = Pixels
