--[[   
 
    Keybind class for pre-existing keybinds, both from the base game and other addons.
    
    This will wrap almost all original keybind functionality, but hide the keybind when
    Take All, Take All by Subject or Take All by Sender are running.
    
  ]]

local addon = Postmaster
local class = addon.classes
local debug = false

class.OriginalKeybind = class.Keybind:Subclass()

function class.OriginalKeybind:New(originalDescriptor)
    return class.Keybind.New(self, originalDescriptor)
end

function class.OriginalKeybind:Initialize(originalDescriptor)
    if originalDescriptor then
        self.originalDescriptor = originalDescriptor
        self.keybind = self.originalDescriptor.keybind
        class.Keybind.Initialize(self)
    end
end

function class.OriginalKeybind:Callback()
    if addon:IsBusy() then return end
    if not self.originalDescriptor then
        return
    end
    local callback = self.originalDescriptor.callback
    if not callback then
        return
    end
    self.originalDescriptor.callback()
end

function class.OriginalKeybind:GetName()
    if not self.originalDescriptor then
        return
    end
    return self.originalDescriptor.name
end

function class.OriginalKeybind:GetOrder()
    if not self.originalDescriptor then
        return
    end
    return self.originalDescriptor.order
end

function class.OriginalKeybind:GetSound()
    if not self.originalDescriptor then
        return
    end
    return self.originalDescriptor.sound
end

function class.OriginalKeybind:Visible() 
    if addon:IsBusy() then return end
    if not self.originalDescriptor then
        return false
    end
    local visible = self.originalDescriptor.visible
    if not visible then
        return false
    end
    return self.originalDescriptor.visible()
end