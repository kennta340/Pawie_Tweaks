-- ==========================================
-- PAWIE TWEAKS - Core Setup
-- ==========================================
local addonName, PT = ...
local coreFrame = CreateFrame("Frame")

-- Default settings
local defaultSettings = {
    scale = 1.0, 
    fadeOnMove = true, 
    autoQuest = true,
    skipDelete = true,
    autoBoP = true,
    autoSell = true
}

-- ==========================================
-- MODULE: Map Tweaks
-- ==========================================
local function InitMap()
    SetCVar("miniWorldMap", 1)
    WorldMapFrame:SetMovable(true)
    WorldMapFrame:SetUserPlaced(true)
    WorldMapFrame:SetClampedToScreen(true)
    
    if PawieTweaksDB.scale then
        WorldMapFrame:SetScale(PawieTweaksDB.scale)
    end
    
    -- Drag Frame
    local dragFrame = CreateFrame("Frame", nil, WorldMapFrame)
    dragFrame:SetPoint("TOPLEFT", 0, 0)
    dragFrame:SetPoint("TOPRIGHT", 0, 0)
    dragFrame:SetHeight(35)
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:SetScript("OnDragStart", function() WorldMapFrame:StartMoving() end)
    dragFrame:SetScript("OnDragStop", function() WorldMapFrame:StopMovingOrSizing() end)

    -- Clean UP UI
    if WorldMapZoneMinimapDropDown then WorldMapZoneMinimapDropDown:Hide() end
    if WorldMapZoomOutButton then WorldMapZoomOutButton:Hide() end
    if WorldMapMagnifyingGlassButton then WorldMapMagnifyingGlassButton:Hide() end
    if WorldMapPlayer then WorldMapPlayer:SetScale(1.5) end

    -- Scaling Logic
    local function MapScale(self, delta)
        local scale = WorldMapFrame:GetScale() + (delta * 0.1)
        if scale > 0.5 and scale < 2.5 then
            WorldMapFrame:SetScale(scale)
            PawieTweaksDB.scale = scale
        end
    end
    
    WorldMapFrame:EnableMouseWheel(true)
    WorldMapFrame:HookScript("OnMouseWheel", MapScale)
    if WorldMapButton then
        WorldMapButton:EnableMouseWheel(true)
        WorldMapButton:HookScript("OnMouseWheel", MapScale)
    end

    local scaleHandle = CreateFrame("Frame", nil, WorldMapFrame)
    scaleHandle:SetSize(16, 16)
    scaleHandle:SetPoint("BOTTOMRIGHT", -10, 10)
    scaleHandle:EnableMouse(true)
    scaleHandle:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 15)
    scaleHandle.tex = scaleHandle:CreateTexture(nil, "OVERLAY")
    scaleHandle.tex:SetAllPoints()
    scaleHandle.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    scaleHandle.tex:SetBlendMode("ADD")

    scaleHandle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isScaling = true
            self.initialX, self.initialY = GetCursorPosition()
            self.initialScale = WorldMapFrame:GetScale()
            self:SetScript("OnUpdate", function(self)
                local currentX, currentY = GetCursorPosition()
                local scaleDelta = ((currentX - self.initialX) - (currentY - self.initialY)) * 0.003
                local newScale = self.initialScale + scaleDelta
                if newScale < 0.4 then newScale = 0.4 end
                if newScale > 2.5 then newScale = 2.5 end
                WorldMapFrame:SetScale(newScale)
            end)
        end
    end)

    scaleHandle:SetScript("OnMouseUp", function(self)
        if self.isScaling then
            self.isScaling = false
            self:SetScript("OnUpdate", nil)
            PawieTweaksDB.scale = WorldMapFrame:GetScale()
        end
    end)

    -- Fade on Move
    local logicFrame = CreateFrame("Frame", nil, WorldMapFrame)
    local updateTimer = 0
    logicFrame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer > 0.1 then 
            updateTimer = 0
            if WorldMapFrame:IsVisible() then
                if PawieTweaksDB.fadeOnMove then
                    if GetUnitSpeed("player") > 0 then
                        WorldMapFrame:SetAlpha(0.5)
                    else
                        WorldMapFrame:SetAlpha(1.0)
                    end
                else
                    if WorldMapFrame:GetAlpha() ~= 1.0 then WorldMapFrame:SetAlpha(1.0) end
                end
            end
        end
    end)
