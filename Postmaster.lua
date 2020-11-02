-- Postmaster Addon for Elder Scrolls Online
-- Original Authors: Anthony Korchak aka Zierk + Garkin
-- Completely rewritten by silvereyes

Postmaster = {
    name = "Postmaster",
    title = GetString(SI_PM_NAME),
    version = "3.11.4",
    author = "silvereyes, Garkin & Zierk",
    
    -- For development use only. Set to true to see a ridiculously verbose 
    -- activity log for this addon in the chat window.
    debugMode = false,
    
    -- Flag to signal that once one email is taken and deleted, the next message 
    -- should be selected and the process should continue on it
    takingAll = false,
    
    -- Flag to signal that a message is in the process of having its attachments
    -- taken and then subsequently being deleted.  Used to disable other keybinds
    -- while this occurs.
    taking = false,
    
    -- Used to synchronize item and money attachment retrieval events so that
    -- we know when to issue a DeleteMail() call.  DeleteMail() will not work
    -- unless all server-side events related to a mail are done processing.
    -- For normal mail, this includes EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS
    -- and/or EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS.  
    -- For C.O.D. mail, the events are EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, 
    -- EVENT_MONEY_UPDATE, and EVENT_MAIL_SEND_SUCCESS (for the outgoing gold mail)
    awaitingAttachments = {},
    
    -- Contains detailed information about mail attachments (links, money, cod)
    -- for mail currently being taken.  Used to display summaries to chat.
    attachmentData = {},
    
    -- Remembers mail removal requests that don't receive a mail removed event from the server
    -- or which have the event come in while the inbox is closed
    -- so that the removals can be processed once the inbox opens again.
    mailIdsMarkedForDeletion = {},
    
    -- Remembers mail ids that fail to delete during a Take All operation
    -- for whatever reason, and therefore should not be taken again during the same
    -- operation.
    mailIdsFailedDeletion = {},
    
    -- Contains details about C.O.D. mail being taken, since events related to
    -- taking C.O.D.s do not contain mail ids as parameters.
    codMails = {},
    
    classes = {},
}

-- Max milliseconds to wait for a mail removal event from the server after calling DeleteMail
PM_DELETE_MAIL_TIMEOUT_MS = 1500

-- Number of time to try deleting the message if it fails
PM_DELETE_MAIL_MAX_RETRIES = 3

PM_MAIL_READ_TIMEOUT_MS = 1500
PM_MAIL_READ_MAX_RETRIES = 1

-- Max milliseconds to wait for attachments to be retreived after calling ZO_MailInboxShared_TakeAll
PM_TAKE_TIMEOUT_MS = 1500

-- Number of time to try taking attachments if the attempt fails
PM_TAKE_ATTACHMENTS_MAX_RETRIES = 3

-- Prefixes for bounce mail subjects
PM_BOUNCE_MAIL_PREFIXES = {
    "RTS",
    "BOUNCE",
    "RETURN"
}

-- Initalizing the addon
local function OnAddonLoaded(eventCode, addOnName)

    local self = Postmaster
    
    if ( addOnName ~= self.name ) then return end
    EVENT_MANAGER:UnregisterForEvent(self.name, eventCode)
    
    -- Initialize settings menu, saved vars, and slash commands to open settings
    self:SettingsSetup()
    
    -- Wire up scene callbacks
    self:CallbackSetup()
    
    -- Wire up server event handlers
    self:EventSetup()
    
    -- Wire up prehooks for ESOUI functions
    self:PrehookSetup()
    
    -- Wire up posthooks for ESOUI functions
    self:PosthookSetup()
    
    -- Replace keybinds in the mouse/keyboard inbox UI
    self:KeybindSetupKeyboard()
    
    -- TODO: add gamepad inbox UI keybind support
end

local systemEmailSubjects = {
    ["craft"] = {
        zo_strlower(GetString(SI_PM_CRAFT_BLACKSMITH)),
        zo_strlower(GetString(SI_PM_CRAFT_CLOTHIER)),
        zo_strlower(GetString(SI_PM_CRAFT_ENCHANTER)),
        zo_strlower(GetString(SI_PM_CRAFT_PROVISIONER)),
        zo_strlower(GetString(SI_PM_CRAFT_WOODWORKER)),
    },
    ["guildStore"] = {
        zo_strlower(GetString(SI_PM_GUILD_STORE_CANCELED)),
        zo_strlower(GetString(SI_PM_GUILD_STORE_EXPIRED)),
        zo_strlower(GetString(SI_PM_GUILD_STORE_PURCHASED)),
        zo_strlower(GetString(SI_PM_GUILD_STORE_SOLD)),
    },
    ["pvp"] = {
        zo_strlower(GetString(SI_PM_PVP_FOR_THE_WORTHY)),
        zo_strlower(GetString(SI_PM_PVP_THANKS)),
        zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_1)),
        zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_2)),
        zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_3)),
        zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_1)),
        zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_2)),
        zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_3)),
        zo_strlower(GetString(SI_PM_PVP_LOYALTY)),
    }
}

local systemEmailSenders = {
    ["undaunted"] = {
        zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_NORMAL)),
        zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_VET)),
        zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_1)),
        zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_2)),
        zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_3)),
    },
    ["pvp"] = {
        zo_strlower(GetString(SI_PM_BATTLEGROUNDS_NPC)),
    },
}

local function CanTakeAllDelete(mailData, attachmentData)

    local self = Postmaster
    
    if not mailData or not mailData.mailId or type(mailData.mailId) ~= "number" then 
        self.Debug("mailData parameter not working right")
        return false 
    end
    
    local mailIdString = self.GetMailIdString(mailData.mailId)
    if self.mailIdsFailedDeletion[mailIdString] == true then 
        self.Debug("Cannot delete because this mail already failed deletion")
        return false
    end
    
    -- Item was meant to be deleted, but the inbox closed, so include it in 
    -- the take all list
    if self:IsMailMarkedForDeletion(mailData.mailId) then
        return true
    end
    
    
    local deleteSettings = {
        cod              = self.settings.takeAllCodDelete,
        playerEmpty      = self.settings.takeAllPlayerDeleteEmpty,
        playerAttached   = self.settings.takeAllPlayerAttachedDelete,
        playerReturned   = self.settings.takeAllPlayerReturnedDelete,
        systemEmpty      = self.settings.takeAllSystemDeleteEmpty,
        systemAttached   = self.settings.takeAllSystemAttachedDelete,
        systemGuildStore = self.settings.takeAllSystemGuildStoreDelete,
        systemHireling   = self.settings.takeAllSystemHirelingDelete,
        systemOther      = self.settings.takeAllSystemOtherDelete,
        systemPvp        = self.settings.takeAllSystemPvpDelete,
        systemUndaunted  = self.settings.takeAllSystemUndauntedDelete,
    }
    
    -- Handle C.O.D. mail
    if attachmentData and attachmentData.cod > 0 then
        if not deleteSettings.cod then
            self.Debug("Cannot delete COD mail")
        end
        return deleteSettings.cod
    end
    
    local fromSystem = (mailData.fromCS or mailData.fromSystem)
    local hasAttachments = attachmentData and (attachmentData.money > 0 or #attachmentData.items > 0)
    if hasAttachments then
        
        -- Special handling for hireling mail, since we know even without opening it that
        -- all the attachments can potentially go straight to the craft bag
        local subjectField = "subject"
        local isHirelingMail = fromSystem and self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["craft"])
        
        if fromSystem then 
            if deleteSettings.systemAttached then
                
                if isHirelingMail then
                    if not deleteSettings.systemHireling then
                        self.Debug("Cannot delete hireling mail")
                    end
                    return deleteSettings.systemHireling
                
                elseif self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["guildStore"]) then
                    if not deleteSettings.systemGuildStore then
                        self.Debug("Cannot delete guild store mail")
                    end
                    return deleteSettings.systemGuildStore
                    
                elseif self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["pvp"]) 
                       or self:MailFieldMatch(mailData, "senderDisplayName", systemEmailSenders["pvp"])
                then
                    if not deleteSettings.systemPvp then
                        self.Debug("Cannot delete PvP rewards mail")
                    end
                    return deleteSettings.systemPvp
                
                elseif self:MailFieldMatch(mailData, "senderDisplayName", systemEmailSenders["undaunted"]) then
                    if not deleteSettings.systemUndaunted then
                        self.Debug("Cannot delete Undaunted rewards mail")
                    end
                    return deleteSettings.systemUndaunted
                    
                else 
                    if not deleteSettings.systemOther then
                        self.Debug("Cannot delete uncategorized system mail")
                    end
                    return deleteSettings.systemOther
                end
                    
            else
                if not deleteSettings.systemAttached then
                    self.Debug("Cannot delete system mail")
                end
                return false
            end
        elseif mailData.returned then
                if not deleteSettings.playerReturned then
                    self.Debug("Cannot delete returned mail")
                end
            return deleteSettings.playerReturned 
        else
            if not deleteSettings.playerAttached then
                self.Debug("Cannot delete player mail with attachments")
            end
            return deleteSettings.playerAttached 
        end
    else
        if fromSystem then
            if not deleteSettings.systemEmpty then
                self.Debug("Cannot delete empty system mail")
            end
            return deleteSettings.systemEmpty
        else 
            if not deleteSettings.playerEmpty then
                self.Debug("Cannot delete empty player mail")
            end
            return deleteSettings.playerEmpty 
        end
    end
    
