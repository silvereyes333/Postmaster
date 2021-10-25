--[[   
 
    Take and Delete or just Delete, depending on if the current mail has attachments or not.
    
  ]]

local addon = Postmaster
local debug = false
local delete = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_NEGATIVE")
local take = addon.Utility.KeybindGetDescriptor(MAIL_INBOX.selectionKeybindStripDescriptor, "UI_SHORTCUT_PRIMARY")

local TakeAndDelete = addon.classes.Keybind:Subclass()

function TakeAndDelete:New(...)
    return addon.classes.Keybind.New(self)
end

function TakeAndDelete:Initialize()
    self.name = addon.name .. "KeybindTakeAndDelete"
    self.keybind = "UI_SHORTCUT_PRIMARY"
    addon.classes.Keybind.Initialize(self)
end

function TakeAndDelete:Callback()
    if addon:IsBusy() then return end
    if delete.visible()
       or (MailR and MailR.IsMailIdSentMail(MAIL_INBOX.mailId))
    then
        addon.Utility.Debug("deleting mail id "..tostring(MAIL_INBOX.mailId), debug)
        delete.callback()
        return
    end
    
    local mailData = addon.Utility.KeyboardGetOpenData()
    if self:CanTake(mailData) then
        addon.taking = true
    end
    take.callback()
end

--[[ True if the given mail can be taken by Take operations according
     to current options panel criteria. ]]
function TakeAndDelete:CanTake(mailData)
  
    -- Exclude any items that we've already read attachmnents for that we know
    -- contain only unique items that are already in our backpack.
    if addon.Utility.MailContainsOnlyUniqueConflictAttachments(mailData.mailId) then
        return false
    end
  
    return addon.Utility.CanTake(mailData, {
        ["codTake"]           = addon.settings.quickTakeCodTake,
        ["codGoldLimit"]      = addon.settings.quickTakeCodGoldLimit,
        ["reservedSlots"]     = 0,
        ["systemAttached"]    = addon.settings.quickTakeSystemAttached,
        ["systemHireling"]    = addon.settings.quickTakeSystemHireling,
        ["systemGuildStoreSales"]  = addon.settings.quickTakeSystemGuildStoreSales,
        ["systemGuildStoreItems"]  = addon.settings.quickTakeSystemGuildStoreItems,
        ["systemPvp"]         = addon.settings.quickTakeSystemPvp,
        ["systemUndaunted"]   = addon.settings.quickTakeSystemUndaunted,
        ["systemOther"]       = addon.settings.quickTakeSystemOther,
        ["playerReturned"]    = addon.settings.quickTakePlayerReturned,
        ["playerAttached"]    = addon.settings.quickTakePlayerAttached,
        ["systemDeleteEmpty"] = true,
        ["playerDeleteEmpty"] = true,
    })
end

function TakeAndDelete:GetName()
    if delete.visible() or
       (MailR and MailR.IsMailIdSentMail(addon.mailId))
    then
        return delete.name
    end
    
    if self:CanTake(addon.Utility.KeyboardGetOpenData()) then
        return GetString(SI_LOOT_TAKE)
    else
        return take.name
    end
end

function TakeAndDelete:Visible()
    if addon:IsBusy() then return false end
    
    local mailId = MAIL_INBOX:GetOpenMailId()
    if not mailId then
        return false
    end
    
    -- Exclude any items that we've already read attachmnents for that we know
    -- contain only unique items that are already in our backpack.
    if addon.Utility.MailContainsOnlyUniqueConflictAttachments(mailId) then
        return false
    end
    
    return true
end

addon.keybinds.keyboard.TakeAndDelete = TakeAndDelete:New()