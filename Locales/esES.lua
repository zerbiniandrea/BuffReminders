local _, BR = ... -- luacheck: ignore 211
-- If you add real translations, uncomment the next line. Then the Language setting lists this locale.
-- BR.translatedLocales.esES = "Español (España)"
if BR.locale ~= "esES" then
    return
end

local L = BR.L -- luacheck: ignore 211

-- Translate below. Missing entries fall back to English automatically.
-- See Locales/enUS.lua for all available keys and their English values.
-- Example: L["Category.Raid"] = "Your Translation"
