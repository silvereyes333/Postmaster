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
    
    addon.keybinds.keyboard.TakeAll:Callback(true)
end

function Quaternary:GetFilterFieldValue(mailData)
    
    if not mailData then
        mailData = addon.Utility.KeyboardGetOpenData()
    end
    
    if not mailData or not mailData[addon.settings.keybinds.quaternary] then
        return
    end
    
    local filterFieldValue = zo_strlower(mailData[addon.settings.keybinds.quaternary])
    
    -- For subject filters, remove any RTS prefixes
    if addon.settings.keybinds.quaternary == "subject" then
        for _, bounceMailPrefix in ipairs(PM_BOUNCE_MAIL_PREFIXES) do
            bounceMailPrefix = zo_strlower(bounceMailPrefix)
            if filterFieldValue == bounceMailPrefix then
                filterFieldValue = ""
                break
            else
                filterFieldValue = string.gsub(filterFieldValue, "^" .. zo_strlower(bounceMailPrefix) .. " ", "")
            end
        end
    end
    
    return filterFieldValue
end

function Quaternary:GetName()
    if addon.settings.keybinds.quaternary == "subject" then
        return GetString(SI_PM_TAKE_ALL_BY_SUBJECT)
    end
    if addon.settings.keybinds.quaternary == "senderDisplayName" then
        return GetString(SI_PM_TAKE_ALL_BY_SENDER)
    end
end

function Quaternary:Visible()
    if not addon.settings.keybinds.quaternary
       or addon.settings.keybinds.quaternary == ""
       or addon:IsBusy()
    then
        return false
    end
    local filterFieldValue = self:GetFilterFieldValue()
    if not filterFieldValue then
        return false
    end
    addon.filterFieldValue = filterFieldValue
    local visible = addon.keybinds.keyboard.TakeAll:GetNext() ~= nil
    addon.filterFieldValue = nil
    return visible
end

addon.keybinds.keyboard.Quaternary = Quaternary:New()
