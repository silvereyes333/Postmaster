--[[   
 
    Take All
    
  ]]

local addon = Postmaster
local class = addon.classes
local debug = false

class.TakeAllGamepad = addon.classes.Keybind:Subclass()

function class.TakeAllGamepad:New(...)
    return addon.classes.Keybind.New(self, ...)
end

function class.TakeAllGamepad:Initialize()
    self.name = addon.name .. "KeybindTakeAllGamepad"
    self.keybind = "UI_SHORTCUT_SECONDARY"
    self.take =  addon.Utility.KeybindGetDescriptor(MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor, "UI_SHORTCUT_PRIMARY")
    self.keyboardKeybind = addon.keybinds.keyboard.TakeAll
    addon.classes.Keybind.Initialize(self)
end

function class.TakeAllGamepad:Callback()
    -- TODO: move to shared function with the keyboard TakeAll.lua
    addon.Utility.Debug("class.TakeAllGamepad:Callback()", debug)
    if addon:IsBusy() then return end
    if self:CanTakeSelectedMail() then
        addon.Utility.Debug("Selected mail can be taken by Take All. Taking.", debug)
        addon.taking    = true
        addon.takingAll = true
        self:TakeOrDeleteSelected()
    elseif self:SelectNext() then
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
function class.TakeAllGamepad:CanTakeSelectedMail()
    -- TODO: move to shared function with the keyboard TakeAll.lua
    local selectedMailData = addon.Utility.GamepadGetSelectedMailData()
    if selectedMailData
       and self.keyboardKeybind:CanTake(selectedMailData) 
    then 
        return true 
    end
end

function class.TakeAllGamepad:GetName()
    return GetString(SI_LOOT_TAKE_ALL)
end

--[[ Gets the next highest-priority mail data instance that Take All can take ]]
function class.TakeAllGamepad:GetNext()
    local data, index = addon.Utility.GetMailData()
    for listIndex, item in ipairs(data) do
        item = item[index]
        if self.keyboardKeybind:CanTake(item) then
            addon.Utility.Debug("TakeAllGamepad:GetNext() returning mail id " .. tostring(item.mailId), debug)
            return item, listIndex
        end
    end
    addon.Utility.Debug("TakeAllGamepad:GetNext() returning nil", debug)
end

function class.TakeAllGamepad:GamepadGetMailReadCallback(retries)
    -- TODO: move to shared function with the keyboard TakeAll.lua
    return function()
        addon.Events:UnregisterForUpdate(EVENT_MAIL_READABLE)
        addon.Utility.Debug("class.TakeAllGamepad:GamepadGetMailReadCallback(" .. tostring(retries) .. ")", debug)
        retries = retries - 1
        if retries < 0 then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_READ_FAILED)
            addon:Reset()
        else
            self:GamepadMailRead(retries)
        end
    end
end

function class.TakeAllGamepad:GamepadMailRead(retries)
        addon.Utility.Debug("class.TakeAllGamepad:GamepadMailRead(" .. tostring(retries) .. ")", debug)
    
    if not retries then
        retries = PM_MAIL_READ_MAX_RETRIES
    end
    
    -- If there exists another message in the inbox that has attachments, select it. otherwise, clear the selection.
    local nextMailData, nextMailIndex = self:GetNext()
    
    -- TODO: Figure out why this doesn't work right
    
    if nextMailData then
        addon.Events:RegisterForUpdate(EVENT_MAIL_READABLE, PM_MAIL_READ_TIMEOUT_MS, self:GamepadGetMailReadCallback(retries) )
        addon.Utility.Debug("MAIL_MANAGER_GAMEPAD.inbox.mailList:SetSelectedIndex(" .. tostring(nextMailIndex) .. ")", debug)
        MAIL_MANAGER_GAMEPAD.inbox.mailList:SetSelectedIndex(nextMailIndex)
    end
    return nextMailData
end

--[[ Selects the next highest-priority mail data instance that Take All can take ]]
function class.TakeAllGamepad:SelectNext()
    -- Don't need to get anything. The current selection already has attachments.
    if self:CanTakeSelectedMail() then return true end
    
    local nextMailData = self:GamepadMailRead()
    if nextMailData then
        return true
    end
end

--[[ Takes attachments from the selected (readable) mail if they exist, or 
     deletes the mail if it has no attachments. ]]
function class.TakeAllGamepad:TakeOrDeleteSelected()
    addon.Utility.Debug("class.TakeAllGamepad:TakeOrDeleteSelected()", debug)
    if self:TryCodMail() then return end
    
    local mailData = addon.Utility.GamepadGetSelectedMailData()
    
    -- Get the latest data, in case it has changed
    ZO_MailInboxShared_PopulateMailData(mailData, mailData.mailId)
    
    -- TODO: move to shared function with the keyboard TakeAll.lua
    local hasAttachments = (mailData.attachedMoney and mailData.attachedMoney > 0)
      or (mailData.numAttachments and mailData.numAttachments > 0)
    if hasAttachments then
        addon.Utility.Debug("Taking attachments for active mail id " .. tostring(mailData.mailId) .. ", isReadInfoReady = " .. tostring(mailData.isReadInfoReady), debug)
        addon.taking = true
        self.take.callback()
    else
        -- If all attachments are gone, remove the message
        addon.Utility.Debug("Deleting "..tostring(mailData.mailId), debug)
        
        -- Delete the mail
        addon.Delete:ByMailId(mailData.mailId)
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