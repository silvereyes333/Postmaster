--[[   
 
    Take All
    
  ]]

local addon = Postmaster
local debug = false
local filter

local TakeAllGamepad = addon.classes.Keybind:Subclass()

function TakeAllGamepad:New(...)
    return addon.classes.Keybind.New(self, ...)
end

function TakeAllGamepad:Initialize()
    self.name = addon.name .. "KeybindTakeAllGamepad"
    self.keybind = "UI_SHORTCUT_SECONDARY"
    self.take =  addon.Utility.KeybindGetDescriptor(MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor, "UI_SHORTCUT_NEGATIVE")
    self.keyboardKeybind = addon.keybinds.keyboard.TakeAll
    addon.classes.Keybind.Initialize(self)
end

function TakeAllGamepad:Callback()
    -- TODO: move to shared function with the keyboard TakeAll.lua
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
function TakeAllGamepad:CanTakeSelectedMail()
    -- TODO: move to shared function with the keyboard TakeAll.lua
    local selectedMailData = addon.Utility.GamepadGetSelectedMailData()
    if selectedMailData
       and self.keyboardKeybind:CanTake(selectedMailData) 
    then 
        return true 
    end
end

function TakeAllGamepad:GetName()
    return GetString(SI_LOOT_TAKE_ALL)
end

--[[ Gets the next highest-priority mail data instance that Take All can take ]]
function TakeAllGamepad:GetNext()
    local data, index = addon.Utility.GetMailData()
    for listIndex, item in ipairs(data) do
        item = item[index]
        if self:CanTake(item) then
            addon.Utility.Debug("TakeAllGamepad:GetNext() returning mail id " .. tostring(item.mailId), debug)
            return item, listIndex
        end
    end
    addon.Utility.Debug("TakeAllGamepad:GetNext() returning nil", debug)
end

function TakeAllGamepad:GamepadGetMailReadCallback(retries)
    -- TODO: move to shared function with the keyboard TakeAll.lua
    return function()
        addon.Events:UnregisterForUpdate(EVENT_MAIL_READABLE)
        retries = retries - 1
        if retries < 0 then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, SI_PM_READ_FAILED)
            addon:Reset()
        else
            self:GamepadMailRead(retries)
        end
    end
end

function TakeAllGamepad:GamepadMailRead(retries)
    
    if not retries then
        retries = PM_MAIL_READ_MAX_RETRIES
    end
    
    -- If there exists another message in the inbox that has attachments, select it. otherwise, clear the selection.
    local nextMailData, nextMailIndex = self:GetNext()
    if nextMailData then
        addon.Events:RegisterForUpdate(EVENT_MAIL_READABLE, PM_MAIL_READ_TIMEOUT_MS, self:GamepadGetMailReadCallback(retries) )
        MAIL_MANAGER_GAMEPAD.inbox.mailList:SetDefaultSelectedIndex(nextMailIndex)
        MAIL_MANAGER_GAMEPAD.inbox.mailList:Commit(true)
    end
    return nextMailData
end

--[[ Selects the next highest-priority mail data instance that Take All can take ]]
function TakeAllGamepad:SelectNext()
    -- Don't need to get anything. The current selection already has attachments.
    if self:CanTakeSelectedMail() then return true end
    
    local nextMailData = self:GamepadMailRead()
    if nextMailData then
        return true
    end
end

--[[ Takes attachments from the selected (readable) mail if they exist, or 
     deletes the mail if it has no attachments. ]]
function TakeAllGamepad:TakeOrDeleteSelected()
    if self:TryCodMail() then return end
    local mailData = addon.Utility.GamepadGetSelectedMailData()
    
    -- TODO: move to shared function with the keyboard TakeAll.lua
    local hasAttachments = (mailData.attachedMoney and mailData.attachedMoney > 0)
      or (mailData.numAttachments and mailData.numAttachments > 0)
    if hasAttachments then
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
function TakeAllGamepad:TryCodMail()
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

function TakeAllGamepad:Visible()
    -- TODO: move to shared function with the keyboard TakeAll.lua
    if addon:IsBusy() or not self:GetNext() then
        return false
    end
    return true
end

-- Class is instantiated inside GamepadKeybinds.lua::OnInitializeKeybindDescriptors(inbox)