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
    
    -- Solid Background with softer borders (#021A32)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", -- Solid texture
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Softer border
        tile = false, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.008, 0.102, 0.196, 1) -- Solid Deep Blue #021A32
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) -- Grey Border
    
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
    f.Title:SetPoint("TOP", 10, -8)
    f.Title:SetText("DBC")
    
    -- Addon Icon
    f.HeaderIcon = f:CreateTexture(nil, "OVERLAY")
    f.HeaderIcon:SetSize(20, 20)
    f.HeaderIcon:SetPoint("RIGHT", f.Title, "LEFT", -5, 0)
    f.HeaderIcon:SetTexture("Interface\\AddOns\\DungeonBossChecklist\\icon.png")
    
    -- Subtitle
    f.Info = f:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
    f.Info:SetPoint("TOP", 0, -22)
    f.Info:SetText("No Instance")
    
    -- Compact Toggle Button
    local btnCompact = CreateFrame("Button", nil, f)
    btnCompact:SetSize(16, 16)
    btnCompact:SetPoint("TOPRIGHT", -8, -8)
    btnCompact:SetFrameLevel(f:GetFrameLevel() + 10) -- Force on top
    btnCompact:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
    btnCompact:SetPushedTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Down")
    btnCompact:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    btnCompact:SetScript("OnClick", function()
        DBC.DB.ui.compact = not DBC.DB.ui.compact
        DBC:UpdateUI()
    end)
    f.BtnCompact = btnCompact

    -- Announce Button
    local btnAnnounce = CreateFrame("Button", nil, f)
    btnAnnounce:SetSize(16, 16)
    btnAnnounce:SetPoint("TOPRIGHT", btnCompact, "TOPLEFT", -2, 0)
    btnAnnounce:SetFrameLevel(f:GetFrameLevel() + 10) -- Force on top
    btnAnnounce:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
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
    f.Scroll = CreateFrame("ScrollFrame", "DungeonBossChecklistScrollFrame", f, "UIPanelScrollFrameTemplate")
    f.Scroll:SetPoint("TOPLEFT", 10, -40)
    f.Scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Enable Mouse Wheel Scrolling
    f.Scroll:EnableMouseWheel(true)
    f.Scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local step = 20
        local newScroll = current - (delta * step)
        if newScroll < 0 then newScroll = 0 end
        if newScroll > maxScroll then newScroll = maxScroll end
        self:SetVerticalScroll(newScroll)
    end)
    
    -- Auto-hide ScrollBar via OnScrollRangeChanged
    f.Scroll:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
        local scrollBar = self.ScrollBar or _G[self:GetName().."ScrollBar"]
        local scrollUp = _G[self:GetName().."ScrollBarScrollUpButton"]
        local scrollDown = _G[self:GetName().."ScrollBarScrollDownButton"]
        
        if not yrange or yrange < 0.1 then
            if scrollBar then scrollBar:Hide() end
            if scrollUp then scrollUp:Hide() end
            if scrollDown then scrollDown:Hide() end
            self:SetPoint("BOTTOMRIGHT", -10, 10)
            DBC.UIFrame.Content:SetWidth(MAIN_WIDTH - 20)
        else
            if scrollBar then scrollBar:Show() end
            if scrollUp then scrollUp:Show() end
            if scrollDown then scrollDown:Show() end
            self:SetPoint("BOTTOMRIGHT", -30, 10)
            DBC.UIFrame.Content:SetWidth(MAIN_WIDTH - 40)
        end
    end)
    
    -- Content Container
    f.Content = CreateFrame("Frame", nil, f.Scroll)
    f.Content:SetSize(MAIN_WIDTH - 40, 1)
    f.Scroll:SetScrollChild(f.Content)
    
    f.Checkboxes = {}
    f.Headers = {}
    
    DBC.UIFrame = f
    
    DBC:InitLootWindow()

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

