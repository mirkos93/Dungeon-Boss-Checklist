-- Options.lua
local addonName, addon = ...
local DBC = addon

function DBC:InitOptions()
    local p = CreateFrame("Frame", "DungeonBossChecklistOptions", UIParent)
    p.name = "Dungeon Boss Checklist"
    
    -- Title
    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Dungeon Boss Checklist Options")
    
    local ver = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    ver:SetText("Version: " .. DBC.DB.options.version)
    
    -- Toggle Party Log
    local cbParty = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    cbParty:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -20)
    cbParty.Text:SetText("Enable party kill log")
    cbParty:SetScript("OnShow", function(self) self:SetChecked(DBC.DB.options.enablePartyLog) end)
    cbParty:SetScript("OnClick", function(self)
        DBC.DB.options.enablePartyLog = self:GetChecked()
        DBC:UpdateUI()
    end)

    -- Include Special Bosses in Party Log
    local cbPartySpecial = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    cbPartySpecial:SetPoint("TOPLEFT", cbParty, "BOTTOMLEFT", 0, -10)
    cbPartySpecial.Text:SetText("Include special bosses in party log")
    cbPartySpecial:SetScript("OnShow", function(self) self:SetChecked(DBC.DB.options.partyLogIncludeSpecial) end)
    cbPartySpecial:SetScript("OnClick", function(self)
        DBC.DB.options.partyLogIncludeSpecial = self:GetChecked()
        DBC:UpdateUI()
    end)
    
    -- Show Special Bosses
    local cbShowSpecial = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    cbShowSpecial:SetPoint("TOPLEFT", cbPartySpecial, "BOTTOMLEFT", 0, -10)
    cbShowSpecial.Text:SetText("Show special bosses in checklist")
    cbShowSpecial:SetScript("OnShow", function(self) self:SetChecked(DBC.DB.options.showSpecialBosses) end)
    cbShowSpecial:SetScript("OnClick", function(self)
        DBC.DB.options.showSpecialBosses = self:GetChecked()
        DBC:UpdateUI()
    end)

    -- Toggle Debug
    local cbDebug = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    cbDebug:SetPoint("TOPLEFT", cbShowSpecial, "BOTTOMLEFT", 0, -20)
    cbDebug.Text:SetText("Enable Debug Messages")
    cbDebug:SetScript("OnShow", function(self) self:SetChecked(DBC.DB.options.debug) end)
    cbDebug:SetScript("OnClick", function(self)
        DBC.DB.options.debug = self:GetChecked()
        DBC:UpdateUI()
    end)
    
    -- Reset Current Run Button
    local btnReset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnReset:SetSize(120, 25)
    btnReset:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 0, -20)
    btnReset:SetText("Reset Current Run")
    btnReset:SetScript("OnClick", function() 
        if DBC.CurrentRun then
            DBC.CurrentRun.killed = {}
            DBC:UpdateUI()
            print("[DBC] Run reset manually via options.")
        else
            print("[DBC] No active run to reset.")
        end
    end)
    
    DBC.OptionsFrame = p

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(p)
    elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(p, p.name)
        Settings.RegisterAddOnCategory(category)
    end
end