end

-- Extracting item ids from item links
local function GetItemIdFromLink(itemLink)
    local itemId = select(4, ZO_LinkHandler_ParseLink(itemLink))
    if itemId and itemId ~= "" then
        return tonumber(itemId)
    end
end

local function MailDeleteFailed(timeoutData)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_DELETE_FAILED)
    Postmaster:Reset()
end

local MailDelete
local function GetMailDeleteCallback(mailId, retries)
    return function()
        retries = retries - 1
        if retries < 0 then
            MailDeleteFailed()
        else
            MailDelete(mailId, retries)
        end
    end
end

function MailDelete(mailId, retries)
    -- Wire up timeout callback
    local self = Postmaster
    if not retries then
        retries = PM_DELETE_MAIL_MAX_RETRIES
    end
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Delete", PM_DELETE_MAIL_TIMEOUT_MS, GetMailDeleteCallback(mailId, retries))
    
    DeleteMail(mailId, false)
end

local MailRead
local function GetMailReadCallback(retries)
    return function()
        local self = Postmaster
        retries = retries - 1
        if retries < 0 then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_READ_FAILED)
            self:Reset()
        else
            MailRead(retries)
        end
    end
end

function MailRead(retries)

    local self = Postmaster
    if not retries then
        retries = PM_MAIL_READ_MAX_RETRIES
    end
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Read", PM_MAIL_READ_TIMEOUT_MS, GetMailReadCallback(retries) )
    
    -- If there exists another message in the inbox that has attachments, select it. otherwise, clear the selection.
    local nextMailData = self:TakeAllGetNext()
    ZO_ScrollList_SelectData(ZO_MailInboxList, nextMailData)
    return nextMailData
end

local function TakeFailed()
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_TAKE_ATTACHMENTS_FAILED)
    Postmaster:Reset()
end

local TakeTimeout
local function GetTakeCallback(mailId, retries)
    return function()
        retries = retries - 1
        if retries < 0 then
            TakeFailed()
        else
            TakeTimeout(mailId, retries)
            ZO_MailInboxShared_TakeAll(mailId)
        end
    end
end
function TakeTimeout(mailId, retries)
    local self = Postmaster
    if not retries then
        retries = PM_TAKE_ATTACHMENTS_MAX_RETRIES
    end
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Take", PM_TAKE_TIMEOUT_MS, GetTakeCallback(mailId, retries) )
end

-- Register events
EVENT_MANAGER:RegisterForEvent(Postmaster.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)


--[[ Outputs formatted message to chat window if debugging is turned on ]]
function Postmaster.Debug(input, force)
    local self = Postmaster
    if not force and not self.debugMode then
        return
    end
    d("[PM-DEBUG] " .. input)
end

--[[ Registers a potential backpack slot as unique ]]--
function Postmaster:DiscoverUniqueBackpackItem(slotIndex)
    local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
    if not itemLink or itemLink == "" then
        self.backpackUniqueItems[slotIndex] = nil
    end
    local isUnique = IsItemLinkUnique(itemLink)
    if isUnique then
        self.backpackUniqueItems[slotIndex] = GetItemIdFromLink(itemLink)
    end
end

--[[ Scans the backpack and generates a list of unique items ]]--
function Postmaster:DiscoverUniqueItemsInBackpack()
    self.backpackUniqueItems = {}
    local slotIndex, _
    for slotIndex, _ in pairs(PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK].slots) do
        self:DiscoverUniqueBackpackItem(slotIndex)
    end
    return self.backpackUniqueItems
end

--[[ Places the cursor in the send mail body field. Used by the Reply action. ]]
function Postmaster.FocusSendMailBody()
    ZO_MailSendBodyField:TakeFocus()
end

--[[ Searches self.codMails for the first mail id and C.O.D. mail data taht
     match the given expected amount. ]]
function Postmaster:GetCodMailByGoldChangeAmount(goldChanged)
    for mailIdString,codMail in pairs(self.codMails) do
        if codMail.amount == goldChanged then
            return mailIdString,codMail
        end
    end
end

--[[ Searches self.codMails for the first mail id and C.O.D. mail data that 
     is marked as "complete". ]]
function Postmaster:GetFirstCompleteCodMail()
    for mailIdString,codMail in pairs(self.codMails) do
        if codMail.complete then
            return mailIdString,codMail
        end
    end
end

--[[ Returns a sorted list of mail data for the current inbox, whether keyboard 
     or gamepad. The second output parameter is the name of the mailData field 
     for items in the returned list. ]]
function Postmaster.GetMailData()
    if IsInGamepadPreferredMode() then 
        return MAIL_MANAGER_GAMEPAD.inbox.mailList.dataList, "dataSource"
    else
        return ZO_MailInboxList.data, "data"
    end
end

--[[ Returns a safe string representation of the given mail ID. Useful as an 
     associative array key for lookups. ]]
function Postmaster.GetMailIdString(mailId)
    local mailIdType = type(mailId)
    if mailIdType == "string" then 
        return mailId 
    elseif mailIdType == "number" then 
        return zo_getSafeId64Key(mailId) 
    else return 
        tostring(mailId) 
    end
end

--[[ Returns the current mail messages data array, if one is selected ]]
function Postmaster.GetOpenMailData()
    local mailId = MAIL_INBOX:GetOpenMailId()
    if type(mailId) ~= "number" then 
        Postmaster.Debug("There is no open mail id "..tostring(mailId))
        return 
    end
    local mailData = MAIL_INBOX:GetMailData(mailId)
    return mailData
end

--[[ True if Postmaster is doing any operations on the inbox. ]]
function Postmaster:IsBusy()
    return self.taking or self.takingAll or self.deleting or self.returning
end

