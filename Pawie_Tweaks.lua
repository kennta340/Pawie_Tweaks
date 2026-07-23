-- ==========================================
-- PAWIE TWEAKS - v2.16 (FastLoot, Tooltip Colors & Gryphons)
-- ==========================================
local addonName, PT = ...
local coreFrame = CreateFrame("Frame")

-- Default settings
local defaultSettings = {
    autoQuest = true,
    chatClassColors = true,
    blockDuels = false,         
    blockGuildInvites = false,
    hideGryphons = true
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

local function ApplyGryphons(hide)
    if hide then
        MainMenuBarLeftEndCap:Hide()
        MainMenuBarRightEndCap:Hide()
    else
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    end
end

-- ==========================================
-- MODULE: Background QoL (Always ON)
-- ==========================================
local function InitBackgroundQoL()
    
    if GameTooltipStatusBar then
        GameTooltipStatusBar:Hide()
        GameTooltipStatusBar:HookScript("OnShow", function(self) self:Hide() end)
    end

    if LFDLeaveFrameLeaveButton then
        LFDLeaveFrameLeaveButton:HookScript("OnClick", function() LeaveParty() end)
    end

    hooksecurefunc("StaticPopup_Show", function(which)
        if which == "DELETE_GOOD_ITEM" then
            local frame = StaticPopup_FindVisible(which)
            if frame then frame.editBox:SetText(DELETE_ITEM_CONFIRM_STRING) end
        end
    end)
    
    local lootConfirm = CreateFrame("Frame")
    lootConfirm:RegisterEvent("LOOT_BIND_CONFIRM")
    lootConfirm:RegisterEvent("CONFIRM_LOOT_ROLL")

    local bopPending = {}
    local bopDelay = CreateFrame("Frame")
    bopDelay:Hide()
    bopDelay:SetScript("OnUpdate", function(self)
        self:Hide()
        for slot in pairs(bopPending) do
            LootSlot(slot)
            bopPending[slot] = nil
        end
    end)

    lootConfirm:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "LOOT_BIND_CONFIRM" then
            ConfirmLootSlot(arg1)
            StaticPopup_Hide("LOOT_BIND")
            bopPending[arg1] = true
            bopDelay:Show()
        elseif event == "CONFIRM_LOOT_ROLL" then
            ConfirmLootRoll(arg1, arg2)
            StaticPopup_Hide("CONFIRM_LOOT_ROLL")
        end
    end)

    local function ChatInviteFilter(self, event, msg, author, ...)
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
            local inGroup = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
            local isLeader = IsPartyLeader()
            if not inGroup or isLeader then
                InviteUnit(target)
                print("|cff00ff00Pawie Tweaks:|r Invited " .. target .. ".")
            else
                SendChatMessage("Can we invite " .. target .. "?", "PARTY")
            end
            return
        end
        orig_SetItemRef(link, text, button, chatFrame)
    end

    SetCVar("Sound_EnableErrorSpeech", "0")
    local originalAddMessage = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(frame, text, red, green, blue, id)
        if text then
            local lowerText = string.lower(text)
            if lowerText:match("bag is not empty") or lowerText:match("non%-empty") or lowerText:match("no more bag slots") or lowerText:match("free bag slot") or lowerText:match("inventory is full") or lowerText:match("cannot be equipped") or lowerText:match("with empty bags") then
                return
            end
            if lowerText:match("not ready") or lowerText:match("out of range") or lowerText:match("not enough") or lowerText:match("in progress") or lowerText:match("cooldown") or lowerText:match("can't cast") or lowerText:match("nothing to attack") then
                return
            end
        end
        originalAddMessage(frame, text, red, green, blue, id)
    end
end

-- ==========================================
-- MODULE: Fast Auto-Loot
-- ==========================================
local function InitFastLoot()
    local fastLootFrame = CreateFrame("Frame")
    fastLootFrame:RegisterEvent("LOOT_OPENED")
    fastLootFrame:RegisterEvent("LOOT_CLOSED")
    
    fastLootFrame:SetScript("OnEvent", function(self, event)
        if event == "LOOT_OPENED" then
            -- Kolla om Auto Loot är aktivt via inställning + shift-modifieraren
            local isAutoLoot = GetCVarBool("autoLootDefault")
            if IsModifiedClick("AUTOLOOTTOGGLE") then
                isAutoLoot = not isAutoLoot
            end

            if isAutoLoot then
                if LootFrame then LootFrame:SetAlpha(0) end
                for i = 1, GetNumLootItems() do
                    LootSlot(i)
                end
            else
                if LootFrame then LootFrame:SetAlpha(1) end
            end
        elseif event == "LOOT_CLOSED" then
            if LootFrame then LootFrame:SetAlpha(1) end
        end
    end)
