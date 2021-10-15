
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
    ZO_PreHook("ZO_MailInboxShared_TakeAll", self:Closure(self.MailInboxSharedTakeAll))
    ZO_PreHook("RequestReadMail", self:Closure(self.RequestReadMail))
    ZO_PreHook("ZO_Dialogs_ShowDialog", self:Closure(self.DialogsShowDialog))
    ZO_PreHook("ZO_Dialogs_ShowGamepadDialog", self:Closure(self.DialogsShowGamepadDialog))
    ZO_PreHook(MAIL_INBOX, "OnMailRemoved", self:Closure(self.InboxOnMailRemoved))
    ZO_PreHook(MAIL_INBOX.navigationTree, "Commit", self:Closure(self.InboxNavigationTreeCommit))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "InitializeOptionsList", self:Closure(self.MailGamepadInboxInitializeOptionsList))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "OnMailTargetChanged", self:Closure(self.MailGamepadInboxOnMailTargetChanged))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "RefreshMailList", self:Closure(self.MailGamepadInboxRefreshMailList))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "ShowMailItem", self:Closure(self.MailGamepadInboxShowMailItem))
end

function Prehooks:Closure(fn)
    return function(...)
        return fn(self, ...)
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

-- [[ Sets the auto-select node for a keyboard inbox nav tree commit to be for a deferred select mail id. ]]
function Prehooks:InboxNavigationTreeCommit(tree, autoSelectNode, bringParentIntoView)
    addon.Utility.Debug("MAIL_INBOX.navigationTree:Commit(autoSelectNode: " .. tostring(autoSelectNode) 
        .. ", bringParentIntoView: " .. tostring(bringParentIntoView) .. ")", debug)
    
    -- If there's no deferred mail id to select, proceed with the normal commit logic
    if not self.deferredSelectMailId then
        return
    end
    
    -- Replace the auto-select node with the one that was deferred selection
    autoSelectNode = tree:GetTreeNodeByData({ mailId=self.deferredSelectMailId })
    self.deferredSelectMailId = nil
    
    -- Run Commit with the new auto-select node
    tree:Commit(autoSelectNode, bringParentIntoView)
    
    -- Fix for bug that caused some controls to be left highlighted
    tree:RefreshVisible()
    
    return true
end

-- [[ Prevents auto returned mails or deleted mails during take all from progressing the selected mail index. ]]
function Prehooks:InboxOnMailRemoved(inbox, mailId)
    local message = "MAIL_INBOX:OnMailRemoved(" .. tostring(inbox) .. ", " .. tostring(mailId) .. ")"
    if addon.Delete:IsMailIdQueued(mailId) then
        addon.Utility.Debug(message .. ": Deferred until after our mail removed event runs...", debug)
        return true
    elseif addon.AutoReturn:IsMailIdQueued(mailId) then
        addon.Utility.Debug(message .. ": Prevented. In the middle of an auto-return.", debug)
        return true
    else
        addon.Utility.Debug(message, debug)
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

function Prehooks:MailGamepadInboxInitializeOptionsList(inbox)
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox.mailList, "Clear", self:Closure(self.MailGamepadInboxListClear))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox.mailList, "Commit", self:Closure(self.MailGamepadInboxListCommit))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox.mailList, "SetSelectedIndex", self:Closure(self.MailGamepadInboxListSetSelectedIndex))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox.mailList, "UpdateAnchors", self:Closure(self.MailGamepadInboxListUpdateAnchors))
end

function Prehooks:MailGamepadInboxListClear(list)
    addon.Utility.Debug("MailGamepadInboxListClear()", debug)
end

