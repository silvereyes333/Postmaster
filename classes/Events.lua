--[[ 
    ===================================
            GAME CLIENT EVENTS 
    ===================================
  ]]
  
local addon = Postmaster
local debug = false
local exitMailNodeControl

-- Singleton class
local Events = ZO_Object:Subclass()

function Events:New()
    return ZO_Object.New(self)
end

function Events:Initialize()
  
    self.handlerNames = {
        [EVENT_INVENTORY_IS_FULL]                = "InventoryIsFull",
        [EVENT_INVENTORY_SINGLE_SLOT_UPDATE]     = "InventorySingleSlotUpdate",
        [EVENT_MAIL_INBOX_UPDATE]                = "MailInboxUpdate",
        [EVENT_MAIL_READABLE]                    = "MailReadable",
        [EVENT_MAIL_REMOVED]                     = "MailRemoved",
        [EVENT_MAIL_SEND_SUCCESS]                = "MailSendSuccess",
        [EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS]  = "MailTakeAttachedItemSuccess",
        [EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS] = "MailTakeAttachedMoneySuccess",
        [EVENT_MONEY_UPDATE]                     = "MoneyUpdate",
    }
    
    -- Special keys where RegisterForUpdate() and UnregisterForUpdate() should share the same 
    -- names for multiple events.
    self.updateKeys = {
        [EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS]  = "MailTake",
        [EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS] = "MailTake",
        [EVENT_MONEY_UPDATE]                     = "MailTake",
    }
    
    self.updateKeyPrefix = addon.name .. ".Events."
    
    for event, handlerName in pairs(self.handlerNames) do
        EVENT_MANAGER:RegisterForEvent(addon.name, event, self:Closure(handlerName))
    end
    
    -- We are only interested in backpack inventory updates
    EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    
    -- Fix for Wykkyd Mailbox keybind conflicts
    if type(WYK_MailBox) == "table" then
        WYK_MailBox:UnregisterEvent(EVENT_MAIL_READABLE)
    end
end

function Events:Closure(functionName)
    return function(...)
        self[functionName](self, ...)
    end
end

--[[ Raised when an attempted item transfer to the backpack fails due to not 
     enough slots being available.  When this happens, we should abort any 
     pending operations and reset controller state. ]]
function Events:InventoryIsFull(eventCode, numSlotsRequested, numSlotsFree)

    addon.Utility.Debug("EVENT_INVENTORY_IS_FULL(" .. tostring(eventCode) .. ", "..tostring(numSlotsRequested) .. "," .. tostring(numSlotsFree) .. ")", debug)
    addon:Reset()
    addon.Utility.UpdateKeybindButtonGroup()
end

--[[ Raised when a backpack inventory slot is updated. ]]
function Events:InventorySingleSlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)

    addon.Utility.Debug("EVENT_INVENTORY_SINGLE_SLOT_UPDATE(" .. tostring(eventCode) .. ", "..tostring(bagId) .. "," .. tostring(slotIndex)
        .. "," .. tostring(isNewItem) .. "," .. tostring(itemSoundCategory) .. "," .. tostring(inventoryUpdateReason)
        .. "," .. tostring(stackCountChange) .. ")", debug)
    addon.UniqueBackpackItemsList:Update(slotIndex)
end

--[[ Raised whenever new mail arrives.  When this happens, mark that we need to 
     check for auto-return mail. ]]
function Events:MailInboxUpdate(eventCode)

    addon.Utility.Debug("EVENT_MAIL_INBOX_UPDATE(" .. tostring(eventCode) .. ")", debug)
    if not addon.settings.bounce then return end
    
    -- DeleteQueued will not run until the mailbox is updated the first time.
    -- Unlock it now.
    addon.Utility.Debug("Unlocking Delete:DeleteQueued().", debug)
    addon.Delete:Unlock()
    
    -- Auto return only runs a single time every time the inbox updates.
    -- Unlock it now.  It will automatically re-lock itself after it runs, until
    -- the next time the inbox updates.
    addon.Utility.Debug("Unlocking AutoReturn:QueueAndReturn().", debug)
    addon.AutoReturn:Unlock()
    
    -- Try deleting any messages queued for deletion
    if addon.Delete:DeleteQueued() then
        return
    end
    
    -- Try auto-returning any new mail that's arrived
    addon.AutoReturn:QueueAndReturn()
end

--[[ Raised in response to a successful RequestReadMail() call. Indicates that
     the mail is now open and ready for actions. It is necessary for this event 
     to fire before most actions on a mail message will be allowed by the server.
     Here, we trigger or cancel the next Take All loop,
     as well as automatically delete any empty messages pending removal. ]]
function Events:MailReadable(eventCode, mailId)

    addon.Utility.Debug("EVENT_MAIL_READABLE(" .. tostring(eventCode) .. "," .. tostring(mailId) .. ")", debug)
    self:UnregisterForUpdate(EVENT_MAIL_READABLE)
        
    -- If taking all, then go ahead and start the next Take loop, since the
    -- mail and attachments are readable now.
    if addon.takingAll then
        addon.Utility.GetActiveKeybinds().TakeAll:DequeueReadRequest(mailId)
    end
