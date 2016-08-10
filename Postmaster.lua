-- Postmaster Addon for Elder Scrolls Online
-- Original Authors: Anthony Korchak aka Zierk + Garkin
-- Completely rewritten by silvereyes

Postmaster = {
    name = "Postmaster",
    title = GetString(SI_PM_NAME),
    version = "3.4.0",
    author = "|c99CCEFsilvereyes|r, |cEFEBBEGarkin|r & Zierk",
    
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
    
    -- Remembers mail removal requests that come in while the inbox is closed,
    -- so that the removals can be processed once the inbox opens again.
    mailIdsMarkedForDeletion = {},
    
    -- Contains details about C.O.D. mail being taken, since events related to
    -- taking C.O.D.s do not contain mail ids as parameters.
    codMails = {}
}

-- Format for chat print and debug messages, with addon title prefix
PM_CHAT_FORMAT = zo_strformat("<<1>>", Postmaster.title) .. "|cFFFFFF: <<1>>|r"

-- Max length of a line in chat, after the prefix.
PM_MAX_CHAT_LENGTH = 355 - string.len(PM_CHAT_FORMAT)

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

-- Register events
EVENT_MANAGER:RegisterForEvent(Postmaster.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)


--[[ Outputs formatted message to chat window if debugging is turned on ]]
function Postmaster.Debug(input, scopeDebug)
    if not Postmaster.debugMode and not scopeDebug then return end
    Postmaster.Print(input)
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

--[[ True if Postmaster is doing any operations on the inbox. ]]
function Postmaster:IsBusy()
    return self.taking or self.takingAll or self.deleting or self.returning
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
    local LAM2 = LibStub("LibAddonMenu-2.0")
    if not LAM2 then return end
    LAM2:OpenToPanel(Postmaster.settingsPanel)
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
    local lines = Postmaster.SplitLines(input, PM_MAX_CHAT_LENGTH, {"%s","\n","|h|h"})
    for i=1,#lines do
        local output = zo_strformat(PM_CHAT_FORMAT, lines[i])
        d(output)
    end
end

--[[ Outputs a verbose summary of all attachments and gold transferred by the 
     current Take or Take All command. ]]
function Postmaster.PrintAttachmentSummary(attachmentData)
    if not Postmaster.settings.verbose then return end
    
    local summary = ""
    
    -- Add items summary
    for attachIndex=1,#attachmentData.items do
        local attachmentItem = attachmentData.items[attachIndex]
        if attachIndex > 1 then
            summary = summary .. " "
        end
        local countString = zo_strformat(GetString(SI_HOOK_POINT_STORE_REPAIR_KIT_COUNT), attachmentItem.count)
        local itemString = zo_strformat("<<1>> <<2>>", attachmentItem.link, countString)
        
        -- Make sure that item link x quantity remains indivisible in summary so that we don't end up with 
        -- counts on a separate line.
        if string.len(summary) + string.len(itemString) > PM_MAX_CHAT_LENGTH then
            Postmaster.Print(summary)
            summary = ""
        end
        summary = summary .. itemString
    end
    
    -- Add money summary
    local money
    if attachmentData.money > 0 then 
        money = attachmentData.money
    elseif attachmentData.cod > 0 then 
        money = -attachmentData.cod 
    end
    if money then
        if #attachmentData.items > 0 then
            summary = summary .. GetString(SI_PM_AND)
        end
        local moneyString = ZO_CurrencyControl_FormatCurrencyAndAppendIcon(money, true, CURT_MONEY, IsInGamepadPreferredMode())
        summary = zo_strformat("<<1>><<2>>", summary, moneyString)
    end
    
    Postmaster.Print(summary)
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
    
    -- Print summary if verbose setting is on. 
    -- Do this here, immediately after all attachments are collected and C.O.D. are paid, 
    -- Don't wait until the mail removed event, because it may or may not go 
    -- through if the user closes the inbox.
    Postmaster.PrintAttachmentSummary(self.attachmentData[mailIdString])
    
    -- Clean up tracking arrays
    self.awaitingAttachments[mailIdString] = nil
    self.attachmentData[mailIdString] = nil
    
    -- If inbox is open...
    if(SCENE_MANAGER:IsShowing("mailInbox")) then
        -- If all attachments are gone, remove the message
        self.Debug("Deleting "..tostring(mailId))
        DeleteMail(mailId, true)
        PlaySound(SOUNDS.MAIL_ITEM_DELETED)
        
    -- Inbox is no longer open, so delete events won't be raised
    else
        -- Mark mail for deletion the next time the mailbox is opened
        self.Debug("Marking mail id "..tostring(mailId).." for deletion")
        table.insert(self.mailIdsMarkedForDeletion, mailId)
        
        if not AreId64sEqual(self.mailIdLastOpened,mailId) then
            
            self.Debug("Marking mail id "..tostring(mailId).." to be opened when inbox does")
            MAIL_INBOX.mailId = nil
            MAIL_INBOX.requestMailId = mailId
        end
    end
