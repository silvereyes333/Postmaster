-- French strings
local strings = {
    ["SI_PM_CHAT_MESSAGES"]                      = "Messages Chat",
    ["SI_PM_SHORT_PREFIX"]                       = "Utiliser le préfixe court dans la messagerie",
    ["SI_PM_SHORT_PREFIX_TOOLTIP"]               = "Affiche le préfixe [PM] au lieu de [Postmaster] dans les messages de discussion.",
    ["SI_PM_PREFIX_HEADER"]                      = "Préfixe",
    ["SI_PM_COLORED_PREFIX"]                     = "Utiliser les couleurs de préfixe Postmaster 3.8",
    ["SI_PM_COLORED_PREFIX_TOOLTIP"]             = { "Fait que le préfixe des messages de discussion utilise les couleurs bleues de Postmaster 3.8 (c'est-à-dire <<1>>|r ou <<2>>|r) au lieu du paramètre Couleur des Messages Chat.", SI_PM_PREFIX_COLOR, SI_PM_PREFIX_SHORT_COLOR },
    ["SI_PM_CHAT_USE_SYSTEM_COLOR"]              = "Utiliser la couleur de message système par défaut",
    ["SI_PM_CHAT_COLOR"]                         = "Couleur des Messages Chat",
    ["SI_PM_DELETE_DIALOG_SUPPRESS"]             = "Suppression de la confirmation d'effacement",
    ["SI_PM_DELETE_DIALOG_SUPPRESS_TOOLTIP"]     = "Cette option activée, l'effacement des courriers sans pièce jointe ne nécessitera plus de confirmation. Les courriers seront effacés immédiatement.",
    ["SI_PM_RETURN_DIALOG_SUPPRESS"]             = "Suppression de la confirmation de retour",
    ["SI_PM_BOUNCE"]                             = "Retour automatique du courrier",
    ["SI_PM_BOUNCE_TOOLTIP"]                     = "Sonde la boite de réception pour examiner les nouveaux courriers et les renvoi à l'expéditeur si le sujet commence par ou contient: RETURN, BOUNCE, RTS",
    ["SI_PM_BOUNCE_MESSAGE"]                     = { "Courrier retourné à <<1>>", POSTMASTER_STRING_NO_FORMAT },
    ["SI_PM_WYKKYD_MAILBOX_RETURN_WARNING"]      = "Wykkyd Mailbox return bot est activé",
    ["SI_PM_WYKKYD_MAILBOX_DETECTED_WARNING"]    = "Wykkyd Mailbox détecté. Notez SVP que le retour automatique des courriers est désactivé si vous activez Wykkyd Mailbox return bot.",
    ["SI_PM_RESERVED_SLOTS"]                     = "Emplacements réservés",
    ["SI_PM_RESERVED_SLOTS_TOOLTIP"]             = "<<1>> laissera un certain nombre d'emplacements ouverts dans l'inventaire",
    ["SI_PM_SYSTEM"]                             = "Courriers systèmes",
    ["SI_PM_SYSTEM_TAKE_ATTACHED"]               = "Courriers systèmes avec pièces jointes",
    ["SI_PM_SYSTEM_DELETE_ATTACHED"]             = "Effacer courriers systèmes avec pièces jointes",
    ["SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP"]       = "Lorsque cette option est activée, la commande <<1>> récupérera les pièces jointes et, si demandé, effacera les courriers concernés",
    ["SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP_QUICK"] = { "Lorsque cette option est activée, la commande <<1>> récupérera les pièces jointes et effacera les courriers concernés", SI_PM_TAKE },
    ["SI_PM_SYSTEM_TAKE_PVP"]                    = "Récompenses de guerre de l'alliance / Champs de bataille / PvP",
    ["SI_PM_SYSTEM_TAKE_CRAFTING"]               = "Fournisseur",
    ["SI_PM_SYSTEM_TAKE_UNDAUNTED"]              = "Indomptables",
    ["SI_PM_SYSTEM_TAKE_OTHER"]                  = "Toutes les autres pièces jointes du système",
    ["SI_PM_SYSTEM_DELETE_EMPTY"]                = "Courriers systèmes sans pièces jointes",
    ["SI_PM_SYSTEM_DELETE_EMPTY_TOOLTIP_QUICK"]  = { "Lorsque cette option est activée , la commande <<1>> effacera tous les courriers systèmes sans pièces jointes", SI_PM_TAKE },
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER"]         = "Filtrer les courriers systèmes sans pièces jointes",
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER_TOOLTIP"] = { "Quand ce filtre n'est pas vide , la commande <<1>> effacera uniquement les courriers systèmes sans pièce jointe qui contiennent dans le champs texte, l'expéditeur ou le sujet, un mot ou une phrase donnés. <<2>>", SI_PM_TAKE_ALL, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER_TOOLTIP_QUICK"] = { "Quand ce filtre n'est pas vide , la commande <<1>> effacera uniquement les courriers systèmes sans pièce jointe qui contiennent dans le champs texte, l'expéditeur ou le sujet, un mot ou une phrase donnés. <<2>>", SI_PM_TAKE, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_PLAYER"]                             = "Courriers des joueurs",
    ["SI_PM_PLAYER_TAKE_ATTACHED"]               = "Courriers des joueurs avec pièces jointes",
    ["SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP"]       = { "Lorsque cette option est activée , la commande <<1>> récupérera les pièces jointes et, si demandé, effacera tous les courriers des joueurs possédant des pièces jointes , à l'exclusion <<2>>", SI_PM_TAKE_ALL, SI_MAIL_SEND_COD },
    ["SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP_QUICK"] = { "Lorsque cette option est activée , la commande <<1>> récupérera les pièces jointes et effacera tous les courriers des joueurs possédant des pièces jointes , à l'exclusion <<2>>", SI_PM_TAKE, SI_MAIL_SEND_COD },
    ["SI_PM_PLAYER_TAKE_RETURNED"]               = "Courriers retournés",
    ["SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP"]       = "Lorsque cette option est activée, la commande <<1>> récupère les pièces-jointes et, si demandé, supprime tous les mails qui vous ont été retournés.",
    ["SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP_QUICK"] = { "Lorsque cette option est activée, la commande <<1>> récupère les pièces-jointes et supprime tous les mails qui vous ont été retournés.", SI_PM_TAKE },
    ["SI_PM_PLAYER_DELETE_EMPTY"]                = "Courriers des joueurs sans pièces jointes",
    ["SI_PM_PLAYER_DELETE_EMPTY_TOOLTIP"]        = "Lorsque cette option est activée , la commande <<1>> effacera tous les courriers des joueurs sans pièces jointes.",
    ["SI_PM_PLAYER_DELETE_EMPTY_TOOLTIP_QUICK"]  = { "Lorsque cette option est activée , la commande <<1>> effacera tous les courriers des joueurs sans pièces jointes.", SI_PM_TAKE },
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER"]         = "Filtrer les courriers des joueurs sans pièces jointes",
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER_TOOLTIP"] = { "Lorsque ce filtre est pas vide , la commande <<1>> ne supprime le courrier des joueurs sans pièces jointes qui contiennent également l'un des mots ou des phrases données dans les champs de l'expéditeur ou objet. <<2>>", SI_PM_TAKE_ALL, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER_TOOLTIP_QUICK"] = { "Lorsque ce filtre est pas vide , la commande <<1>> ne supprime le courrier des joueurs sans pièces jointes qui contiennent également l'un des mots ou des phrases données dans les champs de l'expéditeur ou objet. <<2>>", SI_PM_TAKE, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_COD"]                                = { "<<1>> Courrier", SI_MAIL_SEND_COD },
    ["SI_PM_COD_TOOLTIP"]                        = { "Lorsque cette option est activée, la commande <<1>> gérera <<2>> courrier répondant aux critères suivants", SI_PM_TAKE_ALL, SI_MAIL_SEND_COD },
    ["SI_PM_COD_TOOLTIP_QUICK"]                  = { "Lorsque cette option est activée, la commande <<1>> gérera <<2>> courrier répondant aux critères suivants", SI_PM_TAKE, SI_MAIL_SEND_COD },
    ["SI_PM_COD_LIMIT"]                          = { "<<1>> Limite", SI_MAIL_SEND_COD },
    ["SI_PM_COD_LIMIT_TOOLTIP"]                  = { "Seulement le courrier avec une quantité inférieure à <<1>> sera payée.  Réglez sur zéro (0) pour sans limite.", SI_MAIL_SEND_COD },
    ["SI_PM_MASTER_MERCHANT_WARNING"]            = "Master Merchant n'est pas activé",
    ["SI_PM_COD_MM_DEAL_0"]                      = "Sur-évalué",
    ["SI_PM_COD_MM_DEAL_1"]                      = "Ok",
    ["SI_PM_COD_MM_DEAL_2"]                      = "Raisonnable",
    ["SI_PM_COD_MM_DEAL_3"]                      = "Bon",
    ["SI_PM_COD_MM_DEAL_4"]                      = "Grand",
    ["SI_PM_COD_MM_DEAL_5"]                      = "Achète le!",
    ["SI_PM_COD_MM_MIN_DEAL"]                    = { "<<1>> Affaire Minimum", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_MIN_DEAL_TOOLTIP"]            = { "Analyse les pièces jointes du courrier par rapport à une valeur relative de Master Merchant market et ne paye que les <<1>> courriers dont les pièces jointes sont de bonnes affaires.  Réglez sur 'Sur-évalué' pour sans limite.", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA"]                     = { "Sans les données de Master Merchant", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA_TOOLTIP"]             = { "Lorsque cette option est activée , la commande <<1>> gérera <<2>> courrier dont les pièces jointes ne possédent pas les données de prix de Master Merchant", SI_PM_TAKE_ALL, SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA_TOOLTIP_QUICK"]       = { "Lorsque cette option est activée , la commande <<1>> gérera <<2>> courrier dont les pièces jointes ne possédent pas les données de prix de Master Merchant", SI_PM_TAKE, SI_MAIL_SEND_COD },
    ["SI_PM_HELP_01"]                            = "Utilisez les commandes |cFF00FF/pm|r ou |cFF00FF/postmaster|r dans le chat comme raccourcis vers cet écran",
    ["SI_PM_HELP_02"]                            = { "Pour interagir avec <<1>> , ouvrez votre courrier reçu", SI_PM_NAME },
    ["SI_PM_HELP_03"]                            = { "<<1>> prélévera les pièces jointes du message puis le supprimera", SI_PM_TAKE },
    ["SI_PM_HELP_04"]                            = "<<1>> prélévera les pièces jointes de tous les messages puis les supprimera :",
    ["SI_PM_CRAFT_BLACKSMITH"]                   = "Matériaux bruts de forge",
    ["SI_PM_CRAFT_CLOTHIER"]                     = "Matériaux bruts de couture",
    ["SI_PM_CRAFT_ENCHANTER"]                    = "Matériaux bruts d'enchantement",
    ["SI_PM_CRAFT_PROVISIONER"]                  = "Matériaux bruts de cuisine",
    ["SI_PM_CRAFT_WOODWORKER"]                   = "Matériaux bruts de travail du bois",
    ["SI_PM_GUILD_STORE_CANCELED"]               = "Objet annulé",
    ["SI_PM_GUILD_STORE_EXPIRED"]                = "Objet arrivé à expiration",
    ["SI_PM_GUILD_STORE_PURCHASED"]              = "Objet acheté",
    ["SI_PM_GUILD_STORE_SOLD"]                   = "Objet vendu",
    ["SI_PM_PVP_FOR_THE_WORTHY"]                 = "La récompense des braves !",
    ["SI_PM_PVP_THANKS"]                         = "Merci, guerrier",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_1"]             = "Pour l'Alliance !",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_2"]             = "",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_3"]             = "",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_1"]          = "L'Alliance vous remercie",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_2"]          = "",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_3"]          = "",
    ["SI_PM_PVP_LOYALTY"]                        = "La récompense de la loyauté",
    ["SI_PM_UNDAUNTED_INVITE"]                   = "Invitation à l'enclave des Indomptables",
    ["SI_PM_UNDAUNTED_NPC_VET"]                  = "Glirion Barbe-Rousse",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_1"]              = "Turuk Rougegriffes",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_2"]              = "Kailstig la Hache",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_3"]              = "Mordra la puissante",
    ["SI_PM_BATTLEGROUNDS_NPC"]                  = "Maître de guerre Rivyn",
    ["SI_PM_MESSAGE"]                            = "courrier",
    ["SI_PM_TAKE_ALL_BY_SUBJECT"]                = "Prendre par sujet",
    ["SI_PM_TAKE_ALL_BY_SENDER"]                 = "Prendre par expéditeur",
    ["SI_PM_KEYBIND_ENABLE_TOOLTIP"]             = { "Active les raccourcis Postmaster: <<1>> et <<2>>", SI_LOOT_TAKE, SI_LOOT_TAKE_ALL },
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    POSTMASTER_STRINGS[stringId] = value
end