-- Core.lua
local addonName, addon = ...
local DBC = addon

-- Global DB Access
DBC.DB = nil
DBC.BossDB = {
    instances = {},
    instanceNameIndex = {}, -- normalized instance name -> key
    mapIdIndex = {}, -- mapID -> key
    instanceIdIndex = {}, -- instanceID (from data.lua) -> key
    npcToInstance = {} -- npcID -> key (for fast lookup in combat log)
}

-- Constants
local KEEP_RUNS_DAYS = 14

local function NormalizeName(name)
    if not name then return nil end
    local s = string.lower(tostring(name))
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    s = s:gsub("'", "")
    return s
end

local function SafeName(value)
    if value == nil then return nil end
    if type(value) == "string" then return value end
    if type(value) == "number" then return tostring(value) end
    if type(value) == "function" then
        local ok, res = pcall(value)
        if ok and type(res) == "string" then return res end
    end
    return tostring(value)
end

function DBC:Debug(msg)
    if DBC.DB and DBC.DB.options and DBC.DB.options.debug then
        print("[DBC] " .. msg)
    end
end

-- Event Frame
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...)
    if DBC[event] then
        DBC[event](DBC, ...)
    end
end)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")

-- =========================================================================
-- DATABASE BUILDING
-- =========================================================================
function DBC:FindDataRoot()
    if _G.DBC_Data and next(_G.DBC_Data) then
        return _G.DBC_Data, "DBC_Data"
    end
    if _G.data and type(_G.data) == "table" and next(_G.data) then
        return _G.data, "data"
    end
    if _G.AtlasLoot then
        if _G.AtlasLoot.Data and type(_G.AtlasLoot.Data) == "table" and next(_G.AtlasLoot.Data) then
            return _G.AtlasLoot.Data, "AtlasLoot.Data"
        end
        if _G.AtlasLoot.ItemDB and type(_G.AtlasLoot.ItemDB) == "table" and next(_G.AtlasLoot.ItemDB) then
            return _G.AtlasLoot.ItemDB, "AtlasLoot.ItemDB"
        end
    end
    return nil, nil
end

local function LooksLikeDataTable(tbl)
    if type(tbl) ~= "table" then return false end
    local probe = tbl["Maraudon"] or tbl["Ragefire"] or tbl["WailingCaverns"]
    return type(probe) == "table" and type(probe.items) == "table"
end

local function ProbeTable(root, depth, visited)
    if type(root) ~= "table" or depth <= 0 then return nil end
    if visited[root] then return nil end
    visited[root] = true

    if LooksLikeDataTable(root) then return root end

    for _, v in pairs(root) do
        if type(v) == "table" then
            local found = ProbeTable(v, depth - 1, visited)
            if found then return found end
        end
    end
    return nil
end

local function ResolveDataRoot(root, rootName)
    if LooksLikeDataTable(root) then
        return root, rootName
    end

    if type(root) == "table" then
        local direct = {
            { key = addonName, label = "." .. addonName },
            { key = "data", label = ".data" },
            { key = "Data", label = ".Data" },
            { key = "ItemDB", label = ".ItemDB" },
            { key = "itemDB", label = ".itemDB" },
            { key = "db", label = ".db" },
            { key = "DB", label = ".DB" },
        }

        for _, entry in ipairs(direct) do
            local candidate = root[entry.key]
            if LooksLikeDataTable(candidate) then
                return candidate, (rootName or "data") .. entry.label
            end
        end

        local probed = ProbeTable(root, 3, {})
        if probed then
            return probed, (rootName or "data") .. ".probed"
        end
    end

    return root, rootName
end

