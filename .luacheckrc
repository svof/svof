
read_globals = {
  "atcp", "gmcp",
  -- Mudlets API
  table = {
    fields = {
      "contains",
      "save",
      "load",
    }
  },
  "dinsertText", "cecho", "decho", "showUnzipProgress", "wait", "expandAlias", "echo", "selectString", "selectSection", "replace", "setBgColor", "setFgColor", "tempTimer", "tempTrigger", "tempRegexTrigger", "closeMudlet", "loadWindowLayout", "saveWindowLayout", "setFontSize", "getFontSize", "openUserWindow", "echoUserWindow", "enableTimer", "disableTimer", "enableKey", "disableKey", "killKey", "clearUserWindow", "clearWindow", "killTimer", "moveCursor", "getLines", "getLineNumber", "insertHTML", "insertText", "enableTrigger", "disableTrigger", "killTrigger", "getLineCount", "getColumnNumber", "send", "selectCaptureGroup", "tempLineTrigger", "raiseEvent", "deleteLine", "copy", "cut", "paste", "pasteWindow", "debugc", "setWindowWrap", "setWindowWrapIndent", "resetFormat", "moveCursorEnd", "getLastLineNumber", "getNetworkLatency", "createMiniConsole", "createLabel", "raiseWindow", "lowerWindow", "hideWindow", "showWindow", "createBuffer", "createStopWatch", "getStopWatchTime", "stopStopWatch", "startStopWatch", "resetStopWatch", "closeUserWindow", "resizeWindow", "appendBuffer", "setBackgroundImage", "setBackgroundColor", "createButton", "setLabelClickCallback", "setLabelDoubleClickCallback", "setLabelReleaseCallback", "setLabelMoveCallback", "setLabelWheelCallback", "setLabelOnEnter", "setLabelOnLeave", "moveWindow", "setTextFormat", "getMainWindowSize", "getMousePosition", "getCurrentLine", "setMiniConsoleFontSize", "selectCurrentLine", "spawn", "getButtonState", "showToolBar", "hideToolBar", "loadRawFile", "setBold", "setItalics", "setUnderline", "setStrikeOut", "disconnect", "tempButtonToolbar", "tempButton", "setButtonStyleSheet", "reconnect", "getMudletHomeDir", "getMudletLuaDefaultPaths", "setTriggerStayOpen", "wrapLine", "getFgColor", "getBgColor", "tempColorTrigger", "isAnsiFgColor", "isAnsiBgColor", "stopSounds", "playSoundFile", "setBorderTop", "setBorderBottom", "setBorderLeft", "setBorderRight", "setBorderColor", "setConsoleBufferSize", "enableScrollBar", "disableScrollBar", "startLogging", "calcFontSize", "permRegexTrigger", "permSubstringTrigger", "permBeginOfLineStringTrigger", "tempComplexRegexTrigger", "permTimer", "permAlias", "permKey", "tempKey", "exists", "isActive", "enableAlias", "tempAlias", "disableAlias", "killAlias", "setLabelStyleSheet", "getTime", "invokeFileDialog", "getTimestamp", "setLink", "deselect", "insertLink", "echoLink", "echoPopup", "insertPopup", "setPopup", "sendATCP", "hasFocus", "isPrompt", "feedTriggers", "sendTelnetChannel102", "setRoomWeight", "getRoomWeight", "gotoRoom", "setMapperView", "getRoomExits", "lockRoom", "createMapper", "getMainConsoleWidth", "resetProfile", "printCmdLine", "searchRoom", "clearCmdLine", "getAreaTable", "getAreaTableSwap", "getAreaRooms", "getPath", "centerview", "denyCurrentSend", "tempBeginOfLineTrigger", "tempExactMatchTrigger", "sendGMCP", "roomExists", "addRoom", "setExit", "setRoomCoordinates", "getRoomCoordinates", "createRoomID", "getRoomArea", "setRoomArea", "resetRoomArea", "setAreaName", "roomLocked", "setCustomEnvColor", "getCustomEnvColorTable", "setRoomEnv", "setRoomName", "getRoomName", "setGridMode", "solveRoomCollisions", "addSpecialExit", "removeSpecialExit", "getSpecialExits", "getSpecialExitsSwap", "clearSpecialExits", "getRoomEnv", "getRoomUserData", "setRoomUserData", "searchRoomUserData", "getRoomsByPosition", "clearRoomUserData", "clearRoomUserDataItem", "downloadFile", "appendCmdLine", "getCmdLine", "openUrl", "sendSocket", "setRoomIDbyHash", "getRoomIDbyHash", "addAreaName", "getRoomAreaName", "deleteArea", "deleteRoom", "setRoomChar", "getRoomChar", "registerAnonymousEventHandler", "saveMap", "loadMap", "setMainWindowSize", "setAppStyleSheet", "sendIrc", "getIrcNick", "getIrcServer", "getIrcChannels", "getIrcConnectedHost", "setIrcNick", "setIrcServer", "setIrcChannels", "restartIrc", "connectToServer", "getRooms", "createMapLabel", "deleteMapLabel", "highlightRoom", "unHighlightRoom", "getMapLabels", "getMapLabel", "lockExit", "hasExitLock", "lockSpecialExit", "hasSpecialExitLock", "setExitStub", "connectExitStub", "getExitStubs", "getExitStubs1", "setModulePriority", "getModulePriority", "updateMap", "addMapEvent", "removeMapEvent", "getMapEvents", "addMapMenu", "removeMapMenu", "getMapMenus", "installPackage", "installModule", "uninstallModule", "reloadModule", "exportAreaImage", "createMapImageLabel", "setMapZoom", "uninstallPackage", "setExitWeight", "setDoor", "getDoors", "getExitWeights", "addSupportedTelnetOption", "setMergeTables", "getModulePath", "getAreaExits", "auditAreas", "sendMSDP", "handleWindowResizeEvent", "addCustomLine", "getCustomLines", "getMudletVersion", "openWebPage", "getAllRoomEntrances", "getRoomUserDataKeys", "getAllRoomUserData", "searchAreaUserData", "getMapUserData", "getAreaUserData", "setMapUserData", "setAreaUserData", "getAllAreaUserData", "getAllMapUserData", "clearAreaUserData", "clearAreaUserDataItem", "clearMapUserData", "clearMapUserDataItem", "setDefaultAreaVisible", "getProfileName", "raiseGlobalEvent", "saveProfile", "setServerEncoding", "getServerEncoding", "getServerEncodingsList", "alert", "tempPromptTrigger", "permPromptTrigger", "getColumnCount", "getRowCount"}

