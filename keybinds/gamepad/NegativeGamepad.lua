--[[   
 
    Back - OR - Cancel take all, depending on context 
    
  ]]

local addon = Postmaster
local debug = false
local class = addon.classes

class.NegativeGamepad = addon.classes.OriginalKeybind:Subclass()

function class.NegativeGamepad:New(...)
    return addon.classes.OriginalKeybind.New(self)
end

function class.NegativeGamepad:Initialize()
    self.name = addon.name .. "KeybindNegativeGamepad"
    self.back =  addon.Utility.KeybindGetDescriptor(MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor, "UI_SHORTCUT_NEGATIVE")
    addon.classes.OriginalKeybind.Initialize(self, self.back)
end

function class.NegativeGamepad:Callback()
    if addon.taking then 
        -- Abort take all command
        if addon.takingAll then
            addon:Reset()
        end
    elseif self.back.visible() then
        self.back.callback()
    end
end

function class.NegativeGamepad:GetName()
    if addon.takingAll then
        return GetString(SI_CANCEL)
    end
    if self.back.visible() then
        return self.back.name
    end
    return GetString(SI_CANCEL)
end

function class.NegativeGamepad:Visible()
    if addon.takingAll then return true end
    if addon:IsBusy() then return false end
    addon.Utility.Debug("NegativeGamepad:Visible() is using base game back visibility of " .. tostring(self.back.visible()), debug)
    return self.back.visible()
end

-- Class is instantiated inside GamepadKeybinds.lua::OnInitializeKeybindDescriptors(inbox)