end

--[[ Raised in response to a successful DeleteMail() call. Used to trigger 
     opening the next mail with attachments for Take All, or reset state 
     variables and refresh the keybind strip for Take. ]]
function Events:MailRemoved(eventCode, mailId)

    addon.Utility.Debug("EVENT_MAIL_REMOVED(" .. tostring(eventCode) .. "," .. tostring(mailId) .. ")", debug)
    
    -- If a mail id was queued for deletion, dequeue it
    local deleteQueuedRunning = addon.Delete:IsRunning()
    local deleteWasQueued = addon.Delete:DequeueMailId(mailId)
    if deleteWasQueued and deleteQueuedRunning then
        -- If addon.Delete is running through a DeleteQueued() operation, then
        -- proceed to the next in the queue.
        addon.Delete:DeleteNext()
        return
    end
    
    -- If a mail id was queued for return, dequeue it
    local autoReturnQueueRunning = addon.AutoReturn:IsRunning()
    if addon.AutoReturn:DequeueMailId(mailId) and autoReturnQueueRunning then
        -- If addon.AutoReturn is running through a QueueAndDelete() operation, then
        -- proceed to the next in the queue.
        addon.AutoReturn:ReturnNext()
        return
    end
    
    -- Just a quick sanity check.  If a mail was removed while an auto-return or auto-delete queue was running,
    -- possibly by another addon, stop processing.
    if autoReturnQueueRunning or deleteQueuedRunning then
        return
    end
    
    if eventCode == EVENT_MAIL_REMOVED then
        
        -- Unwire timeout callback
        self:UnregisterForUpdate(EVENT_MAIL_REMOVED)
        PlaySound(SOUNDS.MAIL_ITEM_DELETED)
        addon.Utility.Debug("deleted mail id "..tostring(mailId))
    end
    
    -- Everything below this point relates to Take, Take All and Take All by Subject/Author operations
    if not addon.taking then
        return
    end
    
    local isInboxOpen = addon.Utility.IsInboxShown()
    
    local isNotDone = false
    
    -- For non-canceled take all requests, select the next mail for taking.
    -- It will be taken automatically by Event_MailReadable() once the 
    -- EVENT_MAIL_READABLE event comes back from the server.
    if isInboxOpen and addon.takingAll and not deleteQueuedRunning then
        addon.Utility.Debug("Selecting next mail with attachments", debug)
        isNotDone = addon.Utility.GetActiveKeybinds().TakeAll:SelectNext(mailId, nil, eventCode)
    end
    
    if isInboxOpen and deleteWasQueued and eventCode == EVENT_MAIL_REMOVED and not IsInGamepadPreferredMode() then
        
        -- Call the keyboard/mouse mail removed handler that was deferred earlier in Prehooks.lua.
        -- The following will end the active mail read, refresh the mail list and select 
        -- any mail ids that were deferred above.
        MAIL_INBOX:OnMailRemoved(mailId)
        
        -- Clear out any stuck mouseovers
        addon.Utility.KeyboardInboxTreeEvalAllNodes(exitMailNodeControl)
    end
    
    -- Everything below this point is for when the take all operation is done.
    if isNotDone then
        return
    end
    
    -- Ensure that a keyboard mail is selected after a take all operation.
    -- The selection was potentially cleared to avoid progressing to the second mail after the final
    -- MAIL_INBOX:RefreshData()
    if not IsInGamepadPreferredMode() then
        
        local inboxMailId = MAIL_INBOX:GetOpenMailId()
        local selectNode
        
        -- Prefer the node already displaying
        if inboxMailId then
            selectNode = MAIL_INBOX.navigationTree:GetTreeNodeByData({ mailId = inboxMailId })
            if selectNode then
                MAIL_INBOX.navigationTree:Commit(selectNode, true)
            end
        end
        
        -- Otherwise, select the first node in the tree
        if not selectNode then
            MAIL_INBOX.navigationTree:SelectAnything()
        end
        
        -- Not sure how this could happen, but if the inbox has no mail nodes, but it
        -- is still tracking an open mail id, then close out the tracking data.
        local selectedNode = MAIL_INBOX.navigationTree:GetSelectedNode()
        if inboxMailId and not selectedNode or not selectedNode.data or not selectedNode.data.mailId then
            MAIL_INBOX:EndRead()
        end
    end
    
    -- This was either a normal take, or there are no more valid mails
    -- for take all, or an abort was requested, so cancel out.
    addon:Reset()
    
    -- If the inbox is still open when the delete comes through, refresh the
    -- keybind strip.
    if isInboxOpen then
        addon.Utility.UpdateKeybindButtonGroup()
    end
end

--[[ Raised after a sent mail message is received by the server. We only care
     about this event because C.O.D. mail cannot be deleted until it is raised. ]]