function DBC:BuildBossDB()
    local dataRoot, rootName = DBC:FindDataRoot()
    if not dataRoot then
        print("[DBC] Error: data.lua datasource not found.")
        return
    end

    dataRoot, rootName = ResolveDataRoot(dataRoot, rootName)
    if not LooksLikeDataTable(dataRoot) then
        local probed = ProbeTable(_G.AtlasLoot or _G, 5, {})
        if probed then
            dataRoot = probed
            rootName = "global.probed"
        end
    end

    DBC.BossDB = {
        instances = {},
        instanceNameIndex = {},
        mapIdIndex = {},
        instanceIdIndex = {},
        npcToInstance = {}
    }

    local countD, countB = 0, 0

    for key, data in pairs(dataRoot) do
        if type(data) == "table" and data.items then
            local entryName = SafeName(data.name) or key
            local entry = {
                key = key,
                name = entryName,
                aliases = {},
                mapId = data.MapID,
                instanceId = data.InstanceID,
                bosses = {},
                bossByNpcId = {}
            }

            local aliases = {}
            aliases[1] = entryName
            aliases[2] = key
            if type(data.aliases) == "table" then
                for _, a in ipairs(data.aliases) do
                    table.insert(aliases, a)
                end
            elseif type(data.alias) == "string" then
                table.insert(aliases, data.alias)
            end
            for _, a in ipairs(aliases) do
                if a and a ~= "" then
                    table.insert(entry.aliases, a)
                    local norm = NormalizeName(a)
                    if norm then
                        DBC.BossDB.instanceNameIndex[norm] = key
                    end
                end
            end

            if entry.mapId then
                DBC.BossDB.mapIdIndex[entry.mapId] = key
                DBC.BossDB.mapIdIndex[tostring(entry.mapId)] = key
            end
            if entry.instanceId then
                DBC.BossDB.instanceIdIndex[entry.instanceId] = key
                DBC.BossDB.instanceIdIndex[tostring(entry.instanceId)] = key
            end

            local bossIndex = 1
            for _, item in ipairs(data.items) do
                local npcIDs = {}
                if type(item.npcID) == "number" then
                    if item.npcID > 0 then
                        npcIDs[1] = item.npcID
                    end
                elseif type(item.npcID) == "table" then
                    for _, nid in ipairs(item.npcID) do
                        if type(nid) == "number" and nid > 0 then
                            table.insert(npcIDs, nid)
                        end
                    end
                end

                if #npcIDs > 0 and not item.ExtraList then
                    local primaryNpcID = npcIDs[1]
                    local bossName = SafeName(item.name) or "Unknown Boss"
                    local bInfo = {
                        index = bossIndex,
                        npcId = primaryNpcID,
                        name = bossName,
                        optional = (item.optional == true or item.Optional == true),
                        specialType = item.specialType,
                        atlasMapBossId = item.AtlasMapBossID
                    }

                    table.insert(entry.bosses, bInfo)
                    for _, nid in ipairs(npcIDs) do
                        entry.bossByNpcId[nid] = bInfo
                        DBC.BossDB.npcToInstance[nid] = key
                    end

                    bossIndex = bossIndex + 1
                    countB = countB + 1
                end
            end

            if #entry.bosses > 0 then
                DBC.BossDB.instances[key] = entry
                countD = countD + 1
            end
        end
    end

    if countD == 0 and rootName ~= "global.probed" then
        local probed = ProbeTable(_G, 5, {})
        if probed and probed ~= dataRoot then
            dataRoot = probed
            rootName = "global.probed"
            for key, data in pairs(dataRoot) do
                if type(data) == "table" and data.items then
                    local entryName = SafeName(data.name) or key
                    local entry = {
                        key = key,
                        name = entryName,
                        aliases = {},
                        mapId = data.MapID,
                        instanceId = data.InstanceID,
                        bosses = {},
                        bossByNpcId = {}
                    }

                    local aliases = {}
                    aliases[1] = entryName
                    aliases[2] = key
                    if type(data.aliases) == "table" then
                        for _, a in ipairs(data.aliases) do
                            table.insert(aliases, a)
                        end
                    elseif type(data.alias) == "string" then
                        table.insert(aliases, data.alias)
                    end
                    for _, a in ipairs(aliases) do
                        if a and a ~= "" then
                            table.insert(entry.aliases, a)
                            local norm = NormalizeName(a)
                            if norm then
                                DBC.BossDB.instanceNameIndex[norm] = key
                            end
                        end
                    end

                    if entry.mapId then
                        DBC.BossDB.mapIdIndex[entry.mapId] = key
                        DBC.BossDB.mapIdIndex[tostring(entry.mapId)] = key
                    end
                    if entry.instanceId then
                        DBC.BossDB.instanceIdIndex[entry.instanceId] = key
                        DBC.BossDB.instanceIdIndex[tostring(entry.instanceId)] = key
                    end

                    local bossIndex = 1
                    for _, item in ipairs(data.items) do
                        local npcIDs = {}
                        if type(item.npcID) == "number" then
                            if item.npcID > 0 then
                                npcIDs[1] = item.npcID
                            end
                        elseif type(item.npcID) == "table" then
                            for _, nid in ipairs(item.npcID) do
                                if type(nid) == "number" and nid > 0 then
                                    table.insert(npcIDs, nid)
                                end
                            end
                        end

                        if #npcIDs > 0 and not item.ExtraList then
                            local primaryNpcID = npcIDs[1]
                            local bossName = SafeName(item.name) or "Unknown Boss"
                            local bInfo = {
                                index = bossIndex,
                                npcId = primaryNpcID,
                                name = bossName,
                                optional = (item.optional == true or item.Optional == true),
                                specialType = item.specialType,
                                atlasMapBossId = item.AtlasMapBossID
                            }

                            table.insert(entry.bosses, bInfo)
                            for _, nid in ipairs(npcIDs) do
                                entry.bossByNpcId[nid] = bInfo
                                DBC.BossDB.npcToInstance[nid] = key
                            end

                            bossIndex = bossIndex + 1
                            countB = countB + 1
                        end
                    end

                    if #entry.bosses > 0 then
                        DBC.BossDB.instances[key] = entry
                        countD = countD + 1
                    end
                end
            end
        end
    end

    DungeonBossChecklist_BossDB = DBC.BossDB
    DBC.RawData = dataRoot -- Store raw data for loot lookup
    DBC:Debug(string.format("Database built from %s: %d instances, %d bosses.", rootName or "data", countD, countB))