end

--[[ Sets state variables back to defaults and ensures a consistent inbox state ]]
function Postmaster:Reset()
    self.taking = false
    self.takingAll = false
    self.abortRequested = false
    ZO_MailInboxList.autoSelect = true  
    if MAIL_INBOX.mailId then
        local currentMailData = MAIL_INBOX:GetMailData(self.mailId)
        if not currentMailData then
            MAIL_INBOX.mailId = nil
            ZO_ScrollList_AutoSelectData(ZO_MailInboxList)
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
        zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_1)),
        zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_2)),
        zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_3)),
        zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_1)),
        zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_2)),
        zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_3)),
        zo_strlower(GetString(SI_PM_PVP_LOYALTY)),
    }
}

local undauntedEmailSenders = {
    zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_NORMAL)),
    zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_VET)),
    zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_1)),
    zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_2)),
    zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_3)),
}

--[[ True if the given mail can be taken by Take All operations according
     to current options panel criteria. ]]
function Postmaster:TakeAllCanTake(mailData)
    if not mailData or not mailData.mailId or type(mailData.mailId) ~= "number" then 
        return false 
    end
    
    -- Item was meant to be deleted, but the inbox closed, so include it in 
    -- the take all list
    if self:IsMailMarkedForDeletion(mailData.mailId) then
        return true
    
    -- Handle C.O.D. mail
    elseif mailData.codAmount > 0 then
    
        -- Skip C.O.D. mails, if so configured
        if not self.settings.codTake then return false
        
        -- Enforce C.O.D. absolute gold limit
        elseif self.settings.codGoldLimit > 0 and mailData.codAmount > self.settings.codGoldLimit then return false
        
        -- Skip C.O.D. mails that we don't have enough money to pay for
        elseif mailData.codAmount > GetCurrentMoney() then return false 
        
        else return true end
    end
    
    local fromSystem = (mailData.fromCS or mailData.fromSystem)
    local hasAttachments = mailData.attachedMoney > 0 or mailData.numAttachments > 0
    if hasAttachments then
    
        -- Check to make sure there are enough slots available in the backpack
        -- to contain all attachments.  This logic is overly simplistic, since 
        -- theoretically, stacking and craft bags could free up slots. But 
        -- reproducing that business logic here sounds hard, so I gave up.
        if mailData.numAttachments > 0 
           and (GetNumBagFreeSlots(BAG_BACKPACK) - mailData.numAttachments) < self.settings.reservedSlots 
        then 
            return false 
        end
        
        if fromSystem then 
            if self.settings.systemTakeAttached then
                
                local subjectField = "subject"
                
                if self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["craft"]) then
                    return self.settings.systemTakeHireling
                
                elseif self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["guildStore"]) then
                    return self.settings.systemTakeGuildStore
                    
                elseif self:MailFieldMatch(mailData, subjectField, systemEmailSubjects["pvp"]) then
                    return self.settings.systemTakePvp
                
                elseif self:MailFieldMatch(mailData, "senderDisplayName", undauntedEmailSenders) then
                    return self.settings.systemTakeUndaunted
                    
                else 
                    return self.settings.systemTakeOther
                end
                    
            else
                return false
            end
        elseif mailData.returned then
            return self.settings.playerTakeReturned 
        else
            return self.settings.playerTakeAttached 
        end
    else
        if fromSystem then 
            return self.settings.systemDeleteEmpty
        else 
            return self.settings.playerDeleteEmpty 
        end
    end
