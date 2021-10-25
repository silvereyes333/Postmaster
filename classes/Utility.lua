--[[ 
    ===================================
            UTILITY FUNCTIONS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false
local PM_DIALOG = "Postmaster.Dialog"

-- STATIC CLASS
addon.Utility = ZO_Object:Subclass()


--[[ True if the given mail can be taken according to the given settings ]]
function addon.Utility.CanTake(mailData, settings)
    
    if not mailData or not mailData.mailId or type(mailData.mailId) ~= "number" then
        addon.Utility.Debug("Utility.CanTake(" .. tostring(mailData and mailData.mailId) 
            .. ") returning false due to a bad mailId", debug)
        return false 
    end
    
    local mailIdString = addon.Utility.GetMailIdString(mailData.mailId)
    if addon.mailIdsFailedDeletion[mailIdString] == true then
        addon.Utility.Debug("Utility.CanTake(" .. tostring(mailData and mailData.mailId) 
            .. ") returning false because it previously failed deletion.", debug)
        return false
    end
    
    local hasAttachments = addon.Utility.HasAttachments(mailData)
    
    -- Handle C.O.D. mail
    if mailData.codAmount and mailData.codAmount > 0 then
    
        -- Skip C.O.D. mails, if so configured
        if not settings.codTake then return false
        
        -- Enforce C.O.D. absolute gold limit
        elseif settings.codGoldLimit > 0 and mailData.codAmount > settings.codGoldLimit then return false
        
        -- Skip C.O.D. mails that we don't have enough money to pay for
        elseif mailData.codAmount > GetCurrentMoney() then return false 
        
        else return true end
    end
    
    local fromSystem = (mailData.fromCS or mailData.fromSystem)
    if hasAttachments then
        
        -- Special handling for hireling mail, since we know even without opening it that
        -- all the attachments can potentially go straight to the craft bag
        local subjectField = "subject"
        local isHirelingMail = fromSystem and addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["craft"])
        local freeSlots = GetNumBagFreeSlots(BAG_BACKPACK)
        local attachmentsToCraftBag = isHirelingMail and HasCraftBagAccess() and GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG) == "1" and freeSlots > 0
        
        -- Check to make sure there are enough slots available in the backpack
        -- to contain all attachments.  This logic is overly simplistic, since 
        -- theoretically, stacking and craft bags could free up slots. But 
        -- reproducing that business logic here sounds hard, so I gave up.
        if mailData.numAttachments and mailData.numAttachments > 0 
           and (freeSlots - mailData.numAttachments) < (settings.reservedSlots or 0)
           and not attachmentsToCraftBag
        then 
            addon.Utility.Debug("Utility.CanTake(" .. tostring(mailData and mailData.mailId) 
                .. ") returning false there are not enough slots in the backpack.", debug)
            return false 
        end
        
        if fromSystem then 
            if settings.systemAttached then
                
                if isHirelingMail then
                    return settings.systemHireling
                
                elseif addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["guildStoreSales"]) then
                    return settings.systemGuildStoreSales
                
                elseif addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["guildStoreItems"]) then
                    return settings.systemGuildStoreItems
                    
                elseif addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["pvp"])
                       or addon.Utility.MailFieldMatch(mailData, "senderDisplayName", addon.systemEmailSenders["pvp"])
                then
                    return settings.systemPvp
                
                elseif addon.Utility.MailFieldMatch(mailData, "senderDisplayName", addon.systemEmailSenders["undaunted"]) then
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

--[[ Collects a summary of attachment data ]]
function addon.Utility.CollectAttachments(sender, attachmentData)
    local self = Postmaster
    if not addon.settings.chatContentsSummary.enabled or not attachmentData then return end
    
    -- Add items summary
    for attachIndex=1,#attachmentData.items do
        local attachmentItem = attachmentData.items[attachIndex]
        addon.summary:AddItemLink(sender, attachmentItem.link, attachmentItem.count)
    end
    
    -- Add money summary
    local money
    if attachmentData.money > 0 then 
        money = attachmentData.money
    elseif attachmentData.cod > 0 then 
        money = -attachmentData.cod 
    end
    if money then
        addon.summary:AddCurrency(sender, CURT_MONEY, money)
    end
    
    addon.summary:IncrementMailCount(sender)
end

--[[ Outputs formatted message to chat window if debugging is turned on ]]
function addon.Utility.Debug(input, force)
    if not force and not addon.debugMode then
        return
    end
    d("[PM-DEBUG] " .. input)
end

