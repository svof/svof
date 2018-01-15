max_line_length = false

read_globals = {
  "atcp", "gmcp", "line", "Geyser", "yajl",
  -- Mudlets API
  table = {
    fields = {
      "contains",
      "save",
      "load",
      "n_complement",
      "index_of",
      "size",
    }
  },
  string = {
    fields = {
      "split",
      "title",
    }
  },
  "ndb", "display", "matches", "multimatches", "lfs", "color_table", "fg", "bg", "sendAll", "cinsertText", "dinsertText", "cecho", "decho", "expandAlias", "echo", "selectString", "selectSection", "replace", "setBgColor", "setFgColor", "tempTimer", "tempTrigger", "tempRegexTrigger", "closeMudlet", "loadWindowLayout", "saveWindowLayout", "setFontSize", "getFontSize", "openUserWindow", "echoUserWindow", "enableTimer", "disableTimer", "enableKey", "disableKey", "killKey", "clearUserWindow", "clearWindow", "killTimer", "moveCursor", "getLines", "getLineNumber", "insertHTML", "insertText", "enableTrigger", "disableTrigger", "killTrigger", "getLineCount", "getColumnNumber", "send", "selectCaptureGroup", "tempLineTrigger", "raiseEvent", "deleteLine", "copy", "cut", "paste", "pasteWindow", "debugc", "setWindowWrap", "setWindowWrapIndent", "resetFormat", "moveCursorEnd", "getLastLineNumber", "getNetworkLatency", "createMiniConsole", "createLabel", "raiseWindow", "lowerWindow", "hideWindow", "showWindow", "createBuffer", "createStopWatch", "getStopWatchTime", "stopStopWatch", "startStopWatch", "resetStopWatch", "closeUserWindow", "resizeWindow", "appendBuffer", "setBackgroundImage", "setBackgroundColor", "createButton", "setLabelClickCallback", "setLabelDoubleClickCallback", "setLabelReleaseCallback", "setLabelMoveCallback", "setLabelWheelCallback", "setLabelOnEnter", "setLabelOnLeave", "moveWindow", "setTextFormat", "getMainWindowSize", "getMousePosition", "getCurrentLine", "setMiniConsoleFontSize", "selectCurrentLine", "spawn", "getButtonState", "showToolBar", "hideToolBar", "loadRawFile", "setBold", "setItalics", "setUnderline", "setStrikeOut", "disconnect", "tempButtonToolbar", "tempButton", "setButtonStyleSheet", "reconnect", "getMudletHomeDir", "getMudletLuaDefaultPaths", "setTriggerStayOpen", "wrapLine", "getFgColor", "getBgColor", "tempColorTrigger", "isAnsiFgColor", "isAnsiBgColor", "stopSounds", "playSoundFile", "setBorderTop", "setBorderBottom", "setBorderLeft", "setBorderRight", "setBorderColor", "setConsoleBufferSize", "enableScrollBar", "disableScrollBar", "startLogging", "calcFontSize", "permRegexTrigger", "permSubstringTrigger", "permBeginOfLineStringTrigger", "tempComplexRegexTrigger", "permTimer", "permAlias", "permKey", "tempKey", "exists", "isActive", "enableAlias", "tempAlias", "disableAlias", "killAlias", "setLabelStyleSheet", "getTime", "invokeFileDialog", "getTimestamp", "setLink", "deselect", "insertLink", "echoLink", "dechoLink", "echoPopup", "insertPopup", "setPopup", "sendATCP", "hasFocus", "isPrompt", "feedTriggers", "sendTelnetChannel102", "setRoomWeight", "getRoomWeight", "gotoRoom", "setMapperView", "getRoomExits", "lockRoom", "createMapper", "getMainConsoleWidth", "resetProfile", "printCmdLine", "searchRoom", "clearCmdLine", "getAreaTable", "getAreaTableSwap", "getAreaRooms", "getPath", "centerview", "denyCurrentSend", "tempBeginOfLineTrigger", "tempExactMatchTrigger", "sendGMCP", "roomExists", "addRoom", "setExit", "setRoomCoordinates", "getRoomCoordinates", "createRoomID", "getRoomArea", "setRoomArea", "resetRoomArea", "setAreaName", "roomLocked", "setCustomEnvColor", "getCustomEnvColorTable", "setRoomEnv", "setRoomName", "getRoomName", "setGridMode", "solveRoomCollisions", "addSpecialExit", "removeSpecialExit", "getSpecialExits", "getSpecialExitsSwap", "clearSpecialExits", "getRoomEnv", "getRoomUserData", "setRoomUserData", "searchRoomUserData", "getRoomsByPosition", "clearRoomUserData", "clearRoomUserDataItem", "downloadFile", "appendCmdLine", "getCmdLine", "openUrl", "sendSocket", "setRoomIDbyHash", "getRoomIDbyHash", "addAreaName", "getRoomAreaName", "deleteArea", "deleteRoom", "setRoomChar", "getRoomChar", "registerAnonymousEventHandler", "saveMap", "loadMap", "setMainWindowSize", "setAppStyleSheet", "sendIrc", "getIrcNick", "getIrcServer", "getIrcChannels", "getIrcConnectedHost", "setIrcNick", "setIrcServer", "setIrcChannels", "restartIrc", "connectToServer", "getRooms", "createMapLabel", "deleteMapLabel", "highlightRoom", "unHighlightRoom", "getMapLabels", "getMapLabel", "lockExit", "hasExitLock", "lockSpecialExit", "hasSpecialExitLock", "setExitStub", "connectExitStub", "getExitStubs", "getExitStubs1", "setModulePriority", "getModulePriority", "updateMap", "addMapEvent", "removeMapEvent", "getMapEvents", "addMapMenu", "removeMapMenu", "getMapMenus", "installPackage", "installModule", "uninstallModule", "reloadModule", "exportAreaImage", "createMapImageLabel", "setMapZoom", "uninstallPackage", "setExitWeight", "setDoor", "getDoors", "getExitWeights", "addSupportedTelnetOption", "setMergeTables", "getModulePath", "getAreaExits", "auditAreas", "sendMSDP", "handleWindowResizeEvent", "addCustomLine", "getCustomLines", "getMudletVersion", "openWebPage", "getAllRoomEntrances", "getRoomUserDataKeys", "getAllRoomUserData", "searchAreaUserData", "getMapUserData", "getAreaUserData", "setMapUserData", "setAreaUserData", "getAllAreaUserData", "getAllMapUserData", "clearAreaUserData", "clearAreaUserDataItem", "clearMapUserData", "clearMapUserDataItem", "setDefaultAreaVisible", "getProfileName", "raiseGlobalEvent", "saveProfile", "setServerEncoding", "getServerEncoding", "getServerEncodingsList", "alert", "tempPromptTrigger", "permPromptTrigger", "getColumnCount", "getRowCount"}

