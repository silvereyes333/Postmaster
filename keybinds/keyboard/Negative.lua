--[[   
 
    Return to sender - OR - Cancel take all, depending on context 
    
  ]]

local addon = Postmaster
local debug = false
local delete = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_NEGATIVE")
local returnToSender = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_SECONDARY")

local Negative = addon.classes.Keybind:Subclass()

function Negative:New(...)
    return addon.classes.Keybind.New(self)
end

function Negative:Initialize()
    self.name = addon.name .. "KeybindNegative"
    self.keybind = "UI_SHORTCUT_NEGATIVE"
    self.delete = delete
    self.returnToSender = returnToSender
    addon.classes.Keybind.Initialize(self)
end

function Negative:Callback()
    if addon.taking then 
        -- Abort take all command
        if addon.takingAll then
            addon:Reset()
        end
    -- Return to sender when not in the middle of a take all
    elseif addon.settings.keybinds.enable then
        if returnToSender.visible() then
            returnToSender.callback()
        end
    elseif delete.visible() then
        delete.callback()
    end
end

function Negative:GetName()
    if addon.takingAll then
        return GetString(SI_CANCEL)
    end
    if addon.settings.keybinds.enable then
        if returnToSender.visible() then
            return returnToSender.name
        end
    else
        if delete.visible() then
            return delete.name
        end
    end
    return GetString(SI_CANCEL)
end

function Negative:Visible()
    if addon.takingAll then return true end
    if addon:IsBusy() then return false end
    if MailR and MailR.IsMailIdSentMail(MAIL_INBOX.mailId) then
        return false
    end
    if addon.settings.keybinds.enable then
        addon.Utility.Debug("Negative:Visible() is using base game return to sender visibility of " .. tostring(returnToSender.visible()), debug)
        return returnToSender.visible()
    else
        addon.Utility.Debug("Negative:Visible() is using base game delete visibility of " .. tostring(delete.visible()), debug)
        return delete.visible()
    end
end

addon.keybinds.keyboard.Negative = Negative:New()