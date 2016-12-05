local CancelTests
local function MaxIterationsReached(timeoutData)
    d("Max number of retry attempts reached")
    CancelTests()
end
local function RunTests(runCount)
    local LTO = LibStub("LibTimeout")
    if not LTO then
        d("LibTimeout did not properly load")
        return
    end
    if not runCount or runCount == "" then runCount = 1 end
    d("RunTests iteration "..tostring(runCount))
    local options = { name="MyTimeout", doneCallback = MaxIterationsReached, maxRetries = 5 }
    LTO:StartTimeout(options, 1000, RunTests, runCount + 1)
end
CancelTests = function()
    local LTO = LibStub("LibTimeout")
    if LTO then LTO:CancelTimeout(RunTests) end
end
SLASH_COMMANDS["/ltotest"] = RunTests
SLASH_COMMANDS["/ltocancel"] = CancelTests