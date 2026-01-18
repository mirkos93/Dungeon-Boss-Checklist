-- UI.lua
local addonName, addon = ...
local DBC = addon

local MAIN_WIDTH = 260
local ROW_HEIGHT = 20
local HEADER_HEIGHT = 16
local MAX_VISIBLE_ROWS = 12

function DBC:InitUI()
    -- Main Frame
    local f = CreateFrame("Frame", "DungeonBossChecklistFrame", UIParent, "BackdropTemplate")
    f:SetSize(MAIN_WIDTH, (MAX_VISIBLE_ROWS * ROW_HEIGHT) + 40)
    f:SetPoint(DBC.DB.ui.point, UIParent, DBC.DB.ui.relativePoint, DBC.DB.ui.x, DBC.DB.ui.y)
    f:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogFrame-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Movable
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    f.TitleBar = CreateFrame("Frame", nil, f)
    f.TitleBar:SetPoint("TOPLEFT", 4, -4)
    f.TitleBar:SetPoint("TOPRIGHT", -4, -4)
    f.TitleBar:SetHeight(20)
    f.TitleBar:EnableMouse(true)
    f.TitleBar:RegisterForDrag("LeftButton")
    f.TitleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    f.TitleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        DBC.DB.ui.point = point
        DBC.DB.ui.relativePoint = relPoint
        DBC.DB.ui.x = x
        DBC.DB.ui.y = y
    end)
    
    -- Title
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Title:SetPoint("TOP", 10, -8) -- Shifted slightly to the right to make room for icon
    f.Title:SetText("DBC")
    
    -- Addon Icon in UI
    f.HeaderIcon = f:CreateTexture(nil, "OVERLAY")
    f.HeaderIcon:SetSize(20, 20)
    f.HeaderIcon:SetPoint("RIGHT", f.Title, "LEFT", -5, 0)
    f.HeaderIcon:SetTexture("Interface\\AddOns\\DungeonBossChecklist\\icon.png")
    
    -- Subtitle (Instance Info)
    f.Info = f:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
    f.Info:SetPoint("TOP", 0, -22)
    f.Info:SetText("No Instance")
    
    -- Compact Toggle Button
    local btnCompact = CreateFrame("Button", nil, f)
    btnCompact:SetSize(16, 16)
    btnCompact:SetPoint("TOPRIGHT", -8, -8)
    btnCompact:SetNormalTexture("Interface\Buttons\UI-Panel-CollapseButton-Up")
    btnCompact:SetPushedTexture("Interface\Buttons\UI-Panel-CollapseButton-Down")
    btnCompact:SetHighlightTexture("Interface\Buttons\UI-Panel-MinimizeButton-Highlight")
    btnCompact:SetScript("OnClick", function()
        DBC.DB.ui.compact = not DBC.DB.ui.compact
        DBC:UpdateUI()
    end)
    f.BtnCompact = btnCompact

    -- Announce Button
    local btnAnnounce = CreateFrame("Button", nil, f)
    btnAnnounce:SetSize(16, 16)
    btnAnnounce:SetPoint("TOPRIGHT", btnCompact, "TOPLEFT", -2, 0)
    btnAnnounce:SetNormalTexture("Interface\Buttons\UI-GuildButton-PublicNote-Up")
    btnAnnounce:SetScript("OnClick", function()
        DBC:AnnounceRemaining()
    end)
    btnAnnounce:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Announce Remaining Bosses")
        GameTooltip:Show()
    end)
    btnAnnounce:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.BtnAnnounce = btnAnnounce

    -- ScrollFrame
    f.Scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.Scroll:SetPoint("TOPLEFT", 10, -40)
    f.Scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Content Container
    f.Content = CreateFrame("Frame", nil, f.Scroll)
    f.Content:SetSize(MAIN_WIDTH - 40, 1) -- Height updated dynamically
    f.Scroll:SetScrollChild(f.Content)
    
    f.Checkboxes = {}
    f.Headers = {}
    
    DBC.UIFrame = f
    
    -- Commands
    SLASH_DBC1 = "/dbc"
    SlashCmdList["DBC"] = function(msg)
        local cmd = string.lower(strtrim(msg or ""))
        if cmd == "show" then
            DBC.DB.ui.shown = true
            DBC:UpdateUI()
        elseif cmd == "hide" then
            DBC.DB.ui.shown = false
            DBC:UpdateUI()
        elseif cmd == "reset" then
            if DBC.CurrentInstanceKey and not DBC.CurrentRun then
                DBC:EnsureRunContext(DBC.CurrentInstanceKey, nil)
            end
            if DBC.CurrentRun then
                DBC.CurrentRun.killed = {}
                DBC:UpdateUI()
                print("[DBC] Run reset.")
            end
        elseif cmd == "options" then
            if DBC.OptionsFrame then InterfaceOptionsFrame_OpenToCategory(DBC.OptionsFrame) end
        elseif cmd == "debug on" then
            DBC.DB.options.debug = true
            print("[DBC] Debug ON")
            DBC:UpdateUI()
        elseif cmd == "debug off" then
            DBC.DB.options.debug = false
            print("[DBC] Debug OFF")
            DBC:UpdateUI()
        elseif cmd == "prune" then
            DBC:PruneOldRuns(true)
        else
            -- Toggle
            DBC.DB.ui.shown = not DBC.DB.ui.shown
            DBC:UpdateUI()
        end
    end
    
    DBC:UpdateUI()
