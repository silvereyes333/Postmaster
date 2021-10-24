--[[   
 
    Take All
    
  ]]

local addon = Postmaster
local class = addon.classes
local debug = false
local SKIP_SELECTED = true

class.TakeAllGamepad = addon.classes.Keybind:Subclass()

function class.TakeAllGamepad:New(...)
    return addon.classes.Keybind.New(self, ...)
end

function class.TakeAllGamepad:Initialize()
    self.name = addon.name .. "KeybindTakeAllGamepad"
    self.keybind = "UI_SHORTCUT_SECONDARY"
    self.take =  addon.Utility.KeybindGetDescriptor(MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor, "UI_SHORTCUT_PRIMARY")
    self.keyboardKeybind = addon.keybinds.keyboard.TakeAll
    self.readQueue = {}
    addon.classes.Keybind.Initialize(self)
end

function class.TakeAllGamepad:Callback()
    -- TODO: move to shared function with the keyboard TakeAll.lua
    addon.Utility.Debug("class.TakeAllGamepad:Callback()", debug)
    
    if addon:IsBusy() then return end
    
    ZO_ClearTable(self.readQueue)
    
    local canTake, mailData = self:CanTakeSelectedMail()
    if canTake then
        addon.Utility.Debug("Selected mail id " .. tostring(mailData.mailId) .. " can be taken by Take All. Taking.", debug)
        addon.taking    = true
        addon.takingAll = true
        self:DequeueReadRequest(mailData.mailId, true)
        
    elseif self:SelectNext(mailData and mailData.mailId, SKIP_SELECTED) then
        addon.Utility.Debug("Getting next mail with attachments", debug)
        addon.taking    = true
        addon.takingAll = true
        -- will call the take or delete callback when the message is read
        
    else
        addon.Utility.Debug("Selected mail cannot be taken, nor can any others.", debug)
    end
end

--[[ True if the currently-selected mail can be taken by Take All operations 
     according to current options panel criteria. ]]
function class.TakeAllGamepad:CanTakeSelectedMail(excludeMailId)
    -- TODO: move to shared function with the keyboard TakeAll.lua
    local selectedMailData = addon.Utility.GamepadGetSelectedMailData()
    if selectedMailData and self.keyboardKeybind:CanTake(selectedMailData, excludeMailId) then 
        addon.Utility.Debug("TakeAllGamepad:CanTakeSelectedMail() for mail id " .. tostring(selectedMailData.mailId) .. " = true", debug)
        return true, selectedMailData 
    end
    return nil, selectedMailData
end

--[[ If a given mail id has a queued read request, 
     takes attachments from the the related mail message, if they exist.
     Deletes the mail if it has no attachments.
     Causes the mail id to be removed from the read queue. ]]
function class.TakeAllGamepad:DequeueReadRequest(mailId, force)
    
    addon.Utility.Debug("class.TakeAllGamepad:DequeueReadRequest(" .. tostring(mailId) .. ", " .. tostring(force) .. ")", debug)
    
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
    
    -- Get the latest data, in case it has changed
    ZO_MailInboxShared_PopulateMailData(mailData, mailId)
    
    -- TODO: move to shared function with the keyboard TakeAll.lua
    local hasAttachments = (mailData.attachedMoney and mailData.attachedMoney > 0)
      or (mailData.numAttachments and mailData.numAttachments > 0)
    if hasAttachments then
        addon.Utility.Debug("Taking attachments for active mail id " .. tostring(mailId) .. ", isReadInfoReady = " .. tostring(mailData.isReadInfoReady), debug)
        addon.taking = true
        self.take.callback()
    else
        -- If all attachments are gone, remove the message
        addon.Utility.Debug("Deleting "..tostring(mailId), debug)
        
        -- Delete the mail
        addon.Delete:ByMailId(mailId)
    end
end

function class.TakeAllGamepad:GetName()
    return GetString(SI_LOOT_TAKE_ALL)
end

--[[ Gets the next highest-priority mail data instance that Take All can take ]]
function class.TakeAllGamepad:GetNext(excludeMailId)
    local dataList, dataKey = addon.Utility.GetMailData()
    for index, dataEntry in ipairs(dataList) do
        local mailData = dataEntry[dataKey]
        if self.keyboardKeybind:CanTake(mailData, excludeMailId) then
            if dataEntry.canSelect == false then
                addon.Utility.Debug("TakeAllGamepad:GetNext() could not return mail id " .. tostring(mailData.mailId) .. " because it is marked as unselectable", debug)
            else
                addon.Utility.Debug("TakeAllGamepad:GetNext() returning mail id " .. tostring(mailData.mailId), debug)
                return mailData, index
            end
        end
    end
    addon.Utility.Debug("TakeAllGamepad:GetNext() returning nil", debug)
