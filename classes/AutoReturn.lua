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
    self.queuedMailIds = {}
end

function AutoReturn:DequeueMailId(mailId)
    addon.Utility.Debug("AutoReturn:DequeueMailId(" .. tostring(mailId) .. ")", debug)
    local mailId64 = self:IsMailIdQueued(mailId)
    if mailId64 then
        local senderName = self.queuedMailIds[mailId64]
        addon.Utility.Print(zo_strformat(GetString(SI_PM_BOUNCE_MESSAGE), senderName))
        self.queuedMailIds[mailId64] = nil
        return true
    end
end

function AutoReturn:IsMailIdQueued(mailId)
    local mailId64 = zo_getSafeId64Key(mailId)
    if self.queuedMailIds[mailId64] then
        addon.Utility.Debug("AutoReturn:IsMailIdQueued(" .. tostring(mailId) .. ") = " .. mailId64, debug)
        return mailId64
    end
end

function AutoReturn:IsRunning()
    return self.running
end

function AutoReturn:QueueAndReturn()
    addon.Utility.Debug("AutoReturn:QueueAndReturn()", debug)
    if self:IsRunning() or not addon.settings.bounce or not addon.Events:IsInboxUpdated() or addon.taking or addon.takingAll or not SCENE_MANAGER:IsShowing("mailInbox") then
        return
    end
    
    self.running = true
    local data, mailDataIndex = addon.Utility.GetMailData()
    for _,entry in pairs(data) do
        local mailData = mailDataIndex and entry[mailDataIndex] or entry
        if mailData and mailData.mailId and not mailData.fromCS 
           and not mailData.fromSystem and mailData.codAmount == 0 
           and (mailData.numAttachments > 0 or mailData.attachedMoney > 0)
           and not mailData.returned
           and addon.Utility.StringMatchFirstPrefix(zo_strupper(mailData.subject), PM_BOUNCE_MAIL_PREFIXES) 
        then
            local mailId64 = zo_getSafeId64Key(mailData.mailId)
            self.queuedMailIds[mailId64] = mailData.senderDisplayName
        end
    end
    self:ReturnNext(true)
end

function AutoReturn:ReturnNext(doNotRefresh)
    addon.Utility.Debug("AutoReturn:ReturnNext(" .. tostring(doNotRefresh) .. ")", debug)
    local returnMailIdStr = next(self.queuedMailIds)
    if returnMailIdStr then
        local mailId = StringToId64(returnMailIdStr)
        addon.Utility.Debug("Calling ReturnMail(" .. tostring(mailId) .. ")", debug)
        ReturnMail(mailId)
    else
        addon.Events:SetInboxUpdated(false)
        self.running = false
        addon.Utility.Debug("AutoReturn is no longer running.", debug)
        if doNotRefresh then
            return
        end
        addon.Utility.Debug("Refreshing mail list.", debug)
        if IsInGamepadPreferredMode() then
            MAIL_MANAGER_GAMEPAD.inbox:RefreshMailList()
        else
            MAIL_INBOX:RefreshData()
        end
    end
end

addon.AutoReturn = AutoReturn:New()