end

function DBC:GetCheckbox(index)
    if not DBC.UIFrame.Checkboxes[index] then
        local cb = CreateFrame("Button", nil, DBC.UIFrame.Content)
        cb:SetSize(MAIN_WIDTH - 40, ROW_HEIGHT)
        
        -- Icon (Skull/Check)
        cb.Icon = cb:CreateTexture(nil, "ARTWORK")
        cb.Icon:SetSize(14, 14)
        cb.Icon:SetPoint("LEFT", 0, 0)
        
        -- Text
        cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
        cb.Text:SetPoint("LEFT", cb.Icon, "RIGHT", 5, 0)
        cb.Text:SetPoint("RIGHT", 0, 0)
        
        -- Quest Icon
        cb.QuestIcon = cb:CreateTexture(nil, "OVERLAY")
        cb.QuestIcon:SetSize(12, 12)
        cb.QuestIcon:SetPoint("RIGHT", cb, "RIGHT", -2, 0)
        cb.QuestIcon:SetTexture("Interface\GossipFrame\ActiveQuestIcon")
        cb.QuestIcon:Hide()

        cb:SetScript("OnClick", function(self)
            if self.npcID then
                local isKilled = not self.isKilled
                DBC:SetBossKilled(self.npcID, isKilled, true)
            end
        end)
        
        cb:SetScript("OnEnter", function(self)
            if self.bossData and self.instData then
                DBC:ShowBossTooltip(self, self.instData, self.bossData)
            end
            self.Text:SetTextColor(1, 1, 1)
        end)
        
        cb:SetScript("OnLeave", function(self)
            DBC:HideBossTooltip()
            if self.isKilled then
                self.Text:SetTextColor(0.5, 0.5, 0.5)
            else
                self.Text:SetTextColor(1, 0.82, 0)
            end
        end)
        
        DBC.UIFrame.Checkboxes[index] = cb
    end
    return DBC.UIFrame.Checkboxes[index]
end

function DBC:GetHeader(index)
    if not DBC.UIFrame.Headers[index] then
        local h = DBC.UIFrame.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetTextColor(0.7, 0.7, 0.7)
        DBC.UIFrame.Headers[index] = h
    end
    return DBC.UIFrame.Headers[index]
end

function DBC:AnnounceRemaining()
    if not DBC.CurrentInstanceKey then return end
    if not IsInGroup() then 
        print("[DBC] Not in a group.")
        return 
    end
    
    local remaining = DBC:GetRemainingBossNamesWithFilter(DBC.CurrentInstanceKey, true)
    local msg
    if #remaining == 0 then
        msg = "[DBC] All bosses cleared!"
    else
        local list = table.concat(remaining, ", ")
        msg = string.format("[DBC] Remaining: %s", list)
    end
    SendChatMessage(msg, "PARTY")
end

function DBC:ShowBossTooltip(owner, instData, boss)
    if not boss or not instData then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(boss.name, 1, 1, 1)
    
    if boss.specialType then
        local typeName = (boss.specialType == "rare" and "Rare") or (boss.specialType == "quest" and "Quest") or "Special"
        GameTooltip:AddLine(typeName, 0.4, 0.8, 1)
    end
    
    -- Loot
    local lootTable = DBC:GetBossLoot(boss)
    if lootTable then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Loot Table:", 1, 0.82, 0)
        local count = 0
        for _, entry in ipairs(lootTable) do
            if count >= 10 then 
                GameTooltip:AddLine("...and more", 0.6, 0.6, 0.6) 
                break 
            end
            
            -- Entry format in AtlasLoot data: { index, itemID/string, ... }
            local itemID = entry[2]
            if type(itemID) == "number" then
                local name, link, quality = GetItemInfo(itemID)
                if name then
                    local r, g, b = GetItemQualityColor(quality or 1)
                    GameTooltip:AddLine(name, r, g, b)
                else
                    GameTooltip:AddLine("Item #"..itemID, 0.6, 0.6, 0.6)
                end
                count = count + 1
            elseif type(itemID) == "string" and string.sub(itemID, 1, 3) == "INV" then
                -- Icon/Header spacer, ignore
            end
        end
        if count == 0 then
            GameTooltip:AddLine("Retrieving item info...", 0.6, 0.6, 0.6)
        end
    else
        GameTooltip:AddLine("No loot data available.", 0.5, 0.5, 0.5)
    end
    
    GameTooltip:Show()
