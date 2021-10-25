--[[   
 
    Take All
    
  ]]

local addon = Postmaster
local debug = false
local SKIP_SELECTED = true
local take = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_PRIMARY")

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
    self.readQueue = {}
    addon.classes.Keybind.Initialize(self)
end

function TakeAll:Callback()
    if addon:IsBusy() then return end
    
    ZO_ClearTable(self.readQueue)
    
    local canTake, mailData = self:CanTakeSelectedMail()
    if canTake then
        addon.Utility.Debug("Selected mail id " .. tostring(mailData.mailId) .. " can be taken by Take All. Taking.", debug)
        addon.taking    = true
        addon.takingAll = true
        MAIL_INBOX.selectMailIdOnRefresh = nil
        self:DequeueReadRequest(mailData.mailId, true)
        
    elseif self:SelectNext(mailData and mailData.mailId, SKIP_SELECTED) then
        addon.Utility.Debug("Getting next mail with attachments", debug)
        addon.taking    = true
        addon.takingAll = true
        MAIL_INBOX.selectMailIdOnRefresh = nil
        -- will call the take or delete callback when the message is read
        
    else
        addon.Utility.Debug("Selected mail id " .. tostring(mailData and mailData.mailId) .. " cannot be taken, nor can any others.", debug)
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
  
    -- Take by Subject / Sender
    if addon.filterFieldValue and addon.filterFieldKeybind then
        if not addon.filterFieldKeybind:IsDeleteEnabled() then
            addon.Utility.Debug("Delete is not enabled for " .. addon.filterFieldKeybind.name .. ". TakeAll:CanDelete() mail id " .. tostring(mailData and mailData.mailId) .. "? false", debug)
            return false
        end
        local mailDataFieldValue = addon.filterFieldKeybind:GetFilterFieldValue(mailData)
        local canDelete = mailDataFieldValue and mailDataFieldValue == addon.filterFieldValue
        addon.Utility.Debug("mailDataFieldValue = " .. tostring(mailDataFieldValue) .. ", filterFieldValue = " .. tostring(addon.filterFieldValue), debug) 
        addon.Utility.Debug("TakeAll:CanDelete() mail id " .. tostring(mailData and mailData.mailId) .. "? " .. tostring(canDelete), debug)
        return canDelete
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
function TakeAll:CanTake(mailData, excludeMailId)
  
    if excludeMailId and AreId64sEqual(mailData.mailId, excludeMailId) then
        addon.Utility.Debug("CanTake() false for excluded mail id " .. tostring(excludeMailId), debug) 
        return false
    end
  
    local canTake
    
    -- Exclude any items that we've already read attachmnents for that we know
    -- contain only unique items that are already in our backpack.
    if addon.Utility.MailContainsOnlyUniqueConflictAttachments(mailData.mailId) then
        return false
    end
    
    -- Take by Subject / Sender
    if addon.filterFieldValue and addon.filterFieldKeybind then
        local hasAttachments = addon.Utility.HasAttachments(mailData)
        if not hasAttachments and not addon.filterFieldKeybind:IsDeleteEnabled() then
            addon.Utility.Debug("CanTake() false for mail id " .. tostring(mailData.mailId) 
                .. " because it has no attachments, and " 
                .. tostring(addon.filterFieldKeybind:GetDeleteSettingName()) .. " is false"
                , debug) 
            return false
        end
        local mailDataFieldValue = addon.filterFieldKeybind:GetFilterFieldValue(mailData)
        canTake = mailDataFieldValue and mailDataFieldValue == addon.filterFieldValue
        addon.Utility.Debug("mailDataFieldValue = " .. tostring(mailDataFieldValue) .. ", filterFieldValue = " .. tostring(addon.filterFieldValue), debug) 
    else
        -- Filter based on normal primary Take All keybind settings
        canTake = addon.Utility.CanTake(mailData, {
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
    end
    addon.Utility.Debug("TakeAll:CanTake() mail id " .. tostring(mailData and mailData.mailId) .. "? " .. tostring(canTake), debug)
    return canTake
end

--[[ True if the currently-selected mail can be taken by Take All operations 
     according to current options panel criteria. ]]
function TakeAll:CanTakeSelectedMail(excludeMailId)
    local selectedMailData = addon.Utility.KeyboardGetSelectedMailData()
    if selectedMailData
       and (not excludeMailId or not AreId64sEqual(selectedMailData.mailId, excludeMailId))
       and self:CanTake(selectedMailData) 
    then 
        return true, selectedMailData
    end
    return nil, selectedMailData
end

--[[ If a given mail id has a queued read request, 
     takes attachments from the the related mail message, if they exist.
     Deletes the mail if it has no attachments.
     Causes the mail id to be removed from the read queue. ]]
function TakeAll:DequeueReadRequest(mailId, force)
  
    local mailIdStr = addon.Utility.GetMailIdString(mailId)
    if not self.readQueue[mailIdStr] and not force then
        return
    end
    
    self.readQueue[mailIdStr] = nil
    
    if self:TryCodMail() then
        return
    end
    
    local mailData = addon.Utility.GetMailDataById(mailId)
    if not mailData then
        addon.Utility.Debug("No mail with id " .. tostring(mailId) .. " exists. Cannot take or delete.", debug)
        return
    end
    
    local hasAttachments = (mailData.attachedMoney and mailData.attachedMoney > 0)
      or (mailData.numAttachments and mailData.numAttachments > 0)
    if hasAttachments then
        addon.taking = true
        take.callback()
    else
        -- If all attachments are gone, remove the message
        addon.Utility.Debug("Deleting " .. tostring(mailId), debug)
        
        -- Delete the mail
        addon.Delete:ByMailId(mailId)
    end
end

function TakeAll:GetName()
    return GetString(SI_LOOT_TAKE_ALL)
end

--[[ Gets the next highest-priority mail data instance that Take All can take ]]
function TakeAll:GetNext(excludeMailId)
    local iterator = addon.classes.InboxTreeIterator:New(self.iterationFilter)
    local nextMailData = iterator.next(MAIL_INBOX.navigationTree:GetSelectedNode(), excludeMailId)
    if nextMailData then
        addon.Utility.Debug("TakeAll:KeyboardGetNext() returning mail id " .. tostring(nextMailData.mailId), debug)
        return nextMailData
    end
    addon.Utility.Debug("TakeAll:KeyboardGetNext() returning nil", debug)
end

function TakeAll:KeyboardGetMailReadCallback(retries, excludeMailId, calledFromEvent)
    return function()
        addon.Events:UnregisterForUpdate(EVENT_MAIL_READABLE)
        retries = retries - 1
        if retries < 0 then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_READ_FAILED)
            addon:Reset()
        else
            self:KeyboardMailRead(retries, excludeMailId, calledFromEvent)
        end
    end
end

function TakeAll:KeyboardMailRead(retries, excludeMailId, calledFromEvent)
    
    if not retries then
        retries = PM_MAIL_READ_MAX_RETRIES
    end
    
    -- If there exists another message in the inbox that has attachments, select it. otherwise, clear the selection.
    local nextMailData = self:GetNext(excludeMailId)
    if not nextMailData then
        return
    end
    
    local mailIdStr = addon.Utility.GetMailIdString(nextMailData.mailId)
    self.readQueue[mailIdStr] = true
    
    -- On there's an event handler in MAIL_INBOX for mail removed events that automatically reloads the entire mail list.
    if calledFromEvent == EVENT_MAIL_REMOVED then
      
        addon.Utility.Debug("Called from legit EVENT_MAIL_REMOVED. Deferring keyboard mail id " .. tostring(nextMailData.mailId) .. " selection.", debug)
      
        -- Right before the mail list reload is committed, set the selected index to that matching the next mail id
        addon.Prehooks:SetDeferredSelectMailId(nextMailData.mailId)
            
    -- If this wasn't called from an actual mail remove event, then it was probably called from Delete:ByMailId() 
    -- when CanDelete() was false, in which case we need to select the new mail ourselves.  The mail list won't be refreshed.
    else
        addon.Utility.Debug("MAIL_INBOX.navigationTree:Commit(node with data mail id " .. tostring(nextMailData.mailId) .. ")", debug)
        addon.Events:RegisterForUpdate(EVENT_MAIL_READABLE, PM_MAIL_READ_TIMEOUT_MS, self:KeyboardGetMailReadCallback(retries, excludeMailId, calledFromEvent) )
        MAIL_INBOX.navigationTree:Commit(nextMailData and nextMailData.node, false)
    end
    
    return nextMailData
end

--[[ Selects the next highest-priority mail data instance that Take All can take ]]
function TakeAll:SelectNext(excludeMailId, skipSelected, calledFromEvent)
  
    -- Don't need to get anything. The current selection already has attachments.
    if not skipSelected and self:CanTakeSelectedMail(excludeMailId) then
        return true
    end
    
    local nextMailData = self:KeyboardMailRead(PM_MAIL_READ_MAX_RETRIES, excludeMailId, calledFromEvent)
    if nextMailData then
        return true
    end
    
    -- No more takeable mail. Clear selection.
    MAIL_INBOX.navigationTree:ClearSelectedNode()
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