function addon.Utility.GamepadGetSelectedMailData()
    return MAIL_MANAGER_GAMEPAD.inbox:GetActiveMailData()
end

function addon.Utility.GamepadIsInboxShown()
    return SCENE_MANAGER:IsShowing("mailManagerGamepad") and MAIL_MANAGER_GAMEPAD.activeFragment == GAMEPAD_MAIL_INBOX_FRAGMENT
end

function addon.Utility.GetActiveKeybinds()
    local keybindScope = IsInGamepadPreferredMode() and "gamepad" or "keyboard"
    return addon.keybinds[keybindScope]
end

function addon.Utility.GetAttachmentData(mailId)
  
    if not IsReadMailInfoReady(mailId) then
        return
    end
  
    local numAttachments, attachedMoney, codAmount = GetMailAttachmentInfo(mailId)
    local attachmentData = { items = {}, money = attachedMoney, cod = codAmount, numAttachments = numAttachments, uniqueItemConflictCount = 0 }
    for attachIndex = 1, numAttachments do
        local itemLink = GetAttachedItemLink(mailId, attachIndex)
        if addon.UniqueBackpackItemsList:ContainsItemLink(itemLink) then
            attachmentData.uniqueItemConflictCount = attachmentData.uniqueItemConflictCount + 1
        else
            local _, stack = GetAttachedItemInfo(mailId, attachIndex)
            local attachmentItem = { link = itemLink, count = stack or 1 }
            table.insert(attachmentData.items, attachmentItem)
        end
    end
    
    return attachmentData
end

--[[ Searches addon.codMails for the first mail id and C.O.D. mail data taht
     match the given expected amount. ]]
function addon.Utility.GetCodMailByGoldChangeAmount(goldChanged)
    for mailIdString,codMail in pairs(addon.codMails) do
        if codMail.amount == goldChanged then
            return mailIdString, codMail
        end
    end
end

--[[ Searches addon.codMails for the first mail id and C.O.D. mail data that 
     is marked as "complete". ]]
function addon.Utility.GetFirstCompleteCodMail()
    for mailIdString,codMail in pairs(addon.codMails) do
        if codMail.complete then
            return mailIdString, codMail
        end
    end
end

--[[ Returns a sorted list of mail data for the current inbox, whether keyboard 
     or gamepad. The second output parameter is the name of the mailData field 
     for items in the returned list. ]]
function addon.Utility.GetMailData()
    local data, index
    if IsInGamepadPreferredMode() then
        if not MAIL_MANAGER_GAMEPAD.inbox.mailList then
            return {}
        end
        data = MAIL_MANAGER_GAMEPAD.inbox.mailList.dataList
        index = "dataSource"
    else
        data = MAIL_INBOX.masterList
    end
    if data == nil then
        return {}
    end
    return data, index
end

function addon.Utility.GetMailDataById(mailId)
    if IsInGamepadPreferredMode() then
        return MAIL_MANAGER_GAMEPAD.inbox.mailDataById[zo_getSafeId64Key(mailId)]
    else
        return MAIL_INBOX:GetMailData(mailId)
    end
end

--[[ Returns a safe string representation of the given mail ID. Useful as an 
     associative array key for lookups. ]]
function addon.Utility.GetMailIdString(mailId)
    local mailIdType = type(mailId)
    if mailIdType == "string" then 
        return mailId 
    elseif mailIdType == "number" then 
        return zo_getSafeId64Key(mailId) 
    else return 
        tostring(mailId) 
    end
end


function addon.Utility.GetMessageDialog()
    if(not ESO_Dialogs[PM_DIALOG]) then
        ESO_Dialogs[PM_DIALOG] = {
            canQueue = true,
            title = { text = "" },
            mainText = { text = "" },
            buttons = {{ text = SI_OK }}
        }
    end
    return ESO_Dialogs[PM_DIALOG]
end

function addon.Utility.HasAttachments(mailData)
    if not mailData then
        return false
    end
    return (mailData.attachedMoney and mailData.attachedMoney > 0) or (mailData.numAttachments and mailData.numAttachments > 0)
end

function addon.Utility.IsInboxShown()
    if IsInGamepadPreferredMode() then
        return addon.Utility.GamepadIsInboxShown()
    else
        return addon.Utility.KeyboardIsInboxShown()
    end
end

--[[ Given a keybind group descriptor and a keybind name, returns the button
     descriptor assigned to that keybind. ]]
