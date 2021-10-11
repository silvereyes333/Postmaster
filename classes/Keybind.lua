--[[   
 
    Base keybind class
    
  ]]

local addon = Postmaster
local classes = addon.classes
local debug = false
local closure

classes.Keybind = ZO_Object:Subclass()

function classes.Keybind:New(...)
    local instance = ZO_Object.New(self)
    instance.name = addon.name .. "Keybind"
    instance:Initialize(...)
    return instance
end

function classes.Keybind:Initialize()
    self.descriptor = {
        name = closure(self, self.GetName),
        keybind = self.keybind,
        callback = closure(self, self.Callback),
        order = closure(self, self.GetOrder),
        sound = closure(self, self.GetSound),
        visible = closure(self, self.Visible),
    }
    addon.Utility.Debug("Initialized keybind " .. tostring(self.name), debug)
end

function classes.Keybind:Callback()
    -- override
end

function classes.Keybind:GetDescriptor()
    return self.descriptor
end

function classes.Keybind:GetName()
    -- override
end

function classes.Keybind:GetOrder()
    -- override
end

function classes.Keybind:GetSound()
    -- override
end

function classes.Keybind:Visible()
    -- override
end

function closure(self, callback)
    return function(...)
        return callback(self, ...)
    end
end