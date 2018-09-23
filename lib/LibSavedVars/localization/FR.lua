local strings = {
    ["SI_LSV_ACCOUNT_WIDE"]    = "Appliquer les réglages au niveau du compte",
    ["SI_LSV_ACCOUNT_WIDE_TT"] = "Tous les réglages ci-dessous seront les mêmes pour chacun de vos personnages.",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    LIBSAVEDVARS_STRINGS[stringId] = value
end