function DBC:InitLootWindow()
    local f = CreateFrame("Frame", "DBC_LootFrame", UIParent, "BackdropTemplate")
    f:SetSize(220, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:Hide()
    
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogFrame-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    f:SetScript("OnMouseDown", function(self) self:StartMoving() end)
    f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    
    -- Close Button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    
    -- Title
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Title:SetPoint("TOP", 0, -15)
    f.Title:SetText("Loot")
    
    -- Scroll
    f.Scroll = CreateFrame("ScrollFrame", "DBC_LootScrollFrame", f, "UIPanelScrollFrameTemplate")
    f.Scroll:SetPoint("TOPLEFT", 15, -40)
    f.Scroll:SetPoint("BOTTOMRIGHT", -35, 15)

    f.Scroll:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
        local scrollBar = self.ScrollBar or _G[self:GetName().."ScrollBar"]
        local scrollUp = _G[self:GetName().."ScrollBarScrollUpButton"]
        local scrollDown = _G[self:GetName().."ScrollBarScrollDownButton"]

        if not yrange or yrange < 0.1 then
            if scrollBar then scrollBar:Hide() end
            if scrollUp then scrollUp:Hide() end
            if scrollDown then scrollDown:Hide() end
            self:SetPoint("BOTTOMRIGHT", -15, 15)
            DBC.LootFrame.Content:SetWidth(190)
        else
            if scrollBar then scrollBar:Show() end
            if scrollUp then scrollUp:Show() end
            if scrollDown then scrollDown:Show() end
            self:SetPoint("BOTTOMRIGHT", -35, 15)
            DBC.LootFrame.Content:SetWidth(180)
        end
    end)
    
    f.Content = CreateFrame("Frame", nil, f.Scroll)
    f.Content:SetSize(180, 1)
    f.Scroll:SetScrollChild(f.Content)
    
    f.Rows = {}
    DBC.LootFrame = f
end

function DBC:ShowLootWindow(boss)
    if not boss then return end
    local lootTable = DBC:GetBossLoot(boss)
    if not lootTable then 
        print("[DBC] No loot data for " .. boss.name)
        return 
    end
    
    local f = DBC.LootFrame
    f.Title:SetText(boss.name)
    f:Show()
    
    -- Hide old rows
    for _, r in pairs(f.Rows) do r:Hide() end
    
    local yOffset = 0
    local rowIndex = 1
    
    for _, entry in ipairs(lootTable) do
        local itemID = entry[2]
        -- Only process numeric IDs (skip headers)
        if type(itemID) == "number" then
            local row = f.Rows[rowIndex]
            if not row then
                row = CreateFrame("Button", nil, f.Content)
                row:SetSize(180, 36)
                
                row.Icon = row:CreateTexture(nil, "ARTWORK")
                row.Icon:SetSize(32, 32)
                row.Icon:SetPoint("LEFT", 0, 0)
                
                row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
                row.Name:SetPoint("RIGHT", 0, 0)
                row.Name:SetJustifyH("LEFT")
                row.Name:SetWordWrap(false)
                
                row:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(self.link or "item:"..self.itemID)
                    GameTooltip:Show()
                    CursorUpdate(self)
                end)
                row:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                    ResetCursor()
                end)
                row:SetScript("OnClick", function(self)
                    if not self.link then return end
                    if IsModifiedClick("CHATLINK") then
                        ChatEdit_InsertLink(self.link)
                    elseif IsModifiedClick("DRESSUP") then
                        DressUpItemLink(self.link)
                    end
                end)
                
                f.Rows[rowIndex] = row
            end
            
            row:SetPoint("TOPLEFT", 0, yOffset)
            row.itemID = itemID
            
            local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
            if name then
                row.Name:SetText(name)
                local r, g, b = GetItemQualityColor(quality or 1)
                row.Name:SetTextColor(r, g, b)
                row.Icon:SetTexture(icon)
                row.link = link
            else
                row.Name:SetText("Loading item #" .. itemID)
                row.Name:SetTextColor(0.5, 0.5, 0.5)
                row.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                row.link = nil
                -- Trigger load
                local item = Item:CreateFromItemID(itemID)
                if item then
                    item:ContinueOnItemLoad(function()
                        if f:IsVisible() and row:IsVisible() and row.itemID == itemID then
                            local n, l, q, _, _, _, _, _, _, i = GetItemInfo(itemID)
                            row.Name:SetText(n)
                            local r, g, b = GetItemQualityColor(q or 1)
                            row.Name:SetTextColor(r, g, b)
                            row.Icon:SetTexture(i)
                            row.link = l
                        end
                    end)
                end
            end
            
            row:Show()
            yOffset = yOffset - 38
            rowIndex = rowIndex + 1
        end
    end
    
    local totalHeight = math.abs(yOffset)
    f.Content:SetHeight(totalHeight)

    f.Scroll:UpdateScrollChildRect()
    local visibleHeight = f.Scroll:GetHeight() or 0
    local needScroll = totalHeight > (visibleHeight + 1)
    local scrollBar = f.Scroll.ScrollBar or _G[f.Scroll:GetName().."ScrollBar"]
    local scrollUp = _G[f.Scroll:GetName().."ScrollBarScrollUpButton"]
    local scrollDown = _G[f.Scroll:GetName().."ScrollBarScrollDownButton"]

    if needScroll then
        if scrollBar then scrollBar:Show() end
        if scrollUp then scrollUp:Show() end
        if scrollDown then scrollDown:Show() end
        f.Scroll:SetPoint("BOTTOMRIGHT", -35, 15)
        f.Content:SetWidth(180)
    else
        if scrollBar then scrollBar:Hide() end
        if scrollUp then scrollUp:Hide() end
        if scrollDown then scrollDown:Hide() end
        f.Scroll:SetVerticalScroll(0)
        f.Scroll:SetPoint("BOTTOMRIGHT", -15, 15)
        f.Content:SetWidth(190)
    end