--[[ Returns true if the given item link is for a unique item that is already in the player backpack. ]]--
function Postmaster:IsItemUniqueInBackpack(itemLink)
    local isUnique = IsItemLinkUnique(itemLink)
    if isUnique then
        local itemId = GetItemIdFromLink(itemLink)
        for slotIndex, backpackItemId in pairs(self.backpackUniqueItems) do
            if backpackItemId == itemId then
                return true
            end
        end
    end
end

--[[ True if the inbox was closed when a RequestMailDelete() call came in for 
     the given mail ID, and therefore needs to be deleted when the inbox opens
     once more. ]]
function Postmaster:IsMailMarkedForDeletion(mailId)
    if not mailId then return end
    for deleteIndex=1,#self.mailIdsMarkedForDeletion do
        if AreId64sEqual(self.mailIdsMarkedForDeletion[deleteIndex],mailId) then
            return deleteIndex
        end
    end
end

--[[ Checks the given field of a mail message for a given list of
     substrings and returns true if a match is found.
     Note, returns true for "body" requests when the read info isn't yet ready. ]]
function Postmaster:MailFieldMatch(mailData, field, substrings)
    
    -- We need to read mail contents
    if field == "body" then
    
        -- the mail isn't ready. Return true for now to trigger the read request,
        -- and we'll have to match again after it's ready.
        if not mailData.isReadInfoReady then
            return true
        end
        
        -- Match on body text
        local body = zo_strlower(ReadMail(mailData.mailId))
        if Postmaster.StringMatchFirst(body, substrings) then
            return true
        end
    
    -- All other fields are available without a read request first
    else
        local value = zo_strlower(mailData[field])
        if Postmaster.StringMatchFirst(value, substrings) then
            return true
        end
    end
end

--[[ Opens the addon settings panel ]]
function Postmaster.OpenSettingsPanel()
    LibAddonMenu2:OpenToPanel(Postmaster.settingsPanel)
end

--[[ Similar to ZO_PreHook(), except runs the hook function after the existing
     function.  If the hook function returns a value, that value is returned
     instead of the existing function's return value.]]
function Postmaster.PostHook(objectTable, existingFunctionName, hookFunction)
    if(type(objectTable) == "string") then
        hookFunction = existingFunctionName
        existingFunctionName = objectTable
        objectTable = _G
    end
     
    local existingFn = objectTable[existingFunctionName]
    if((existingFn ~= nil) and (type(existingFn) == "function"))
    then    
        local newFn =   function(...)
                            local returnVal = existingFn(...)
                            local hookVal = hookFunction(...)
                            if hookVal then
                                returnVal = hookVal
                            end
                            return returnVal
                        end

        objectTable[existingFunctionName] = newFn
    end
end

--[[ Outputs formatted message to chat window ]]
function Postmaster.Print(input)
    local self = Postmaster
    local output = self.prefix .. input .. self.suffix
    self.chat:Print(output)
end

--[[ Collects a summary of attachment data ]]
function Postmaster.CollectAttachments(sender, attachmentData)
    local self = Postmaster
    if not self.settings.chatContentsSummary.enabled or not attachmentData then return end
    
    -- Add items summary
    for attachIndex=1,#attachmentData.items do
        local attachmentItem = attachmentData.items[attachIndex]
        self.summary:AddItemLink(sender, attachmentItem.link, attachmentItem.count)
    end
    
    -- Add money summary
    local money
    if attachmentData.money > 0 then 
        money = attachmentData.money
    elseif attachmentData.cod > 0 then 
        money = -attachmentData.cod 
    end
    if money then
        self.summary:AddCurrency(sender, CURT_MONEY, money)
    end
end

--[[ Called to delete the current mail after all attachments are taken and all 
     C.O.D. money has been removed from the player's inventory.  ]]
function Postmaster:RequestMailDelete(mailId)
    local mailIdString = self.GetMailIdString(mailId)
    
    -- If the we haven't received confirmation that the server received the
    -- payment for a C.O.D. mail, exit without deleting the mail. 
    -- This method will be called again from Event_MailSendSuccess(), at which
    -- time it should proceed with the delete because the mail id string is
    -- removed from self.codMails.
    local codMail = self.codMails[self.GetMailIdString(mailId)]
    if codMail then
        codMail.complete = true
        return
    end
    
    -- Collect summary of attachments
    -- Do this here, immediately after all attachments are collected and C.O.D. are paid, 
    -- Don't wait until the mail removed event, because it may or may not go 
    -- through if the user closes the inbox.
    local mailData = MAIL_INBOX:GetMailData(mailId)
    self.CollectAttachments(mailData.fromSystem and "@SYSTEM" or mailData.senderDisplayName, self.attachmentData[mailIdString])
    
    -- Clean up tracking arrays
    self.awaitingAttachments[mailIdString] = nil
    
    local attachmentData = self.attachmentData[mailIdString]
    self.attachmentData[mailIdString] = nil
    
    if (mailData.attachedMoney and mailData.attachedMoney > 0) or (mailData.numAttachments and mailData.numAttachments > 0) then
        self.Debug("Cannot delete mail id "..mailIdString.." because it is not empty")
        self.mailIdsFailedDeletion[mailIdString] = true
        self.Event_MailRemoved(nil, mailId)
        return
    end
    
    
    -- Check that the current type of mail should be deleted
    if self.takingAll then
        if not CanTakeAllDelete(mailData, attachmentData) then
            self.Debug("Not deleting mail id "..mailIdString.." because of configured options")
            -- Skip actual mail removal and go directly to the postprocessing logic
            self.mailIdsFailedDeletion[mailIdString] = true
            self.Event_MailRemoved(nil, mailId)
            return
        end
    end
    
    
    -- Mark mail for deletion
    self.Debug("Marking mail id "..tostring(mailId).." for deletion")
    table.insert(self.mailIdsMarkedForDeletion, mailId)
    
    -- If inbox is open...
    if SCENE_MANAGER:IsShowing("mailInbox") then
        -- If all attachments are gone, remove the message
        self.Debug("Deleting "..tostring(mailId))
        
        MailDelete(mailId)
        
    -- Inbox is no longer open, so delete events won't be raised
    else
        if not AreId64sEqual(self.mailIdLastOpened,mailId) then
            self.Debug("Marking mail id "..tostring(mailId).." to be opened when inbox does")
            MAIL_INBOX.mailId = nil
            MAIL_INBOX.requestMailId = mailId
        end
    end
end

--[[ Sets state variables back to defaults and ensures a consistent inbox state ]]
function Postmaster:Reset()
    self.Debug("Reset")
    self.taking = false
    self.takingAll = false
    self.mailIdsFailedDeletion = {}
    -- Print attachment summary
    self.summary:Print()
    ZO_MailInboxList.autoSelect = true
    -- Unwire timeout callbacks
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Delete")
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Read")
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Take")
    KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
    if MAIL_INBOX.mailId then
        local currentMailData = ZO_MailInboxList.selectedData
        if not currentMailData then
            self.Debug("Current mail data is nil. Setting MAIL_INBOX.mailId=nil")
            MAIL_INBOX.mailId = nil
            MAIL_INBOX.selectedData = nil
            ZO_ScrollList_AutoSelectData(ZO_MailInboxList)
        elseif not MAIL_INBOX.selectedData then
            MAIL_INBOX.mailId = currentMailData.mailId
            MAIL_INBOX.selectedData = currentMailData
        end
    end
end

--[[ Generates an array of lines all less than the given maximum string length,
     optionally using an array of word boundary strings for pretty wrapping.
     If a line has no word boundaries, or if no boundaries were specified, then
     each line will just be split at the maximum string length. ]]
function Postmaster.SplitLines(text, maxStringLength, wordBoundaries)
    wordBoundaries = wordBoundaries or {}
    local lines = {}
    local index = 1
    local textMax = string.len(text) + 1
    while textMax > index do
        local splitAt
        if index + maxStringLength > textMax then
            splitAt = textMax - index
        else
            local substring = string.sub(text, index, index + maxStringLength - 1)
            for _,delimiter in ipairs(wordBoundaries) do
                local pattern = ".*("..delimiter..")"
                local _,matchIndex = string.find(substring, pattern)
                if matchIndex and (splitAt == nil or matchIndex > splitAt) then
                    splitAt = matchIndex
                end
            end
            splitAt = splitAt or maxStringLength
        end
        local line = string.sub(text, index, index + splitAt - 1 )
        table.insert(lines, line)
        index = index + splitAt 
    end
    return lines
end

--[[ Checks the given string for a given list of
     substrings and returns the start and end indexes if a match is found. ]]
function Postmaster.StringMatchFirst(s, substrings)
    assert(type(s) == "string", "s parameter must be a string")
    if s == "" then return end
    for i=1,#substrings do
        local sub = substrings[i]
        if sub ~= "" then
            local matchStart, matchEnd = s:find(sub, 1, true)
            if matchStart then
                return matchStart, matchEnd
            end
        end
    end
end

--[[ Checks the given string for a given list of
     prefixes and returns the start and end indexes if a match is found. ]]
function Postmaster.StringMatchFirstPrefix(s, prefixes)
    assert(type(s) == "string", "s parameter must be a string")
    if s == "" then return end
    local sLen = s:len()
    for i=1,#prefixes do
        local prefix = prefixes[i]
        if prefix ~= "" then
            local pLen = prefix:len()
            if sLen == pLen then
                if s == prefix then
                    return 1, pLen
                end
            elseif sLen > pLen then
                prefix = prefix .. GetString(SI_PM_WORD_SEPARATOR)
                if prefix:len() > pLen then
                    pLen = prefix:len()
                    if sLen == pLen then
                        if s == prefix then
                            return 1, pLen
                        end
                    end
                end
                if sLen > pLen then
                    if s:sub(1, pLen) == prefix then
                        return 1, pLen
                    end
                end
            end
        end
    end
end


--[[ True if the given mail can be taken according to the given settings ]]
local function CanTakeShared(mailData, settings)

    local self = Postmaster
    
    if not mailData or not mailData.mailId or type(mailData.mailId) ~= "number" then 
        return false 
    end
    
    local mailIdString = self.GetMailIdString(mailData.mailId)
    if self.mailIdsFailedDeletion[mailIdString] == true then
        return false
    end
    
    -- Item was meant to be deleted, but the inbox closed, so include it in 
    -- the take all list
    if self:IsMailMarkedForDeletion(mailData.mailId) then
        return true
    
    -- Handle C.O.D. mail
    elseif mailData.codAmount and mailData.codAmount > 0 then
    
        -- Skip C.O.D. mails, if so configured
        if not settings.codTake then return false
        
        -- Enforce C.O.D. absolute gold limit
        elseif settings.codGoldLimit > 0 and mailData.codAmount > settings.codGoldLimit then return false
        
        -- Skip C.O.D. mails that we don't have enough money to pay for
        elseif mailData.codAmount > GetCurrentMoney() then return false 
        
        else return true end
    end
    
    local fromSystem = (mailData.fromCS or mailData.fromSystem)
    local hasAttachments = (mailData.attachedMoney and mailData.attachedMoney > 0) or (mailData.numAttachments and mailData.numAttachments > 0)
    if hasAttachments then
        
        -- Special handling for hireling mail, since we know even without opening it that
        -- all the attachments can potentially go straight to the craft bag
        local subjectField = "subject"
        local isHirelingMail = fromSystem and self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["craft"])
        local freeSlots = GetNumBagFreeSlots(BAG_BACKPACK)
        local attachmentsToCraftBag = isHirelingMail and HasCraftBagAccess() and GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG) == "1" and freeSlots > 0
        
        -- Check to make sure there are enough slots available in the backpack
        -- to contain all attachments.  This logic is overly simplistic, since 
        -- theoretically, stacking and craft bags could free up slots. But 
        -- reproducing that business logic here sounds hard, so I gave up.
        if mailData.numAttachments and mailData.numAttachments > 0 
           and (freeSlots - mailData.numAttachments) < settings.reservedSlots
           and not attachmentsToCraftBag
        then 
            return false 
        end
        
        if fromSystem then 
            if settings.systemAttached then
                
                if isHirelingMail then
                    return settings.systemHireling
                
                elseif self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["guildStore"]) then
                    return settings.systemGuildStore
                    
                elseif self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["pvp"])
                       or self:MailFieldMatch(mailData, "senderDisplayName", systemEmailSenders["pvp"])
                then
                    return settings.systemPvp
                
                elseif self:MailFieldMatch(mailData, "senderDisplayName", systemEmailSenders["undaunted"]) then
                    return settings.systemUndaunted
                    
                else 
                    return settings.systemOther
                end
                    
            else
                return false
            end
        elseif mailData.returned then
            return settings.playerReturned 
        else
            return settings.playerAttached 
        end
    else
        if fromSystem then 
            return settings.systemDeleteEmpty
        else 
            return settings.playerDeleteEmpty 
        end
    end
end


--[[ True if the given mail can be taken by Take operations according
     to current options panel criteria. ]]
function Postmaster:QuickTakeCanTake(mailData)
    return CanTakeShared(mailData, {
        ["codTake"]           = self.settings.quickTakeCodTake,
        ["codGoldLimit"]      = self.settings.quickTakeCodGoldLimit,
        ["reservedSlots"]     = 0,
        ["systemAttached"]    = self.settings.quickTakeSystemAttached,
        ["systemHireling"]    = self.settings.quickTakeSystemHireling,
        ["systemGuildStore"]  = self.settings.quickTakeSystemGuildStore,
        ["systemPvp"]         = self.settings.quickTakeSystemPvp,
        ["systemUndaunted"]   = self.settings.quickTakeSystemUndaunted,
        ["systemOther"]       = self.settings.quickTakeSystemOther,
        ["playerReturned"]    = self.settings.quickTakePlayerReturned,
        ["playerAttached"]    = self.settings.quickTakePlayerAttached,
        ["systemDeleteEmpty"] = true,
        ["playerDeleteEmpty"] = true,
    })
end

--[[ True if the given mail can be taken by Take All operations according
     to current options panel criteria. ]]
function Postmaster:TakeAllCanTake(mailData)
    return CanTakeShared(mailData, {
        ["codTake"]           = self.settings.takeAllCodTake,
        ["codGoldLimit"]      = self.settings.takeAllCodGoldLimit,
        ["reservedSlots"]     = self.settings.reservedSlots,
        ["systemAttached"]    = self.settings.takeAllSystemAttached,
        ["systemHireling"]    = self.settings.takeAllSystemHireling,
        ["systemGuildStore"]  = self.settings.takeAllSystemGuildStore,
        ["systemPvp"]         = self.settings.takeAllSystemPvp,
        ["systemUndaunted"]   = self.settings.takeAllSystemUndaunted,
        ["systemOther"]       = self.settings.takeAllSystemOther,
        ["playerReturned"]    = self.settings.takeAllPlayerReturned,
        ["playerAttached"]    = self.settings.takeAllPlayerAttached,
        ["systemDeleteEmpty"] = self.settings.takeAllSystemDeleteEmpty,
        ["playerDeleteEmpty"] = self.settings.takeAllPlayerDeleteEmpty,
    })
end

--[[ True if the currently-selected mail can be taken by Take All operations 
     according to current options panel criteria. ]]
function Postmaster:TakeAllCanTakeSelectedMail()
    if MAIL_INBOX.selectedData 
       and self:TakeAllCanTake(MAIL_INBOX.selectedData) 
    then 
        return true 
    end
end

--[[ Gets the next highest-priority mail data instance that Take All can take ]]
function Postmaster:TakeAllGetNext()
    for i=1,#ZO_MailInboxList.data do
        local item = ZO_MailInboxList.data[i]
        if self:TakeAllCanTake(item.data) then
            return item.data
        end
    end
end

--[[ Selects the next highest-priority mail data instance that Take All can take ]]
function Postmaster:TakeAllSelectNext()
    -- Don't need to get anything. The current selection already has attachments.
    if self:TakeAllCanTakeSelectedMail() then return true end
    
    local nextMailData = MailRead()
    if nextMailData then
        return true
    end
end

--[[ Takes attachments from the selected (readable) mail if they exist, or 
     deletes the mail if it has no attachments. ]]
function Postmaster:TakeOrDeleteSelected()
    if self:TryTakeAllCodMail() then return end
    local mailData = MAIL_INBOX.selectedData
    local hasAttachments = (mailData.attachedMoney and mailData.attachedMoney > 0)
      or (mailData.numAttachments and mailData.numAttachments > 0)
    if hasAttachments then
        self.taking = true
        self.originalDescriptors.take.callback()
    else
        -- If all attachments are gone, remove the message
        self.Debug("Deleting "..tostring(mailData.mailId))
        
        -- Delete the mail
        self:RequestMailDelete(mailData.mailId)
    end
end

--[[ Scans the inbox for any player messages starting with RTS, BOUNCE or RETURN
     in the subject, and automatically returns them to sender, if so configured ]]
function Postmaster:TryAutoReturnMail()
    if not self.settings.bounce or not self.inboxUpdated or self:IsBusy() then
        return
    end
    
    self.returning = true
    local data, mailDataIndex = self.GetMailData()
    for _,entry in pairs(data) do
        local mailData = entry[mailDataIndex]
        if mailData and mailData.mailId and not mailData.fromCS 
           and not mailData.fromSystem and mailData.codAmount == 0 
           and (mailData.numAttachments > 0 or mailData.attachedMoney > 0)
           and not mailData.returned
           and Postmaster.StringMatchFirstPrefix(zo_strupper(mailData.subject), PM_BOUNCE_MAIL_PREFIXES) 
        then
            ReturnMail(mailData.mailId)
            self.Print(zo_strformat(GetString(SI_PM_BOUNCE_MESSAGE), mailData.senderDisplayName))
        end
    end
    self.inboxUpdated = false
    self.returning = false
end

--[[ Called when the inbox opens to automatically delete any mail that finished
     a Take or Take All operation after the inbox was closed. ]]
function Postmaster:TryDeleteMarkedMail(mailId)
    local deleteIndex = self:IsMailMarkedForDeletion(mailId)
    if not deleteIndex then return end
    -- Resume the Take operation. will be cleared when the mail removed event handler fires.
    self.taking = true 
    self.Debug("deleting mail id "..tostring(mailId))
    self:RequestMailDelete(mailId)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
    return deleteIndex
end

--[[ Bypasses the original "Take attachments" logic for C.O.D. mail during a
     Take All operation. ]]
function Postmaster:TryTakeAllCodMail()
    if not self.settings.takeAllCodTake then return end
    local mailData = MAIL_INBOX.selectedData
    if mailData.codAmount and mailData.codAmount > 0 then
        self.taking = true
        MAIL_INBOX.pendingAcceptCOD = true
        ZO_MailInboxShared_TakeAll(mailData.mailId)
        MAIL_INBOX.pendingAcceptCOD = false
        return true
    end
end




--[[ 
    ===================================
                KEYBINDS
    ===================================
  ]]

--[[ Given a keybind group descriptor and a keybind name, returns the button
     descriptor assigned to that keybind. ]]
function Postmaster.KeybindGetDescriptor(keybindGroup, keybind)
    for i,descriptor in ipairs(keybindGroup) do
        if descriptor.keybind == keybind then
            return descriptor
        end
    end
end

--[[ Saves the original keyboard UI inbox keybinds and replaces them with our
     custom ones. ]]
function Postmaster:KeybindSetupKeyboard()

    local originalGroup = MAIL_INBOX.selectionKeybindStripDescriptor
    self.originalDescriptors = {
        take = self.KeybindGetDescriptor(originalGroup, "UI_SHORTCUT_PRIMARY"),
        delete = self.KeybindGetDescriptor(originalGroup, "UI_SHORTCUT_NEGATIVE"),
        returnToSender = self.KeybindGetDescriptor(originalGroup, "UI_SHORTCUT_SECONDARY"),
        reply = self.KeybindGetDescriptor(originalGroup, "MAIL_REPLY")
    }
    
    --[[ Create the new primary, secondary and negative keybinds.
         Note the use of anonymous functions is necessary, since keybind 
         button callbacks do not pass "self", and the only argument they 
         pass is a boolean specifying whether it was a keyup or keydown.]]
    local controller = self
    local keybindGroup = {
        inboxController = self,
        alignment = originalGroup.alignment,
        {
            name = self.Keybind_Primary_GetName,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = self.Keybind_Primary_Callback,
            visible = self.Keybind_Primary_Visible
        },
        {
            name = GetString(SI_LOOT_TAKE_ALL),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = self.Keybind_TakeAll_Callback,
            visible = self.Keybind_TakeAll_Visible
        },
        {
            name = self.Keybind_Negative_GetName,
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = self.Keybind_Negative_Callback,
            visible = self.Keybind_Negative_Visible,
            originalDescriptor = self.originalDescriptors.returnToSender
        }
    }
    
    -- Create a tertiary keybind for Reply, 
    -- if MailR didn't already add a reply keybind
    if not self.originalDescriptors.reply then
        table.insert(keybindGroup, {
            name = GetString(SI_MAIL_READ_REPLY),
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = self.Keybind_Reply_Callback,
            visible = self.Keybind_Reply_Visible
        })
    end
    
    -- Point any additional existing keybinds that we haven't mapped already to
    -- the Keybind_Other_Callback() method, which hides the button if a Take
    -- or Take All operation is in process, but otherwise calls the original
    -- callback when executed.
    for i,descriptor in ipairs(originalGroup) do
        local existing = self.KeybindGetDescriptor(keybindGroup, descriptor.keybind)
        if not existing then
            table.insert(keybindGroup, {
                name = descriptor.name,
                keybind = descriptor.keybind,
                callback = self.Keybind_Other_Callback,
                visible = self.Keybind_Other_Visible,
                originalDescriptor = descriptor
            })
        end
    end
    
    -- Overwrite the keybind strip for the mouse/keyboard UI inbox
    MAIL_INBOX.selectionKeybindStripDescriptor = keybindGroup
end

--[[   
 
    Return to sender - OR - Cancel take all, depending on context 
    
  ]]
function Postmaster.Keybind_Negative_Callback()
    local self = Postmaster
    if self.taking then 
        -- Abort take all command
        if self.takingAll then
            self:Reset()
        end
    -- Return to sender when not in the middle of a take all
    elseif self.originalDescriptors.returnToSender.visible() then
        self.originalDescriptors.returnToSender.callback()
    end
end
function Postmaster.Keybind_Negative_GetName()
    local self = Postmaster
    if self.originalDescriptors.returnToSender.visible() then
        return self.originalDescriptors.returnToSender.name
    end
    return GetString(SI_CANCEL)
end
function Postmaster.Keybind_Negative_Visible()
    local self = Postmaster
    if self.takingAll then return true end
    if self:IsBusy() then return false end
    if MailR and MailR.IsMailIdSentMail(MAIL_INBOX.mailId) then
        return false
    end
    return self.originalDescriptors.returnToSender.visible()
end

--[[   
 
    The following methods just wrap a check for the self.taking state variable
    to ensure that no other existing keybinds execute while Take or Take All 
    command is running.
    
  ]]
function Postmaster.Keybind_Other_Callback()
    local self = Postmaster
    self.Keybind_Other_Invoke(self.keybindButtonForCallback, "callback")
end
function Postmaster.Keybind_Other_Invoke(button, functionName)
    local self = Postmaster
    if self:IsBusy() then return end
    if not button then return end
    local buttonDescriptor = button.keybindButtonDescriptor
    if not buttonDescriptor or not buttonDescriptor.originalDescriptor then return end
    local functionInstance = buttonDescriptor.originalDescriptor[functionName]
    if type(functionInstance) ~= "function" then return end
    return functionInstance()
end
function Postmaster.Keybind_Other_Visible()
    local self = Postmaster
    return self.Keybind_Other_Invoke(self.keybindButtonForVisible, "visible")
end

--[[   
 
    Take or Delete, depending on if the current mail has attachments or not.
    
  ]]
function Postmaster.Keybind_Primary_Callback()
    local self = Postmaster
    if self:IsBusy() then return end
    if self.originalDescriptors.delete.visible()
       or (MailR and MailR.IsMailIdSentMail(MAIL_INBOX.mailId))
    then
        self.Debug("deleting mail id "..tostring(MAIL_INBOX.mailId))
        self.originalDescriptors.delete.callback()
        return
    end
    
    local mailData = self.GetOpenMailData()
    if self:QuickTakeCanTake(mailData) then
        self.taking = true
    end
    self.originalDescriptors.take.callback()
end
function Postmaster.Keybind_Primary_GetName()
    local self = Postmaster
    if self.originalDescriptors.delete.visible() or
       (MailR and MailR.IsMailIdSentMail(self.mailId))
    then
        return self.originalDescriptors.delete.name
    end
    
    local mailData = self.GetOpenMailData()
    if self:QuickTakeCanTake(mailData) then
        return GetString(SI_LOOT_TAKE)
    else
        return GetString(SI_MAIL_READ_ATTACHMENTS_TAKE)
    end
end
function Postmaster.Keybind_Primary_Visible()
    local self = Postmaster
    if self:IsBusy() then return false end
    if self.originalDescriptors.take.visible() then return true end
    if MailR and MailR.IsMailIdSentMail(MAIL_INBOX.mailId) then return true end
    return self.originalDescriptors.delete.visible()
end

--[[   
 
    Reply
    
  ]]
function Postmaster.Keybind_Reply_Callback()
    local self = Postmaster
    
    -- Look up the current mail message in the inbox
    local mailData = self.GetOpenMailData()
    
    -- Make sure it's a non-returned mail from another player
    if not mailData or mailData.fromSystem or mailData.returned then return end
    
    -- Populate the sender and subject for the reply
    local address = mailData.senderDisplayName
    local subject = mailData.subject
    
    MAIL_SEND:ClearFields()
    MAIL_SEND:SetReply(address, subject)
    SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, self.FocusSendMailBody)
    ZO_MainMenuSceneGroupBar.m_object:SelectDescriptor("mailSend")
end
function Postmaster.Keybind_Reply_Visible()
    local self = Postmaster
    if self:IsBusy() then return false end
    if MAIL_INBOX.mailId == nil then return end
    local mailData = MAIL_INBOX:GetMailData(MAIL_INBOX.mailId)
    if not mailData then return false end
    return not (mailData.fromCS or mailData.fromSystem)
end

--[[   
 
    Take All
    
  ]]
function Postmaster.Keybind_TakeAll_Callback()
    local self = Postmaster
    if self:IsBusy() then return end
    if self:TakeAllCanTakeSelectedMail() then
        self.Debug("Selected mail has attachments. Taking.")
        self.taking    = true
        self.takingAll = true
        ZO_MailInboxList.autoSelect = false
        self:TakeOrDeleteSelected()
    elseif self:TakeAllSelectNext() then
        self.Debug("Getting next mail with attachments")
        self.taking    = true
        self.takingAll = true
        ZO_MailInboxList.autoSelect = false
        -- will call the take or delete callback when the message is read
    end
end
function Postmaster.Keybind_TakeAll_Visible()
    local self = Postmaster
    if self:IsBusy() or not self:TakeAllGetNext() then return false end
    return true
end





--[[ 
    ===================================
                CALLBACKS
    ===================================
  ]]
  
--[[ Wire up all callback handlers ]]
function Postmaster:CallbackSetup()
    CALLBACK_MANAGER:RegisterCallback("BackpackFullUpdate", self.Callback_BackpackFullUpdate)
    MAIL_INBOX_SCENE:RegisterCallback("StateChange",        self.Callback_MailInbox_StateChange)
end

--[[ Raised whenever the backpack inventory is populated. ]]
function Postmaster.Callback_BackpackFullUpdate()
    local self = Postmaster
    self:DiscoverUniqueItemsInBackpack()
end

--[[ Raised whenever the inbox is shown or hidden. ]]
function Postmaster.Callback_MailInbox_StateChange(oldState, newState)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    
    -- Inbox shown
    if newState == SCENE_SHOWN then
        -- Request mail from the server that was originally requested while
        -- the inbox was closed
        if(MAIL_INBOX.requestMailId) then
            MAIL_INBOX:RequestReadMessage(MAIL_INBOX.requestMailId)
            MAIL_INBOX.requestMailId = nil
        end
        -- If a mail is selected that was previously marked for deletion but never
        -- finished, automatically delete it.
        if not self:TryDeleteMarkedMail(MAIL_INBOX.mailId) then
            -- If not deleting mail, then try auto returning mail
            self:TryAutoReturnMail()
        end
    
    -- Inbox hidden
    -- Reset state back to default when inbox hidden, since most server events
    -- will no longer fire with the inbox closed.
    elseif newState == SCENE_HIDDEN then
    
        self:Reset()
    end
end





--[[ 
    ===================================
               SERVER EVENTS 
    ===================================
  ]]

function Postmaster:EventSetup()
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_IS_FULL, self.Event_InventoryIsFull)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self.Event_InventorySingleSlotUpdate)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_INBOX_UPDATE, self.Event_MailInboxUpdate)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_READABLE,     self.Event_MailReadable)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_REMOVED,      self.Event_MailRemoved)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_SEND_SUCCESS, self.Event_MailSendSuccess)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, 
        self.Event_MailTakeAttachedItemSuccess)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS,  
        self.Event_MailTakeAttachedMoneySuccess)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MONEY_UPDATE,      self.Event_MoneyUpdate)
    
    -- Fix for Wykkyd Mailbox keybind conflicts
    if type(WYK_MailBox) == "table" then
        WYK_MailBox:UnregisterEvent(EVENT_MAIL_READABLE)
    end