end

-- Retrieves the loot table for a specific boss from the raw data.
-- This function searches the preserved 'dataRoot' (DBC.RawData) for an entry matching the boss's NPC ID.
-- It returns the first table found that resembles a loot list.
function DBC:GetBossLoot(boss)
    if not boss or not DBC.RawData then return nil end
    -- We need to find the original item entry in RawData
    -- We can search by npcID in the instance data
    local key = DBC.BossDB.npcToInstance[boss.npcId]
    if not key then return nil end
    
    local instRaw = DBC.RawData[key]
    if not instRaw or not instRaw.items then return nil end
    
    for _, item in ipairs(instRaw.items) do
        local match = false
        if type(item.npcID) == "number" and item.npcID == boss.npcId then match = true end
        if type(item.npcID) == "table" then
            for _, nid in ipairs(item.npcID) do
                if nid == boss.npcId then match = true break end
            end
        end
        
        if match then
            -- Found the raw entry, return the loot table (usually under a difficulty key like NORMAL_DIFF)
            -- We'll try to find the first table that looks like a loot list
            -- HEURISTIC: Loot tables contains list of items: { {1, 1234}, {2, 5678} }
            -- DisplayIDs is: { {1234} } -> only 1 element
            for k, v in pairs(item) do
                if type(v) == "table" and #v > 0 and type(v[1]) == "table" and v[1][1] then
                    -- Ensure it's a loot entry (has at least index and ID)
                    if #v[1] >= 2 then
                        return v -- Return the first loot list found
                    end
                end
            end
        end
    end
    return nil
end

-- Checks if the given boss name is a target of any active quest in the player's log.
-- Scans all quest log entries and their objectives (leaderboards) for a case-insensitive string match.
function DBC:IsBossQuestObjective(bossName)
    if not bossName then return false end
    local numEntries, numQuests = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, _, isHeader, _, _, _, _, questID = GetQuestLogTitle(i)
        if not isHeader then
            local numObjectives = GetNumQuestLeaderBoards(i)
            for j = 1, numObjectives do
                local text, type, finished = GetQuestLogLeaderBoard(j, i)
                if not finished and text then
                    -- Simple check: does objective text contain boss name?
                    -- This covers "Kill BossName" and "Loot Item from BossName" usually
                    if string.find(string.lower(text), string.lower(bossName), 1, true) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- =========================================================================
-- UTILS: GUID & STATE
-- =========================================================================
function DBC:ParseNpcGuid(guid)
    if not guid then return nil, nil end
    -- GUID format: Creature-0-serverID-instanceID-zoneUID-npcID-spawnUID
    local unitType, _, _, instanceID, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(instanceID), tonumber(npcID), unitType
    end
    return nil, nil
end

function DBC:IsDungeonInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "party"
end

function DBC:GetPendingRunKey(instanceKey)
    return "pending:" .. tostring(instanceKey)
end