end

-- ==========================================
-- MODULE: Auto Quest
-- ==========================================
local function InitAutoQuest()
    local questFrame = CreateFrame("Frame")
    questFrame:RegisterEvent("QUEST_GREETING")
    questFrame:RegisterEvent("GOSSIP_SHOW")
    questFrame:RegisterEvent("QUEST_DETAIL")
    questFrame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    questFrame:RegisterEvent("QUEST_PROGRESS")
    questFrame:RegisterEvent("QUEST_COMPLETE")
    
    questFrame:SetScript("OnEvent", function(self, ev)
        if not PawieTweaksDB.autoQuest then return end
        if IsShiftKeyDown() then return end 
        
        if ev == "QUEST_GREETING" then
            local numActive = GetNumActiveQuests()
            for i = 1, numActive do 
                local _, isComplete = GetActiveTitle(i)
                if isComplete then
                    SelectActiveQuest(i)
                    return
                end
            end
            local numAvailable = GetNumAvailableQuests()
            if numAvailable > 0 then
                SelectAvailableQuest(1)
                return
            end
            
        elseif ev == "GOSSIP_SHOW" then
            local activeQuests = {GetGossipActiveQuests()}
            if #activeQuests > 0 then
                local index = 1
                for i = 1, #activeQuests, 4 do
                    if activeQuests[i+3] then
                        SelectGossipActiveQuest(index)
                        return
                    end
                    index = index + 1
                end
            end
            local availableQuests = {GetGossipAvailableQuests()}
            if #availableQuests > 0 then
                SelectGossipAvailableQuest(1)
                return
            end
            
        elseif ev == "QUEST_DETAIL" then
            local objective = string.lower(GetObjectiveText() or "")
            local text = string.lower(GetQuestText() or "")
            if string.find(objective, "escort") or string.find(objective, "protect") or string.find(objective, "guard") or string.find(text, "escort") then
                print("|cff00ff00Pawie Tweaks:|r Escort quest detected. Auto-accept paused.")
            else
                AcceptQuest()
            end
            
        elseif ev == "QUEST_ACCEPT_CONFIRM" then
            print("|cff00ff00Pawie Tweaks:|r Event warning detected. Auto-accept paused.")
            
        elseif ev == "QUEST_PROGRESS" then
            if IsQuestCompletable() then CompleteQuest() end
            
        elseif ev == "QUEST_COMPLETE" then
            if GetNumQuestChoices() <= 1 then GetQuestReward(1) end
        end
    end)
end

