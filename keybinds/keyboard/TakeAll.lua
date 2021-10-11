--[[   
 
    Take All
    
  ]]

local addon = Postmaster
local debug = false
local take = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_PRIMARY")
local filter

local TakeAll = addon.classes.Keybind:Subclass()

function TakeAll:New(...)
    return addon.classes.Keybind.New(self, ...)
end

function TakeAll:Initialize()
    self.name = addon.name .. "KeybindTakeAll"
    self.keybind = "UI_SHORTCUT_SECONDARY"
    self.iterationFilter = function(...)
        return self:CanTake(...)
    end
    addon.classes.Keybind.Initialize(self)
end

function TakeAll:Callback()
    if addon:IsBusy() then return end
    if self:CanTakeSelectedMail() then
        addon.Utility.Debug("Selected mail can be taken by Take All. Taking.", debug)
        addon.taking    = true
        addon.takingAll = true
        MAIL_INBOX.selectMailIdOnRefresh = nil
        self:TakeOrDeleteSelected()
    elseif self:SelectNext() then
        addon.Utility.Debug("Getting next mail with attachments", debug)
        addon.taking    = true
        addon.takingAll = true
        MAIL_INBOX.selectMailIdOnRefresh = nil
        -- will call the take or delete callback when the message is read
    else
        addon.Utility.Debug("Selected mail cannot be taken, nor can any others.", debug)
    end
end

function TakeAll:CanDelete(mailData, attachmentData)
    
    if not mailData or not mailData.mailId or type(mailData.mailId) ~= "number" then 
        addon.Utility.Debug("mailData parameter not working right", debug)
        return false 
    end
    
    local mailIdString = addon.Utility.GetMailIdString(mailData.mailId)
    if addon.mailIdsFailedDeletion[mailIdString] == true then 
        addon.Utility.Debug("Cannot delete because this mail already failed deletion", debug)
        return false
    end
  
    -- Quaternary custom take all filter
    if addon.settings.keybinds.quaternary and addon.settings.keybinds.quaternary ~= "" and addon.filterFieldValue then
        local mailDataFieldValue = addon.keybinds.keyboard.Quaternary:GetFilterFieldValue(mailData)
        return mailDataFieldValue and mailDataFieldValue == addon.filterFieldValue
    end
    
    
    local deleteSettings = {
        cod              = addon.settings.takeAllCodDelete,
        playerEmpty      = addon.settings.takeAllPlayerDeleteEmpty,
        playerAttached   = addon.settings.takeAllPlayerAttachedDelete,
        playerReturned   = addon.settings.takeAllPlayerReturnedDelete,
        systemEmpty      = addon.settings.takeAllSystemDeleteEmpty,
        systemAttached   = addon.settings.takeAllSystemAttachedDelete,
        systemGuildStoreSales = addon.settings.takeAllSystemGuildStoreSalesDelete,
        systemGuildStoreItems = addon.settings.takeAllSystemGuildStoreItemsDelete,
        systemHireling   = addon.settings.takeAllSystemHirelingDelete,
        systemOther      = addon.settings.takeAllSystemOtherDelete,
        systemPvp        = addon.settings.takeAllSystemPvpDelete,
        systemUndaunted  = addon.settings.takeAllSystemUndauntedDelete,
    }
    
    -- Handle C.O.D. mail
    if attachmentData and attachmentData.cod > 0 then
        if not deleteSettings.cod then
            addon.Utility.Debug("Cannot delete COD mail", debug)
        end
        return deleteSettings.cod
    end
    
    local fromSystem = (mailData.fromCS or mailData.fromSystem)
    local hasAttachments = attachmentData and (attachmentData.money > 0 or #attachmentData.items > 0)
    if hasAttachments then
        
        -- Special handling for hireling mail, since we know even without opening it that
        -- all the attachments can potentially go straight to the craft bag
        local subjectField = "subject"
        local isHirelingMail = fromSystem and addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["craft"])
        
        if fromSystem then 
            if deleteSettings.systemAttached then
                
                if isHirelingMail then
                    if not deleteSettings.systemHireling then
                        addon.Utility.Debug("Cannot delete hireling mail", debug)
                    end
                    return deleteSettings.systemHireling
                
                elseif addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["guildStoreSales"]) then
                    if not deleteSettings.systemGuildStoreSales then
                        addon.Utility.Debug("Cannot delete guild store sales mail", debug)
                    end
                    return deleteSettings.systemGuildStoreSales
                
                elseif addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["guildStoreItems"]) then
                    if not deleteSettings.systemGuildStoreItems then
                        addon.Utility.Debug("Cannot delete guild store items mail", debug)
                    end
                    return deleteSettings.systemGuildStoreItems
                    
                elseif addon.Utility.MailFieldMatch(mailData, subjectField, addon.systemEmailSubjects["pvp"]) 
                       or addon.Utility.MailFieldMatch(mailData, "senderDisplayName", addon.systemEmailSenders["pvp"])
                then
                    if not deleteSettings.systemPvp then
                        addon.Utility.Debug("Cannot delete PvP rewards mail", debug)
                    end
                    return deleteSettings.systemPvp
                
                elseif addon.Utility.MailFieldMatch(mailData, "senderDisplayName", addon.systemEmailSenders["undaunted"]) then
                    if not deleteSettings.systemUndaunted then
                        addon.Utility.Debug("Cannot delete Undaunted rewards mail", debug)
                    end
                    return deleteSettings.systemUndaunted
                    
                else 
                    if not deleteSettings.systemOther then
                        addon.Utility.Debug("Cannot delete uncategorized system mail", debug)
                    end
                    return deleteSettings.systemOther
                end
                    
            else
                if not deleteSettings.systemAttached then
                    addon.Utility.Debug("Cannot delete system mail", debug)
                end
                return false
            end
        elseif mailData.returned then
                if not deleteSettings.playerReturned then
                    addon.Utility.Debug("Cannot delete returned mail", debug)
                end
            return deleteSettings.playerReturned 
        else
            if not deleteSettings.playerAttached then
                addon.Utility.Debug("Cannot delete player mail with attachments", debug)
            end
            return deleteSettings.playerAttached 
        end
    else
        if fromSystem then
            if not deleteSettings.systemEmpty then
                addon.Utility.Debug("Cannot delete empty system mail", debug)
            end
            return deleteSettings.systemEmpty
        else 
            if not deleteSettings.playerEmpty then
                addon.Utility.Debug("Cannot delete empty player mail", debug)
            end
            return deleteSettings.playerEmpty 
        end
    end
    