function DBC:EnsureRunContext(instanceKey, instanceID)
    if not instanceKey then return end

    -- 1. If we have a definitive ID, save it as the active run for this map
    if instanceID then
        DBC.DB.activeRuns = DBC.DB.activeRuns or {}
        DBC.DB.activeRuns[instanceKey] = instanceID
    end

    -- 2. If no ID provided (e.g. login/reload), try to restore the last active one
    if not instanceID then
        local savedID = DBC.DB.activeRuns and DBC.DB.activeRuns[instanceKey]
        if savedID then
            local savedRun = DBC.DB.runs[tostring(savedID)]
            -- Resume only if run exists and was active recently (e.g. < 4 hours) to avoid stale data
            -- Classic dungeon clears can take time, 4 hours (14400s) is safe.
            if savedRun and (time() - (savedRun.lastSeenAt or 0) < 14400) then
                instanceID = savedID
                DBC:Debug("Resuming persisted run: " .. instanceID)
            end
        end
    end

    if instanceID then
        local runKey = tostring(instanceID)
        local run = DBC.DB.runs[runKey]

        if not run then
            local pendingKey = DBC:GetPendingRunKey(instanceKey)
            if DBC.DB.runs[pendingKey] then
                run = DBC.DB.runs[pendingKey]
                DBC.DB.runs[pendingKey] = nil
                run.pending = nil
            else
                run = { instanceName = instanceKey, startedAt = time(), killed = {} }
            end
            run.instanceName = instanceKey
            DBC.DB.runs[runKey] = run
            DBC:Debug("New run detected: " .. runKey .. " (" .. instanceKey .. ")")
        end

        run.lastSeenAt = time()
        DBC.CurrentRun = run
        DBC.CurrentInstanceID = runKey
        DBC.CurrentRunKey = runKey
    else
        local pendingKey = DBC:GetPendingRunKey(instanceKey)
        local run = DBC.DB.runs[pendingKey]
        if not run then
            run = { instanceName = instanceKey, startedAt = time(), killed = {}, pending = true }
            DBC.DB.runs[pendingKey] = run
            DBC:Debug("Pending run created for " .. instanceKey)
        end
        run.lastSeenAt = time()
        DBC.CurrentRun = run
        DBC.CurrentInstanceID = nil
        DBC.CurrentRunKey = pendingKey
    end
end

function DBC:InitializeRun(instanceID, instanceKey)
    if not instanceID then return end
    DBC:EnsureRunContext(instanceKey, instanceID)
end

function DBC:GetTotalAndKilled(instanceKey)
    if not instanceKey then return 0, 0 end
    local instData = DBC.BossDB.instances[instanceKey]
    if not instData then return 0, 0 end

    local total = #instData.bosses
    local killed = 0
    
    if DBC.CurrentRun and DBC.CurrentRun.killed then
        for _, boss in ipairs(instData.bosses) do
            if DBC.CurrentRun.killed[boss.npcId] then
                killed = killed + 1
            end
        end
    end
    return killed, total
end

function DBC:GetRemainingBossNames(instanceKey)
    return DBC:GetRemainingBossNamesWithFilter(instanceKey, true)
end

function DBC:IsSpecialBoss(boss)
    return boss and boss.specialType ~= nil
end

function DBC:GetRemainingBossNamesWithFilter(instanceKey, includeSpecial)
    local instData = instanceKey and DBC.BossDB.instances[instanceKey]
    if not instData or not DBC.CurrentRun then return {} end

    local remaining = {}
    for _, boss in ipairs(instData.bosses) do
        if not DBC.CurrentRun.killed[boss.npcId] then
            if includeSpecial or not DBC:IsSpecialBoss(boss) then
                table.insert(remaining, boss.name)
            end
        end
    end
    return remaining
end

function DBC:GetRemainingSpecialBossNames(instanceKey)
    local instData = instanceKey and DBC.BossDB.instances[instanceKey]
    if not instData or not DBC.CurrentRun then return {} end

    local remaining = {}
    for _, boss in ipairs(instData.bosses) do
        if DBC:IsSpecialBoss(boss) and not DBC.CurrentRun.killed[boss.npcId] then
            table.insert(remaining, boss.name)
        end
    end
    return remaining
end

