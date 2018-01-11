max_line_length = false

read_globals = {
  "atcp", "gmcp",
  -- Mudlets API
  table = {
    fields = {
      "contains",
      "save",
      "load",
      "n_complement",
      "index_of",
    }
  },
  string = {
    fields = {
      "split",
    }
  },
  "sendAll", "dinsertText", "cecho", "decho", "expandAlias", "echo", "selectString", "selectSection", "replace", "setBgColor", "setFgColor", "tempTimer", "tempTrigger", "tempRegexTrigger", "closeMudlet", "loadWindowLayout", "saveWindowLayout", "setFontSize", "getFontSize", "openUserWindow", "echoUserWindow", "enableTimer", "disableTimer", "enableKey", "disableKey", "killKey", "clearUserWindow", "clearWindow", "killTimer", "moveCursor", "getLines", "getLineNumber", "insertHTML", "insertText", "enableTrigger", "disableTrigger", "killTrigger", "getLineCount", "getColumnNumber", "send", "selectCaptureGroup", "tempLineTrigger", "raiseEvent", "deleteLine", "copy", "cut", "paste", "pasteWindow", "debugc", "setWindowWrap", "setWindowWrapIndent", "resetFormat", "moveCursorEnd", "getLastLineNumber", "getNetworkLatency", "createMiniConsole", "createLabel", "raiseWindow", "lowerWindow", "hideWindow", "showWindow", "createBuffer", "createStopWatch", "getStopWatchTime", "stopStopWatch", "startStopWatch", "resetStopWatch", "closeUserWindow", "resizeWindow", "appendBuffer", "setBackgroundImage", "setBackgroundColor", "createButton", "setLabelClickCallback", "setLabelDoubleClickCallback", "setLabelReleaseCallback", "setLabelMoveCallback", "setLabelWheelCallback", "setLabelOnEnter", "setLabelOnLeave", "moveWindow", "setTextFormat", "getMainWindowSize", "getMousePosition", "getCurrentLine", "setMiniConsoleFontSize", "selectCurrentLine", "spawn", "getButtonState", "showToolBar", "hideToolBar", "loadRawFile", "setBold", "setItalics", "setUnderline", "setStrikeOut", "disconnect", "tempButtonToolbar", "tempButton", "setButtonStyleSheet", "reconnect", "getMudletHomeDir", "getMudletLuaDefaultPaths", "setTriggerStayOpen", "wrapLine", "getFgColor", "getBgColor", "tempColorTrigger", "isAnsiFgColor", "isAnsiBgColor", "stopSounds", "playSoundFile", "setBorderTop", "setBorderBottom", "setBorderLeft", "setBorderRight", "setBorderColor", "setConsoleBufferSize", "enableScrollBar", "disableScrollBar", "startLogging", "calcFontSize", "permRegexTrigger", "permSubstringTrigger", "permBeginOfLineStringTrigger", "tempComplexRegexTrigger", "permTimer", "permAlias", "permKey", "tempKey", "exists", "isActive", "enableAlias", "tempAlias", "disableAlias", "killAlias", "setLabelStyleSheet", "getTime", "invokeFileDialog", "getTimestamp", "setLink", "deselect", "insertLink", "echoLink", "echoPopup", "insertPopup", "setPopup", "sendATCP", "hasFocus", "isPrompt", "feedTriggers", "sendTelnetChannel102", "setRoomWeight", "getRoomWeight", "gotoRoom", "setMapperView", "getRoomExits", "lockRoom", "createMapper", "getMainConsoleWidth", "resetProfile", "printCmdLine", "searchRoom", "clearCmdLine", "getAreaTable", "getAreaTableSwap", "getAreaRooms", "getPath", "centerview", "denyCurrentSend", "tempBeginOfLineTrigger", "tempExactMatchTrigger", "sendGMCP", "roomExists", "addRoom", "setExit", "setRoomCoordinates", "getRoomCoordinates", "createRoomID", "getRoomArea", "setRoomArea", "resetRoomArea", "setAreaName", "roomLocked", "setCustomEnvColor", "getCustomEnvColorTable", "setRoomEnv", "setRoomName", "getRoomName", "setGridMode", "solveRoomCollisions", "addSpecialExit", "removeSpecialExit", "getSpecialExits", "getSpecialExitsSwap", "clearSpecialExits", "getRoomEnv", "getRoomUserData", "setRoomUserData", "searchRoomUserData", "getRoomsByPosition", "clearRoomUserData", "clearRoomUserDataItem", "downloadFile", "appendCmdLine", "getCmdLine", "openUrl", "sendSocket", "setRoomIDbyHash", "getRoomIDbyHash", "addAreaName", "getRoomAreaName", "deleteArea", "deleteRoom", "setRoomChar", "getRoomChar", "registerAnonymousEventHandler", "saveMap", "loadMap", "setMainWindowSize", "setAppStyleSheet", "sendIrc", "getIrcNick", "getIrcServer", "getIrcChannels", "getIrcConnectedHost", "setIrcNick", "setIrcServer", "setIrcChannels", "restartIrc", "connectToServer", "getRooms", "createMapLabel", "deleteMapLabel", "highlightRoom", "unHighlightRoom", "getMapLabels", "getMapLabel", "lockExit", "hasExitLock", "lockSpecialExit", "hasSpecialExitLock", "setExitStub", "connectExitStub", "getExitStubs", "getExitStubs1", "setModulePriority", "getModulePriority", "updateMap", "addMapEvent", "removeMapEvent", "getMapEvents", "addMapMenu", "removeMapMenu", "getMapMenus", "installPackage", "installModule", "uninstallModule", "reloadModule", "exportAreaImage", "createMapImageLabel", "setMapZoom", "uninstallPackage", "setExitWeight", "setDoor", "getDoors", "getExitWeights", "addSupportedTelnetOption", "setMergeTables", "getModulePath", "getAreaExits", "auditAreas", "sendMSDP", "handleWindowResizeEvent", "addCustomLine", "getCustomLines", "getMudletVersion", "openWebPage", "getAllRoomEntrances", "getRoomUserDataKeys", "getAllRoomUserData", "searchAreaUserData", "getMapUserData", "getAreaUserData", "setMapUserData", "setAreaUserData", "getAllAreaUserData", "getAllMapUserData", "clearAreaUserData", "clearAreaUserDataItem", "clearMapUserData", "clearMapUserDataItem", "setDefaultAreaVisible", "getProfileName", "raiseGlobalEvent", "saveProfile", "setServerEncoding", "getServerEncoding", "getServerEncodingsList", "alert", "tempPromptTrigger", "permPromptTrigger", "getColumnCount", "getRowCount"}

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
        "lostbal_shrugging", "actions", "usingbal", "check_generics", "reset", "sendcuring", "ignore_illusion",
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
            unknownmental = { read_only = false, other_fields = true },
            unknownany = { read_only = false, other_fields = true },
            unknowncrippledlimb = { read_only = false, other_fields = true },
            unknowncrippledarm = { read_only = false, other_fields = true },
            unknowncrippledleg = { read_only = false, other_fields = true },
            skullfractures = { read_only = false, other_fields = true },
            crackedribs = { read_only = false, other_fields = true },
            wristfractures = { read_only = false, other_fields = true },
            torntendons = { read_only = false, other_fields = true },
            cholerichumour = { read_only = false, other_fields = true },
            melancholichumour = { read_only = false, other_fields = true },
            phlegmatichumour = { read_only = false, other_fields = true },
            sanguinehumour = { read_only = false, other_fields = true },
          }
        },
        degenerateaffs = { read_only = false },
        deteriorateaffs = { read_only = false },
        focuscurables = { read_only = false },
        treecurables = { read_only = false },
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
            fix_affs_and_defs         = { read_only = false },
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
        "conf", "signals", "codepaste", "lifevision", "addaff",
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
