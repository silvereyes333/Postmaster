local addon = Postmaster
local class = addon.classes
local debug = false
local RegisterTimeout, GetTimeout

local Delete = ZO_Object:Subclass()

function Delete:New(...)
    local instance = ZO_Object.New(self)
    self.Initialize(instance, ...)
    return instance
end

function Delete:Initialize()
    
    self.running = false
    self.locked = true
    
    -- Remembers mail removal requests that don't receive a mail removed event from the server
    -- or which have the event come in while the inbox is closed
    -- so that the removals can be processed once the inbox opens again.
    self.queuedMailIds = {}
end

--[[ Called to delete the current mail after all attachments are taken and all 
     C.O.D. money has been removed from the player's inventory.  ]]
function Delete:ByMailId(mailId)
  
    local mailIdString = addon.Utility.GetMailIdString(mailId)
    
    -- If the we haven't received confirmation that the server received the
    -- payment for a C.O.D. mail, exit without deleting the mail. 
    -- This method will be called again from Postmaster.Events:MailSendSuccess(), at which
    -- time it should proceed with the delete because the mail id string is
    -- removed from addon.codMails.
    local codMail = addon.codMails[addon.Utility.GetMailIdString(mailId)]
    if codMail then
        codMail.complete = true
        return
    end
    
    -- Collect summary of attachments
    -- Do this here, immediately after all attachments are collected and C.O.D. are paid, 
    -- Don't wait until the mail removed event, because it may or may not go 
    -- through if the user closes the inbox.
    local mailData = addon.Utility.GetMailDataById(mailId)
    
    -- Get the latest data, in case it has changed
    ZO_MailInboxShared_PopulateMailData(mailData, mailId)
    
    addon.Utility.CollectAttachments(mailData.fromSystem and "@SYSTEM" or mailData.senderDisplayName, addon.attachmentData[mailIdString])
    
    -- Clean up tracking arrays
    addon.awaitingAttachments[mailIdString] = nil
    
    local attachmentData = addon.attachmentData[mailIdString]
    addon.attachmentData[mailIdString] = nil
    
    if (mailData.attachedMoney and mailData.attachedMoney > 0) or (mailData.numAttachments and mailData.numAttachments > 0) then
        addon.Utility.Debug("Cannot delete mail id " .. tostring(mailId) .. " because it is not empty. attachedMoney: " .. tostring(mailData.attachedMoney) .. ", numAttachments: ".. tostring(mailData.numAttachments))
        addon.mailIdsFailedDeletion[mailIdString] = true
        addon.Events:MailRemoved(nil, mailId)
        return
    end
    
    -- Check that the current type of mail should be deleted
    if addon.takingAll then
        if not addon.keybinds.keyboard.TakeAll:CanDelete(mailData, attachmentData) then
            addon.Utility.Debug("Not deleting mail id "..mailIdString.." because of configured options")
            -- Skip actual mail removal and go directly to the postprocessing logic
            addon.mailIdsFailedDeletion[mailIdString] = true
            addon.Events:MailRemoved(nil, mailId)
            return
        end
    end
    
    -- Mark mail for deletion
    addon.Utility.Debug("Marking mail id "..tostring(mailId).." for deletion")
    self.queuedMailIds[mailIdString] = true
    
    -- If inbox is open...
    if addon.Utility.IsInboxShown() then
        -- If all attachments are gone, remove the message
        addon.Utility.Debug("Deleting "..tostring(mailId))
        
        self:RegisterTimeout(mailId)
        DeleteMail(mailId, false)
    end
end

function Delete:DeleteQueued()
    addon.Utility.Debug("Delete:QueueAndReturn()", debug)
    
    if not addon.settings.bounce
       or not self.locked
       or not addon.Utility.IsInboxShown()
       or addon:IsBusy()
       or not next(self.queuedMailIds)
    then
        return
    end
    
    self.running = true
    return self:DeleteNext(true)
end

function Delete:DequeueMailId(mailId)
    addon.Utility.Debug("Delete:DequeueMailId(" .. tostring(mailId) .. ")", debug)
    if not mailId then return end
    local mailIdStr = self:IsMailIdQueued(mailId)
    if mailIdStr then
        self.queuedMailIds[mailIdStr] = nil
        return true
    end
end

function Delete:DeleteNext(doNotRefresh)
    addon.Utility.Debug("Delete:DeleteNext(" .. tostring(doNotRefresh) .. ")", debug)
    local deleteMailIdStr = next(self.queuedMailIds)
    if deleteMailIdStr then
        local mailId = StringToId64(deleteMailIdStr)
        addon.Utility.Debug("Calling DeleteMail(" .. tostring(mailId) .. ", false)", debug)
        DeleteMail(mailId, false)
        return true
    else
        self.running = false
        addon.Utility.Debug("Delete is no longer running.", debug)
        if doNotRefresh then
            return
        end
        
        addon.Utility.Debug("Refreshing mail list.", debug)
        addon.Utility.RefreshMailList()
        
        addon.Utility.Debug("Refreshing keybinds.", debug)
        addon.Utility:UpdateKeybindButtonGroup()
        
        -- Proceed to auto-return mail, now that we are done deleting queued messages
        addon.AutoReturn:QueueAndReturn()
    end
end

function Delete:GetTimeout(mailId, retries)
    return function()
        addon.Events:UnregisterForUpdate(EVENT_MAIL_REMOVED)
        retries = retries - 1
        if retries < 0 then
            self:OnFailed()
        else
            self:RegisterTimeout(mailId, retries)
            DeleteMail(mailId, false)
        end
    end
end

--[[ True if the inbox was closed when a Postmaster.Delete:ByMailId() call came in for 
     the given mail ID, and therefore needs to be deleted when the inbox opens
     once more. ]]
function Delete:IsMailIdQueued(mailId)
    if not mailId then return end
    local mailId64 = zo_getSafeId64Key(mailId)
    if self.queuedMailIds[mailId64] then
        addon.Utility.Debug("Delete:IsMailIdQueued(" .. tostring(mailId) .. ") = " .. mailId64, debug)
        return mailId64
    end
end

function Delete:IsRunning()
    return self.running
end

function Delete:OnFailed()
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_DELETE_FAILED)
    addon:Reset()
end

function Delete:RegisterTimeout(mailId, retries)
    -- Wire up timeout callback
    if not retries then
        retries = PM_DELETE_MAIL_MAX_RETRIES
    end
    addon.Events:RegisterForUpdate(EVENT_MAIL_REMOVED, PM_DELETE_MAIL_TIMEOUT_MS, self:GetTimeout(mailId, retries))
end

--[[ DeleteQueued is locked by default, and only unlocks once the inbox is updated.
     In contrast to AutoReturn, however, it will not re-lock after that point. 
     It and will run as many times as it is called. ]]
function Delete:Unlock()
    self.locked = false
end

addon.Delete = Delete:New()