function DBC:GetCounts(instanceKey)
    local instData = instanceKey and DBC.BossDB.instances[instanceKey]
    if not instData then return 0, 0, 0, 0 end

    local mainTotal, mainKilled = 0, 0
    local specialTotal, specialKilled = 0, 0

    for _, boss in ipairs(instData.bosses) do
        if DBC:IsSpecialBoss(boss) then
            specialTotal = specialTotal + 1
            if DBC.CurrentRun and DBC.CurrentRun.killed[boss.npcId] then
                specialKilled = specialKilled + 1
            end
        else
            mainTotal = mainTotal + 1
            if DBC.CurrentRun and DBC.CurrentRun.killed[boss.npcId] then
                mainKilled = mainKilled + 1
            end
        end
    end

    return mainKilled, mainTotal, specialKilled, specialTotal
end

-- =========================================================================
-- LOGIC: KILL TRACKING
-- =========================================================================
function DBC:SetBossKilled(npcID, isKilled, isManual)
    if not DBC.CurrentRun then
        if DBC.CurrentInstanceKey then
            DBC:EnsureRunContext(DBC.CurrentInstanceKey, nil)
        end
    end
    if not DBC.CurrentRun then return end
    
    local wasKilled = DBC.CurrentRun.killed[npcID]
    
    -- Only act if state changes
    if wasKilled ~= isKilled then
        DBC.CurrentRun.killed[npcID] = isKilled
        DBC.CurrentRun.lastSeenAt = time()
        DBC.CurrentRun.lastSeenByNpcId = DBC.CurrentRun.lastSeenByNpcId or {}

        if isKilled then
            local subzone = GetSubZoneText and GetSubZoneText() or ""
            local zone = GetZoneText and GetZoneText() or ""
            if subzone and subzone ~= "" then
                DBC.CurrentRun.lastSeenByNpcId[npcID] = subzone
            elseif zone and zone ~= "" then
                DBC.CurrentRun.lastSeenByNpcId[npcID] = zone
            end
        end

        if isManual then
            DBC:Debug("Manual toggle npcID " .. npcID .. " -> " .. tostring(isKilled))
        end
        
        -- Logic for Party Chat
        if isKilled and DBC.DB.options.enablePartyLog and IsInGroup() then
            -- Avoid spam: only notify if it was alive before
            DBC:SendProgressToParty(npcID)
        end
        
        DBC:UpdateUI()
    end
end