end

--[[ Raised when an attempted item transfer to the backpack fails due to not 
     enough slots being available.  When this happens, we should abort any 
     pending operations and reset controller state. ]]
function Postmaster.Event_InventoryIsFull(eventCode, numSlotsRequested, numSlotsFree)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    self:Reset()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
end

--[[ Raised when a player inventory slot is updated. ]]
function Postmaster.Event_InventorySingleSlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    if bagId ~= BAG_BACKPACK then
        return
    end
    local self = Postmaster
    self:DiscoverUniqueBackpackItem(slotIndex)
end

--[[ Raised whenever new mail arrives.  When this happens, mark that we need to 
     check for auto-return mail. ]]
function Postmaster.Event_MailInboxUpdate(eventCode)
    local self = Postmaster
    if not self.settings.bounce then return end
    
    self.Debug("Setting self.inboxUpdated to true")
    self.inboxUpdated = true
end

--[[ Raised in response to a successful RequestReadMail() call. Indicates that
     the mail is now open and ready for actions. It is necessary for this event 
     to fire before most actions on a mail message will be allowed by the server.
     Here, we trigger or cancel the next Take All loop,
     as well as automatically delete any empty messages marked for removal in the
     self.mailIdsMarkedForDeletion array. ]]
function Postmaster.Event_MailReadable(eventCode, mailId)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    self.Debug("Event_MailReadable("..tostring(mailId)..")")
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Read")
        
    -- If taking all, then go ahead and start the next Take loop, since the
    -- mail and attachments are readable now.
    if self.takingAll then 
        self:TakeOrDeleteSelected()
        
    -- If a mail is selected that was previously marked for deletion but never
    -- finished, automatically delete it.
    elseif not self:TryDeleteMarkedMail(MAIL_INBOX.mailId) then
    
        -- Otherwise, try auto-returning any new mail that's arrived
        self:TryAutoReturnMail()
    
    end