function Events:MailSendSuccess(eventCode)
    if not addon.taking then return end
    addon.Utility.Debug("Event_MailSendSuccess()", debug)
    local mailIdString,codMail = addon.Utility.GetFirstCompleteCodMail()
    if not codMail then return end
    addon.codMails[mailIdString] = nil
    -- Now that we've seen that the gold is sent, we can delete COD mail
    addon.Delete:ByMailId(codMail.mailId)
end

--[[ Raised when attached items are all received into inventory from a mail.
     Used to automatically trigger mail deletion. ]]
function Events:MailTakeAttachedItemSuccess(eventCode, mailId)
    if not addon.taking then return end
    addon.Utility.Debug("attached items taken "..tostring(mailId))
    local waitingForMoney
    local mailIdString = addon.Utility.GetMailIdString(mailId)
    if addon.awaitingAttachments[mailIdString] then
        waitingForMoney = table.remove(addon.awaitingAttachments[mailIdString])
    end
    if waitingForMoney then 
        addon.Utility.Debug("still waiting for money or COD. exiting.", debug)
    else
        -- Stop take attachments retries
        self:UnregisterForUpdate(EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS)
        addon.Delete:ByMailId(mailId)
    end
end

--[[ Raised when attached gold is all received into inventory from a mail.
     Used to automatically trigger mail deletion. ]]
function Events:MailTakeAttachedMoneySuccess(eventCode, mailId)
    if not addon.taking then return end
    addon.Utility.Debug("attached money taken "..tostring(mailId), debug)
    local waitingForItems
    local mailIdString = addon.Utility.GetMailIdString(mailId)
    if addon.awaitingAttachments[mailIdString] then
        waitingForItems = table.remove(addon.awaitingAttachments[mailIdString])
    end
    if waitingForItems then 
        addon.Utility.Debug("still waiting for items. exiting.", debug)
    else
        -- Stop take attachments retries
        self:UnregisterForUpdate(EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS)
        addon.Delete:ByMailId(mailId)
    end
end

--[[ Raised whenever gold enters or leaves the player's inventory.  We only care
     about money leaving inventory due to a mail event, indicating a C.O.D. payment.
     Used to automatically trigger mail deletion. ]]
function Events:MoneyUpdate(eventCode, newMoney, oldMoney, reason)

    if not addon.taking then return end
    
    addon.Utility.Debug("Event_MoneyUpdate(" .. tostring(eventCode) .. "," .. tostring(newMoney) .. "," 
        .. tostring(oldMoney) .. "," .. tostring(reason) .. ")", debug)
    
    if reason ~= CURRENCY_CHANGE_REASON_MAIL or oldMoney <= newMoney then 
        addon.Utility.Debug("not mail reason or money change not negative", debug)
        return
    end
   
    -- Unfortunately, since this isn't a mail-specific event 
    -- (thanks ZOS for not providing one), it doesn't have a mailId parameter, 
    -- so we kind of kludge it by using C.O.D. amount and assuming first-in-first-out
    local goldChanged = oldMoney - newMoney
    local mailIdString, codMail = addon.Utility.GetCodMailByGoldChangeAmount(goldChanged)
    
    -- This gold removal event is unrelated to C.O.D. mail. Exit.
    if not codMail then
        addon.Utility.Debug("did not find any mail items with a COD amount of "..tostring(goldChanged), debug)
        return
    end
    
    -- Stop take attachments retries
    self:UnregisterForUpdate(EVENT_MONEY_UPDATE)
    
    -- This is a C.O.D. payment, so trigger a mail delete if all items have been
    -- removed from the mail already.
    addon.Utility.Debug("COD amount of " .. tostring(goldChanged) .. " paid " .. mailIdString, debug)
    local waitingForItems
    if addon.awaitingAttachments[mailIdString] then
        waitingForItems = table.remove(addon.awaitingAttachments[mailIdString])
    end
    if waitingForItems then 
        addon.Utility.Debug("still waiting for items. exiting.", debug)
    else
        addon.Delete:ByMailId(codMail.mailId)
    end
end

function Events:RegisterForUpdate(eventCode, timeout, callback)
    local updateKey = self.updateKeys[eventCode] or self.handlerNames[eventCode]
    EVENT_MANAGER:RegisterForUpdate(addon.name .. ".Events." .. updateKey, timeout, callback)
end

function Events:UnregisterAllForUpdate(eventCode)
    local unregistered = {}
    for eventCode, handlerName in pairs(self.handlerNames) do
        local updateKey = self.updateKeys[eventCode] or handlerName
        if not unregistered[updateKey] then
            EVENT_MANAGER:UnregisterForUpdate(self.updateKeyPrefix .. updateKey)
        end
        unregistered[updateKey] = true
    end
end

function Events:UnregisterForUpdate(eventCode)
    local updateKey = self.updateKeys[eventCode] or self.handlerNames[eventCode]
    EVENT_MANAGER:UnregisterForUpdate(self.updateKeyPrefix .. updateKey)
end

function exitMailNodeControl(node)
    ZO_MailInboxRow_OnMouseExit(node:GetControl())
end

addon.Events = Events:New()