files["raw-svo.install.lua"] = {
  read_globals = {
    createLabel = { read_only = false },
    "Logger",
    ndb = { read_only = false, other_fields = true },
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen", "update", "aiprompt", "deleteLineP", "setignore", "actions_performed", "sp_limbs",
          "sp_checksp", "count_until_last_paragraph", "findbybals", "vaff", "convert_string", "green",
          "swapped_asthma", "prio_swap", "updateloggingconfig", "keystolist", "longeststring", "contains",
          "oneconcat", "setdefaultprompt", "riftlabel", "setupserverside", "conf_printinstallhint", "pipe_assignid",
          installclear = { read_only = false },
          installstart = { read_only = false },
          defdefup     = { read_only = false },
          installtimer = { read_only = false },
          defkeepup    = { read_only = false },
          install      = { read_only = false, other_fields = true },
          config_dict  = { read_only = false, other_fields = true },
          sk           = { read_only = false, other_fields = true },
          conf         = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.config.lua"] = {
  read_globals = {
    createLabel = { read_only = false },
    "Logger",
    ndb = { read_only = false, other_fields = true },
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen", "update", "aiprompt", "deleteLineP", "setignore", "actions_performed", "sp_limbs",
          "sp_checksp", "count_until_last_paragraph", "findbybals", "vaff", "convert_string", "green",
          "swapped_asthma", "prio_swap", "updateloggingconfig", "keystolist", "longeststring", "contains",
          "oneconcat", "setdefaultprompt", "riftlabel", "setupserverside",
          conf_printinstallhint = { read_only = false },
          wait_tbl              = { read_only = false },
          swapped_asthma        = { read_only = false },
          tntf_set              = { read_only = false },
          echof                 = { read_only = false },
          moveprompt            = { read_only = false },
          innews                = { read_only = false },
          bottomprompt          = { read_only = false },
          showprompt            = { read_only = false },
          bottom_border         = { read_only = false },
          config_dict           = { read_only = false, other_fields = true },
          conf                  = { read_only = false, other_fields = true },
          config                = { read_only = false, other_fields = true },
          sk                    = { read_only = false, other_fields = true },
          me                    = { read_only = false, other_fields = true },
          dict                  = { read_only = false, other_fields = true },
          pipes                 = { read_only = false, other_fields = true },
          ignore                = { read_only = false, other_fields = true },
          sp_config             = { read_only = false, other_fields = true },
          serverignore          = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.valid.main.lua"] = {
  read_globals = {
    createLabel = { read_only = false },
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen", "update", "aiprompt", "deleteLineP", "setignore", "actions_performed", "sp_limbs",
          "sp_checksp", "count_until_last_paragraph", "findbybals", "vaff",
          smoke_cure                    = { read_only = false },
          show_info                     = { read_only = false },
          ignore_illusion               = { read_only = false },
          not_illusion                  = { read_only = false },
          missing_enchant               = { read_only = false },
          missing_tinderbox             = { read_only = false },
          apply_cure                    = { read_only = false },
          focus_cure                    = { read_only = false },
          herb_cure                     = { read_only = false },
          sip_cure                      = { read_only = false },
          applyelixir_cure              = { read_only = false },
          knight_focused                = { read_only = false },
          connected                     = { read_only = false },
          ignore_snake_bite             = { read_only = false },
          passive_cure_paragraph        = { read_only = false },
          disable_generic_trigs         = { read_only = false },
          enable_generic_trigs          = { read_only = false },
          check_generics                = { read_only = false },
          generics_enabled              = { read_only = false },
          generics_enabled_for_blackout = { read_only = false },
          generics_enabled_for_passive  = { read_only = false },
          dict                          = { read_only = false, other_fields = true },
          conf                          = { read_only = false, other_fields = true },
          defs                          = { read_only = false, other_fields = true },
          valid                         = { read_only = false, other_fields = true },
          sk                            = { read_only = false, other_fields = true },
          sys                           = { read_only = false, other_fields = true },
          me                            = { read_only = false, other_fields = true },
          pipes                         = { read_only = false, other_fields = true },
          vm                            = { read_only = false, other_fields = true },
          bals                          = { read_only = false, other_fields = true },
          affsp                         = { read_only = false, other_fields = true },
          rift                          = { read_only = false, other_fields = true },
          es_potions                    = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.valid.simple.lua"] = {
  read_globals = {
    createLabel = { read_only = false },
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen", "update",
          affsp = { read_only = false },
          valid = { read_only = false, other_fields = true },
          sk    = { read_only = false, other_fields = true },
          dict  = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.valid.diag.lua"] = {
  read_globals = {
    createLabel = { read_only = false },
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen", "update",
          affsp = { read_only = false },
          valid = { read_only = false, other_fields = true },
          sk    = { read_only = false, other_fields = true },
          dict  = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.rift.lua"] = {
  read_globals = {
    createLabel = { read_only = false },
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen", "update",
          intlen             = { read_only = false },
          es_vialids         = { read_only = false, other_fields = true },
          me                 = { read_only = false, other_fields = true },
          pipes              = { read_only = false, other_fields = true },
          rift               = { read_only = false, other_fields = true },
          conf               = { read_only = false, other_fields = true },
          myrift             = { read_only = false, other_fields = true },
          myinv              = { read_only = false, other_fields = true },
          riftlabel          = { read_only = false, other_fields = true },
          sys                = { read_only = false, other_fields = true },
          sk                 = { read_only = false, other_fields = true },
          riftline           = { read_only = false },
          showrift           = { read_only = false },
          showinv            = { read_only = false },
          showprecache       = { read_only = false },
          setprecache        = { read_only = false },
          invline            = { read_only = false },
          riftremoved        = { read_only = false },
          pocketbelt_added   = { read_only = false },
          pocketbelt_removed = { read_only = false },
          riftadded          = { read_only = false },
          riftnada           = { read_only = false },
          riftate            = { read_only = false },
          toggle_riftlabel   = { read_only = false },
          sip   = { read_only = false },
          apply   = { read_only = false },
          eat   = { read_only = false },
          fillpipe   = { read_only = false },
      }
    }
  }
}

files["raw-svo.pipes.lua"] = {
  read_globals = {
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen",
          firstpipe       = { read_only = false },
          lastlit         = { read_only = false },
          pipeout         = { read_only = false },
          pipestart       = { read_only = false },
          parseplist      = { read_only = false },
          parseplistempty = { read_only = false },
          parseplistend   = { read_only = false },
          pipe_assignid   = { read_only = false },
          me              = { read_only = false, other_fields = true },
          pipes           = { read_only = false, other_fields = true },
          conf           = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.controllers.lua"] = {
  read_globals = {
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf",
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
          "defupfinish", "bottomprompt", "showprompt", "make_prio_table", "errorf", "echofn", "make_sync_prio_table",
          "inra", "intlen",
          blackout          = { read_only = false },
          sendc          = { read_only = false },
          curingcommand     = { read_only = false },
          extended_eq       = { read_only = false },
          fullstats         = { read_only = false },
          givewarning       = { read_only = false },
          givewarning_multi = { read_only = false },
          gotarmbalance     = { read_only = false },
          gotbalance        = { read_only = false },
          goteq             = { read_only = false },
          lyre_step         = { read_only = false },
          onprompt          = { read_only = false },
          printorder        = { read_only = false },
          printordersync    = { read_only = false },
          prio_makefirst    = { read_only = false },
          prio_slowswap     = { read_only = false },
          prio_swap         = { read_only = false },
          prio_undofirst    = { read_only = false },
          QQ                = { read_only = false },
          prompt_stats      = { read_only = false },
          savesettings      = { read_only = false },
          queuecommand      = { read_only = false },
          can_usemana       = { read_only = false },
          havechannelsfor   = { read_only = false },
          prefixwarning     = { read_only = false },
          prompttrigger     = { read_only = false },
          aiprompt          = { read_only = false },
          promptcount       = { read_only = false },
          lastpromptnumber  = { read_only = false },
          lastprompttime    = { read_only = false },
          paragraph_length  = { read_only = false },
          innews            = { read_only = false },
          sacid             = { read_only = false },
          me     = { read_only = false, other_fields = true },
          bals   = { read_only = false, other_fields = true },
          dict   = { read_only = false, other_fields = true },
          stats  = { read_only = false, other_fields = true },
          cnrl   = { read_only = false, other_fields = true },
          sk     = { read_only = false, other_fields = true },
          sys    = { read_only = false, other_fields = true },
          valid  = { read_only = false, other_fields = true },
          pflags = { read_only = false, other_fields = true },
          serverignore = { read_only = false, other_fields = true },
          conf = { read_only = false, other_fields = true },
          newbals = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.skeleton.lua"] = {
  read_globals = {
    svo = {
      fields = {
        "assert", "haveskillset", "sys", "defdefup", "defkeepup", "signals", "deepcopy", "conf", "sk", "me", "defs", "defc", "defences", "stats", "empty", "cnrl", "rift", "bals",
        "doingaction", "usingbal", "serverignore", "ignore", "getHighestKey", "doaction",
        "dict_purgative", "dict_salve_def", "dict_herb", "dict_misc", "dict_misc_def",
        "dict_smoke_def", "dict_balanceful", "dict_balanceful_def", "dict_balanceless",
        "dict_balanceless_def", "index_map", "getBoundary", "debugf", "valid", "pl", "oldsend",
        "echof", "affsp", "actions", "actionfinished", "actionclear", "paragraph_length",
        "make_gnomes_work", "check_dofree", "will_take_balance", "fancysend", "fancysendall",
        "bals_in_use", "concatand", "lastpromptnumber", "mm_create_riftlabel", "getDefaultColor",
        "syncdelay", "checkaction", "find_until_last_paragraph", "ignore_illusion",
        "rmaff", "codepaste", "echoafftime", "startbalancewatch",  "endbalancewatch", "app", "config",
        "wait_tbl", "doaddfree", "getDefaultColorNums", "prompttrigger", "itf", "sacid",
        bottomprompt           = { read_only = false, other_fields = true },
        bottom_border          = { read_only = false },
        moveprompt             = { read_only = false },
        errorf                 = { read_only = false },
        balanceless            = { read_only = false },
        balanceful             = { read_only = false },
        echon                  = { read_only = false },
        contains               = { read_only = false },
        addaff                 = { read_only = false },
        addaffdict             = { read_only = false },
        rmaff                  = { read_only = false },
        removeaff              = { read_only = false },
        removeafflevel         = { read_only = false },
        can_usemana            = { read_only = false },
        force_send             = { read_only = false },
        newbals                = { read_only = false },
        check_sip              = { read_only = false },
        check_purgative        = { read_only = false },
        check_salve            = { read_only = false },
        check_herb             = { read_only = false },
        check_misc             = { read_only = false },
        check_smoke            = { read_only = false },
        check_moss             = { read_only = false },
        check_focus            = { read_only = false },
        checkanyaffs           = { read_only = false },
        check_balanceful_acts  = { read_only = false },
        check_balanceless_acts = { read_only = false },
        addbalanceless         = { read_only = false },
        removebalanceless      = { read_only = false },
        addbalanceful          = { read_only = false },
        removebalanceful       = { read_only = false },
        clearbalanceful        = { read_only = false },
        clearbalanceless       = { read_only = false },
        send_in_the_gnomes     = { read_only = false },
        update_rift_view       = { read_only = false },
        updateaffcount         = { read_only = false },
        lostbal_tree           = { read_only = false },
        lostbal_focus          = { read_only = false },
        lostbal_shrugging      = { read_only = false },
        lostbal_fitness        = { read_only = false },
        lostbal_rage           = { read_only = false },
        lostbal_voice          = { read_only = false },
        lostbal_sip            = { read_only = false },
        lostbal_moss           = { read_only = false },
        lostbal_purgative      = { read_only = false },
        lostbal_smoke          = { read_only = false },
        lostbal_dragonheal     = { read_only = false },
        lostbal_healing        = { read_only = false },
        lostbal_word           = { read_only = false },
        lostbal_herb           = { read_only = false },
        lostbal_salve          = { read_only = false },
        balanceful_used        = { read_only = false },
        getping                = { read_only = false },
        amiwielding            = { read_only = false },
        sendcuring             = { read_only = false },
        sendc                  = { read_only = false },
        lifevision             = { read_only = false, other_fields = true },
        watch                  = { read_only = false, other_fields = true },
        reenabled9multi        = { read_only = false },
        make_gnomes_work_async = { read_only = false },
        make_gnomes_work_sync  = { read_only = false },
        make_gnomes_work       = { read_only = false },
        ["9multicmd_cleared"]  = { read_only = false },
        pipes = {
          read_only = false,
          other_fields = true
        },
        sk = {
          read_only = true,
          other_fields = true,
          fields = {
            onpromptfuncs               = { read_only = false, other_fields = true },
            onpromptaifuncs               = { read_only = false, other_fields = true },
            onprompt_beforeaction_do               = { read_only = false },
            onprompt_beforelifevision_do               = { read_only = false },
            onprompt_beforelifevision_add               = { read_only = false },
            onprompt_beforeaction_add               = { read_only = false },
            gnomes_are_working               = { read_only = false },
            wont_heal_this               = { read_only = false },
            syncdebug               = { read_only = false },
            doingstuff_inslowmode               = { read_only = false },
            increasedlag               = { read_only = false },
            checkwillpower               = { read_only = false },
            lowwillpower                 = { read_only = false },
            lag_tickedonce                 = { read_only = false },
            reset_laglevel                 = { read_only = false },
            updatehealingmap                 = { read_only = false },
            inring                 = { read_only = false },
            morphsforskill                 = { read_only = false, other_fields = true },
            skillmorphs                 = { read_only = false, other_fields = true },
            healingmap                 = { read_only = false, other_fields = true },
            checking_herb_ai             = { read_only = false },
            paused_for_burrow             = { read_only = false },
            balance_controller           = { read_only = false },
            getuntilprompt               = { read_only = false },
            blockherbbal               = { read_only = false },
            makewarnings                 = { read_only = false },
            retardation_symptom          = { read_only = false },
            stupidity_symptom            = { read_only = false },
            illness_constitution_symptom = { read_only = false },
            transfixed_symptom           = { read_only = false },
            stun_symptom                 = { read_only = false },
            impale_symptom               = { read_only = false },
            aeon_symptom                 = { read_only = false },
            paralysis_symptom            = { read_only = false },
            haemophilia_symptom          = { read_only = false },
            webbed_symptom               = { read_only = false },
            roped_symptom                = { read_only = false },
            impaled_symptom              = { read_only = false },
            hypochondria_symptom         = { read_only = false },
            unparryable_symptom          = { read_only = false },
            warn                         = { read_only = false },
            retardation_count            = { read_only = false },
            stupidity_count              = { read_only = false },
            illness_constitution_count   = { read_only = false },
            transfixed_count             = { read_only = false },
            stun_count                   = { read_only = false },
            impale_count                 = { read_only = false },
            aeon_count                   = { read_only = false },
            paralysis_count              = { read_only = false },
            haemophilia_count            = { read_only = false },
            webbed_count                 = { read_only = false },
            roped_count                  = { read_only = false },
            impaled_count                = { read_only = false },
            hypochondria_count           = { read_only = false },
            unparryable_count            = { read_only = false },
            limbnames                    = { read_only = false },
            increase_lagconf             = { read_only = false },
            clearmorphs                  = { read_only = false },
            inamorph                     = { read_only = false },
            validmorphskill              = { read_only = false },
            inamorphfor                  = { read_only = false },
            updatemorphskill             = { read_only = false },
            enable_single_prompt         = { read_only = false },
            showstatchanges              = { read_only = false },
            have_parryable               = { read_only = false },
            cant_parry                   = { read_only = false },
            check_shipmode               = { read_only = false },
            sawcuring                    = { read_only = false },
            sawqueueing                  = { read_only = false },
            dosendqueue                  = { read_only = false },
            setup9multicmd               = { read_only = false },
            sendqueuecmd               = { read_only = false },
            fix_affs_and_defs         = { read_only = false },
            checkrewield         = { read_only = false },
            rewielddables         = { read_only = false },
            removed_something         = { read_only = false },
            check_burrow_pause         = { read_only = false },
            sendqueue         = { read_only = false, other_fields = true },
            sendqueuel         = { read_only = false },
            sendcuringtimer         = { read_only = false },
            retrieving_herbs         = { read_only = false },
            stopprocessing         = { read_only = false },
            warnings         = { read_only = false, other_fields = true },
          }
        },
        conf = {
          read_only = true,
          other_fields = true,
          fields = {
            arena = { read_only = false },
            batch = { read_only = false },
          }
        },
        dict = {
          read_only = true,
          other_fields = true,
          fields = {
            rewield = { read_only = false, other_fields = true },
          }
        },
        me = {
          read_only = true,
          other_fields = true,
          fields = {
            haveillusion = { read_only = false },
            unparryables = { read_only = false, other_fields = true },
          }
        },
        affs = { read_only = false, other_fields = true },
        affl = { read_only = false, other_fields = true },
        sys = {
          read_only = false,
          other_fields = true
        },
      }
    },
    send = { read_only = false },
    expandAlias = { read_only = false },
  }
}

files["raw-svo.dict.lua"] = {
  read_globals = {
    svo = {
      fields = {
        "defdefup", "defkeepup", "signals", "deepcopy", "rmaff", "apply", "lostbal_salve", "getHighestKey",
        "lostbal_herb", "eat", "me", "defs", "defences", "doingaction", "enabledclasses", "paragraph_length",
        "make_gnomes_work", "lostbal_purgative", "lostbal_focus", "lostbal_sip", "empty", "lostbal_healing",
        "lostbal_moss", "find_until_last_paragraph", "echof", "debugf", "lostbal_tree", "haveskillset",
        "sip", "doaction", "killaction", "checkany", "lostbal_smoke", "updateaffcount", "addaffdict", "oneconcatwithval",
        "can_usemana", "getping", "lostbal_voice", "lostbal_rage", "lostbal_fitness", "fullstats", "shrugging",
        "lostbal_shrugging", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
        "fitness",  "containsbyname", "assert", "defs_data", "concatand", "prio", "enabledskills", "show_info",
        "donext", "findbybal", "send_in_the_gnomes", "bals_in_use", "gettreeableaffs", "endbalancewatch", "valid",
        "tree", "restore", "dragonheal", "lostbal_dragonheal", "process_defs", "check_sp_satisfied", "sp_config",
        "will_take_balance", "lastlit", "fillpipe", "pflags", "pl", "syncdelay", "sendc", "config", "rage",
        dict                  = { read_only = false, other_fields = true },
        codepaste             = { read_only = false, other_fields = true },
        ignore                = { read_only = false, other_fields = true },
        affsp                 = { read_only = false, other_fields = true },
        lifevision            = { read_only = false, other_fields = true },
        actions               = { read_only = false, other_fields = true },
        affl                  = { read_only = false, other_fields = true },
        sps                   = { read_only = false, other_fields = true },
        basicdef              = { read_only = false },
        find_lowest_sync       = { read_only = false },
        make_prio_table       = { read_only = false },
        make_sync_prio_table  = { read_only = false },
        make_prio_tablef      = { read_only = false },
        make_sync_prio_tablef = { read_only = false },
        clear_balance_prios   = { read_only = false },
        clear_sync_prios      = { read_only = false },
        dict_validate         = { read_only = false },
        find_lowest_async     = { read_only = false },
        check_retardation     = { read_only = false },
        dict_balanceful       = { read_only = false, other_fields = true },
        dict_balanceless      = { read_only = false, other_fields = true },
        dict_balanceful_def   = { read_only = false, other_fields = true },
        dict_balanceless_def  = { read_only = false, other_fields = true },
        dict_herb             = { read_only = false, other_fields = true },
        dict_misc             = { read_only = false, other_fields = true },
        dict_misc_def         = { read_only = false, other_fields = true },
        dict_purgative        = { read_only = false, other_fields = true },
        dict_salve_def        = { read_only = false, other_fields = true },
        dict_smoke_def        = { read_only = false, other_fields = true },
        sys = {
          read_only = true,
          other_fields = true,
          fields = {
            input_to_actions = { read_only = false, other_fields = true },
            last_used        = { read_only = false, other_fields = true },
            sendonceonly     = { read_only = false },
            manualdiag       = { read_only = false },
            sp_satisfied     = { read_only = false },
            blockoutr        = { read_only = false },
          }
        },
        cnrl = {
          read_only = true,
          other_fields = true,
          fields = {
            warning        = { read_only = false, other_fields = true },
          }
        },
        affs = {
          read_only = true,
          other_fields = true,
          fields = {
            bleeding   = { read_only = false, other_fields = true },
            unknownany = { read_only = false, other_fields = true },
            webbed     = { read_only = false },
          }
        },
        bals = {
          read_only = true,
          other_fields = true,
          fields = {
            ['?'] = { read_only = false },
          }
        },
        defc = {
          read_only = true,
          other_fields = true,
          fields = {
            sileris = { read_only = false },
          }
        },
        rift = {
          read_only = true,
          other_fields = true,
          fields = {
            invcontents = { read_only = false, other_fields = true },
          }
        },
        me = {
          read_only = true,
          other_fields = true,
          fields = {
            manualdefcheck = { read_only = false },
          }
        },
        stats = {
          read_only = true,
          other_fields = true,
          fields = {
            age = { read_only = false },
          }
        },
        conf = {
          read_only = true,
          other_fields = true,
          fields = {
            paused = { read_only = false },
            send_bypass = { read_only = false },
          }
        },
        pipes = {
          read_only = true,
          other_fields = true,
          fields = {
            valerian = { read_only = false, other_fields = true },
            elm      = { read_only = false, other_fields = true },
            skullcap = { read_only = false, other_fields = true }
          }
        },
        sk = {
          read_only = true,
          other_fields = true,
          fields = {
            tremoloside         = { read_only = false, other_fields = true },
            didfootingattack    = { read_only = false },
            delaying_break      = { read_only = false },
            stupidity_count     = { read_only = false },
            smallbleedremove    = { read_only = false },
            next_burn           = { read_only = false },
            current_burn        = { read_only = false },
            previous_burn       = { read_only = false },
            forcelight_elm      = { read_only = false },
            forcelight_valerian = { read_only = false },
            forcelight_skullcap = { read_only = false },
            stopprocessing      = { read_only = false },
            diag_list           = { read_only = false },
            check_retardation           = { read_only = false },
            retardation_count           = { read_only = false },
            burns               = { read_only = false, other_fields = true },
            priochangecache     = { read_only = false, other_fields = true },
          }
        }
      }
    }
  }
}

files["raw-svo.empty.lua"] = {
  read_globals = {
    svo = {
      fields = {
        "lostbal_herb", "affs", "rmaff", "dict", "deepcopy", "debugf", "defences", "rmaff",
        empty = {
          read_only = false,
          other_fields = true
        },
        dict = {
          read_only = true,
          fields = {
            unknownmental       = { read_only = false, other_fields = true },
            unknownany          = { read_only = false, other_fields = true },
            unknowncrippledlimb = { read_only = false, other_fields = true },
            unknowncrippledarm  = { read_only = false, other_fields = true },
            unknowncrippledleg  = { read_only = false, other_fields = true },
            skullfractures      = { read_only = false, other_fields = true },
            crackedribs         = { read_only = false, other_fields = true },
            wristfractures      = { read_only = false, other_fields = true },
            torntendons         = { read_only = false, other_fields = true },
            cholerichumour      = { read_only = false, other_fields = true },
            melancholichumour   = { read_only = false, other_fields = true },
            phlegmatichumour    = { read_only = false, other_fields = true },
            sanguinehumour      = { read_only = false, other_fields = true },
          }
        },
        degenerateaffs  = { read_only = false },
        deteriorateaffs = { read_only = false },
        focuscurables   = { read_only = false },
        treecurables    = { read_only = false },
        gettreeableaffs = { read_only = false },
      }
    }
  }
}

files["raw-svo.misc.lua"] = {
  read_globals = {
    "Logger",
    svo = {
      fields = {
        "signals", "defs", "deepcopy", "assert", "conf", "affs", "lastpromptnumber", "innews", "cp", "sys", "pl",
        "sendc", "paragraph_length", "lifevision", "checkaction", "actions", "dict", "haveskillset", "config",
        gagline                    = { read_only = false },
        ignore                     = { read_only = false, other_fields = true },
        serverignore               = { read_only = false, other_fields = true },
        toboolean                  = { read_only = false },
        debugf                     = { read_only = false },
        errorf                     = { read_only = false },
        vecho                      = { read_only = false },
        getDefaultColor            = { read_only = false },
        updateloggingconfig        = { read_only = false },
        showprompt                 = { read_only = false },
        echof                      = { read_only = false },
        echofn                     = { read_only = false },
        echon                      = { read_only = false },
        itf                        = { read_only = false },
        snd                        = { read_only = false },
        getHighestKey              = { read_only = false },
        getDefaultColorNums        = { read_only = false },
        getLowestKey               = { read_only = false },
        getHighestValue            = { read_only = false },
        getBoundary                = { read_only = false },
        oneconcat                  = { read_only = false },
        oneconcatwithval           = { read_only = false },
        concatand                  = { read_only = false },
        concatandf                 = { read_only = false },
        keystolist                 = { read_only = false },
        longeststring              = { read_only = false },
        safeconcat                 = { read_only = false },
        deleteLineP                = { read_only = false },
        deleteAllP                 = { read_only = false },
        containsbyname             = { read_only = false },
        contains                   = { read_only = false },
        syncdelay                  = { read_only = false },
        events                     = { read_only = false },
        gevents                    = { read_only = false },
        convert_string             = { read_only = false },
        count_until_last_paragraph = { read_only = false },
        find_until_last_paragraph  = { read_only = false },
        convert_boolean            = { read_only = false },
        setdefaultprompt           = { read_only = false },
        setignore                  = { read_only = false },
        unsetignore                = { read_only = false },
        setserverignore            = { read_only = false },
        unsetserverignore          = { read_only = false },
        ceased_wielding            = { read_only = false },
        unwielded                  = { read_only = false },
        basictableindexdiff        = { read_only = false },
        update                     = { read_only = false },
        fancysend                  = { read_only = false },
        fancysendall               = { read_only = false },
        oldsend                    = { read_only = false },
        yep                        = { read_only = false },
        nope                       = { read_only = false },
        red                        = { read_only = false },
        green                      = { read_only = false },
        echos                      = { read_only = false, other_fields = true },
        echosd                     = { read_only = false, other_fields = true },
        sk = {
          read_only = true,
          fields = {
            checkrewield              = { read_only = false },
            reverse                   = { read_only = false },
            anytoshort                = { read_only = false },
            echofwindow               = { read_only = false },
            requested_deletelineP     = { read_only = false },
            systemscommands           = { read_only = false, other_fields = true },
            onprompt_beforeaction_add = { read_only = true },
          }
        },
        me = {
          read_only = true,
          fields = {
            wielded     = { read_only = false, other_fields = true },
            shippromptn = { read_only = true }
          }
        }
      }
    },
    decho = { read_only = false },
    echo = { read_only = false },
  }
}

files["raw-svo.setup.lua"] = {
  globals = {
    "color_table",
    svo = {
      fields = {
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "cpp", "defences", "lifevision", "signals",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "innews", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave", "sps", "defdefup", "defkeepup", "empty",
        debugf        = { read_only = true },
        rmaff         = { read_only = true },
        echof         = { read_only = true },
        addaff        = { read_only = true },
        prompttrigger = { read_only = true },
        update        = { read_only = true },
        killaction    = { read_only = true },
      }
    },
    Logger = {
      read_only = true,
      other_fields = true
    },
    gmcp = {
      read_only = true,
      other_fields = true,
    },
    table = {
      fields = {
        pickle = {
          read_only = true
        }
      }
    }
  }
}

files["raw-svo.actionsystem.lua"] = {
  read_globals = {
    svo = {
      fields = {
        "pl", "affs", "sys", "syncdelay", "debugf", "dict", "sk", "echof", "make_gnomes_work",
        "conf", "signals", "codepaste", "lifevision", "addaff", "assert", "addaffdict",
        doaction = {
          read_only = false
        },
        actions = {
          read_only = false,
          fields = {"set"}
        },
        actions_performed = {
          read_only = false,
          fields = {"?"}
        },
        bals_in_use = {
          read_only = false,
          other_fields = true
        },
        checkaction       = { read_only = false },
        checkany          = { read_only = false },
        findbybal         = { read_only = false },
        findbybals        = { read_only = false },
        actionclear       = { read_only = false },
        will_take_balance = { read_only = false },
        actionfinished    = { read_only = false },
        killaction        = { read_only = false },
        usingbal          = { read_only = false },
        usingbalance      = { read_only = false },
        doingaction       = { read_only = false },
        doing             = { read_only = false },
        haveorwill        = { read_only = false },
        valid_sync_action = { read_only = false },
        codepaste = {
          fields = {
            balanceful_codepaste = { read_only = false }
          }
        }
      }
    }
  }
}
