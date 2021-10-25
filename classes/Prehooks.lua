
--[[ 
    ===================================
                 PREHOOKS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false
local COLOR_DISABLED = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_DISABLED))

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
    ZO_PreHook(MAIL_INBOX, "EndRead", self:Closure(self.InboxEndRead))
    ZO_PreHook(MAIL_INBOX, "OnMailRemoved", self:Closure(self.InboxOnMailRemoved))
    ZO_PreHook(MAIL_INBOX, "RefreshData", self:Closure(self.InboxRefreshData))
    ZO_PreHook(MAIL_INBOX, "RefreshAttachmentsHeaderShown", self:Closure(self.InboxRefreshAttachmentsHeaderShown))
    ZO_PreHook(MAIL_INBOX.navigationTree, "Commit", self:Closure(self.InboxNavigationTreeCommit))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "InitializeOptionsList", self:Closure(self.MailGamepadInboxInitializeOptionsList))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "OnMailTargetChanged", self:Closure(self.MailGamepadInboxOnMailTargetChanged))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "RefreshMailList", self:Closure(self.MailGamepadInboxRefreshMailList))
    ZO_PreHook(MAIL_MANAGER_GAMEPAD.inbox, "ShowMailItem", self:Closure(self.MailGamepadInboxShowMailItem))
    if LibCustomMenu then
        ZO_PreHook(MAIL_SEND, "Send", self:Closure(self.SendMailOnSend))
    end
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

function Prehooks:InboxEndRead(inbox)
    addon.Utility.Debug("MAIL_INBOX:EndRead()", debug)
end

-- [[ Sets the auto-select node for a keyboard inbox nav tree commit to be for a deferred select mail id. ]]
function Prehooks:InboxNavigationTreeCommit(tree, autoSelectNode, bringParentIntoView)
    addon.Utility.Debug("MAIL_INBOX.navigationTree:Commit(autoSelectNode: { data: { mailId: " 
        .. tostring(autoSelectNode and autoSelectNode.data and autoSelectNode.data.mailId) .. " }} "
        .. ", bringParentIntoView: " .. tostring(bringParentIntoView) .. ")", debug)
    
    -- If there's no deferred mail id to select, proceed with the normal commit logic
    if not self.deferredSelectMailId then
        addon.Utility.Debug("No deferred selection mail id. Committing with base code", debug) 
        return
    end
    
    -- Replace the auto-select node with the one that was deferred selection
    local autoSelectData = { mailId=self.deferredSelectMailId }
    autoSelectNode = tree:GetTreeNodeByData(autoSelectData)
    addon.Utility.Debug("Setting autoSelectNode to { data: { mailId: " 
        .. tostring(autoSelectNode and autoSelectNode.data and autoSelectNode.data.mailId)
        .. " due to deferredSelectMailId: " .. tostring(self.deferredSelectMailId), debug)
    self.deferredSelectMailId = nil
    
    -- Run Commit with the new auto-select node
    tree:Commit(autoSelectNode, bringParentIntoView)
    
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
        addon.Utility.Debug(message .. ": Proceeding with base code", debug)
    end
end

function Prehooks:InboxRefreshData(inbox)
    addon.Utility.Debug("MAIL_INBOX:RefreshData()", debug)
end

function Prehooks:InboxRefreshAttachmentsHeaderShown(inbox)
    addon.Utility.Debug("MAIL_INBOX:InboxRefreshAttachmentsHeaderShown()", debug)
    if not inbox or not inbox.attachmentsHeaderControl then
        return
    end
    if not self.defaultAttachmentsHeaderText then
        self.defaultAttachmentsHeaderText = inbox.attachmentsHeaderControl:GetText()
    end
    local mailId = inbox:GetOpenMailId()
    if not mailId then
        return
    end
    local text = self.defaultAttachmentsHeaderText
    if addon.Utility.MailContainsOnlyUniqueConflictAttachments(mailId) then
        text = text .. " " .. GetString(SI_ITEM_FORMAT_STR_UNIQUE)
        text = COLOR_DISABLED:Colorize(text)
    end
    inbox.attachmentsHeaderControl:SetText(text)
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
    
    local attachmentData = addon.Utility.GetAttachmentData(mailId)
    if not attachmentData then
        return
    end
    
    local mailIdString = addon.Utility.GetMailIdString(mailId)
    
    addon.awaitingAttachments[mailIdString] = {}
    
    if attachmentData.cod > 0 then
        if addon.takingAll then
            if not addon.settings.takeAllCodTake then return end
        elseif not addon.pendingAcceptCOD then return end
    end 
    
    if attachmentData.numAttachments > 0 then
    
        -- If all attachments were unique and already in the backpack
        if attachmentData.uniqueItemConflictCount == attachmentData.numAttachments then
            addon.Utility.Debug("Not taking attachments for "..mailIdString
                       .." because it contains only unique items that are already in the backpack", debug)
            addon.Events:MailRemoved(nil, mailId)
            return true
        end
        if attachmentData.money > 0 or attachmentData.cod > 0 then
            table.insert(addon.awaitingAttachments[mailIdString], true)
            -- Wire up timeout callback
            self:RegisterTakeAttachmentsTimeout(mailId)
        end
    end
    addon.attachmentData[mailIdString] = attachmentData
    if attachmentData.cod > 0 then
        addon.codMails[mailIdString] = { mailId = mailId, amount = attachmentData.cod, complete = false }
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

function Prehooks:SendMailOnSend()
    addon.Utility.Debug("Prehooks:SendMailOnSend(). Saving send mail fields.", debug)
    addon.SendMail:SaveData()
end

function Prehooks:SetDeferredSelectMailId(mailId)
    addon.Utility.Debug("Prehooks:SetDeferredSelectMailId(" .. tostring(mailId) .. ")", debug)
    self.deferredSelectMailId = mailId
end

addon.Prehooks = Prehooks:New()
