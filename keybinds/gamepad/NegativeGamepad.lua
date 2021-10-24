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
    else
        self.back.callback()
    end
end

function class.NegativeGamepad:GetName()
    if addon.takingAll then
        return GetString(SI_CANCEL)
    end
    return self.back.name
end

function class.NegativeGamepad:Visible()
    if addon.takingAll then return true end
    if addon:IsBusy() then return false end
    addon.Utility.Debug("NegativeGamepad:Visible() is using base game back visibility of " .. tostring(true), debug)
    return true
end

-- Class is instantiated inside GamepadKeybinds.lua::OnInitializeKeybindDescriptors(inbox)