end

--[[ True if the given mail can be taken by Take All operations according
     to current options panel criteria. ]]
function TakeAll:CanTake(mailData)
  
    -- Quaternary custom take all filter
    if addon.settings.keybinds.quaternary and addon.settings.keybinds.quaternary ~= "" and addon.filterFieldValue then
        local mailDataFieldValue = addon.keybinds.keyboard.Quaternary:GetFilterFieldValue(mailData)
        return mailDataFieldValue and mailDataFieldValue == addon.filterFieldValue
    end
  
    -- Filter based on normal primary Take All keybind settings
    local canTake = addon.Utility.CanTake(mailData, {
        ["codTake"]           = addon.settings.takeAllCodTake,
        ["codGoldLimit"]      = addon.settings.takeAllCodGoldLimit,
        ["reservedSlots"]     = addon.settings.reservedSlots,
        ["systemAttached"]    = addon.settings.takeAllSystemAttached,
        ["systemHireling"]    = addon.settings.takeAllSystemHireling,
        ["systemGuildStoreSales"]  = addon.settings.takeAllSystemGuildStoreSales,
        ["systemGuildStoreItems"]  = addon.settings.takeAllSystemGuildStoreItems,
        ["systemPvp"]         = addon.settings.takeAllSystemPvp,
        ["systemUndaunted"]   = addon.settings.takeAllSystemUndaunted,
        ["systemOther"]       = addon.settings.takeAllSystemOther,
        ["playerReturned"]    = addon.settings.takeAllPlayerReturned,
        ["playerAttached"]    = addon.settings.takeAllPlayerAttached,
        ["systemDeleteEmpty"] = addon.settings.takeAllSystemDeleteEmpty,
        ["playerDeleteEmpty"] = addon.settings.takeAllPlayerDeleteEmpty,
    })
    addon.Utility.Debug("TakeAll:CanTake() mail id " .. tostring(mailData and mailData.mailId) .. "? " .. tostring(canTake), debug)
    return canTake