end

--[[ Raised in response to a successful DeleteMail() call. Used to trigger 
     opening the next mail with attachments for Take All, or reset state 
     variables and refresh the keybind strip for Take. ]]
function Postmaster.Event_MailRemoved(eventCode, mailId)
    local self = Postmaster
    if not self.taking then return end
    local deleteIndex = self:IsMailMarkedForDeletion(mailId)
    table.remove(self.mailIdsMarkedForDeletion, deleteIndex)
    
    if IsInGamepadPreferredMode() then return end
    
    if eventCode then
        
        -- Unwire timeout callback
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "Delete")
        PlaySound(SOUNDS.MAIL_ITEM_DELETED)
        self.Debug("deleted mail id "..tostring(mailId))
    end
    
    -- In the middle of auto-return
    if self.returning then return end
    
    local isInboxOpen = SCENE_MANAGER:IsShowing("mailInbox")
    
    -- For non-canceled take all requests, select the next mail for taking.
    -- It will be taken automatically by Event_MailReadable() once the 
    -- EVENT_MAIL_READABLE event comes back from the server.
    if isInboxOpen and self.takingAll then
        self.Debug("Selecting next mail with attachments")
        if self:TakeAllSelectNext() then return end
    end
    
    -- This was either a normal take, or there are no more valid mails
    -- for take all, or an abort was requested, so cancel out.
    self:Reset()
    
    -- If the inbox is still open when the delete comes through, refresh the
    -- keybind strip.
    if isInboxOpen then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
        
    -- If the inbox was closed when the actual delete came through from the
    -- server, it leaves the inbox list in an inconsistent (dirty) state.
    else
        self.Debug("Setting inbox mail id to nil")
        MAIL_INBOX.mailId = nil
        
        -- if the inbox is open, try auto returning mail now
        self:TryAutoReturnMail()
    end
