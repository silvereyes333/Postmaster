--[[ 
    ===================================
             CALLBACK HANDLERS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false

-- Singleton class
local Callbacks = ZO_Object:Subclass()

function Callbacks:New()
    return ZO_Object.New(self)
end
  
--[[ Wire up all callback handlers ]]
function Callbacks:Initialize()
    MAIL_INBOX_SCENE:RegisterCallback("StateChange", self:CreateCallback("MailInboxStateChange"))
end

function Callbacks:CreateCallback(callbackName)
    return function(...)
        self[callbackName](self, ...)
    end
end

--[[ Raised whenever the inbox is shown or hidden. ]]
function Callbacks:MailInboxStateChange(oldState, newState)
    if IsInGamepadPreferredMode() then return end
    
    addon.Utility.Debug("Callbacks:MailInboxStateChange(" .. tostring(oldState) .. ", " .. tostring(newState) .. ")", debug)
    
    -- Inbox shown
    if newState == SCENE_SHOWN then
      
        -- Delete any mail that was requested to be deleted, but failed because the inbox hid before.
        -- Note, if this is true, AutoReturn:QueueAndReturn() will be run after it finishes.
        if addon.Delete:DeleteQueued() then
            return
        end
        
        -- If not deleting mail, then try auto returning mail
        if addon.AutoReturn:QueueAndReturn() then
            return
        end
    
    -- Inbox hidden
    -- Reset state back to default when inbox hidden, since most server events
    -- will no longer fire with the inbox closed.
    elseif newState == SCENE_HIDDEN then
    
        addon:Reset()
    end
end

addon.Callbacks = Callbacks:New()