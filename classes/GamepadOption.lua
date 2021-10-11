--[[   
 
    Base gamepad extra option menu entry class
    
  ]]

local addon = Postmaster
local classes = addon.classes
local debug = false
local closure

classes.GamepadOption = ZO_Object:Subclass()

function classes.GamepadOption:New(...)
    local instance = ZO_Object.New(self)
    instance.name = addon.name .. "GamepadOption"
    return instance
end

function classes.GamepadOption:CreateEntryData()
    local option = ZO_GamepadEntryData:New(self:GetName())
    option.selectedCallback = closure(self, self.SelectedCallback)
    option.selectedNameColor = closure(self, self.SelectedNameColor)
    return option
end

function classes.GamepadOption:GetName()
    -- override
end

function classes.GamepadOption:SelectedCallback()
    -- override
end

function classes.GamepadOption:SelectedNameColor()                           
    return ZO_SELECTED_TEXT
end

function closure(self, callback)
    return function(...)
        return callback(self, ...)
    end
end