--[[ 
    Tracks unique items in an inventory bag.
  ]]
  
local addon = Postmaster
local class = addon.classes
local debug = false

addon.classes.UniqueBagItemsList = ZO_InitializingObject:Subclass()
  
--[[ Wire up all callback handlers ]]
function class.UniqueBagItemsList:Initialize(bagId)
    addon.Utility.Debug("UniqueBagItemsList:Initialize()", debug)
    self.bagId = bagId
    self.uniqueItemIds = {}
    self.slotUniqueItemIds = {}
    self:ScanBag()
end

--[[ Returns true if the given item link is for a unique item that is already in the bag. ]]--
function class.UniqueBagItemsList:ContainsItemLink(itemLink)
    local isUnique = IsItemLinkUnique(itemLink)
    if isUnique then
        local itemId = GetItemLinkItemId(itemLink)
        if self.uniqueItemIds[itemId] then
            return true
        end
    end
end

function class.UniqueBagItemsList:ScanBag()
    addon.Utility.Debug("UniqueBagItemsList:ScanBag()", debug)
    ZO_ClearTable(self.uniqueItemIds)
    for slotIndex in ZO_IterateBagSlots(self.bagId) do
        self:Update(slotIndex)
    end
end

--[[ Registers a potential backpack slot as unique ]]--
function class.UniqueBagItemsList:Update(slotIndex)
    local itemLink = GetItemLink(self.bagId, slotIndex)
    local itemId
    if not itemLink or itemLink == "" then
        itemId = self.slotUniqueItemIds[slotIndex]
        if itemId then
            self.uniqueItemIds[itemId] = nil
        end
        self.slotUniqueItemIds[slotIndex] = nil
        return
    end
    itemId = GetItemLinkItemId(itemLink)
    if IsItemLinkUnique(itemLink) then
        self.uniqueItemIds[itemId] = true
        self.slotUniqueItemIds[slotIndex] = itemId
    else
        self.uniqueItemIds[itemId] = nil
        self.slotUniqueItemIds[slotIndex] = nil
    end
end