end

--[[ True if the currently-selected mail can be taken by Take All operations 
     according to current options panel criteria. ]]
function TakeAll:CanTakeSelectedMail()
    local selectedMailData = addon.Utility.KeyboardGetSelectedMailData()
    if selectedMailData
       and self:CanTake(selectedMailData) 
    then 
        return true 
    end
end

function TakeAll:GetName()
    return GetString(SI_LOOT_TAKE_ALL)
end

--[[ Gets the next highest-priority mail data instance that Take All can take ]]
function TakeAll:GetNext()
    local iterator = addon.classes.InboxTreeIterator:New(self.iterationFilter)
    local nextMailData = iterator.next(MAIL_INBOX.navigationTree:GetSelectedNode())
    if nextMailData then
        addon.Utility.Debug("TakeAll:KeyboardGetNext() returning mail id " .. tostring(nextMailData.mailId), debug)
        return nextMailData
    end
    addon.Utility.Debug("TakeAll:KeyboardGetNext() returning nil", debug)
end

function TakeAll:KeyboardGetMailReadCallback(retries)
    return function()
        addon.Events:UnregisterForUpdate(EVENT_MAIL_READABLE)
        retries = retries - 1
        if retries < 0 then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_READ_FAILED)
            addon:Reset()
        else
            self:KeyboardMailRead(retries)
        end
    end
end

function TakeAll:KeyboardMailRead(retries)
    
    if not retries then
        retries = PM_MAIL_READ_MAX_RETRIES
    end
    
    -- If there exists another message in the inbox that has attachments, select it. otherwise, clear the selection.
    local nextMailData = self:GetNext()
    if nextMailData then
        addon.Events:RegisterForUpdate(EVENT_MAIL_READABLE, PM_MAIL_READ_TIMEOUT_MS, self:KeyboardGetMailReadCallback(retries) )
        MAIL_INBOX.navigationTree:Commit(nextMailData and nextMailData.node, false)
    end
    return nextMailData
end

--[[ Selects the next highest-priority mail data instance that Take All can take ]]
function TakeAll:SelectNext()
    -- Don't need to get anything. The current selection already has attachments.
    if self:CanTakeSelectedMail() then return true end
    
    local nextMailData = self:KeyboardMailRead()
    if nextMailData then
        return true
    end
end

--[[ Takes attachments from the selected (readable) mail if they exist, or 
     deletes the mail if it has no attachments. ]]
function TakeAll:TakeOrDeleteSelected()
    if self:TryCodMail() then return end
    local mailData = addon.Utility.KeyboardGetSelectedMailData()
    local hasAttachments = (mailData.attachedMoney and mailData.attachedMoney > 0)
      or (mailData.numAttachments and mailData.numAttachments > 0)
    if hasAttachments then
        addon.taking = true
        take.callback()
    else
        -- If all attachments are gone, remove the message
        addon.Utility.Debug("Deleting "..tostring(mailData.mailId), debug)
        
        -- Delete the mail
        addon.Delete:ByMailId(mailData.mailId)
    end
end

--[[ Bypasses the original "Take attachments" logic for C.O.D. mail during a
     Take All operation. ]]
function TakeAll:TryCodMail()
    if not addon.settings.takeAllCodTake then return end
    local mailData = addon.Utility.KeyboardGetSelectedMailData()
    if mailData.codAmount and mailData.codAmount > 0 then
        addon.taking = true
        addon.pendingAcceptCOD = true
        ZO_MailInboxShared_TakeAll(mailData.mailId)
        addon.pendingAcceptCOD = false
        return true
    end
end

function TakeAll:Visible()
    if addon:IsBusy() or not self:GetNext() then
        return false
    end
    return true
end

addon.keybinds.keyboard.TakeAll = TakeAll:New()