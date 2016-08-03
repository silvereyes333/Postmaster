for stringId, value in pairs(PM_STRINGS) do
    local stringValue
    if type(value) == "table" then
        for i=2,#value do
            if type(value[i]) == "string" then
                value[i] = _G[value[i]]
            end
            value[i] = GetString(value[i])
        end
        stringValue = zo_strformat(unpack(value))
    else
        stringValue = zo_strformat(value, GetString(SI_PM_TAKE_ALL))
    end
	ZO_CreateStringId(stringId, stringValue)
end
PM_STRINGS = nil