end

function DBC:GetCheckbox(index)
    if not DBC.UIFrame.Checkboxes[index] then
        local cb = CreateFrame("Button", nil, DBC.UIFrame.Content)
        cb:SetSize(MAIN_WIDTH - 40, ROW_HEIGHT)
        
        -- Checkbox Texture
        cb.Check = cb:CreateTexture(nil, "ARTWORK")
        cb.Check:SetSize(16, 16)
        cb.Check:SetPoint("LEFT", 0, 0)
        cb.Check:SetTexture("Interface\\Buttons\\UI-CheckBox-Up") 

        -- Icon (Skull/Rare)
        cb.Icon = cb:CreateTexture(nil, "ARTWORK")
        cb.Icon:SetSize(14, 14)
        cb.Icon:SetPoint("LEFT", cb.Check, "RIGHT", 2, 0)
        
        -- Loot Button (Bag)
        cb.LootBtn = CreateFrame("Button", nil, cb)
        cb.LootBtn:SetSize(14, 14)
        cb.LootBtn:SetPoint("RIGHT", cb, "RIGHT", -2, 0)
        cb.LootBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
        cb.LootBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")
        cb.LootBtn:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if parent.bossData then
                DBC:ShowLootWindow(parent.bossData)
            end
        end)
        cb.LootBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("View Loot", 1, 1, 1)
            GameTooltip:Show()
        end)
        cb.LootBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Text
        cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
        cb.Text:SetPoint("LEFT", cb.Icon, "RIGHT", 5, 0)
        cb.Text:SetPoint("RIGHT", cb.LootBtn, "LEFT", -5, 0) -- Anchor to LootBtn
        
        -- Quest Icon
        cb.QuestIcon = cb:CreateTexture(nil, "OVERLAY")
        cb.QuestIcon:SetSize(12, 12)
        cb.QuestIcon:SetPoint("RIGHT", cb.LootBtn, "LEFT", -2, 0) -- Left of LootBtn
        cb.QuestIcon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
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
    
    local remaining = DBC:GetRemainingBossNamesWithFilter(DBC.CurrentInstanceKey, true)
    local msg
    if #remaining == 0 then
        msg = "[DBC] All bosses cleared!"
    else
        local list = table.concat(remaining, ", ")
        msg = string.format("[DBC] Remaining: %s", list)
    end

    if IsInGroup() then 
        SendChatMessage(msg, "PARTY")
    else
        print(msg .. " (Solo Mode)")
    end
