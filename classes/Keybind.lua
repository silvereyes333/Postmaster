--[[   
 
    Base keybind class
    
  ]]

local addon = Postmaster
local class = addon.classes
local debug = false
local closure

class.Keybind = ZO_Object:Subclass()

function class.Keybind:New(...)
    local instance = ZO_Object.New(self)
    instance.name = addon.name .. "Keybind"
    instance:Initialize(...)
    return instance
end

function class.Keybind:Initialize()
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

function class.Keybind:Callback()
    -- override
end

function class.Keybind:GetDescriptor()
    return self.descriptor
end

function class.Keybind:GetName()
    -- override
end

function class.Keybind:GetOrder()
    -- override
end

function class.Keybind:GetSound()
    -- override
end

function class.Keybind:Visible()
    -- override
end

function closure(self, callback)
    return function(...)
        return callback(self, ...)
    end
end