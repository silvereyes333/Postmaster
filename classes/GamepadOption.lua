--[[   
 
    Base gamepad extra option menu entry class
    
  ]]

local addon = Postmaster
local class = addon.classes
local debug = false
local closure

class.GamepadOption = ZO_Object:Subclass()

function class.GamepadOption:New(...)
    local instance = ZO_Object.New(self)
    instance.name = addon.name .. "GamepadOption"
    return instance
end

function class.GamepadOption:CreateEntryData()
    local option = ZO_GamepadEntryData:New(self:GetName())
    option.selectedCallback = closure(self, self.SelectedCallback)
    option.selectedNameColor = closure(self, self.SelectedNameColor)
    return option
end

function class.GamepadOption:GetName()
    -- override
end

function class.GamepadOption:SelectedCallback()
    -- override
end

function class.GamepadOption:SelectedNameColor()                           
    return ZO_SELECTED_TEXT
end

function closure(self, callback)
    return function(...)
        return callback(self, ...)
    end
end