files["raw-svo.misc.lua"] = {
  read_globals = {
    "Logger",
    svo = {
      fields = {
        "signals", "sk", "defs", "deepcopy", "assert", "conf",
        toboolean = { read_only = false },
        vecho = { read_only = false },
        echos = { read_only = false, other_fields = true },
        echosd = { read_only = false, other_fields = true },
      }
    }
  }
}

files["raw-svo.setup.lua"] = {
  globals = {
    "color_table",
    svo = {
      fields = {
        "version", "pl", "phpTable", "ripairs", "affs", "balanceless", "cp", "defences", "lifevision", "signals", "sps",
         "sys", "conf", "config", "defc", "defs", "dragonheal", "lifep", "lifevision", "paragraph_length", "restore",
         "shrugging", "sp", "sp_config", "stats", "tree", "rage", "fitness", "valid", "watch", "gaffl", "gdefc",
         "actions", "sk", "vm", "cn", "cnrl", "prio", "reset", "affl", "serverignore", "ignore", "dict", "me",
         "knownskills", "haveskillset", "logging_in", "dont_unpause_login", "innews", "danaeusaffs", "nemesisaffs",
         "scragaffs", "index_map", "lastpromptnumber", "promptcount", "send", "pipes", "affsp", "rift", "install",
         "echosd", "echos", "life", "pflags", "paragraph_length", "es_categories", "es_shortnames", "es_shortnamesr",
         "es_potions", "es_categories", "assert", "deepcopy", "tablesave",
        debugf        = { read_only = true },
        removeaff     = { read_only = true },
        echof         = { read_only = true },
        addaff        = { read_only = true },
        prompttrigger = { read_only = true },
        update        = { read_only = true },
        killaction        = { read_only = true },
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
        actionfinished = { read_only = false },
        killaction = { read_only = false },
        usingbal = { read_only = false },
        usingbalance = { read_only = false },
        doingaction = { read_only = false },
        doing = { read_only = false },
        haveorwill = { read_only = false },
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
