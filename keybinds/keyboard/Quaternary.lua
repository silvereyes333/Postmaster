--[[   
 
    Take All by Subject or Take All by Sender, depending on configuration.
    
  ]]


local addon = Postmaster
local debug = false

local Quaternary = addon.classes.Keybind:Subclass()

function Quaternary:New(...)
    return addon.classes.Keybind.New(self)
end

function Quaternary:Initialize()
    self.name = addon.name .. "KeybindQuaternary"
    self.keybind = "UI_SHORTCUT_QUATERNARY"
    addon.classes.Keybind.Initialize(self)
end

function Quaternary:Callback()
    if not addon.settings.keybinds.quaternary or addon.settings.keybinds.quaternary == "" then
        return
    end
    
    local filterFieldValue = self:GetFilterFieldValue()
    
    if not filterFieldValue then
        return
    end
    
    addon.filterFieldValue = filterFieldValue
    addon.filterFieldKeybind = self
    
    addon.keybinds.keyboard.TakeAll:Callback()
end

function Quaternary:GetFilterFieldValue(mailData)
    
    if not mailData then
        mailData = addon.Utility.KeyboardGetOpenData()
    end
    
    if not mailData or not mailData[addon.settings.keybinds.quaternary] then
        return nil, mailData
    end
    
    local filterFieldValue = zo_strlower(mailData[addon.settings.keybinds.quaternary])
    
    -- For subject filters, remove any RTS prefixes
    if addon.settings.keybinds.quaternary == "subject" then
        filterFieldValue = addon.Utility.StringRemovePrefixes(filterFieldValue, PM_BOUNCE_MAIL_PREFIXES)
    end
    
    return filterFieldValue, mailData
end

function Quaternary:GetName()
    if addon.settings.keybinds.quaternary == "subject" then
        return GetString(SI_PM_TAKE_ALL_BY_SUBJECT)
    end
    if addon.settings.keybinds.quaternary == "senderDisplayName" then
        return GetString(SI_PM_TAKE_ALL_BY_SENDER)
    end
end

function Quaternary:IsDeleteEnabled()
    return addon.settings[self:GetDeleteSettingName()]
end

function Quaternary:GetDeleteSettingName()
    local filterFieldName = addon.settings.keybinds.quaternary
    return ZO_CachedStrFormat("takeAll<<C:1>>Delete", filterFieldName)
end

function Quaternary:Visible()
    if not addon.settings.keybinds.quaternary
       or addon.settings.keybinds.quaternary == ""
       or addon:IsBusy()
    then
        return false
    end
    local filterFieldValue, mailData = self:GetFilterFieldValue()
    if not filterFieldValue then
        addon.Utility.Debug(tostring(self.name) .. " current mail id " .. tostring(mailData and mailData.mailId) .. " has no '" .. tostring(addon.settings.keybinds.quaternary) .. "' field value. visible = false.", debug)
        return false
    end
    addon.filterFieldValue = filterFieldValue
    addon.filterFieldKeybind = self
    local visible = addon.keybinds.keyboard.TakeAll:GetNext() ~= nil
    addon.filterFieldValue = nil
    addon.filterFieldKeybind = nil
    return visible
end

addon.keybinds.keyboard.Quaternary = Quaternary:New()
