--[[   
 
    Keybind class for pre-existing keybinds, both from the base game and other addons.
    
    This will wrap almost all original keybind functionality, but hide the keybind when
    Take All, Take All by Subject or Take All by Sender are running.
    
  ]]

local addon = Postmaster
local classes = addon.classes
local debug = false

classes.OriginalKeybind = classes.Keybind:Subclass()

function classes.OriginalKeybind:New(originalDescriptor)
    return classes.Keybind.New(self, originalDescriptor)
end

function classes.OriginalKeybind:Initialize(originalDescriptor)
    self.originalDescriptor = originalDescriptor
    self.keybind = self.originalDescriptor.keybind
    addon.classes.Keybind.Initialize(self)
end

function classes.OriginalKeybind:Callback()
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

function classes.OriginalKeybind:GetName()
    if not self.originalDescriptor then
        return
    end
    return self.originalDescriptor.name
end

function classes.OriginalKeybind:Visible() 
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