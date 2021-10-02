--[[ 
     Scans the inbox for any player messages starting with RTS, BOUNCE or RETURN
     in the subject, and automatically returns them to sender, if so configured ]]
     
local addon = Postmaster
local debug = false

-- Singleton class
local AutoReturn = ZO_InitializingObject:Subclass()

function AutoReturn:Initialize()
    self.running = false
    
    -- Mail ids that have been auto-returned, but not yet removed
    self.pendingMailIds = {}
end

function AutoReturn:ClearPendingMailId(mailId)
    local mailId64 = zo_getSafeId64Key(mailId)
    if self.pendingMailIds[mailId64] then
        self.pendingMailIds[mailId64] = nil
        return true
    end
end

function AutoReturn:IsRunning()
    return self.running
end

function AutoReturn:Run()
    if not addon.settings.bounce or not addon.Events:IsInboxUpdated() or addon:IsBusy() then
        return
    end
    
    self.running = true
    local data, mailDataIndex = addon.Utility.GetMailData()
    local refresh = false
    for _,entry in pairs(data) do
        local mailData = mailDataIndex and entry[mailDataIndex] or entry
        if mailData and mailData.mailId and not mailData.fromCS 
           and not mailData.fromSystem and mailData.codAmount == 0 
           and (mailData.numAttachments > 0 or mailData.attachedMoney > 0)
           and not mailData.returned
           and addon.Utility.StringMatchFirstPrefix(zo_strupper(mailData.subject), PM_BOUNCE_MAIL_PREFIXES) 
        then
            local mailId64 = zo_getSafeId64Key(mailData.mailId)
            self.pendingMailIds[mailId64] = true
            ReturnMail(mailData.mailId)
            refresh = true
            addon.Utility.Print(zo_strformat(GetString(SI_PM_BOUNCE_MESSAGE), mailData.senderDisplayName))
        end
    end
    
    -- Don't run again until the inbox is updated again
    addon.Events:SetInboxUpdated(false)
    self.running = false
    
    if refresh then
        if IsInGamepadPreferredMode() then
            MAIL_MANAGER_GAMEPAD.inbox:RefreshMailList()
        else
            MAIL_INBOX:RefreshData()
        end
    end
end

addon.AutoReturn = AutoReturn:New()