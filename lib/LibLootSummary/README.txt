ABOUT THIS LIBRARY

    This library is intended to simplify outputing summaries of loot to ESO chat
  
  
USAGE EXAMPLE

    local LLS = LibStub("LibLootSummary")
    if LLS then
        
        -- If set to false, then successive calls to the Add*() methods for the same item id will
        -- be listed separately in the summary.  The default (true) causes the quantities to be
        -- summed and listed once in the summary.
        LLS:SetCombineDuplicates(false)
        
        -- Use comma delimiters between items in the summary, instead of the default single space
        LLS:SetDelimiter(", ")
        
        -- Use bracket style links
        LLS:SetLinkStyle(LINK_STYLE_BRACKETS)
        
        -- Prefix to get prepended to every line of the summary
        LLS:SetPrefix("MyAddon: ")
        
        -- Reset all settings to defaults and remove all items from the pending summary.
        -- LLS:Print() calls this by default.
        LLS:Reset()
        
        -- Add item from bag
        -- If quantity is nil, then the max stack size possible will be used
        LLS:AddItem(bagId, slotIndex, quantity)
        
        -- Add 200x Ancestor Silk
        LLS:AddItemLink("|H1:item:64504:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", 200)
        
        -- Add 1x Aetherial Dust
        LLS:AddItemId(115026, 1)
        
        -- Output the entire summary to chat
        LLS:Print()
        
    end