end

--[[ Raised after a sent mail message is received by the server. We only care
     about this event because C.O.D. mail cannot be deleted until it is raised. ]]
function Postmaster.Event_MailSendSuccess(eventCode) 
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    if not self.taking then return end
    self.Debug("Event_MailSendSuccess()")
    local mailIdString,codMail = self:GetFirstCompleteCodMail()
    if not codMail then return end
    self.codMails[mailIdString] = nil
    -- Now that we've seen that the gold is sent, we can delete COD mail
    self:RequestMailDelete(codMail.mailId)
end

--[[ Raised when attached items are all received into inventory from a mail.
     Used to automatically trigger mail deletion. ]]
function Postmaster.Event_MailTakeAttachedItemSuccess(eventCode, mailId)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    if not self.taking then return end
    self.Debug("attached items taken "..tostring(mailId))
    local waitingForMoney = table.remove(self.awaitingAttachments[self.GetMailIdString(mailId)])
    if waitingForMoney then 
        self.Debug("still waiting for money or COD. exiting.")
    else
        -- Stop take attachments retries
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "Take")
        self:RequestMailDelete(mailId)
    end
end

--[[ Raised when attached gold is all received into inventory from a mail.
     Used to automatically trigger mail deletion. ]]
function Postmaster.Event_MailTakeAttachedMoneySuccess(eventCode, mailId)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    if not self.taking then return end
    self.Debug("attached money taken "..tostring(mailId))
    local waitingForItems = table.remove(self.awaitingAttachments[self.GetMailIdString(mailId)])
    if waitingForItems then 
        self.Debug("still waiting for items. exiting.")
    else
        -- Stop take attachments retries
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "Take")
        self:RequestMailDelete(mailId)
    end
