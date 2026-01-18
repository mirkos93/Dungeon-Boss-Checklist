-- Compat.lua
-- Mocks the AtlasLoot environment to allow loading data.lua standalone.

local addonName = ...
_G.AtlasLoot = _G.AtlasLoot or {}
local AL = _G.AtlasLoot

-- Mock Tables
AL.ItemDB = {}
AL.Locales = setmetatable({}, { __index = function(t,k) return k end })
AL.IngameLocales = setmetatable({}, { __index = function(t,k) return k end })

local contentTypeCounter = 0

-- Mock Versions
AL.CLASSIC_VERSION_NUM = 1
AL.BC_VERSION_NUM = 2
AL.WRATH_VERSION_NUM = 3

-- Global Data Container (this will hold the data populated by data.lua)
_G.DBC_Data = {}

-- Mock Functions
function AL.ReturnForGameVersion(a, b)
    -- Simply return the first argument (Classic)
    if type(a) == "table" then return a[1] end
    return a
end

function AL:GameVersion_GE(ver, t)
    if ver > AL.CLASSIC_VERSION_NUM then
        -- Return a dummy object to preserve table structure (ipairs) but mark for ignore
        return { npcID = -999, name = "IGNORE" }
    end
    return t
end

function AL:GameVersion_LT(ver, t, f)
    if ver > AL.CLASSIC_VERSION_NUM then
        return t
    end
    return f
end

-- Mock ItemDB:Add
function AL.ItemDB:Add(name, ...)
    local t = _G.DBC_Data
    
    -- Mock methods called on the data object
    function t:AddDifficulty(...) return 1 end
    function t:AddItemTableType(...) return 1 end
    function t:AddExtraItemTableType(...) return 1 end
    function t:AddContentType(label, ...)
        contentTypeCounter = contentTypeCounter + 1
        t.__contentTypes = t.__contentTypes or {}
        if label == "Dungeons" then
            t.__contentTypes.dungeon = contentTypeCounter
        elseif label == "20 Raids" then
            t.__contentTypes.raid20 = contentTypeCounter
        elseif label == "40 Raids" then
            t.__contentTypes.raid40 = contentTypeCounter
        end
        return contentTypeCounter
    end
    
    return t
end

-- Mock Global functions that might be used
if not _G.UnitFactionGroup then
    _G.UnitFactionGroup = function() return "Alliance" end -- Default to Alliance if not available (should be avail in WoW)
end

if not _G.getfenv then
    _G.getfenv = function() return _G end
end

-- AtlasLoot item field constants used as table keys
_G.ATLASLOOT_IT_AMOUNT1 = _G.ATLASLOOT_IT_AMOUNT1 or "ATLASLOOT_IT_AMOUNT1"
_G.ATLASLOOT_IT_ALLIANCE = _G.ATLASLOOT_IT_ALLIANCE or "ATLASLOOT_IT_ALLIANCE"
_G.ATLASLOOT_IT_HORDE = _G.ATLASLOOT_IT_HORDE or "ATLASLOOT_IT_HORDE"

-- Backwards-compatible Options API shim (Classic Era variants)
if not _G.InterfaceOptions_AddCategory and _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    _G.InterfaceOptions_AddCategory = function(panel)
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name or "AddOn")
        Settings.RegisterAddOnCategory(category)
        return category
    end
end