function addon.Utility.KeybindGetDescriptor(keybindGroup, keybind)
    for i,descriptor in ipairs(keybindGroup) do
        if descriptor.keybind == keybind then
            return descriptor
        end
    end
end

--[[ Returns the current mail messages data array, if one is selected ]]
function addon.Utility.KeyboardGetOpenData()
    local mailId = MAIL_INBOX:GetOpenMailId()
    if type(mailId) ~= "number" then 
        addon.Utility.Debug("There is no open mail id "..tostring(mailId), debug)
        return 
    end
    local mailData, index = MAIL_INBOX:GetMailData(mailId)
    return index and mailData[index] or mailData
end

function addon.Utility.KeyboardGetSelectedMailData()
    local selectedNode = MAIL_INBOX.navigationTree:GetSelectedNode()
    local selectedMailData = selectedNode and selectedNode.data
    return selectedMailData
end

function addon.Utility.KeyboardInboxTreeEvalAllNodes(eval, node)
  
    if not node then
        node = MAIL_INBOX.navigationTree.rootNode
    end
    
    if node.children then
        for _, child in ipairs(node.children) do
            addon.Utility.KeyboardInboxTreeEvalAllNodes(eval, child)
        end
    elseif node.templateInfo.template == "ZO_MailInboxRow" then
        eval(node)
    end
end

function addon.Utility.KeyboardIsInboxShown()
    return SCENE_MANAGER:IsShowing("mailInbox")
end

--[[ Returns true if the given mail id has been opened and we know it 
     contains attachments, no money, and all attachments conflict with 
     unique items in the backpack ]]--
function addon.Utility.MailContainsOnlyUniqueConflictAttachments(mailId)
    local attachmentData = addon.Utility.GetAttachmentData(mailId)
    if attachmentData
       and (not attachmentData.money or attachmentData.money == 0)
       and attachmentData.numAttachments > 0
       and attachmentData.uniqueItemConflictCount == attachmentData.numAttachments
    then
        return true
    end
end

--[[ Checks the given field of a mail message for a given list of
     substrings and returns true if a match is found.
     Note, returns true for "body" requests when the read info isn't yet ready. ]]
function addon.Utility.MailFieldMatch(mailData, field, substrings)
    
    -- We need to read mail contents
    if field == "body" then
    
        -- the mail isn't ready. Return true for now to trigger the read request,
        -- and we'll have to match again after it's ready.
        if not mailData.isReadInfoReady then
            return true
        end
        
        -- Match on body text
        local body = zo_strlower(ReadMail(mailData.mailId))
        if addon.Utility.StringMatchFirst(body, substrings) then
            return true
        end
    
    -- All other fields are available without a read request first
    else
        local value = zo_strlower(mailData[field])
        if addon.Utility.StringMatchFirst(value, substrings) then
            return true
        end
    end
end

function addon.Utility.MatchMailIdClosure(mailId)
    return function(mailData)
        return mailData and mailData.mailId and AreId64sEqual(mailData.mailId, mailId)
    end
end

--[[ Opens the addon settings panel ]]
function addon.Utility.OpenSettingsPanel()
    LibAddonMenu2:OpenToPanel(addon.settingsPanel)
end

--[[ Outputs formatted message to chat window ]]
function addon.Utility.Print(input)
    local self = Postmaster
    local output = addon.prefix .. input .. addon.suffix
    addon.chat:Print(output)
end

function addon.Utility.RefreshMailList()
    if IsInGamepadPreferredMode() then
        MAIL_MANAGER_GAMEPAD.inbox:RefreshMailList()
    else
        MAIL_INBOX:RefreshData()
    end
end

function addon.Utility.ShowMessageDialog(title, message)
    local dialog = addon.Utility.GetMessageDialog()
    dialog.title.text = title
    dialog.mainText.text = message
    ZO_Dialogs_ShowDialog(PM_DIALOG)
end

--[[ Checks the given string for a given list of
     substrings and returns the start and end indexes if a match is found. ]]
function addon.Utility.StringMatchFirst(s, substrings)
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
function addon.Utility.StringMatchFirstPrefix(s, prefixes)
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

function addon.Utility.StringRemovePrefixes(s, prefixes)
    for i=1, #prefixes do
        local prefix = zo_strlower(prefixes[i])
        if s == prefix then
            return ""
        else
            s = string.gsub(s, "^" .. zo_strlower(prefix) .. " ", "")
        end
    end
    return s
end

function addon.Utility.UpdateKeybindButtonGroup()
    if IsInGamepadPreferredMode() then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor)
    else
        KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
    end
end