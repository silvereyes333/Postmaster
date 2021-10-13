POSTMASTER_STRING_NO_FORMAT = -1
ZO_CreateStringId("SI_PM_NAME",                "Postmaster")
ZO_CreateStringId("SI_PM_PREFIX",              "Postmaster")
ZO_CreateStringId("SI_PM_PREFIX_COLOR",        "|c99CCEFPostmaster|r")
ZO_CreateStringId("SI_PM_PREFIX_SHORT",        "PM")
ZO_CreateStringId("SI_PM_PREFIX_SHORT_COLOR", "|c99CCEFPM|r")
ZO_CreateStringId("SI_PM_TAKE",     zo_strformat("|cFF00FF<<1>>|r", GetString(SI_LOOT_TAKE)))
ZO_CreateStringId("SI_PM_TAKE_ALL", zo_strformat("|cFF00FF<<1>>|r", GetString(SI_LOOT_TAKE_ALL)))
local INDENT = "|t100%:100%:art/icons/placeholder/icon_blank.dds|t"
POSTMASTER_STRINGS = {
    ["SI_PM_WORD_SEPARATOR"]                     = " ",
    ["SI_PM_CHAT_MESSAGES"]                      = "Chat Messages",
    ["SI_PM_SHORT_PREFIX"]                       = "Use Short Prefix",
    ["SI_PM_SHORT_PREFIX_TOOLTIP"]               = "Causes chat messages to be prefixed with [PM] instead of [Postmaster]",
    ["SI_PM_PREFIX_HEADER"]                      = "Prefix",
    ["SI_PM_PREFIX_COMMAND1"]                    = { INDENT .. "|cEEEE00[<<1>>]|r" },
    ["SI_PM_PREFIX_COMMAND2"]                    = { "|c55C755/chatmessage tag <<1>>|r" },
    ["SI_PM_COLORED_PREFIX"]                     = "Use Postmaster 3.8 Colored Prefix",
    ["SI_PM_COLORED_PREFIX_TOOLTIP"]             = { "Causes the prefix for chat messages to use the blue Postmaster 3.8 color (i.e. <<1>>|r or <<2>>|r) instead of the Chat Message Color setting.", SI_PM_PREFIX_COLOR, SI_PM_PREFIX_SHORT_COLOR },
    ["SI_PM_CHAT_USE_SYSTEM_COLOR"]              = "Use Default System Message Color",
    ["SI_PM_CHAT_COLOR"]                         = "Chat Message Color",
    ["SI_PM_DELETE_DIALOG_SUPPRESS"]             = "Suppress Delete Confirmation",
    ["SI_PM_DELETE_DIALOG_SUPPRESS_TOOLTIP"]     = "When this option is enabled, deleting messages that have no attachments will no longer require confirmation. The messages will be deleted immediately.",
    ["SI_PM_RETURN_DIALOG_SUPPRESS"]             = "Suppress Return Confirmation",
    ["SI_PM_BOUNCE"]                             = "Automatic Mail Return",
    ["SI_PM_BOUNCE_TOOLTIP"]                     = "Monitors the inbox for new mail and automatically returns it to the sender if the subject begins with or equals any of the following words: RETURN, BOUNCE, RTS",
    ["SI_PM_BOUNCE_MESSAGE"]                     = { "Returned mail to <<1>>", POSTMASTER_STRING_NO_FORMAT },
    ["SI_PM_WYKKYD_MAILBOX_RETURN_WARNING"]      = "Wykkyd Mailbox return bot is enabled",
    ["SI_PM_WYKKYD_MAILBOX_DETECTED_WARNING"]    = "Wykkyd Mailbox detected. Please note that \"Automatic Mail Return\" |cFF0000deactivates|r if you enable the Wykkyd Mailbox return bot.",
    ["SI_PM_RESERVED_SLOTS"]                     = "Reserved Slots",
    ["SI_PM_RESERVED_SLOTS_TOOLTIP"]             = "<<1>> will leave the given number of backpack slots open",
    ["SI_PM_SYSTEM"]                             = "System Mail",
    ["SI_PM_SYSTEM_TAKE_ATTACHED"]               = "System Mail With Attachments",
    ["SI_PM_SYSTEM_DELETE_ATTACHED"]             = "Delete System Mail With Attachments",
    ["SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP"]       = "When this option is enabled, the <<1>> command takes the attachments from and optionally deletes any system mails that meet the following requirements",
    ["SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP_QUICK"] = { "When this option is enabled, the <<1>> command takes the attachments from and deletes any system mails that meet the following requirements", SI_PM_TAKE },
    ["SI_PM_SYSTEM_TAKE_PVP"]                    = "Alliance War / Battlegrounds / PvP Rewards",
    ["SI_PM_SYSTEM_TAKE_CRAFTING"]               = "Hireling",
    ["SI_PM_SYSTEM_TAKE_UNDAUNTED"]              = "Undaunted",
    ["SI_PM_SYSTEM_TAKE_OTHER"]                  = "All Other System Attachments",
    ["SI_PM_SYSTEM_DELETE_EMPTY"]                = "System Mail Without Attachments",
    ["SI_PM_SYSTEM_DELETE_EMPTY_TOOLTIP"]        = "When this option is enabled, the <<1>> command deletes any system mail that does not have an attachment, such as notifications for items added to collections",
    ["SI_PM_SYSTEM_DELETE_EMPTY_TOOLTIP_QUICK"]  = { "When this option is enabled, the <<1>> command deletes any system mail that does not have an attachment, such as notifications for items added to collections", SI_PM_TAKE },
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER"]         = "Filter System Mail Without Attachments",
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER_TOOLTIP"] = { "When this filter is not empty, the <<1>> command will only delete player mail without attachments that contains one of the given words or phrases in the sender or subject fields. <<2>>", SI_PM_TAKE_ALL, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER_TOOLTIP_QUICK"] = { "When this filter is not empty, the <<1>> command will only delete player mail without attachments that contains one of the given words or phrases in the sender or subject fields. <<2>>", SI_PM_TAKE, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_PLAYER"]                             = "Player Mail",
    ["SI_PM_PLAYER_TAKE_ATTACHED"]               = "Player Mail With Attachments",
    ["SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP"]       = "When this option is enabled, the <<1>> command takes the attachments from and optionally deletes any non-C.O.D. mail from other players that have attachments",
    ["SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP_QUICK"] = { "When this option is enabled, the <<1>> command takes the attachments from and deletes any non-C.O.D. mail from other players that have attachments", SI_PM_TAKE },
    ["SI_PM_PLAYER_TAKE_RETURNED"]               = "Returned Mail",
    ["SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP"]       = "When this option is enabled, the <<1>> command takes the attachments from and optionally deletes any mail returned to you by another player.",
    ["SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP_QUICK"] = { "When this option is enabled, the <<1>> command takes the attachments from and deletes any mail returned to you by another player.", SI_PM_TAKE },
    ["SI_PM_PLAYER_DELETE_EMPTY"]                = "Player Mail Without Attachments",
    ["SI_PM_PLAYER_DELETE_EMPTY_TOOLTIP"]        = "When this option is enabled, the <<1>> command deletes any mail from other players that does not have an attachment",
    ["SI_PM_PLAYER_DELETE_EMPTY_TOOLTIP_QUICK"]  = { "When this option is enabled, the <<1>> command deletes any mail from other players that does not have an attachment", SI_PM_TAKE },
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER"]         = "Filter Player Mail Without Attachments",
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER_TOOLTIP"] = { "When this filter is not empty, the <<1>> command will only delete system mail without attachments that contains one of the given words or phrases in the sender or subject fields. <<2>>", SI_PM_TAKE_ALL, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER_TOOLTIP_QUICK"] = { "When this filter is not empty, the <<1>> command will only delete system mail without attachments that contains one of the given words or phrases in the sender or subject fields. <<2>>", SI_PM_TAKE, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_COD"]                                = { "<<1>> Mail", SI_MAIL_SEND_COD },
    ["SI_PM_COD_TOOLTIP"]                        = { "When this option is enabled, the <<1>> command takes <<2>> mail matching the following criteria", SI_PM_TAKE_ALL, SI_MAIL_SEND_COD },
    ["SI_PM_COD_TOOLTIP_QUICK"]                  = { "When this option is enabled, the <<1>> command takes <<2>> mail matching the following criteria", SI_PM_TAKE, SI_MAIL_SEND_COD },
    ["SI_PM_COD_LIMIT"]                          = { "<<1>> Limit", SI_MAIL_SEND_COD },
    ["SI_PM_COD_LIMIT_TOOLTIP"]                  = { "Only mail with a <<1>> amount less than this value will be paid.  Set to zero (0) for no limit.", SI_MAIL_SEND_COD },
    ["SI_PM_MASTER_MERCHANT_WARNING"]            = "Master Merchant is not enabled",
    ["SI_PM_COD_MM_DEAL_0"]                      = "Overpriced",
    ["SI_PM_COD_MM_DEAL_1"]                      = "Ok",
    ["SI_PM_COD_MM_DEAL_2"]                      = "Reasonable",
    ["SI_PM_COD_MM_DEAL_3"]                      = "Good",
    ["SI_PM_COD_MM_DEAL_4"]                      = "Great",
    ["SI_PM_COD_MM_DEAL_5"]                      = "Buy it!",
    ["SI_PM_COD_MM_MIN_DEAL"]                    = { "<<1>> Minimum Deal", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_MIN_DEAL_TOOLTIP"]            = { "Analyzes <<1>> mail attachments for relative Master Merchant market value and only pays those where all attachments are at least as good of deal as this option.  Set to \"Overpriced\" for no limit.", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA"]                     = { "<<1>> With No Master Merchant Data", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA_TOOLTIP"]             = { "When this option is enabled, the <<1>> command takes <<2>> mail attachments that have no Master Merchant pricing data", SI_PM_TAKE_ALL, SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA_TOOLTIP_QUICK"]       = { "When this option is enabled, the <<1>> command takes <<2>> mail attachments that have no Master Merchant pricing data", SI_PM_TAKE, SI_MAIL_SEND_COD },
    ["SI_PM_HELP_01"]                            = { "To interact with <<1>>, open your mail inbox", SI_PM_NAME },
    ["SI_PM_HELP_02"]                            = "Use |cFF00FF/pm|r or |cFF00FF/postmaster|r in the chat window as shortcuts to this panel",
    ["SI_PM_HELP_03"]                            = { "<<1>> takes attachments and deletes the |cEFEBBEcurrently selected|r mail", SI_PM_TAKE },
    ["SI_PM_HELP_04"]                            = "<<1>> takes attachments and optionally deletes |cEFEBBEall|r of the following mail:",
    ["SI_PM_CRAFT_BLACKSMITH"]                   = "Raw Blacksmith Materials",
    ["SI_PM_CRAFT_CLOTHIER"]                     = "Raw Clothier Materials",
    ["SI_PM_CRAFT_ENCHANTER"]                    = "Raw Enchanter Materials",
    ["SI_PM_CRAFT_PROVISIONER"]                  = "Raw Provisioner Materials",
    ["SI_PM_CRAFT_WOODWORKER"]                   = "Raw Woodworker Materials",
    ["SI_PM_GUILD_STORE_CANCELED"]               = "Item Canceled",
    ["SI_PM_GUILD_STORE_EXPIRED"]                = "Item Expired",
    ["SI_PM_GUILD_STORE_PURCHASED"]              = "Item Purchased",
    ["SI_PM_GUILD_STORE_SOLD"]                   = "Item Sold",
    ["SI_PM_PVP_FOR_THE_WORTHY"]                 = "Rewards for the Worthy!",
    ["SI_PM_PVP_THANKS"]                         = "Our Thanks, Warrior",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_1"]             = "For the Dominion!",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_2"]             = "For the Pact!",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_3"]             = "For the Covenant!",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_1"]          = "The Dominion Thanks You",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_2"]          = "The Pact Thanks You",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_3"]          = "The Covenant Thanks You",
    ["SI_PM_PVP_LOYALTY"]                        = "Campaign Loyalty Reward",
    ["SI_PM_UNDAUNTED_NPC_NORMAL"]               = "Maj al-Ragath",
    ["SI_PM_UNDAUNTED_NPC_VET"]                  = "Glirion the Redbeard",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_1"]              = "Turuk Redclaws",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_2"]              = "Kailstig the Axe",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_3"]              = "Mighty Mordra",
    ["SI_PM_BATTLEGROUNDS_NPC"]                  = "Battlemaster Rivyn",
    ["SI_PM_DELETE_FAILED"]                      = "There was a problem deleting mail. Please try again.",
    ["SI_PM_TAKE_ATTACHMENTS_FAILED"]            = "There was a problem taking attachments. Please try again.",
    ["SI_PM_READ_FAILED"]                        = "There was a problem reading the next mail message. Please try again.",
    ["SI_PM_MESSAGE"]                            = "message",
    ["SI_PM_KEYBOARD"]                           = " (Keyboard)"
    ["SI_PM_TAKE_ALL_BY_SUBJECT"]                = "Take by Subject",
    ["SI_PM_TAKE_ALL_BY_SENDER"]                 = "Take by Sender",
    ["SI_PM_KEYBIND_ENABLE_TOOLTIP"]             = { "Enables the custom Postmaster keybindings: <<1>> and <<2>>", SI_LOOT_TAKE, SI_LOOT_TAKE_ALL },

    --Baertram - Mail Send save message settings
    ["SI_PM_SENDMAIL_MESSAGE_RECIPIENTS"]        = "Save Recipient",
    ["SI_PM_SENDMAIL_MESSAGE_RECIPIENTS_TT"]     = "Automatically save a list of recently sent email recipients after they are sent. You are able to show and select from a list via a right mouse click on the mail recipient text box.",
    ["SI_PM_SENDMAIL_MESSAGE_SUBJECTS"]          = "Save Subject",
    ["SI_PM_SENDMAIL_MESSAGE_SUBJECTS_TT"]       = "Automatically save a list of recently sent email subjects after they are sent. You are able to show and select from a list via a right mouse click on the mail subject text box.",
    ["SI_PM_SENDMAIL_MESSAGE_TEXT"]              = "Save Messages",
    ["SI_PM_SENDMAIL_MESSAGE_TEXT_TT"]           = "Automatically save a list of recently sent email messages after they are sent. You are able to show and select from a list via a right mouse click on the mail message body text box.",
    ["SI_PM_SENDMAIL_MESSAGE_RECENT_SUBJECTS"]   = "Recent Subjects",
    ["SI_PM_SENDMAIL_MESSAGE_RECENT_TEXT"]       = "Recent Messages",
    ["SI_PM_SENDMAIL_AMOUNT"]                    = "Number of Recent Entries to Save",
    ["SI_PM_SENDMAIL_PREVIEW_CHARS"]             = "Recent Messages Menu Character Width",
}