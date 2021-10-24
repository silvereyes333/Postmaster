--[[ 
    ===================================
           KEYBOARD KEYBINDS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false

-- Singleton class
local KeyboardKeybinds = ZO_Object:Subclass()

function KeyboardKeybinds:New()
    return ZO_Object.New(self)
end

--[[ Saves the original keyboard UI inbox keybinds and replaces them with our
     custom ones. ]]
function KeyboardKeybinds:Initialize()
    self.original = MAIL_INBOX.selectionKeybindStripDescriptor
            
    -- Set up return to sender keybind that hides during take all
    local originalTakeAttachmentsDescriptor =
        addon.Utility.KeybindGetDescriptor(self.original, "UI_SHORTCUT_PRIMARY")
    self.takeAttachments =
        addon.classes.OriginalKeybind:New(originalTakeAttachmentsDescriptor)
            
    -- Set up return to sender keybind that hides during take all
    local originalReturnToSenderDescriptor =
        addon.Utility.KeybindGetDescriptor(self.original, "UI_SHORTCUT_SECONDARY")
    self.returnToSender =
        addon.classes.OriginalKeybind:New(originalReturnToSenderDescriptor)
    
    -- Set up reply keybind that hides during take all
    local originalReplyDescriptor =
        addon.Utility.KeybindGetDescriptor(self.original, "UI_SHORTCUT_TERTIARY")
    self.reply =
        addon.classes.OriginalKeybind:New(originalReplyDescriptor)
    
    self:Update()
end

--[[ Updates the keyboard keybind strip with our custom keybinds ]]
function KeyboardKeybinds:Update()
    
    -- If Take, Take All and Take by Subject / Take by Sender are all disabled,
    -- use the original keybinds, not Postmaster ones.
    if not addon.settings.keybinds.enable 
       and (not addon.settings.keybinds.quaternary 
            or addon.settings.keybinds.quaternary == "")
    then
        MAIL_INBOX.selectionKeybindStripDescriptor = self.original
        return
    end
    
    -- Keybind instances to
    local keybinds;
    
    -- Take / Take All are enabled
    if addon.settings.keybinds.enable then
        keybinds = { 
            addon.keybinds.keyboard.TakeAndDelete,
            addon.keybinds.keyboard.TakeAll
        }
    
    -- Base game keybinds, when Take / Take All are disabled
    else
        keybinds = { 
            self.returnToSender,
            self.reply
        }
    end
    
    -- Next, add the negative keybind, for Cancel functionality.
    -- This is necessary, since we will only reach this point if either Take All or
    -- Take All by Subject / Sender is enabled, both of which need Cancel.
    -- Appear as Delete when Take / Take All are disabled and Return to Sender when
    -- Take / Take All are enabled.
    table.insert(keybinds, addon.keybinds.keyboard.Negative)
    
    if not addon.settings.keybinds.enable then
        table.insert(keybinds, self.takeAttachments)
    end
    
    -- Add the Take All by Subject / Take All by Sender keybind, if enabled.
    if addon.settings.keybinds.quaternary and addon.settings.keybinds.quaternary ~= "" then
        table.insert(keybinds, addon.keybinds.keyboard.Quaternary)
    end
    
    -- Keybind descriptors that will override the original keybinds
    local keybindGroup = {
        alignment = self.original.alignment
    }
    
    -- Add keybind descriptors to group
    for _, keybind in ipairs(keybinds) do
        table.insert(keybindGroup, keybind:GetDescriptor())
    end
    
    -- Point any additional existing keybinds that we haven't mapped already to
    -- the OriginalKeybind instances.  This will cause them to be hidden during Take All,
    -- Take All by Subject and Take All by Sender.
    for _, originalDescriptor in ipairs(self.original) do
        local existing = addon.Utility.KeybindGetDescriptor(keybindGroup, originalDescriptor.keybind)
        if not existing then
            local keybind = addon.classes.OriginalKeybind:New(originalDescriptor)
            table.insert(keybinds, keybind)
            local descriptor = keybind:GetDescriptor()
            table.insert(keybindGroup, descriptor)
        end
    end
    
    -- Overwrite the keybind strip for the mouse/keyboard UI inbox
    MAIL_INBOX.selectionKeybindStripDescriptor = keybindGroup
    self.keybinds = keybinds
end

addon.KeyboardKeybinds = KeyboardKeybinds:New()