function DBC:SendProgressToParty(triggerNpcID)
    if not DBC.CurrentInstanceKey then return end
    local instData = DBC.BossDB.instances[DBC.CurrentInstanceKey]
    
    local bossEntry = instData.bossByNpcId[triggerNpcID]
    local bossName = bossEntry and bossEntry.name or "Unknown Boss"

    local includeSpecial = DBC.DB.options.partyLogIncludeSpecial ~= false
    local remainingNames = DBC:GetRemainingBossNamesWithFilter(DBC.CurrentInstanceKey, includeSpecial)
    local remainingSpecial = includeSpecial and {} or DBC:GetRemainingSpecialBossNames(DBC.CurrentInstanceKey)

    local msg
    if #remainingNames == 0 then
        if includeSpecial or #remainingSpecial == 0 then
            msg = string.format("We just killed %s. All bosses cleared!", bossName)
        else
            msg = string.format("We just killed %s. All main bosses cleared! Special remaining: %s",
                bossName, table.concat(remainingSpecial, ", "))
        end
    else
        local remStr = table.concat(remainingNames, ", ")
        msg = string.format("We just killed %s. %d bosses remaining: %s", bossName, #remainingNames, remStr)
    end

    DBC:Debug("Sending party log: " .. msg)
    SendChatMessage(msg, "PARTY")
end

function DBC:PruneOldRuns(forceReport)
    local cutoff = time() - (KEEP_RUNS_DAYS * 24 * 3600)
    local count = 0
    for id, run in pairs(DBC.DB.runs) do
        if run.lastSeenAt < cutoff then
            DBC.DB.runs[id] = nil
            count = count + 1
        end
    end
    if count > 0 then
        if forceReport then
            print("[DBC] Pruned " .. count .. " old runs.")
        else
            DBC:Debug("Pruned " .. count .. " old runs.")
        end
    end
end

-- =========================================================================
-- DYNAMIC RARE MOB DETECTION
-- =========================================================================
function DBC:CheckForRareMob(unit)
    if not unit or not DBC.CurrentInstanceKey then return end
    if not DBC.RareMobs then return end -- No data loaded
    
    local guid = UnitGUID(unit)
    if not guid then return end
    
    local instID, npcID, unitType = DBC:ParseNpcGuid(guid)
    if not npcID then return end
    
    -- Check if it's a known rare
    local rareName = DBC.RareMobs[npcID]
    if rareName then
        local instData = DBC.BossDB.instances[DBC.CurrentInstanceKey]
        
        -- Check if already in list
        if not instData.bossByNpcId[npcID] then
            -- Add dynamically!
            DBC:Debug("Discovered new rare mob: " .. rareName)
            
            local newBoss = {
                index = #instData.bosses + 1,
                npcId = npcID,
                name = rareName,
                specialType = "rare"
            }
            
            table.insert(instData.bosses, newBoss)
            instData.bossByNpcId[npcID] = newBoss
            DBC.BossDB.npcToInstance[npcID] = DBC.CurrentInstanceKey
            
            -- Sort by index (or keep at bottom)
            DBC:UpdateUI()
        end
    end
end

function DBC:PLAYER_TARGET_CHANGED()
    DBC:CheckForRareMob("target")
end

function DBC:UPDATE_MOUSEOVER_UNIT()
    DBC:CheckForRareMob("mouseover")
end

function DBC:NAME_PLATE_UNIT_ADDED(unit)
    DBC:CheckForRareMob(unit)
end

-- =========================================================================
-- EVENTS
-- =========================================================================
function DBC:ADDON_LOADED(name)
    if name ~= addonName then return end
    
    -- Init SavedVars
    DungeonBossChecklistDB = DungeonBossChecklistDB or {
        runs = {},
        activeRuns = {}, -- Maps instanceKey -> last known numeric instanceID
        ui = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, shown = true },
        options = {
            enablePartyLog = true,
            partyLogIncludeSpecial = true,
            showSpecialBosses = true,
            showMinimapPins = true,
            showWorldMapPins = false,
            pinSize = 12,
            debug = false,
            version = "1.0.0"
        },
        schemaVersion = 1
    }
    DBC.DB = DungeonBossChecklistDB

    if not DBC.DB.activeRuns then DBC.DB.activeRuns = {} end
    if DBC.DB.options.enablePartyLog == nil then DBC.DB.options.enablePartyLog = true end
    if DBC.DB.options.partyLogIncludeSpecial == nil then DBC.DB.options.partyLogIncludeSpecial = true end
    if DBC.DB.options.showSpecialBosses == nil then DBC.DB.options.showSpecialBosses = true end
    if DBC.DB.options.showMinimapPins == nil then DBC.DB.options.showMinimapPins = true end
    if DBC.DB.options.showWorldMapPins == nil then DBC.DB.options.showWorldMapPins = false end
    if DBC.DB.options.pinSize == nil then DBC.DB.options.pinSize = 12 end
    if DBC.DB.options.debug == nil then DBC.DB.options.debug = false end

    local tocVersion = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")
    if tocVersion and tocVersion ~= "" then
        DBC.DB.options.version = tocVersion
    end
    
    DBC:BuildBossDB()
    DBC:PruneOldRuns()
    DBC:InitUI()
    DBC:InitOptions()
    
    print("|cff00ff00[DBC]|r loaded. Type /dbc for options.")
end

function DBC:InjectDungeonRares(instanceKey, mapID)
    if not instanceKey or not mapID or not DBC.DungeonRares then return end
    
    local rares = DBC.DungeonRares[mapID]
    if not rares then return end
    
    local instData = DBC.BossDB.instances[instanceKey]
    if not instData then return end
    
    for _, rare in ipairs(rares) do
        -- Check if already exists by ID to avoid duplicates
        if not instData.bossByNpcId[rare.id] then
            DBC:Debug("Injecting known rare: " .. rare.name .. " (" .. rare.id .. ")")
            
            local newBoss = {
                index = #instData.bosses + 1,
                npcId = rare.id,
                name = rare.name,
                optional = true,
                specialType = "rare" -- Triggers rare icon in UI
            }
            
            table.insert(instData.bosses, newBoss)
            instData.bossByNpcId[rare.id] = newBoss
            DBC.BossDB.npcToInstance[rare.id] = instanceKey
        end
    end
end