end

--[[ Raised whenever gold enters or leaves the player's inventory.  We only care
     about money leaving inventory due to a mail event, indicating a C.O.D. payment.
     Used to automatically trigger mail deletion. ]]
function Postmaster.Event_MoneyUpdate(eventCode, newMoney, oldMoney, reason)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    if not self.taking then return end
    self.Debug("Event_MoneyUpdate("..tostring(eventCode)..","..tostring(newMoney)..","..tostring(oldMoney)..","..tostring(reason)..")")
    if reason ~= CURRENCY_CHANGE_REASON_MAIL or oldMoney <= newMoney then 
        self.Debug("not mail reason or money change not negative")
        return
    end
   
    -- Unfortunately, since this isn't a mail-specific event 
    -- (thanks ZOS for not providing one), it doesn't have a mailId parameter, 
    -- so we kind of kludge it by using C.O.D. amount and assuming first-in-first-out
    local goldChanged = oldMoney - newMoney
    local mailIdString,codMail = self:GetCodMailByGoldChangeAmount(goldChanged)
    
    -- This gold removal event is unrelated to C.O.D. mail. Exit.
    if not codMail then
        self.Debug("did not find any mail items with a COD amount of "..tostring(goldChanged))
        return
    end
    
    -- Stop take attachments retries
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Take")
    
    -- This is a C.O.D. payment, so trigger a mail delete if all items have been
    -- removed from the mail already.
    self.Debug("COD amount of "..tostring(goldChanged).." paid "..mailIdString)
    local waitingForItems = table.remove(self.awaitingAttachments[mailIdString])
    if waitingForItems then 
        self.Debug("still waiting for items. exiting.")
    else
        self:RequestMailDelete(codMail.mailId)
    end
end

--[[ 
    ===================================
                 PREHOOKS
    ===================================
  ]]

--[[ Wire up all prehook handlers ]]
function Postmaster:PrehookSetup()
    ZO_PreHook(KEYBIND_STRIP, "SetUpButton", self.Prehook_KeybindStrip_ButtonSetup)
    ZO_PreHook("ZO_MailInboxShared_TakeAll", self.Prehook_MailInboxShared_TakeAll)
    ZO_PreHook("RequestReadMail", self.Prehook_RequestReadMail)
    ZO_PreHook("ZO_ScrollList_SelectData", self.Prehook_ScrollList_SelectData)
    ZO_PreHook("ZO_Dialogs_ShowDialog", self.Prehook_Dialogs_ShowDialog)
    ZO_PreHook("ZO_Dialogs_ShowGamepadDialog", self.Prehook_Dialogs_ShowGamepadDialog)
