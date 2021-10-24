--[[ 
    ===================================
            SECURE POSTHOOKS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false

-- Singleton class
local SecurePostHooks = ZO_Object:Subclass()

function SecurePostHooks:New()
    return ZO_Object.New(self)
end

--[[ Wire up all posthook handlers ]]
function SecurePostHooks:Initialize()
    SecurePostHook(MAIL_MANAGER_GAMEPAD.inbox, "RefreshMailList", self:Closure(self.GamepadInboxScrollListRefreshData))
    SecurePostHook(MAIL_INBOX, "RefreshData", self:Closure(self.KeyboardInboxScrollListRefreshData))
end

function SecurePostHooks:Closure(fn)
    return function(...)
        return fn(self, ...)
    end
end

--[[ Runs after the gamepad inbox scroll list's data refreshes. Used to trigger automatic mail return. ]]
function SecurePostHooks:GamepadInboxScrollListRefreshData(inbox, scrollList)
    addon.Utility.Debug("SecurePostHooks:GamepadInboxScrollListRefreshData()", debug)
    if not addon:IsBusy() then
        addon.AutoReturn:QueueAndReturn()
    end
end
--[[ Runs after the keyboard inbox scroll list's data refreshes. Used to trigger automatic mail return. ]]
function SecurePostHooks:KeyboardInboxScrollListRefreshData(inbox, scrollList)
    addon.Utility.Debug("SecurePostHooks:KeyboardInboxScrollListRefreshData()", debug)
    if not addon:IsBusy() then
        addon.AutoReturn:QueueAndReturn()
    end
    KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
end

addon.SecurePostHooks = SecurePostHooks:New()