end

function DBC:ShowBossTooltip(owner, instData, boss)
    if not boss or not instData then return end
    
    DBC.HoveredBoss = boss
    DBC.HoveredInstData = instData
    
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
            
            local itemID = entry[2]
            if type(itemID) == "number" then
                local name, link, quality = GetItemInfo(itemID)
                if name then
                    local r, g, b = GetItemQualityColor(quality or 1)
                    GameTooltip:AddLine(name, r, g, b)
                else
                    GameTooltip:AddLine("Loading item #"..itemID.."...", 0.5, 0.5, 0.5)
                end
                count = count + 1
            elseif type(itemID) == "string" and string.sub(itemID, 1, 3) == "INV" then
                -- Icon/Header spacer, ignore
            end
        end
        if count == 0 then
            GameTooltip:AddLine("No drops found.", 0.6, 0.6, 0.6)
        end
    else
        GameTooltip:AddLine("No loot data available.", 0.5, 0.5, 0.5)
    end
    
    GameTooltip:Show()
end

function DBC:HideBossTooltip()
    DBC.HoveredBoss = nil
    DBC.HoveredInstData = nil
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
        local scrollBar = DBC.UIFrame.Scroll.ScrollBar or _G[DBC.UIFrame.Scroll:GetName().."ScrollBar"]
        local scrollUp = _G[DBC.UIFrame.Scroll:GetName().."ScrollBarScrollUpButton"]
        local scrollDown = _G[DBC.UIFrame.Scroll:GetName().."ScrollBarScrollDownButton"]
        if scrollBar then scrollBar:Hide() end
        if scrollUp then scrollUp:Hide() end
        if scrollDown then scrollDown:Hide() end
        DBC.UIFrame.BtnCompact:SetNormalTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
        return
    else
        DBC.UIFrame.Scroll:Show()
        DBC.UIFrame.BtnCompact:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
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

        -- Icons & Checkbox State
        if isKilled then
            cb.Check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            cb.Text:SetTextColor(0.5, 0.5, 0.5)
            cb.Icon:SetDesaturated(true)
        else
            cb.Check:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
            cb.Text:SetTextColor(1, 0.82, 0)
            cb.Icon:SetDesaturated(false)
        end

        -- Boss Type Icon (Skull/Rare)
        if boss.specialType == "rare" then
            cb.Icon:SetTexture("Interface\\Minimap\\MiniMap-QuestArrow")
        else
            cb.Icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
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
    
    -- Auto-resize frame (clamp to max rows)
    local frameHeight = math.min(totalHeight + 50, (MAX_VISIBLE_ROWS * ROW_HEIGHT) + 50)
    DBC.UIFrame:SetHeight(frameHeight)
    
    -- Force update scroll range
    DBC.UIFrame.Scroll:UpdateScrollChildRect()

    -- Force scrollbar visibility based on content height
    local scroll = DBC.UIFrame.Scroll
    local visibleHeight = scroll:GetHeight() or 0
    local needScroll = totalHeight > (visibleHeight + 1)
    local scrollBar = scroll.ScrollBar or _G[scroll:GetName().."ScrollBar"]
    local scrollUp = _G[scroll:GetName().."ScrollBarScrollUpButton"]
    local scrollDown = _G[scroll:GetName().."ScrollBarScrollDownButton"]

    if needScroll then
        if scrollBar then scrollBar:Show() end
        if scrollUp then scrollUp:Show() end
        if scrollDown then scrollDown:Show() end
        scroll:SetPoint("BOTTOMRIGHT", -30, 10)
        DBC.UIFrame.Content:SetWidth(MAIN_WIDTH - 40)
    else
        if scrollBar then scrollBar:Hide() end
        if scrollUp then scrollUp:Hide() end
        if scrollDown then scrollDown:Hide() end
        scroll:SetVerticalScroll(0)
        scroll:SetPoint("BOTTOMRIGHT", -10, 10)
        DBC.UIFrame.Content:SetWidth(MAIN_WIDTH - 20)
    end
end