function Prehooks:MailGamepadInboxListCommit(list)
    addon.Utility.Debug("MailGamepadInboxListCommit()", debug)
    if self.deferredSelectMailId then
        local selectedIndex = list:FindFirstIndexByEval(addon.Utility.MatchMailIdClosure(self.deferredSelectMailId))
        list:EnableAnimation(false)
        local ALLOW_EVEN_IF_DISABLED = true
        local FORCE_ANIMATION = true
        local DEFAULT_JUMP_TYPE = nil
        local BLOCK_SELECTION_CHANGED_CALLBACK = true
        addon.Utility.Debug("Prehooks.deferredSelectMailId " .. tostring(self.deferredSelectMailId) .. " detected.  Setting selected index to " .. tostring(selectedIndex), debug)
        list:SetSelectedIndex(selectedIndex, ALLOW_EVEN_IF_DISABLED, FORCE_ANIMATION, DEFAULT_JUMP_TYPE, BLOCK_SELECTION_CHANGED_CALLBACK)
        list:EnableAnimation(true)
        self.deferredSelectMailId = nil
    end
end

function Prehooks:MailGamepadInboxListSetSelectedIndex(list, selectedIndex, allowEvenIfDisabled, forceAnimation, jumpType, blockSelectionChangedCallback)
    addon.Utility.Debug("MailGamepadInboxListSetSelectedIndex(selectedIndex: " .. tostring(selectedIndex) 
        .. ", allowEvenIfDisabled: " .. tostring(allowEvenIfDisabled) .. ", forceAnimation: " .. tostring(forceAnimation)
        .. ", jumpType: " .. tostring(jumpType) .. ", blockSelectionChangedCallback: " .. tostring(blockSelectionChangedCallback) .. ")", 
        debug)
end

function Prehooks:MailGamepadInboxListUpdateAnchors(list, continousTargetOffset, initialUpdate, reselectingDuringRebuild, blockSelectionChangedCallback)
    addon.Utility.Debug("MailGamepadInboxListUpdateAnchors(continuousTargetOffset: " .. tostring(continousTargetOffset) 
        .. ", initialUpdate: " .. tostring(initialUpdate) .. ", reselectingDuringRebuild: " .. tostring(reselectingDuringRebuild) 
        .. ", blockSelectionChangedCallback: " .. tostring(blockSelectionChangedCallback) .. ")", debug)
end

function Prehooks:MailGamepadInboxOnMailTargetChanged(inbox, list, targetData, oldTargetData, reachedTargetIndex, targetSelectedIndex)
    addon.Utility.Debug("MailGamepadInboxOnMailTargetChanged(targetData: { dataSource: { mailId: " 
        .. tostring(targetData and targetData.dataSource and targetData.dataSource.mailId) 
        .. ", subject: " .. tostring(targetData and targetData.dataSource and targetData.dataSource.subject) .. " } }"
        .. ", oldTargetData: { dataSource: { mailId: " 
        .. tostring(oldTargetData and oldTargetData.dataSource and oldTargetData.dataSource.mailId) 
        .. ", subject: " .. tostring(oldTargetData and oldTargetData.dataSource and oldTargetData.dataSource.subject) .. " } }"
        .. ", reachedTargetIndex: " .. tostring(reachedTargetIndex) .. ", targetSelectedIndex: " .. tostring(targetSelectedIndex) .. ")", 
        debug)
end

function Prehooks:MailGamepadInboxRefreshMailList(inbox) 
    addon.Utility.Debug("MailGamepadInboxRefreshMailList()", debug)
end

function Prehooks:MailGamepadInboxShowMailItem(inbox, mailId)
    addon.Utility.Debug("MailGamepadInboxShowMailItem(" .. tostring(mailId) .. ")", debug)
end

function Prehooks:OnTakeAttachmentsFailed()
    addon.Utility.Debug("Prehooks:OnTakeAttachmentsFailed(). Resetting PM.", debug)
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

function Prehooks:SetDeferredSelectMailId(mailId)
    addon.Utility.Debug("Prehooks:SetDeferredSelectMailId(" .. tostring(mailId) .. ")", debug)
    self.deferredSelectMailId = mailId
end

addon.Prehooks = Prehooks:New()