end

--[[ True if the currently-selected mail can be taken by Take All operations 
     according to current options panel criteria. ]]
function Postmaster:TakeAllCanTakeSelectedMail()
    if ZO_MailInboxList.selectedData 
       and self:TakeAllCanTake(ZO_MailInboxList.selectedData) 
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
    
    -- If there exists another message in the inbox that has attachments, select it.
    local nextMailData = self:TakeAllGetNext()
    if nextMailData then
        ZO_ScrollList_SelectData(ZO_MailInboxList, nextMailData)
        return true
    end
end

--[[ Takes attachments from the selected (readable) mail if they exist, or 
     deletes the mail if it has no attachments. ]]
function Postmaster:TakeOrDeleteSelected()
    if self:TryTakeAllCodMail() then return end
    local mailData = ZO_MailInboxList.selectedData
    local hasAttachments = mailData.attachedMoney > 0 or mailData.numAttachments > 0
    if hasAttachments then
        self.originalDescriptors.take.callback()
    else
        -- If all attachments are gone, remove the message
        self.Debug("Deleting "..tostring(mailId))
        DeleteMail(mailData.mailId, true)
        PlaySound(SOUNDS.MAIL_ITEM_DELETED)
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
            if self.settings.verbose then
                self.Print(zo_strformat(GetString(SI_PM_BOUNCE_MESSAGE), mailData.senderDisplayName))
            end
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
    table.remove(self.mailIdsMarkedForDeletion, deleteIndex)
    -- Resume the Take operation. will be cleared when the mail removed event handler fires.
    self.taking = true 
    self.Debug("deleting mail id "..tostring(mailId))
    DeleteMail(mailId, true)
    PlaySound(SOUNDS.MAIL_ITEM_DELETED)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
    return deleteIndex
end

--[[ Bypasses the original "Take attachments" logic for C.O.D. mail during a
     Take All operation. ]]
function Postmaster:TryTakeAllCodMail()
    if not self.settings.codTake then return end
    local mailData = ZO_MailInboxList.selectedData
    if mailData.codAmount > 0 then
        MAIL_INBOX.pendingAcceptCOD = true
        ZO_MailInboxShared_TakeAll(mailData.mailId)
        PlaySound(SOUNDS.MAIL_ACCEPT_COD)
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
            self.abortRequested = true          
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
    else
        self.originalDescriptors.take.callback()
    end
