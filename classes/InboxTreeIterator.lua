--[[ 
     Used to iterate through every mail message in the keyboard / mouse mail 
     inbox in the following order:
     
     1. The currently-selected node first, and then proceed to the end of 
        the opened list in sequence.
        
     2. When the end of the currently-selected list is reached, messages at 
        the top of the list are started, until all messages in the list are
        iterated.
    
     3. If no selected, uniterated list messages remain, then proceed to 
        the first opened list and iterate all messages from the start.
    
     4. If no opened lists remain, then proceed to the first unopened list
        and iterate all messages from the start.
]]--

local addon = Postmaster
local class = addon.classes
local debug = false

class.InboxTreeIterator = ZO_Object:Subclass()

function class.InboxTreeIterator:New(...)
    local instance = ZO_Object.New(self)
    self.Initialize(instance, ...)
    return instance
end

function class.InboxTreeIterator:Initialize(filter)
    
    self.tree = MAIL_INBOX.navigationTree
    
    -- Only mail nodes that match the following filter will be returned by
    -- the iteration function.
    self.filter = filter
    
    -- Keeps track of which messages and lists are already iterated
    self.iteratedNodes = {} 
    
    -- The main iterator function
    self.next = self:CreateNextFunction()
end

--[[ Create the main iteration function, with reference to self ]]--
function class.InboxTreeIterator:CreateNextFunction()
    return function(mailNode, excludeMailId)
        
        -- Figure out where to start iterating
        if not mailNode then
            
            -- No list has been selected yet.
            if not self.activeList then
              
                -- Find all message lists (e.g. player vs. system mail)
                local listNodes = self.tree.rootNode:GetChildren()
                
                -- If the message lists don't exist, return early. They haven't been
                -- initialized yet.
                if not listNodes then
                    return
                end
                
                -- Look through each list...
                for _, listNode in ipairs(listNodes) do
                  
                    -- Skip those lists that have already been iterated
                    if not self.iteratedNodes[listNode] then
                      
                        -- Check that the list has some children in it.
                        local mailNodes = listNode:GetChildren()
                        
                        -- Skip empty lists, and mark them to be skipped in the future
                        if not mailNodes or #mailNodes == 0 or not mailNodes[1].data.mailId then
                            self.iteratedNodes[listNode] = true
                        
                        -- Start iterating the first open, non-empty, uniterated list
                        elseif listNode:IsOpen() then
                            self.activeList = listNode
                        end
                    end
                end
                
                -- No open, non-empty lists found, so look for the first non-open one
                if not self.activeList then
                    for _, listNode in ipairs(listNodes) do
                        if not self.iteratedNodes[listNode] then
                            self.activeList = listNode
                        end
                    end
                end
            end
            
            -- All lists are done iterating
            if not self.activeList then
                return
            end
            
            -- Since the current node wasn't specified, start at the first message in the list.
            -- This is guaranteed to exist.
            local children = self.activeList:GetChildren()
            mailNode = children[1]
            
            -- If the first message in the list has already been iterated, mark this list 
            -- as complete, and then recursively start looking for a different list to iterate.
            if self.iteratedNodes[mailNode] then
                self.iteratedNodes[self.activeList] = true
                self.activeList = nil
                return self.next()
            end
        end
        
        -- Mark the current mail message as iterated
        self.iteratedNodes[mailNode] = true
        
        -- If the mail message matches the filter, then return it.
        if self.filter(mailNode.data)
           and (not excludeMailId or not AreId64sEqual(mailNode.data.mailId, excludeMailId))
        then
            return mailNode.data
        end
        
        -- If the mail message doesn't match the filter, recursively try the next one in the list.
        -- If there is no next one, mailNode:GetNextSiblingNode() will be nil, causing the active
        -- list to start at the beginning.
        return self.next(mailNode:GetNextSiblingNode(), excludeMailId)
    end
end