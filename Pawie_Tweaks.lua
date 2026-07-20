-- ==========================================
-- PAWIE TWEAKS - v1.2
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
    autoSell = true,
    chatClassColors = true,
    clickInvite = true,
    blockDuels = false,         
    blockGuildInvites = false,
    enableMapTweaks = true
}

local function ApplyChatColors(enable)
    local chatTypes = {"SAY", "EMOTE", "YELL", "WHISPER", "GUILD", "OFFICER", "PARTY", "RAID", "RAID_WARNING", "BATTLEGROUND", "BATTLEGROUND_LEADER"}
    for _, type in ipairs(chatTypes) do
        ToggleChatColorNamesByClassGroup(enable, type)
    end
    for i = 1, 10 do
        ToggleChatColorNamesByClassGroup(enable, "CHANNEL"..i)
    end
end

-- ==========================================
-- MODULE: Map Tweaks
-- ==========================================
local function InitMap()
    if not PawieTweaksDB.enableMapTweaks then return end 

    SetCVar("miniWorldMap", 1)
    WorldMapFrame:SetMovable(true)
    WorldMapFrame:SetUserPlaced(true)
    WorldMapFrame:SetClampedToScreen(true)
    
    if PawieTweaksDB.scale then
        WorldMapFrame:SetScale(PawieTweaksDB.scale)
    end
    
    local dragFrame = CreateFrame("Frame", nil, WorldMapFrame)
    dragFrame:SetPoint("TOPLEFT", 0, 0)
    dragFrame:SetPoint("TOPRIGHT", 0, 0)
    dragFrame:SetHeight(35)
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:SetScript("OnDragStart", function() WorldMapFrame:StartMoving() end)
    dragFrame:SetScript("OnDragStop", function() WorldMapFrame:StopMovingOrSizing() end)

    if WorldMapZoneMinimapDropDown then WorldMapZoneMinimapDropDown:Hide() end
    if WorldMapZoomOutButton then WorldMapZoomOutButton:Hide() end
    if WorldMapMagnifyingGlassButton then WorldMapMagnifyingGlassButton:Hide() end
    if WorldMapPlayer then WorldMapPlayer:SetScale(1.5) end

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
                if isComplete then SelectActiveQuest(i); return end
            end
            local numAvailable = GetNumAvailableQuests()
            if numAvailable > 0 then SelectAvailableQuest(1); return end
            
        elseif ev == "GOSSIP_SHOW" then
            local activeQuests = {GetGossipActiveQuests()}
            if #activeQuests > 0 then
                local index = 1
                for i = 1, #activeQuests, 4 do
                    if activeQuests[i+3] then SelectGossipActiveQuest(index); return end
                    index = index + 1
                end
            end
            local availableQuests = {GetGossipAvailableQuests()}
            if #availableQuests > 0 then SelectGossipAvailableQuest(1); return end
            
        elseif ev == "QUEST_DETAIL" then
            local objective = string.lower(GetObjectiveText() or "")
            local text = string.lower(GetQuestText() or "")
            if string.find(objective, "escort") or string.find(objective, "protect") or string.find(text, "escort") then
                print("|cff00ff00Pawie Tweaks:|r Escort quest detected. Auto-accept paused.")
            else AcceptQuest() end
            
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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 }
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
        for i = 1, #chatHistory do allText = allText .. chatHistory[i] .. "\n" end
        allText = allText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        editBox:SetText(allText)
        copyWindow:Show()
        editBox:HighlightText() 
    end)

    hooksecurefunc("StaticPopup_Show", function(which)
        if which == "DELETE_GOOD_ITEM" and PawieTweaksDB.skipDelete then
            local frame = StaticPopup_FindVisible(which)
            if frame then frame.editBox:SetText(DELETE_ITEM_CONFIRM_STRING) end
        end
    end)
    
    local bopFrame = CreateFrame("Frame")
    bopFrame:RegisterEvent("LOOT_BIND_CONFIRM")
    bopFrame:SetScript("OnEvent", function(self, event, slot)
        if PawieTweaksDB.autoBoP then ConfirmLootSlot(slot); StaticPopup_Hide("LOOT_BIND") end
    end)
    
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
        if total > 0 then print("|cff00ff00Pawie Tweaks:|r Sold junk for " .. GetCoinTextureString(total) .. ".") end
    end)

    ApplyChatColors(PawieTweaksDB.chatClassColors)

    local orig_MerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick
    function MerchantItemButton_OnModifiedClick(self, button)
        if IsAltKeyDown() and button == "LeftButton" then
            local id = self:GetID()
            local maxStack = GetMerchantItemMaxStack(id)
            local _, _, _, quantity = GetMerchantItemInfo(id)
            if maxStack > 1 then BuyMerchantItem(id, math.floor(maxStack/quantity)); return end
        end
        orig_MerchantItemButton_OnModifiedClick(self, button)
    end

    local function ChatInviteFilter(self, event, msg, author, ...)
        if not PawieTweaksDB.clickInvite then return false, msg, author, ... end
        local newMsg = string.gsub(msg, "%f[%a]([iI][nN][vV][iI]?[tT]?[eE]?)%f[%A]", "|Hpawieinv:"..author.."|h|cffffff00%1|r|h")
        return false, newMsg, author, ...
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatInviteFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatInviteFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ChatInviteFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatInviteFilter)

    local orig_SetItemRef = SetItemRef
    function SetItemRef(link, text, button, chatFrame)
        local linkType, target = strsplit(":", link)
        if linkType == "pawieinv" then
            if IsPartyLeader() or not IsInGroup() then
                InviteUnit(target); print("|cff00ff00Pawie Tweaks:|r Invited " .. target .. ".")
            else
                DoInvite(target); print("|cff00ff00Pawie Tweaks:|r Suggested invite for " .. target .. " to the party leader.")
            end
            return
        end
        orig_SetItemRef(link, text, button, chatFrame)
    end

    local blockFrame = CreateFrame("Frame")
    blockFrame:RegisterEvent("DUEL_REQUESTED")
    blockFrame:RegisterEvent("GUILD_INVITE_REQUEST")
    blockFrame:SetScript("OnEvent", function(self, event, name)
        local function IsFriend(n)
            for i = 1, GetNumFriends() do if GetFriendInfo(i) == n then return true end end
            if IsInGuild() then
                for i = 1, GetNumGuildMembers() do
                    local gName = select(1, GetGuildRosterInfo(i))
                    if gName and strsplit("-", gName) == n then return true end
                end
            end
            return false
        end

        if not IsFriend(name) then
            if event == "DUEL_REQUESTED" and PawieTweaksDB.blockDuels then
                CancelDuel(); StaticPopup_Hide("DUEL_REQUESTED")
                print("|cff00ff00Pawie Tweaks:|r Blocked duel request from " .. tostring(name) .. ".")
            elseif event == "GUILD_INVITE_REQUEST" and PawieTweaksDB.blockGuildInvites then
                DeclineGuild(); StaticPopup_Hide("GUILD_INVITE")
                print("|cff00ff00Pawie Tweaks:|r Blocked guild invite from " .. tostring(name) .. ".")
            end
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
        msg = string.lower(msg or "")
        msg = msg:match("^%s*(.-)%s*$")
        
        if msg == "map" then
            PawieTweaksDB.enableMapTweaks = not PawieTweaksDB.enableMapTweaks
            print("|cff00ff00Pawie Tweaks:|r Map Tweaks are now " .. (PawieTweaksDB.enableMapTweaks and "ON" or "OFF") .. ". Type /rl to apply!")
            if PT_CBMap then PT_CBMap:SetChecked(PawieTweaksDB.enableMapTweaks) end
        elseif msg == "fade" then
            PawieTweaksDB.fadeOnMove = not PawieTweaksDB.fadeOnMove
            print("|cff00ff00Pawie Tweaks:|r Fade on move is now " .. (PawieTweaksDB.fadeOnMove and "ON" or "OFF") .. ".")
        elseif msg == "quest" then
            PawieTweaksDB.autoQuest = not PawieTweaksDB.autoQuest
            print("|cff00ff00Pawie Tweaks:|r Auto-Quest is now " .. (PawieTweaksDB.autoQuest and "ON" or "OFF") .. ".")
        elseif msg == "duel" then
            PawieTweaksDB.blockDuels = not PawieTweaksDB.blockDuels
            print("|cff00ff00Pawie Tweaks:|r Block Duels is now " .. (PawieTweaksDB.blockDuels and "ON" or "OFF") .. ".")
        elseif msg == "ginv" then
            PawieTweaksDB.blockGuildInvites = not PawieTweaksDB.blockGuildInvites
            print("|cff00ff00Pawie Tweaks:|r Block Guild Invites is now " .. (PawieTweaksDB.blockGuildInvites and "ON" or "OFF") .. ".")
        elseif msg == "colors" then
            PawieTweaksDB.chatClassColors = not PawieTweaksDB.chatClassColors
            ApplyChatColors(PawieTweaksDB.chatClassColors)
            print("|cff00ff00Pawie Tweaks:|r Chat Class Colors are now " .. (PawieTweaksDB.chatClassColors and "ON" or "OFF") .. ".")
        else
            print("|cff00ff00Pawie Tweaks Commands:|r /pawie map, fade, quest, duel, ginv, colors, /rl")
        end
    end

    local optionsPanel = CreateFrame("Frame", "PawieTweaksOptionsPanel", UIParent)
    optionsPanel.name = "Pawie Tweaks"
    InterfaceOptions_AddCategory(optionsPanel)

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16); title:SetText("Pawie Tweaks Settings")
    local desc = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); desc:SetJustifyH("LEFT")
    desc:SetText("A lightweight addon to improve your World Map and automate tedious tasks.")

    local optHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20); optHeader:SetText("Togglable Settings")

    local function CreateCB(name, label, dbKey, relativeTo, cbFunc)
        local cb = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, -3)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnShow", function(self) self:SetChecked(PawieTweaksDB[dbKey]) end)
        cb:SetScript("OnClick", function(self) 
            PawieTweaksDB[dbKey] = self:GetChecked() and true or false 
            if cbFunc then cbFunc(PawieTweaksDB[dbKey]) end
        end)
        return cb
    end

    local cbMap = CreateCB("PT_CBMap", "Enable Map Tweaks (Uncheck to fix compatibility issues)", "enableMapTweaks", optHeader)
    cbMap:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -8)
    local cbQuest = CreateCB("PT_CBQuest", "Auto-Quest (Accepts/Turns in quests. Hold SHIFT to pause)", "autoQuest", cbMap)
    local cbFade = CreateCB("PT_CBFade", "Fade Map on Move", "fadeOnMove", cbQuest)
    local cbDelete = CreateCB("PT_CBDelete", "Skip 'DELETE' typing", "skipDelete", cbFade)
    local cbBoP = CreateCB("PT_CBBoP", "Auto-Confirm Bind on Pickup loot", "autoBoP", cbDelete)
    local cbSell = CreateCB("PT_CBSell", "Auto-Sell Junk", "autoSell", cbBoP)
    local cbInvite = CreateCB("PT_CBInvite", "Clickable Invites in Chat", "clickInvite", cbSell)
    local cbColors = CreateCB("PT_CBColors", "Class Colors in Chat", "chatClassColors", cbInvite, function(val) ApplyChatColors(val) end)
    local cbDuel = CreateCB("PT_CBDuel", "Block Duel Requests", "blockDuels", cbColors)
    local cbGinv = CreateCB("PT_CBGinv", "Block Guild Invites", "blockGuildInvites", cbDuel)
end

-- ==========================================
-- EVENT HANDLER
-- ==========================================
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_LOGIN")

coreFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if type(PawieTweaksDB) ~= "table" then PawieTweaksDB = {} end
        for key, value in pairs(defaultSettings) do
            if PawieTweaksDB[key] == nil then PawieTweaksDB[key] = value end
        end
    elseif event == "PLAYER_LOGIN" then
        InitMap()
        InitAutoQuest()
        InitQoL()
        InitMenuAndCommands()
    end
end)
