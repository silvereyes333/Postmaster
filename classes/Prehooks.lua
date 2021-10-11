
--[[ 
    ===================================
                 PREHOOKS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false

-- Singleton class
local Prehooks = ZO_Object:Subclass()

function Prehooks:New()
    return ZO_Object.New(self)
end

--[[ Wire up all prehook handlers ]]
function Prehooks:Initialize()
    ZO_PreHook("ZO_MailInboxShared_TakeAll", self:Create("MailInboxSharedTakeAll"))
    ZO_PreHook("RequestReadMail", self:Create("RequestReadMail"))
    ZO_PreHook("ZO_Dialogs_ShowDialog", self:Create("DialogsShowDialog"))
    ZO_PreHook("ZO_Dialogs_ShowGamepadDialog", self:Create("DialogsShowGamepadDialog"))
    ZO_PreHook(MAIL_INBOX, "OnMailRemoved", self:Create("InboxOnMailRemoved"))
end

function Prehooks:Create(name)
    return function(...)
        return self[name](self, ...)
    end
end

function Prehooks:GetTakeAttachmentsTimeout(mailId, retries)
    return function()
        addon.Events:UnregisterForUpdate(EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS)
        retries = retries - 1
        if retries < 0 then
            self:OnTakeAttachmentsFailed()
        else
            self:RegisterTakeAttachmentsTimeout(mailId, retries)
            ZO_MailInboxShared_TakeAll(mailId)
        end
    end
end

--[[ Suppress mail delete and/or return to sender dialog in keyboard mode, if configured ]]
function Prehooks:DialogsShowDialog(name, data, textParams, isGamepad)
    if addon.settings.deleteDialogSuppress and name == "DELETE_MAIL" then 
        MAIL_INBOX:ConfirmDelete(MAIL_INBOX.mailId)
        return true
    elseif addon.settings.returnDialogSuppress and name == "MAIL_RETURN_ATTACHMENTS" then
        ReturnMail(MAIL_INBOX.mailId)
        return true
    end
end

--[[ Suppress mail delete and/or return to sender dialog in gamepad mode, if configured ]]
function Prehooks:DialogsShowGamepadDialog(name, data, textParams)
    if addon.settings.deleteDialogSuppress and name == "DELETE_MAIL" then 
        MAIL_MANAGER_GAMEPAD.inbox:Delete()
        return true
    elseif addon.settings.returnDialogSuppress and name == "MAIL_RETURN_ATTACHMENTS" then
        MAIL_MANAGER_GAMEPAD.inbox:ReturnToSender()
        return true
    end
end

-- [[ Prevents auto returned mails from progressing the selected mail index. ]]
function Prehooks:InboxOnMailRemoved(inbox, mailId)
    addon.Utility.Debug("MAIL_INBOX:OnMailRemoved(" .. tostring(inbox) .. ", " .. tostring(mailId) .. ")", debug)
    if addon.AutoReturn:IsMailIdQueued(mailId) then
        return true
    end
end

--[[ Runs before a mail's attachments are taken, recording attachment information
     and initializing controller state variables for the take operation. ]]
function Prehooks:MailInboxSharedTakeAll(mailId)
    addon.Utility.Debug("ZO_MailInboxShared_TakeAll(" .. tostring(mailId) .. ")", debug)
    if not addon.taking then
        return
    end
    local numAttachments, attachedMoney, codAmount = GetMailAttachmentInfo(mailId)
    if codAmount > 0 then
        if addon.takingAll then
            if not addon.settings.takeAllCodTake then return end
        elseif not addon.pendingAcceptCOD then return end
    end 
    addon.awaitingAttachments[addon.Utility.GetMailIdString(mailId)] = {}
    local attachmentData = { items = {}, money = attachedMoney, cod = codAmount }
    local uniqueAttachmentConflictCount = 0
    for attachIndex=1,numAttachments do
        local _, stack = GetAttachedItemInfo(mailId, attachIndex)
        local attachmentItem = { link = GetAttachedItemLink(mailId, attachIndex), count = stack or 1 }
        if addon.UniqueBackpackItemsList:ContainsItemLink(attachmentItem.link) then
            uniqueAttachmentConflictCount = uniqueAttachmentConflictCount + 1
        else
            table.insert(attachmentData.items, attachmentItem)
        end
    end
    local mailIdString = addon.Utility.GetMailIdString(mailId)
    
    if numAttachments > 0 then
    
        -- If all attachments were unique and already in the backpack
        if uniqueAttachmentConflictCount == numAttachments then
            addon.Utility.Debug("Not taking attachments for "..mailIdString
                       .." because it contains only unique items that are already in the backpack", debug)
            addon.mailIdsFailedDeletion[mailIdString] = true
            addon.Events:MailRemoved(nil, mailId)
            return true
        end
        if attachedMoney > 0 or codAmount > 0 then
            table.insert(addon.awaitingAttachments[addon.Utility.GetMailIdString(mailId)], true)
            -- Wire up timeout callback
            self:RegisterTakeAttachmentsTimeout(mailId)
        end
    end
    addon.attachmentData[mailIdString] = attachmentData
    if codAmount > 0 then
        addon.codMails[mailIdString] = { mailId = mailId, amount = codAmount, complete = false }
    end
end

function Prehooks:OnTakeAttachmentsFailed()
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_TAKE_ATTACHMENTS_FAILED)
    addon:Reset()
end

function Prehooks:RegisterTakeAttachmentsTimeout(mailId, retries)
    if not retries then
        retries = PM_TAKE_ATTACHMENTS_MAX_RETRIES
    end
    addon.Events:RegisterForUpdate(EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, PM_TAKE_TIMEOUT_MS, self:GetTakeAttachmentsTimeout(mailId, retries) )
end

--[[ Listen for mail read requests when the inbox is closed and deny them.
     The server won't raise the EVENT_MAIL_READABLE event anyways ]]
function Prehooks:RequestReadMail(mailId)
    addon.Utility.Debug("RequestReadMail(" .. tostring(mailId) .. ")", debug)
    local deny = not addon.Utility.IsInboxShown()
    if deny then
        addon.Utility.Debug("Inbox isn't open. Request denied.", debug)
    end
    return deny
end

addon.Prehooks = Prehooks:New()
