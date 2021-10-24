--[[ 
    ===================================
           KEYBOARD KEYBINDS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false
local alwaysVisible = function() return true end

-- Singleton class
local GamepadKeybinds = ZO_Object:Subclass()

function GamepadKeybinds:New()
    return ZO_Object.New(self)
end

--[[ Hooks the appropriate gamepad mail manager functions to be able to override keybinds. ]]
function GamepadKeybinds:Initialize()
    SecurePostHook(MAIL_MANAGER_GAMEPAD.inbox, "InitializeKeybindDescriptors", self:CreatePostHook(self.OnInitializeKeybindDescriptors))
    SecurePostHook(MAIL_MANAGER_GAMEPAD.inbox, "InitializeOptionsList", self:CreatePostHook(self.OnInitializeOptionsList))
end

function GamepadKeybinds:CreatePostHook(callback)
    return function(...)
        callback(self, ...)
    end
end

function GamepadKeybinds:OnInitializeKeybindDescriptors(inbox)
  
    self.original = inbox.mainKeybindDescriptor
    
    addon.keybinds.gamepad.Negative = addon.classes.NegativeGamepad:New()
    addon.keybinds.gamepad.TakeAll = addon.classes.TakeAllGamepad:New()
    addon.keybinds.gamepad.TakeAndDelete = addon.classes.TakeAndDeleteGamepad:New()
    
    -- Override keybind descriptors with our own
    self:Update()
end

function GamepadKeybinds:OnInitializeOptionsList(inbox)
    -- Add Take by Subject and Take by Sender to self.optionsList.
    -- By default, it supports reply, return to sender, and potentially report player in the future.
    
    local takeBySubjectEntryData = addon.keybinds.gamepad.TakeBySubject:CreateEntryData()
    inbox.optionsList:AddEntry("ZO_GamepadMenuEntryTemplate", takeBySubjectEntryData)

    local takeBySenderEntryData = addon.keybinds.gamepad.TakeBySender:CreateEntryData()
    inbox.optionsList:AddEntry("ZO_GamepadMenuEntryTemplate", takeBySenderEntryData)

    inbox.optionsList:Commit()
end

--[[ Updates the keyboard keybind strip with our custom keybinds ]]
function GamepadKeybinds:Update()
    
    -- Do nothing if gamepad keybinds haven't yet been initialized.
    if not self.original then
        return
    end
    
    -- Keybind instances to    
    local keybinds = {
        addon.keybinds.gamepad.Negative
    }
    
    -- Take / Take All are enabled
    if addon.settings.keybinds.enable then
        table.insert(keybinds, addon.keybinds.gamepad.TakeAndDelete)
        table.insert(keybinds, addon.keybinds.gamepad.TakeAll)
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
            -- Special workaround for Options hiding for system mail
            if descriptor.keybind == "UI_SHORTCUT_TERTIARY" then
                descriptor.visible = alwaysVisible
            end
            table.insert(keybindGroup, descriptor)
        end
    end
    
    -- Overwrite the keybind strip for the gamepad UI inbox
    MAIL_MANAGER_GAMEPAD.inbox.mainKeybindDescriptor = keybindGroup
    self.keybinds = keybinds
end

addon.GamepadKeybinds = GamepadKeybinds:New()