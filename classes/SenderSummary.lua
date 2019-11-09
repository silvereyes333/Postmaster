--[[ 
     A customized version of the List class from LibLootSummary
]]--

local addon = Postmaster
local class = addon.classes
local debug = false

class.SenderSummary = LibLootSummary.List:Subclass()

function class.SenderSummary:New(...)
    return LibLootSummary.List.New(self, ...)
end

function class.SenderSummary:SetSender(sender)
    self.sender = sender
end

--[[ Outputs a verbose summary of all loot and currency ]]
function class.SenderSummary:Print()
    local tagSuffix = self.chat.tagSuffix
    if self.sender then
        local sender = self.sender
        if not self.chat.tagColor then
            sender = addon.prefix .. sender .. addon.suffix
        end
        self.chat:SetTagSuffix(sender)
    end
    LibLootSummary.List.Print(self)
    self.chat:SetTagSuffix(tagSuffix)
end