function DBC:UpdateContext()
    if not DBC:IsDungeonInstance() then
        DBC.CurrentInstanceKey = nil
        DBC.CurrentInstanceID = nil
        DBC.CurrentRun = nil
        DBC.CurrentRunKey = nil
        DBC:UpdateUI()
        return
    end

    local name, _, _, _, _, _, _, instanceIdOrMapId, _, lfgDungeonID = GetInstanceInfo()
    local newKey = nil
    local instanceToken = instanceIdOrMapId
    local instanceTokenNum = instanceToken and tonumber(instanceToken) or nil

    if instanceToken and DBC.BossDB.instanceIdIndex[instanceToken] then
        newKey = DBC.BossDB.instanceIdIndex[instanceToken]
    elseif instanceTokenNum and DBC.BossDB.instanceIdIndex[instanceTokenNum] then
        newKey = DBC.BossDB.instanceIdIndex[instanceTokenNum]
    elseif instanceToken and DBC.BossDB.mapIdIndex[instanceToken] then
        newKey = DBC.BossDB.mapIdIndex[instanceToken]
    elseif instanceTokenNum and DBC.BossDB.mapIdIndex[instanceTokenNum] then
        newKey = DBC.BossDB.mapIdIndex[instanceTokenNum]
    elseif name then
        local normName = NormalizeName(name)
        if normName and DBC.BossDB.instanceNameIndex[normName] then
            newKey = DBC.BossDB.instanceNameIndex[normName]
        end
    end

    if not newKey and C_Map and C_Map.GetBestMapForUnit then
        local playerMapId = C_Map.GetBestMapForUnit("player")
        if playerMapId and (DBC.BossDB.mapIdIndex[playerMapId] or DBC.BossDB.mapIdIndex[tostring(playerMapId)]) then
            newKey = DBC.BossDB.mapIdIndex[playerMapId] or DBC.BossDB.mapIdIndex[tostring(playerMapId)]
        end
    end

    DBC.CurrentInstanceKey = newKey

    if newKey then
        -- Inject static rares using the MapID from our own DB (more reliable than C_Map inside dungeons)
        local instData = DBC.BossDB.instances[newKey]
        if instData and instData.mapId then
            DBC:InjectDungeonRares(newKey, instData.mapId)
        end

        if DBC.CurrentInstanceID and DBC.CurrentRun then
            DBC.CurrentRun.lastSeenAt = time()
        else
            DBC:EnsureRunContext(newKey, nil)
        end
        DBC:Debug("Dungeon detected: " .. newKey)
    else
        DBC.CurrentInstanceID = nil
        DBC.CurrentRun = nil
        DBC.CurrentRunKey = nil
        if DBC.DB and DBC.DB.options and DBC.DB.options.debug then
            local playerMapId = (C_Map and C_Map.GetBestMapForUnit) and C_Map.GetBestMapForUnit("player") or nil
            DBC:Debug(string.format("Dungeon detection failed. name=%s instanceIdOrMapId=%s (%s) playerMapId=%s lfgID=%s",
                tostring(name), tostring(instanceIdOrMapId), type(instanceIdOrMapId), tostring(playerMapId), tostring(lfgDungeonID)))
        else
            DBC:Debug("Dungeon detection failed.")
        end
    end

    DBC:UpdateUI()
end

function DBC:PLAYER_ENTERING_WORLD()
    DBC:UpdateContext()
end

function DBC:ZONE_CHANGED_NEW_AREA()
    DBC:UpdateContext()
end

function DBC:GROUP_ROSTER_UPDATE()
    -- Only needed if we want to auto-disable options, but we check IsInGroup at send time.
end

function DBC:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    
    if subEvent == "UNIT_DIED" or subEvent == "PARTY_KILL" then
        if not DBC:IsDungeonInstance() then return end

        local instID, npcID, unitType = DBC:ParseNpcGuid(destGUID)
        if not instID or not npcID then return end

        local key = DBC.BossDB.npcToInstance[npcID]
        if not key then return end

        DBC:EnsureRunContext(key, instID)
        DBC.CurrentInstanceKey = key

        local instData = DBC.BossDB.instances[key]
        local bossEntry = instData and instData.bossByNpcId[npcID]
        if bossEntry then
            local st = bossEntry.specialType and (" type=" .. tostring(bossEntry.specialType)) or ""
            DBC:Debug("Boss killed: " .. (destName or bossEntry.name) .. " (" .. npcID .. ", " .. (unitType or "unknown") .. ")" .. st)
            DBC:SetBossKilled(bossEntry.npcId, true, false)
        end
    end
end