end

-- ==========================================
-- MODULE: Change Any Bag
-- ==========================================
local function InitBagUpgrade()
    local bu = nil 
    local buFrame = CreateFrame("Frame")
    local BU_TIMEOUT = 15 

    local function SlotLocked(bag, slot)
        return select(3, GetContainerItemInfo(bag, slot)) and true or false
    end

    local function SlotEmpty(bag, slot)
        return GetContainerItemLink(bag, slot) == nil
    end

    local function ItemFamily(link)
        return (link and GetItemFamily(link)) or 0
    end

    local function FamilyFits(bagFamily, itemFamily)
        return bagFamily == 0 or itemFamily == 0 or bit.band(bagFamily, itemFamily) ~= 0
    end

    local function StopBagUpgrade(errMsg)
        if errMsg then print("|cffff0000Pawie Tweaks:|r " .. errMsg) end
        bu = nil
        buFrame:UnregisterEvent("BAG_UPDATE")
        buFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
        buFrame:SetScript("OnUpdate", nil)
    end

    local function StepBagUpgrade()
        if not bu then return end

        if bu.phase == "moving" then
            local mv = bu.moves[1]
            if not mv then
                bu.phase = "equip"
                return StepBagUpgrade()
            end
            if SlotEmpty(mv.fromBag, mv.fromSlot) then
                table.remove(bu.moves, 1) 
                return StepBagUpgrade()
            end
            if SlotLocked(mv.fromBag, mv.fromSlot) or SlotLocked(mv.toBag, mv.toSlot) then
                return 
            end
            PickupContainerItem(mv.fromBag, mv.fromSlot)
            PickupContainerItem(mv.toBag, mv.toSlot)
            return

        elseif bu.phase == "equip" then
            if GetInventoryItemLink("player", bu.targetInvSlot) ~= bu.oldBagLink then
                bu.phase = "park"
                return StepBagUpgrade()
            end
            if CursorHasItem() then return end
            if SlotLocked(bu.newBag, bu.newSlot) then return end
            PickupContainerItem(bu.newBag, bu.newSlot) 
            PutItemInBag(bu.targetInvSlot) 
            return

        elseif bu.phase == "park" then
            if not CursorHasItem() then
                StopBagUpgrade() 
                print("|cff00ff00Pawie Tweaks:|r Bag swap complete!")
                return
            end
            if SlotLocked(bu.parkBag, bu.parkSlot) or not SlotEmpty(bu.parkBag, bu.parkSlot) then
                return
            end
            PickupContainerItem(bu.parkBag, bu.parkSlot)
            StopBagUpgrade()
            print("|cff00ff00Pawie Tweaks:|r Bag swap complete!")
        end
    end

    buFrame:SetScript("OnEvent", StepBagUpgrade)

    local buElapsed = 0
    local function BuWatchdog(_, elapsed)
        buElapsed = buElapsed + elapsed
        if buElapsed > BU_TIMEOUT then
            buElapsed = 0
            StopBagUpgrade("Bag swap timed out.")
        end
    end

    local function StartBagUpgrade(state)
        bu = state
        buElapsed = 0
        buFrame:RegisterEvent("BAG_UPDATE")
        buFrame:RegisterEvent("ITEM_LOCK_CHANGED")
        buFrame:SetScript("OnUpdate", BuWatchdog)
        StepBagUpgrade()
    end

    local function TryBagUpgrade(bag, slot)
        if bu then return false end 
        if InCombatLockdown() then return false end
        if BankFrame and BankFrame:IsShown() then return false end 
        if MerchantFrame and MerchantFrame:IsShown() then return false end 

        local link = GetContainerItemLink(bag, slot)
        if not link then return false end
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
        if equipLoc ~= "INVTYPE_BAG" then return false end

        for bagID = 1, NUM_BAG_SLOTS do
            if GetContainerNumSlots(bagID) == 0 then return false end
        end

        local targetBag, targetSlots
        for bagID = 1, NUM_BAG_SLOTS do
            local n = GetContainerNumSlots(bagID)
            if not targetSlots or n < targetSlots then
                targetBag, targetSlots = bagID, n
            end
        end
        if not targetBag then return false end

        local freeSlots = {} 
        for bagID = 0, NUM_BAG_SLOTS do
            if bagID ~= targetBag then
                local bagFamily = 0
                if bagID > 0 then
                    bagFamily = ItemFamily(GetInventoryItemLink("player", ContainerIDToInventoryID(bagID)))
                end
                for s = 1, GetContainerNumSlots(bagID) do
                    if SlotEmpty(bagID, s) then
                        table.insert(freeSlots, { bag = bagID, slot = s, family = bagFamily })
                    end
                end
            end
        end

        local newBag, newSlot = bag, slot
        local moves, usedFree = {}, {}
        local ok = true
        local itemsToMove = 0

        for s = 1, targetSlots do
            local itemLink = GetContainerItemLink(targetBag, s)
            if itemLink then
                itemsToMove = itemsToMove + 1
                local family = ItemFamily(itemLink)
                local dest
                for i, free in ipairs(freeSlots) do
                    if not usedFree[i] and FamilyFits(free.family, family) then
                        dest, usedFree[i] = free, true
                        break
                    end
                end
                if not dest then ok = false break end
                table.insert(moves, { fromBag = targetBag, fromSlot = s, toBag = dest.bag, toSlot = dest.slot })
                if targetBag == bag and s == slot then
                    newBag, newSlot = dest.bag, dest.slot
                end
            end
        end

        local parkBag, parkSlot
        if ok then
            for i, free in ipairs(freeSlots) do
                if not usedFree[i] and free.family == 0 then 
                    parkBag, parkSlot = free.bag, free.slot
                    usedFree[i] = true
                    break
                end
            end
            if not parkBag then ok = false end
        end

        if not ok then
            local neededSlots = itemsToMove + 1
            print("|cffff0000Pawie Tweaks:|r Auto-swap failed: You need at least " .. neededSlots .. " empty slots in your other bags to clear your smallest bag!")
            return true
        end

        print("|cff00ff00Pawie Tweaks:|r Change Any Bag initiated! Moving items...")
        StartBagUpgrade({
            phase = "moving",
            moves = moves,
            targetBag = targetBag,
            targetInvSlot = ContainerIDToInventoryID(targetBag),
            oldBagLink = GetInventoryItemLink("player", ContainerIDToInventoryID(targetBag)),
            newBag = newBag,
            newSlot = newSlot,
            parkBag = parkBag,
            parkSlot = parkSlot,
        })
        return true
    end

    hooksecurefunc("UseContainerItem", function(bag, slot)
        TryBagUpgrade(bag, slot)
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
    
    local processingEvent = false

    questFrame:SetScript("OnEvent", function(self, ev)
        if not PawieTweaksDB.autoQuest then return end
        if IsShiftKeyDown() then return end 
        if processingEvent then return end
        
        local npcName = string.lower(UnitName("npc") or "")
        local targetName = string.lower(UnitName("target") or "")
        if npcName:match("board") or targetName:match("board") or npcName:match("hero's call") or targetName:match("hero's call") then 
            return 
        end
        
        processingEvent = true
        
        if ev == "QUEST_GREETING" then
            local numActive = GetNumActiveQuests()
            for i = 1, numActive do 
                local _, isComplete = GetActiveTitle(i)
                if isComplete then 
                    SelectActiveQuest(i)
                    processingEvent = false
                    return 
                end
            end
            local numAvailable = GetNumAvailableQuests()
            if numAvailable > 0 then 
                SelectAvailableQuest(1)
                processingEvent = false
                return 
            end
            
        elseif ev == "GOSSIP_SHOW" then
            local active = {GetGossipActiveQuests()}
            if #active > 0 then
                local qIndex = 1
                local i = 1
                while i <= #active do
                    local nextQ = i + 1
                    while nextQ <= #active do
                        if type(active[nextQ]) == "string" and type(active[nextQ+1]) == "number" then
                            break
                        end
                        nextQ = nextQ + 1
                    end
                    
                    local isComplete = active[i+3]
                    if isComplete == true or isComplete == 1 then
                        SelectGossipActiveQuest(qIndex)
                        processingEvent = false
                        return
                    end
                    
                    qIndex = qIndex + 1
                    i = nextQ
                end
            end
            
            local available = {GetGossipAvailableQuests()}
            if #available > 0 then 
                SelectGossipAvailableQuest(1)
                processingEvent = false
                return 
            end
            
        elseif ev == "QUEST_DETAIL" then
            local objective = string.lower(GetObjectiveText() or "")
            local text = string.lower(GetQuestText() or "")
            if string.find(objective, "escort") or string.find(objective, "protect") or string.find(text, "escort") then
                print("|cff00ff00Pawie Tweaks:|r Escort quest detected. Auto-accept paused.")
            else 
                AcceptQuest() 
            end
            
        elseif ev == "QUEST_ACCEPT_CONFIRM" then
            print("|cff00ff00Pawie Tweaks:|r Event warning detected. Auto-accept paused.")
        elseif ev == "QUEST_PROGRESS" then
            if IsQuestCompletable() then CompleteQuest() end
        elseif ev == "QUEST_COMPLETE" then
            local choices = GetNumQuestChoices() or 0
            if choices <= 1 then GetQuestReward(choices) end
        end

        processingEvent = false
    end)
end

-- ==========================================
-- MODULE: UI Tweaks (Tooltip, Chat Copy & Blocks)
-- ==========================================
local function InitUITweaks()

    -- SMART TOOLTIP COLORS
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local _, unit = self:GetUnit()
        if not unit or not UnitIsPlayer(unit) then return end
        
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        if not name or not class then return end
        
        -- 1. Färga endast spelarens namn på första raden (Behåll titeln ifred)
        local color = RAID_CLASS_COLORS[class]
        if color then
            local hexColor = string.format("ff%02x%02x%02x", color.r*255, color.g*255, color.b*255)
            local titleText = GameTooltipTextLeft1:GetText()
            if titleText and string.find(titleText, name) then
                GameTooltipTextLeft1:SetText(string.gsub(titleText, name, "|c" .. hexColor .. name .. "|r"))
            end
        end
        
        -- 2. Färga Guild-namnet gult på rad 2 (om de är med i en guild)
        local guildName = GetGuildInfo(unit)
        if guildName then
            local guildText = GameTooltipTextLeft2:GetText()
            if guildText and string.find(guildText, guildName) then
                GameTooltipTextLeft2:SetText("|cFFFFFF00" .. guildText .. "|r")
            end
        end
    end)

    -- CHAT COPY
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

    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            chatFrame.pawieHistory = {}
            
            local originalChatAddMessage = chatFrame.AddMessage
            chatFrame.AddMessage = function(frame, text, ...)
                if text then
                    table.insert(frame.pawieHistory, text)
                    if #frame.pawieHistory > 200 then table.remove(frame.pawieHistory, 1) end
                end
                originalChatAddMessage(frame, text, ...)
            end

            local copyBtn = CreateFrame("Button", nil, chatFrame)
            copyBtn:SetSize(24, 24)
            copyBtn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -5, -5)
            copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
            copyBtn:SetAlpha(0.3) 
            copyBtn:SetScript("OnEnter", function(self) self:SetAlpha(1.0) end)
            copyBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.3) end)
            copyBtn:SetScript("OnClick", function()
                local allText = ""
                for j = 1, #chatFrame.pawieHistory do allText = allText .. chatFrame.pawieHistory[j] .. "\n" end
                allText = allText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
                editBox:SetText(allText)
                copyWindow:Show()
                editBox:HighlightText() 
            end)
        end
    end

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
        
        if msg == "quest" then
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
            print("|cff00ff00Pawie Tweaks Commands:|r")
            print("  |cffffff00/pawie quest|r - Toggles Auto-Quest accept and turn-in.")
            print("  |cffffff00/pawie duel|r - Toggles blocking of duel requests.")
            print("  |cffffff00/pawie ginv|r - Toggles blocking of guild invites.")
            print("  |cffffff00/pawie colors|r - Toggles class colors in chat.")
            print("  |cffffff00/rl|r - Reloads the UI.")
        end
    end

    local optionsPanel = CreateFrame("Frame", "PawieTweaksOptionsPanel", UIParent)
    optionsPanel.name = "Pawie Tweaks"
    InterfaceOptions_AddCategory(optionsPanel)

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16); title:SetText("Pawie Tweaks Settings")
    local desc = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); desc:SetJustifyH("LEFT")
    desc:SetText("A lightweight addon to automate tedious tasks.")

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

    local cbQuest = CreateCB("PT_CBQuest", "Auto-Quest (Accepts/Turns in quests. Hold SHIFT to pause)", "autoQuest", optHeader)
    cbQuest:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -8)
    local cbColors = CreateCB("PT_CBColors", "Class Colors in Chat", "chatClassColors", cbQuest, function(val) ApplyChatColors(val) end)
    local cbDuel = CreateCB("PT_CBDuel", "Block Duel Requests", "blockDuels", cbColors)
    local cbGinv = CreateCB("PT_CBGinv", "Block Guild Invites", "blockGuildInvites", cbDuel)
    
    -- Vår nya Gryphons-toggle
    local cbGryphons = CreateCB("PT_CBGryphons", "Hide Action Bar Gryphons", "hideGryphons", cbGinv, function(val) ApplyGryphons(val) end)
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
        ApplyGryphons(PawieTweaksDB.hideGryphons)
        InitBackgroundQoL()
        InitFastLoot()
        InitBagUpgrade()
        InitAutoQuest()
        InitUITweaks()
        InitMenuAndCommands()
    end
end)
