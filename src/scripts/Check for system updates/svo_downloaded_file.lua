function svo_downloaded_file(_, filename)
  -- is the file that downloaded our oursystem?

  if filename == tostring(svo.versionfile) then
    svo.checkingupdates = false

    local s = io.open(filename):read("*a")
    if tonumber(svo.version) >= tonumber(s:trim()) then
      if svo.announceupdates == "checking" then
        svo.announceupdates = nil
        svo.echof("You're all good! Latest version is %s and you're on it.", svo.version)
      end
      return
    end

    -- new version? See if we've already downloaded it, if not, do so
    local f = io.open(getMudletHomeDir().."/svo/downloads/available_version")

    local writtenversion

    -- new version file can not exist if we didn't download a system previously
    if f then
      writtenversion = f:read("*a")
    end
    
    if svo.announceupdates == "force" then
      svo.downloadnewsystem(s:trim())
    else
      if not writtenversion or writtenversion:trim() ~= s:trim() then
        if svo.announceupdates == "checking" then svo.echof("A new Svof is available! You're on %s, latest is %s. Want to download it now?", svo.version, s:trim()) end
          svo.showupdatereminder(s:trim())
      end
    end
  
  elseif filename:match("(svo \(.+\)\.xml)$") then
    svo.installsystem(filename)
  end  
end