--[[   
 
    Take and Delete or just Delete, depending on if the current mail has attachments or not.
    
  ]]

local addon = Postmaster
local class = addon.classes
local debug = false

class.TakeAndDeleteGamepad = addon.classes.Keybind:Subclass()

function class.TakeAndDeleteGamepad:New(...)
    return addon.classes.Keybind.New(self)
end

function class.TakeAndDeleteGamepad:Initialize()
    self.name = addon.name .. "KeybindTakeAndDeleteGamepad"
    self.keybind = "UI_SHORTCUT_PRIMARY"
    self.take =  addon.Utility.KeybindGetDescriptor(MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor, "UI_SHORTCUT_PRIMARY")
    self.delete =  addon.Utility.KeybindGetDescriptor(MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor, "UI_SHORTCUT_SECONDARY")
    self.keyboardKeybinds = addon.keybinds.keyboard
    addon.classes.Keybind.Initialize(self)
end

function class.TakeAndDeleteGamepad:Callback()
    if addon:IsBusy() then return end
    
    local mailData = addon.Utility.GamepadGetSelectedMailData()
    
    if self.delete.visible() then
        addon.Utility.Debug("deleting mail id " .. tostring(mailData.mailId), debug)
        self.delete.callback()
        return
    end
    
    -- TODO: inherit from shared class
    if self.keyboardKeybinds.TakeAndDelete:CanTake(mailData) then
        addon.taking = true
    end
    
    self.take.callback()
end

function class.TakeAndDeleteGamepad:GetName()
    if self.delete.visible()
    then
        return self.delete.name
    end
    
    -- TODO: inherit from shared class
    local mailData = addon.Utility.GamepadGetSelectedMailData()
    if self.keyboardKeybinds.TakeAndDelete:CanTake(mailData) then
        return GetString(SI_LOOT_TAKE)
    else
        return self.take.name
    end
end

function class.TakeAndDeleteGamepad:Visible()
    if addon:IsBusy() then return false end
    if self.take.visible() then return true end
    return self.delete.visible()
end

-- Class is instantiated inside GamepadKeybinds.lua::OnInitializeKeybindDescriptors(inbox)