end
function Postmaster.Keybind_Primary_GetName()
    local self = Postmaster
    if self.originalDescriptors.delete.visible() or
       (MailR and MailR.IsMailIdSentMail(self.mailId))
    then
        return self.originalDescriptors.delete.name
    end
    return GetString(SI_LOOT_TAKE)
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
    local mailId = MAIL_INBOX:GetOpenMailId()
    if type(mailId) ~= "number" then 
        Postmaster.Debug("There is no open mail id "..tostring(mailId))
        return 
    end
    local mailData = MAIL_INBOX:GetMailData(mailId)
    
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
    self.abortRequested = false  
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
    MAIL_INBOX_SCENE:RegisterCallback("StateChange", self.Callback_MailInbox_StateChange)
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
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_IS_FULL,  self.Event_InventoryIsFull)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_INBOX_UPDATE,  self.Event_MailInboxUpdate)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_READABLE,      self.Event_MailReadable)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_REMOVED,       self.Event_MailRemoved)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_SEND_SUCCESS,  self.Event_MailSendSuccess)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, 
        self.Event_MailTakeAttachedItemSuccess)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS,  
        self.Event_MailTakeAttachedMoneySuccess)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MONEY_UPDATE,       self.Event_MoneyUpdate)
    
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
    -- An abort request came in while we were waiting for the 
    -- EVENT_MAIL_READABLE event. Go ahead and abort
    if self.abortRequested then
        self:Reset()
        KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
        
    -- If taking all, then go ahead and start the next Take loop, since the
    -- mail and attachments are readable now.
    elseif self.takingAll then 
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
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    
    self.Debug("deleted mail id "..tostring(mailId))
    
    -- In the middle of auto-return
    if self.returning then return end
    
    local isInboxOpen = SCENE_MANAGER:IsShowing("mailInbox")
    
    -- Clear out scroll list selection if autoselect is off
    if not ZO_MailInboxList.autoSelect then
        ZO_MailInboxList.selectedData = nil
        ZO_MailInboxList.selectedDataIndex = nil
        ZO_MailInboxList.lastSelectedDataIndex = nil
        if isInboxOpen then
            MAIL_INBOX:EndRead()
        end
    end
    
    -- For non-canceled take all requests, select the next mail for taking.
    -- It will be taken automatically by Event_MailReadable() once the 
    -- EVENT_MAIL_READABLE event comes back from the server.
    if isInboxOpen and self.takingAll and not self.abortRequested then
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
    self.Debug("attached items taken "..tostring(mailId))
    local waitingForMoney = table.remove(self.awaitingAttachments[self.GetMailIdString(mailId)])
    if waitingForMoney then 
        self.Debug("still waiting for money or COD. exiting.")
    else
        self:RequestMailDelete(mailId)
    end
end

--[[ Raised when attached gold is all received into inventory from a mail.
     Used to automatically trigger mail deletion. ]]
function Postmaster.Event_MailTakeAttachedMoneySuccess(eventCode, mailId)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
    self.Debug("attached money taken "..tostring(mailId))
    local waitingForItems = table.remove(self.awaitingAttachments[self.GetMailIdString(mailId)])
    if waitingForItems then 
        self.Debug("still waiting for items. exiting.")
    else
        self:RequestMailDelete(mailId)
    end
end

--[[ Raised whenever gold enters or leaves the player's inventory.  We only care
     about money leaving inventory due to a mail event, indicating a C.O.D. payment.
     Used to automatically trigger mail deletion. ]]
function Postmaster.Event_MoneyUpdate(eventCode, newMoney, oldMoney, reason)
    if IsInGamepadPreferredMode() then return end
    local self = Postmaster
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
    if Postmaster.settings.deleteDialogSuppress and name == "DELETE_MAIL" then 
        MAIL_INBOX:ConfirmDelete(MAIL_INBOX.mailId)
        return true
    elseif Postmaster.settings.returnDialogSuppress and name == "MAIL_RETURN_ATTACHMENTS" then
        ReturnMail(MAIL_INBOX.mailId)
        return true
    end
end

--[[ Suppress mail delete and/or return to sender dialog in gamepad mode, if configured ]]
function Postmaster.Prehook_Dialogs_ShowGamepadDialog(name, data, textParams)
    if Postmaster.settings.deleteDialogSuppress and name == "DELETE_MAIL" then 
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
    local numAttachments, attachedMoney, codAmount = GetMailAttachmentInfo(mailId)
    if codAmount > 0 then
        if self.takingAll then
            if not self.settings.codTake then return end
        elseif not MAIL_INBOX.pendingAcceptCOD then return end
    end
    self.taking = true
    self.abortRequested = false  
    self.Debug("ZO_MailInboxShared_TakeAll("..tostring(mailId)..")")
    self.awaitingAttachments[self.GetMailIdString(mailId)] = {}
    if numAttachments > 0 and (attachedMoney > 0 or codAmount > 0) then
        table.insert(self.awaitingAttachments[self.GetMailIdString(mailId)], true)
    end
    local attachmentData = { items = {}, money = attachedMoney, cod = codAmount }
    for attachIndex=1,numAttachments do
        local _, stack = GetAttachedItemInfo(mailId, attachIndex)
        local attachmentItem = { link = GetAttachedItemLink(mailId, attachIndex), count = stack or 1 }
        table.insert(attachmentData.items, attachmentItem)
    end
    local mailIdString = self.GetMailIdString(mailId)
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