-- ==========================================
-- MODULE: Quality of Life (QoL)
-- ==========================================
local function InitQoL()
    -- Hide Annoying Errors
    SetCVar("Sound_EnableErrorSpeech", "0")
    local originalAddMessage = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(frame, text, red, green, blue, id)
        if text then
            local lowerText = string.lower(text)
            if lowerText:match("not ready") or lowerText:match("out of range") or lowerText:match("not enough") or lowerText:match("in progress") or lowerText:match("cooldown") or lowerText:match("can't cast") or lowerText:match("nothing to attack") then
                return
            end
        end
        originalAddMessage(frame, text, red, green, blue, id)
    end

    -- Chat Copy Tool
    local chatHistory = {}
    local originalChatAddMessage = ChatFrame1.AddMessage
    ChatFrame1.AddMessage = function(frame, text, ...)
        if text then
            table.insert(chatHistory, text)
            if #chatHistory > 200 then table.remove(chatHistory, 1) end
        end
        originalChatAddMessage(frame, text, ...)
    end

    local copyWindow = CreateFrame("Frame", nil, UIParent)
    copyWindow:SetSize(600, 450)
    copyWindow:SetPoint("CENTER")
    copyWindow:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    copyWindow:Hide()
    copyWindow:SetFrameStrata("DIALOG")

    local closeBtn = CreateFrame("Button", nil, copyWindow, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local scrollArea = CreateFrame("ScrollFrame", "PawieChatCopyScroll", copyWindow, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", 15, -15)
    scrollArea:SetPoint("BOTTOMRIGHT", -30, 15)

    local editBox = CreateFrame("EditBox", nil, scrollArea)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(99999)
    editBox:EnableMouse(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(550)
    scrollArea:SetScrollChild(editBox)

    local copyBtn = CreateFrame("Button", nil, ChatFrame1)
    copyBtn:SetSize(24, 24)
    copyBtn:SetPoint("TOPRIGHT", ChatFrame1, "TOPRIGHT", -5, -5)
    copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    copyBtn:SetAlpha(0.3) 
    copyBtn:SetScript("OnEnter", function(self) self:SetAlpha(1.0) end)
    copyBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.3) end)
    copyBtn:SetScript("OnClick", function()
        local allText = ""
        for i = 1, #chatHistory do
            allText = allText .. chatHistory[i] .. "\n"
        end
        allText = allText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        editBox:SetText(allText)
        copyWindow:Show()
        editBox:HighlightText() 
    end)

    -- Skip "DELETE" typing
    hooksecurefunc("StaticPopup_Show", function(which)
        if which == "DELETE_GOOD_ITEM" and PawieTweaksDB.skipDelete then
            local frame = StaticPopup_FindVisible(which)
            if frame then frame.editBox:SetText(DELETE_ITEM_CONFIRM_STRING) end
        end
    end)
    
    -- Auto BoP
    local bopFrame = CreateFrame("Frame")
    bopFrame:RegisterEvent("LOOT_BIND_CONFIRM")
    bopFrame:SetScript("OnEvent", function(self, event, slot)
        if PawieTweaksDB.autoBoP then
            ConfirmLootSlot(slot)
            StaticPopup_Hide("LOOT_BIND")
        end
    end)
    
    -- Auto Sell
    local sellFrame = CreateFrame("Frame")
    sellFrame:RegisterEvent("MERCHANT_SHOW")
    sellFrame:SetScript("OnEvent", function()
        if not PawieTweaksDB.autoSell then return end
        local total = 0
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                local link = GetContainerItemLink(b, s)
                if link then
                    local _, _, rarity, _, _, _, _, _, _, _, itemPrice = GetItemInfo(link)
                    if rarity == 0 and itemPrice > 0 then
                        local count = select(2, GetContainerItemInfo(b, s))
                        total = total + (itemPrice * count)
                        UseContainerItem(b, s)
                    end
                end
            end
        end
        if total > 0 then
            print("|cff00ff00Pawie Tweaks:|r Sold junk for " .. GetCoinTextureString(total) .. ".")
        end
    end)
end

-- ==========================================
-- MODULE: UI Options Menu & Slash Commands
-- ==========================================
local function InitMenuAndCommands()
    SLASH_PAWIERELOAD1 = "/rl"
    SlashCmdList["PAWIERELOAD"] = function() ReloadUI() end

    SLASH_PAWIETWEAKS1 = "/pawie"
    SlashCmdList["PAWIETWEAKS"] = function(msg)
        msg = string.lower(msg)
        if msg == "fade" then
            PawieTweaksDB.fadeOnMove = not PawieTweaksDB.fadeOnMove
            print("|cff00ff00Pawie Tweaks:|r Fade on move is now " .. (PawieTweaksDB.fadeOnMove and "ON" or "OFF") .. ".")
        elseif msg == "quest" then
            PawieTweaksDB.autoQuest = not PawieTweaksDB.autoQuest
            print("|cff00ff00Pawie Tweaks:|r Auto-Quest is now " .. (PawieTweaksDB.autoQuest and "ON" or "OFF") .. ".")
        else
            print("|cff00ff00Pawie Tweaks Commands:|r")
            print("/rl - Reloads the UI.")
            print("/pawie fade - Toggles map transparency when moving.")
            print("/pawie quest - Toggles auto-accept/turn-in of quests.")
        end
    end

    local optionsPanel = CreateFrame("Frame", "PawieTweaksOptionsPanel", UIParent)
    optionsPanel.name = "Pawie Tweaks"
    InterfaceOptions_AddCategory(optionsPanel)

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Pawie Tweaks Settings")

    local desc = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetJustifyH("LEFT")
    desc:SetText("A lightweight addon to improve your World Map and automate tedious tasks.")

    local optHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    optHeader:SetText("Togglable Settings")

    -- Helper to create checkboxes
    local function CreateCheckbox(name, label, dbKey, relativeTo)
        local cb = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, -5)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnShow", function(self) self:SetChecked(PawieTweaksDB[dbKey]) end)
        cb:SetScript("OnClick", function(self) PawieTweaksDB[dbKey] = self:GetChecked() and true or false end)
        return cb
    end

    local cbQuest = CreateCheckbox("PawieTweaksCBQuest", "Auto-Quest (Accepts/Turns in quests. Hold SHIFT to pause)", "autoQuest", optHeader)
    cbQuest:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -10) -- Adjust first item spacing
    local cbFade = CreateCheckbox("PawieTweaksCBFade", "Fade Map on Move (Map becomes transparent when running)", "fadeOnMove", cbQuest)
    local cbDelete = CreateCheckbox("PawieTweaksCBDelete", "Skip 'DELETE' typing (Auto-fills the text for rare items)", "skipDelete", cbFade)
    local cbBoP = CreateCheckbox("PawieTweaksCBBoP", "Auto-Confirm Bind on Pickup (BoP) loot warnings", "autoBoP", cbDelete)
    local cbSell = CreateCheckbox("PawieTweaksCBSell", "Auto-Sell Junk (Sells all grey items when talking to a vendor)", "autoSell", cbBoP)

    local infoHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", cbSell, "BOTTOMLEFT", 0, -25)
    infoHeader:SetText("Built-in Features (Always Active)")

    local infoText = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", infoHeader, "BOTTOMLEFT", 0, -10)
    infoText:SetJustifyH("LEFT")
    infoText:SetText(
        "• Movable Windowed Map: The World Map can be dragged, and scaled using the mouse wheel.\n" ..
        "• Map UI Cleanup: Removes the clunky default borders and dropdown menus from the map.\n" ..
        "• Larger Player Arrow: Increases your map icon by 50% so it's easier to spot.\n" ..
        "• Chat Copy Tool: Adds a tiny button to the top right of the chat window to copy text.\n" ..
        "• Error Filter: Silences annoying red screen text ('Not ready', 'Out of range', 'Nothing to attack').\n" ..
        "• Quick Reload: Type /rl in the chat to instantly reload your User Interface."
    )
end

-- ==========================================
-- EVENT HANDLER (Addon Initialization)
-- ==========================================
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_LOGIN")

coreFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if type(PawieTweaksDB) ~= "table" then PawieTweaksDB = {} end
        -- Apply default settings if they are missing
        for key, value in pairs(defaultSettings) do
            if PawieTweaksDB[key] == nil then
                PawieTweaksDB[key] = value
            end
        end
    elseif event == "PLAYER_LOGIN" then
        InitMap()
        InitAutoQuest()
        InitQoL()
        InitMenuAndCommands()
    end
end)