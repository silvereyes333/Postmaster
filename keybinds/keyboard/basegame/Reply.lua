--[[   
 
    Base game reply keybind, but hidden during Take All by Subject
    and Take all by Sender.
    
  ]]


local addon = Postmaster
local debug = false
local reply = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_TERTIARY")

local Reply = addon.classes.OriginalKeybind:Subclass()

function Reply:New()
    return addon.classes.OriginalKeybind.New(self, reply)
end

function Reply:Initialize(...)
    self.name = addon.name .. "KeybindBaseGameReply"
    self.reply = reply
    addon.classes.OriginalKeybind.Initialize(self, ...)
end

addon.keybinds.keyboard.basegame.Reply = Reply:New()