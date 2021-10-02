--[[   
 
    Base game return to sender keybind, but hidden during Take All by Subject
    and Take all by Sender.
    
  ]]


local addon = Postmaster
local debug = false
local returnToSender = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_SECONDARY")

local ReturnToSender = addon.classes.OriginalKeybind:Subclass()

function ReturnToSender:New()
    return addon.classes.OriginalKeybind.New(self, returnToSender)
end

function ReturnToSender:Initialize(...)
    self.name = addon.name .. "KeybindBaseGameReturnToSender"
    addon.classes.OriginalKeybind.Initialize(self, ...)
end

addon.keybinds.basegame.ReturnToSender = ReturnToSender:New()