end

function class.TakeAllGamepad:GamepadGetMailReadCallback(retries, excludeMailId, calledFromEvent)
    -- TODO: move to shared function with the keyboard TakeAll.lua
    return function()
        addon.Events:UnregisterForUpdate(EVENT_MAIL_READABLE)
        addon.Utility.Debug("class.TakeAllGamepad:GamepadGetMailReadCallback(" .. tostring(retries) .. ")", debug)
        retries = retries - 1
        if retries < 0 then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_READ_FAILED)
            addon:Reset()
        else
            self:GamepadMailRead(retries, excludeMailId, calledFromEvent)
        end
    end
end

function class.TakeAllGamepad:GamepadMailRead(retries, excludeMailId, calledFromEvent)
        addon.Utility.Debug("class.TakeAllGamepad:GamepadMailRead(" .. tostring(retries) .. ")", debug)
    
    if not retries then
        retries = PM_MAIL_READ_MAX_RETRIES
    end
    
    -- If there exists another message in the inbox that has attachments, select it. otherwise, clear the selection.
    local nextMailData, nextMailIndex = self:GetNext(excludeMailId)
    
    if nextMailData then
      
        local mailIdStr = addon.Utility.GetMailIdString(nextMailData.mailId)
        self.readQueue[mailIdStr] = true
        
        -- On Gamepad, there's an event handler for mail removed events that automatically reloads the entire mail list.
        if calledFromEvent == EVENT_MAIL_REMOVED then
          
            addon.Utility.Debug("Called from legit EVENT_MAIL_REMOVED. Deferring gamepad mail id " .. tostring(nextMailData.mailId) .. " selection.", debug)
          
            -- Right before the mail list reload is committed, set the selected index to that matching the next mail id
            addon.Prehooks:SetDeferredSelectMailId(nextMailData.mailId)
            
        -- If this wasn't called from an actual mail remove event, then it was probably called from Delete:ByMailId() 
        -- when CanDelete() was false, in which case we need to select the mail ourselves
        elseif not calledFromEvent then
            addon.Events:RegisterForUpdate(EVENT_MAIL_READABLE, PM_MAIL_READ_TIMEOUT_MS, self:GamepadGetMailReadCallback(retries, excludeMailId, calledFromEvent) )
            addon.Utility.Debug("MAIL_MANAGER_GAMEPAD.inbox.mailList:SetSelectedIndexWithoutAnimation(" .. tostring(nextMailIndex) .. ")", debug)
            
            local list = MAIL_MANAGER_GAMEPAD.inbox.mailList
            list:SetSelectedIndexWithoutAnimation(nextMailIndex)
        end
    end
    return nextMailData
end

--[[ Selects the next highest-priority mail data instance that Take All can take ]]
function class.TakeAllGamepad:SelectNext(excludeMailId, skipSelected, calledFromEvent)
  
    -- Don't need to get anything. The current selection already has attachments.
    if not skipSelected and self:CanTakeSelectedMail(excludeMailId) then
        return true
    end
    
    local nextMailData = self:GamepadMailRead(PM_MAIL_READ_MAX_RETRIES, excludeMailId, calledFromEvent)
    if nextMailData then
        return true
    end
end

--[[ Bypasses the original "Take attachments" logic for C.O.D. mail during a
     Take All operation. ]]
function class.TakeAllGamepad:TryCodMail()
    if not addon.settings.takeAllCodTake then return end
    local mailData = addon.Utility.GamepadGetSelectedMailData()
    -- TODO: move to shared function with the keyboard TakeAll.lua
    if mailData.codAmount and mailData.codAmount > 0 then
        addon.taking = true
        addon.pendingAcceptCOD = true
        ZO_MailInboxShared_TakeAll(mailData.mailId)
        addon.pendingAcceptCOD = false
        return true
    end
end

function class.TakeAllGamepad:Visible()
    -- TODO: move to shared function with the keyboard TakeAll.lua
    if addon:IsBusy() or not self:GetNext() then
        return false
    end
    return true
end

-- Class is instantiated inside GamepadKeybinds.lua::OnInitializeKeybindDescriptors(inbox)