end

function DBC:HideBossTooltip()
    GameTooltip:Hide()
end

function DBC:UpdateUI()
    if not DBC.DB.ui.shown or not DBC.CurrentInstanceKey then
        DBC.UIFrame:Hide()
        return
    end
    
    local key = DBC.CurrentInstanceKey
    local instData = DBC.BossDB.instances[key]
    if not instData then
        DBC.UIFrame:Hide()
        return
    end

    DBC.UIFrame:Show()
    
    -- Reset rows
    for _, cb in pairs(DBC.UIFrame.Checkboxes) do
        cb:Hide()
    end
    for _, h in pairs(DBC.UIFrame.Headers) do
        h:Hide()
    end
    
    local mainKilled, mainTotal, specialKilled, specialTotal = DBC:GetCounts(key)
    local totalKilled = mainKilled + specialKilled
    local totalCount = mainTotal + specialTotal
    
    DBC.UIFrame.Title:SetText(instData.name)
    DBC.UIFrame.Info:SetText(string.format("%d / %d Bosses", totalKilled, totalCount))
    
    -- Compact Mode
    if DBC.DB.ui.compact then
        DBC.UIFrame:SetHeight(50)
        DBC.UIFrame.Scroll:Hide()
        DBC.UIFrame.BtnCompact:SetNormalTexture("Interface\Buttons\UI-Panel-ExpandButton-Up")
        return
    else
        DBC.UIFrame.Scroll:Show()
        DBC.UIFrame.BtnCompact:SetNormalTexture("Interface\Buttons\UI-Panel-CollapseButton-Up")
    end

    local yOffset = 0
    local showSpecial = DBC.DB.options.showSpecialBosses ~= false
    local headerIndex = 1
    local checkboxIndex = 1

    local function addHeader(text)
        local h = DBC:GetHeader(headerIndex)
        headerIndex = headerIndex + 1
        h:SetPoint("TOPLEFT", 0, yOffset)
        h:SetText(text)
        h:Show()
        yOffset = yOffset - HEADER_HEIGHT
    end

    local function addBossRow(boss)
        local cb = DBC:GetCheckbox(checkboxIndex)
        checkboxIndex = checkboxIndex + 1
        cb:SetPoint("TOPLEFT", 0, yOffset)
        cb.Text:SetText(boss.name)
        cb.npcID = boss.npcId
        cb.bossData = boss
        cb.instData = instData

        local isKilled = false
        if DBC.CurrentRun and DBC.CurrentRun.killed[boss.npcId] then
            isKilled = true
        end
        cb.isKilled = isKilled

        -- Icons
        if isKilled then
            cb.Icon:SetTexture("Interface\RaidFrame\ReadyCheck-Ready") -- Green check
            cb.Text:SetTextColor(0.5, 0.5, 0.5)
        else
            if boss.specialType == "rare" then
                cb.Icon:SetTexture("Interface\Minimap\MiniMap-QuestArrow") -- Placeholder for Rare
                cb.Icon:SetDesaturated(true)
            else
                cb.Icon:SetTexture("Interface\TargetingFrame\UI-TargetingFrame-Skull") -- Skull
            end
            cb.Text:SetTextColor(1, 0.82, 0)
        end
        
        -- Quest Check
        if DBC:IsBossQuestObjective(boss.name) and not isKilled then
            cb.QuestIcon:Show()
            cb.Text:SetTextColor(0.2, 1.0, 0.2) -- Green text for quest targets
        else
            cb.QuestIcon:Hide()
        end

        cb:Show()
        yOffset = yOffset - ROW_HEIGHT
    end

    local mainBosses = {}
    local specialBosses = {}
    for _, boss in ipairs(instData.bosses) do
        if DBC:IsSpecialBoss(boss) then
            table.insert(specialBosses, boss)
        else
            table.insert(mainBosses, boss)
        end
    end

    if #mainBosses > 0 then
        addHeader("Main Bosses")
        for _, boss in ipairs(mainBosses) do
            addBossRow(boss)
        end
    end

    if showSpecial and #specialBosses > 0 then
        if #mainBosses > 0 then yOffset = yOffset - 4 end
        addHeader("Optional / Rare")
        for _, boss in ipairs(specialBosses) do
            addBossRow(boss)
        end
    end
    
    local totalHeight = math.abs(yOffset)
    DBC.UIFrame.Content:SetHeight(totalHeight)
    
    -- Auto-resize frame
    local frameHeight = math.min(totalHeight + 50, (MAX_VISIBLE_ROWS * ROW_HEIGHT) + 50)
    DBC.UIFrame:SetHeight(frameHeight)
end