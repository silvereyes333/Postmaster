--[[   
 
    Take By Sender
    
  ]]

local addon = Postmaster
local debug = false

local OptionsGamepad = addon.classes.GamepadOption:Subclass()

function OptionsGamepad:New(...)
    local instance = addon.classes.GamepadOption.New(self)
    instance:Initialize(...)
    return instance
end

function OptionsGamepad:Initialize(filterFieldName, displayName)
    self.filterFieldName = filterFieldName
    self.displayName = displayName
end

function OptionsGamepad:GetFilterFieldValue(mailData)
    
    addon.Utility.Debug("class.OptionsGamepad:GetFilterFieldValue(mailData: { mailId: " 
        .. tostring(mailData and mailData.mailId) .. " }), self.filterFieldName = " 
        .. tostring(self.filterFieldName), debug)
    
    if not mailData then
        mailData = addon.Utility.GamepadGetSelectedMailData()
    end
    
    if not mailData or not mailData[self.filterFieldName] then
        return
    end
    
    local filterFieldValue = zo_strlower(mailData[self.filterFieldName])
    
    -- For subject filters, remove any RTS prefixes
    if self.filterFieldName == "subject" then
        filterFieldValue = addon.Utility.StringRemovePrefixes(filterFieldValue, PM_BOUNCE_MAIL_PREFIXES)
    end
    
    return filterFieldValue
end

function OptionsGamepad:GetName()
    return self.displayName
end

function OptionsGamepad:IsDeleteEnabled()
    return addon.settings[self:GetDeleteSettingName()]
end

function OptionsGamepad:GetDeleteSettingName()
    return ZO_CachedStrFormat("takeAll<<C:1>>Delete", self.filterFieldName)
end

function OptionsGamepad:SelectedCallback()
    
    addon.Utility.Debug("class.OptionsGamepad:Callback(), self.filterFieldName = " .. tostring(self.filterFieldName), debug)
    
    if addon:IsBusy() then
        return
    end
    
    local filterFieldValue = self:GetFilterFieldValue()
    
    if not filterFieldValue then
        return
    end
    
    addon.filterFieldValue = filterFieldValue
    addon.filterFieldKeybind = self
    
    -- Go back to main options list to display the cancel keybind
    MAIL_MANAGER_GAMEPAD.inbox:EnterMailList()
    
    addon.keybinds.gamepad.TakeAll:Callback()
end

addon.keybinds.gamepad.TakeBySubject =
  OptionsGamepad:New("subject", GetString(SI_PM_TAKE_ALL_BY_SUBJECT))

addon.keybinds.gamepad.TakeBySender =
  OptionsGamepad:New("senderDisplayName", GetString(SI_PM_TAKE_ALL_BY_SENDER))