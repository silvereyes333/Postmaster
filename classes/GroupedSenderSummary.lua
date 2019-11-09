
local addon = Postmaster
local class = addon.classes
local debug = false
local getSummary, sortBySender

class.GroupedSenderSummary = ZO_Object:Subclass()

function class.GroupedSenderSummary:New(...)
    local instance = ZO_Object.New(self)
    self.Initialize(instance, ...)
    return instance
end

function class.GroupedSenderSummary:Initialize(templateSummary)
    self.templateSummary = templateSummary
    self.summaries = {}
end

function class.GroupedSenderSummary:AddCurrency(sender, currencyType, quantity)
    local summary = getSummary(self, sender)
    summary:AddCurrency(currencyType, quantity)
end
function class.GroupedSenderSummary:AddItem(sender, bagId, slotIndex, quantity)
    local summary = getSummary(self, sender)
    summary:AddItem(bagId, slotIndex, quantity)
end
function class.GroupedSenderSummary:AddItemId(sender, itemId, quantity)
    local summary = getSummary(self, sender)
    summary:AddItemId(itemId, quantity)
end
function class.GroupedSenderSummary:AddItemLink(sender, itemLink, quantity, dontChangeStyle)
    local summary = getSummary(self, sender)
    summary:AddItemLink(itemLink, quantity, dontChangeStyle)
end
function class.GroupedSenderSummary:Print()
    local summaries = {}
    for _, summary in pairs(self.summaries) do
        table.insert(summaries, summary)
    end
    table.sort(summaries, sortBySender)
    for _, summary in ipairs(summaries) do
        summary:Print()
    end
    self.summaries = {}
end

function getSummary(self, sender)
    local summary = self.summaries[sender]
    if not summary then
        summary = class.SenderSummary:New()
        ZO_DeepTableCopy(self.templateSummary, summary)
        summary:SetSender(sender)
        self.summaries[sender] = summary
    end
    return summary
end

function sortBySender(summary1, summary2)
    return summary1.sender < summary2.sender
end