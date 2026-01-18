-- BossCoordinates.lua
local addonName, addon = ...
local DBC = addon

-- Coordinate manuali per i Boss nei Dungeon (0-100)
-- [MapID] = { [NpcID] = {x, y, "Note opzionali"} }
DBC.BossCoordinates = {
    -- The Stockade (MapID: 717 - Spesso buggata, usiamo le coordinate relative alla minimappa se possibile)
    [717] = {
        [1696] = {50, 50, "Pattuglia nei corridoi"}, -- Targorr
        [1717] = {38, 58, "Ala sinistra"}, -- Hamhock
        [1716] = {88, 45, "In fondo, cella finale"}, -- Bazil Thredd
        [1663] = {80, 60, "Ala destra"}, -- Dextren Ward
        [1720] = {65, 30, "Piano superiore"}, -- Bruegal Ironknuckle
        [1666] = {20, 50, "Ingresso"}, -- Kam Deepfury
    },
    
    -- Deadmines (MapID: 1581)
    [1581] = {
        [644] = {30, 30, "Stanza dei Goblin"}, -- Rhahk'Zor
        [642] = {45, 45, "Stanza dei Robot"}, -- Sneed
        [643] = {45, 45, "Dentro lo Shredder"}, -- Sneed (Operator)
        [645] = {80, 80, "Sulla nave"}, -- Cookie
        [639] = {90, 90, "Ponte superiore nave"}, -- VanCleef
    }
}
