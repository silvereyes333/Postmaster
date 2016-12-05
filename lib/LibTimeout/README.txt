ABOUT THIS LIBRARY

	This library is intended to simplify timeouts in ESO addons and add the 
	following features to the built-in zo_callLater function:
	- allows you to cancel/abort the timeout
	- allows you to pass in parameters to the callback without using an 
	  anonymous function, which in term increases performance
	- repeated calls to the same timeout function or name will only raise the 
	  callback of the most recent one
  
  
USAGE EXAMPLE

    -- The method we want to retry
	local Run
	
	-- This is a handler for a server event that we want to wait for, but which
	-- may never fire depending on some ZOS dark server magic.
	local function HandleServerEvent(eventCode)
		
		-- Stop listening for timeouts, since the server responded normally
		local LTO = LibStub("LibTimeout")
		if LTO then LTO:CancelTimeout(Run) end
		
		-- Stop listening for the server event
		EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_SRVR)
		
		-- Do stuff ...
	end
	
	-- This is a handler that will run after the optional number of max retries 
	-- are done.
	local function TimeoutDone(options)
        d("Sorry, the event never fired after " .. tostring(options.maxRetries)
          .. " retry attempts.")
	end
	
	-- This is the method that does whatever logic would cause the server event
	-- to fire.  We want to call it again after 1.5 seconds if the server hasn't
	-- responded yet.
	Run = function(arg1, arg2)

		local LTO = LibStub("LibTimeout")
		if LTO then
            local timeoutCallback = Run
            local timeoutMilliseconds = 1500
            LTO:StartTimeout(
                -- This first options table parameter can be excluded if you 
                -- don't need any of the options.
                {
                    doneCallback = TimeoutDone,
                    maxRetries   = 5,            -- 0 will retry forever
                    name         = "MyAddonRun", -- unique name for the callback
                                                 -- only required if 
                                                 -- timeoutCallback is an 
                                                 -- anonymous function that will 
                                                 -- be redefined every run
                }, 
                timeoutMilliseconds, timeoutCallback, arg1, arg2)
        end
		
		-- Set up the server event handler
		EVENT_MANAGER:RegisterForEvent(addonName, EVENT_SRVR, HandleServerEvent)
		
		-- Perform the action that would cause the server to fire the event ...
	end