end


--[[ Suppress mail delete and/or return to sender dialog in keyboard mode, if configured ]]
function Postmaster.Prehook_Dialogs_ShowDialog(name, data, textParams, isGamepad)
    local self = Postmaster
    if self.settings.deleteDialogSuppress and name == "DELETE_MAIL" then 
        MAIL_INBOX:ConfirmDelete(MAIL_INBOX.mailId)
        return true
    elseif Postmaster.settings.returnDialogSuppress and name == "MAIL_RETURN_ATTACHMENTS" then
        ReturnMail(MAIL_INBOX.mailId)
        return true
    end
end

--[[ Suppress mail delete and/or return to sender dialog in gamepad mode, if configured ]]
function Postmaster.Prehook_Dialogs_ShowGamepadDialog(name, data, textParams)
    local self = Postmaster
    if self.settings.deleteDialogSuppress and name == "DELETE_MAIL" then 
        MAIL_MANAGER_GAMEPAD.inbox:Delete()
        return true
    elseif Postmaster.settings.returnDialogSuppress and name == "MAIL_RETURN_ATTACHMENTS" then
        MAIL_MANAGER_GAMEPAD.inbox:ReturnToSender()
        return true
    end
end

--[[ Keybind callback and visible functions do not always reliably pass on data
     about their related descriptor.  Wire up callback and visible events on
     the button to save the current button instance to Postmaster.keybindButtonForCallback
     and Postmaster.keybindButtonForVisible, respectively.  They can then be used for
     the "Other" keybind callbacks and visible methods that don't know which 
     button they were called from. ]]
function Postmaster.Prehook_KeybindStrip_ButtonSetup(keybindStrip, button)
    if not MAIL_INBOX_SCENE:IsShowing() then return end
    local buttonDescriptor = button.keybindButtonDescriptor
    if not buttonDescriptor or not buttonDescriptor.callback or type(buttonDescriptor.callback) ~= "function" then return end
    local callback = buttonDescriptor.callback
    buttonDescriptor.callback = function(...)
        Postmaster.keybindButtonForCallback = button
        callback(...)
    end
    if not buttonDescriptor.visible or type(buttonDescriptor.visible) ~= "function" then return end
    local visible = buttonDescriptor.visible
    buttonDescriptor.visible = function(...)
        Postmaster.keybindButtonForVisible = button
        return visible(...)
    end
end

--[[ Runs before a mail's attachments are taken, recording attachment information
     and initializing controller state variables for the take operation. ]]
function Postmaster.Prehook_MailInboxShared_TakeAll(mailId)
    local self = Postmaster
    if not self.taking then
        return
    end
    local numAttachments, attachedMoney, codAmount = GetMailAttachmentInfo(mailId)
    if codAmount > 0 then
        if self.takingAll then
            if not self.settings.takeAllCodTake then return end
        elseif not MAIL_INBOX.pendingAcceptCOD then return end
    end 
    self.Debug("ZO_MailInboxShared_TakeAll("..tostring(mailId)..")")
    self.awaitingAttachments[self.GetMailIdString(mailId)] = {}
    local attachmentData = { items = {}, money = attachedMoney, cod = codAmount }
    local uniqueAttachmentConflictCount = 0
    for attachIndex=1,numAttachments do
        local _, stack = GetAttachedItemInfo(mailId, attachIndex)
        local attachmentItem = { link = GetAttachedItemLink(mailId, attachIndex), count = stack or 1 }
        if self:IsItemUniqueInBackpack(attachmentItem.link) then
            uniqueAttachmentConflictCount = uniqueAttachmentConflictCount + 1
        else
            table.insert(attachmentData.items, attachmentItem)
        end
    end
    local mailIdString = self.GetMailIdString(mailId)
    
    if numAttachments > 0 then
    
        -- If all attachments were unique and already in the backpack
        if uniqueAttachmentConflictCount == numAttachments then
            self.Debug("Not taking attachments for "..mailIdString
                       .." because it contains only unique items that are already in the backpack")
            self.mailIdsFailedDeletion[mailIdString] = true
            self.Event_MailRemoved(nil, mailId)
            return true
        end
        if attachedMoney > 0 or codAmount > 0 then
            table.insert(self.awaitingAttachments[self.GetMailIdString(mailId)], true)
            -- Wire up timeout callback
            TakeTimeout(mailId)
        end
    end
    self.attachmentData[mailIdString] = attachmentData
    if codAmount > 0 then
        self.codMails[mailIdString] = { mailId = mailId, amount = codAmount, complete = false }
    end
end

--[[ Listen for mail read requests when the inbox is closed and deny them.
     The server won't raise the EVENT_MAIL_READABLE event anyways, and it
     will filter out any subsequent requests for the same mail id until after
     a different mailId is requested.  Record the mail id as self.mailIdLastOpened
     so that we can request the mail again immediately when the inbox is opened. ]]
function Postmaster.Prehook_RequestReadMail(mailId)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    self.Debug("RequestReadMail("..tostring(mailId)..")")
    self.mailIdLastOpened = mailId
    local inboxState = MAIL_INBOX_SCENE.state
    -- Avoid a double read request on inbox open
    local deny = inboxState == SCENE_HIDDEN or inboxState == SCENE_HIDING
    if deny then
        self.Debug("Inbox isn't open. Request denied.")
    end
    return deny
end

--[[ Runs before any scroll list selects an item by its data. We listen for inbox
     items that are selected when the inbox is closed, and then remember them 
     in MAIL_INBOX.requestMailId so that the items can be selected as soon as 
     the inbox opens again. ]]
function Postmaster.Prehook_ScrollList_SelectData(list, data, control, reselectingDuringRebuild)
    if IsInGamepadPreferredMode() then return end
    if list ~= ZO_MailInboxList then return end
    local self = Postmaster
    self.Debug("ZO_ScrollList_SelectData("..tostring(list)
        ..", "..tostring(data)..", "..tostring(control)..", "
        ..tostring(reselectingDuringRebuild)..")")
    local inboxState = MAIL_INBOX_SCENE.state
    if inboxState == SCENE_HIDDEN or inboxState == SCENE_HIDING then
        self.Debug("Clearing inbox mail id")
        -- clear mail id to avoid exceptions during inbox open
        -- it will be reselected by the EVENT_MAIL_READABLE event
        MAIL_INBOX.mailId = nil 
        -- remember the mail id so that it can be requested on mailbox open
        if data and type(data.mailId) == "number" then 
            self.Debug("Setting inbox requested mail id to "..tostring(data.mailId))
            MAIL_INBOX.requestMailId = data.mailId 
        end
    end
end



--[[ 
    ===================================
                 POSTHOOKS
    ===================================
  ]]

--[[ Wire up all posthook handlers ]]
function Postmaster:PosthookSetup()
    self.PostHook(MAIL_MANAGER_GAMEPAD.inbox, "RefreshMailList", self.Posthook_InboxScrollList_RefreshData)
    self.PostHook(ZO_MailInboxList, "RefreshData", self.Posthook_InboxScrollList_RefreshData)
end

--[[ Runs after the inbox scroll list's data refreshes, for both gamepad and 
     keyboard mail fragments. Used to trigger automatic mail return. ]]
function Postmaster.Posthook_InboxScrollList_RefreshData(scrollList)
    Postmaster:TryAutoReturnMail()
end