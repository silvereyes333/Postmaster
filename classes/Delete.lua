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
    
    -- Remembers mail removal requests that don't receive a mail removed event from the server
    -- or which have the event come in while the inbox is closed
    -- so that the removals can be processed once the inbox opens again.
    self.pendingMailIds = {}
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
    local mailData = MAIL_INBOX:GetMailData(mailId)
    addon.Utility.CollectAttachments(mailData.fromSystem and "@SYSTEM" or mailData.senderDisplayName, addon.attachmentData[mailIdString])
    
    -- Clean up tracking arrays
    addon.awaitingAttachments[mailIdString] = nil
    
    local attachmentData = addon.attachmentData[mailIdString]
    addon.attachmentData[mailIdString] = nil
    
    if (mailData.attachedMoney and mailData.attachedMoney > 0) or (mailData.numAttachments and mailData.numAttachments > 0) then
        addon.Utility.Debug("Cannot delete mail id "..mailIdString.." because it is not empty")
        addon.mailIdsFailedDeletion[mailIdString] = true
        addon.Events:MailRemoved(nil, mailId)
        return
    end
    
    
    -- Check that the current type of mail should be deleted
    if addon.takingAll and (not addon.settings.keybinds.quaternary or addon.settings.keybinds.quaternary == "" or not addon.filterFieldValue) then
        if not addon.keybinds.TakeAll:CanDelete(mailData, attachmentData) then
            addon.Utility.Debug("Not deleting mail id "..mailIdString.." because of configured options")
            -- Skip actual mail removal and go directly to the postprocessing logic
            addon.mailIdsFailedDeletion[mailIdString] = true
            addon.Events:MailRemoved(nil, mailId)
            return
        end
    end
    
    
    -- Mark mail for deletion
    addon.Utility.Debug("Marking mail id "..tostring(mailId).." for deletion")
    self.pendingMailIds[mailIdString] = true
    
    -- If inbox is open...
    if SCENE_MANAGER:IsShowing("mailInbox") then
        -- If all attachments are gone, remove the message
        addon.Utility.Debug("Deleting "..tostring(mailId))
        
        self:RegisterTimeout(mailId)
        DeleteMail(mailId, false)
        
    -- Inbox is no longer open, so delete events won't be raised
    else
        if not AreId64sEqual(addon.mailIdLastOpened, mailId) then
            addon.Utility.Debug("Marking mail id "..tostring(mailId).." to be opened when inbox does")
            MAIL_INBOX.mailId = nil
            MAIL_INBOX.requestMailId = mailId
        end
    end
end

--[[ Called when the inbox opens to automatically delete any mail that finished
     a Take or Take All operation after the inbox was closed. ]]
function Delete:ByMailIdIfPending(mailId)
    local deleteIndex = addon.Delete:IsPending(mailId)
    if not deleteIndex then return end
    -- Resume the Take operation. will be cleared when the mail removed event handler fires.
    addon.taking = true 
    addon.Utility.Debug("deleting mail id "..tostring(mailId))
    addon.Delete:ByMailId(mailId)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
    return deleteIndex
end

function Delete:ClearPending(mailId)
    local mailIdString = addon.Utility.GetMailIdString(mailId)
    self.pendingMailIds[mailIdString] = nil
end

--[[ True if the inbox was closed when a Postmaster.Delete:ByMailId() call came in for 
     the given mail ID, and therefore needs to be deleted when the inbox opens
     once more. ]]
function Delete:IsPending(mailId)
    if not mailId then return end
    local mailIdString = addon.Utility.GetMailIdString(mailId)
    return self.pendingMailIds[mailIdString]
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

addon.Delete = Delete:New()
