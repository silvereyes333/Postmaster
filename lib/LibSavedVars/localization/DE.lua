local strings = {
    ["SI_LSV_ACCOUNT_WIDE"]    = "Accountweite Einstellungen",
    ["SI_LSV_ACCOUNT_WIDE_TT"] = "Alle Einstellungen unterhalb sind dieselben für alle deine Figuren.",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    LIBSAVEDVARS_STRINGS[stringId] = value
end