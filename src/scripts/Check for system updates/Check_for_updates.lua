local downloadfolder = getMudletHomeDir().."/svo/downloads/"

-- this should get called at start and every hour after that
function svo.checkforupdates(type)
  local baseUrl = string.format("http://svof.github.io/svof/%s/", svo.conf.releasechannel)
 
	if svo.checkingupdates then return end
  svo.versionfile = downloadfolder.."svo_version"

  if not lfs.attributes(downloadfolder) then
     local t,s = lfs.mkdir(downloadfolder)
     if not t and s ~= "File exists" then svo.echof("Couldn't make the '"..downloadfolder.."' folder; "..s) return end
  end

  svo.checkingupdates = true
  downloadFile(svo.versionfile, baseUrl .. "current_version.txt")

  if type == "checking" then
    svo.echof("Checking for updates...")
    svo.announceupdates = "checking"
  elseif type == "force" then
    svo.echof("(re)downloading latest system...")
    svo.announceupdates = "force"
    svo.version = 0


    local location = getMudletHomeDir().."/svo/downloads/available_version"
    if io.exists(location) then
      local s,m = os.remove(location)
      if not s then svo.echof("Couldn't remove the %s file (error was: %s) - this might be a problem.", location, m) end
    end
    for k,v in pairs(svo.modules_list) do
      location = downloadfolder .. v .. ".xml"
      if io.exists(location) then
        local s,m = os.remove(location)
        if not s then svo.echof("Couldn't delete the old xml (located at %s), because of: %s. This might be a problem.", location, m) end
      end
    end
  else
    svo.announceupdates = nil
  end
end

-- downloads the system & updates the system version saved
function svo.downloadnewsystem(newversion)
--  local baseUrl = string.format("http://svof.github.io/svof/%s/", svo.conf.releasechannel)
  local baseUrl = "https://github.com/svof/svof/raw/in-client-svof/"
	svo.downloadedsystem = svo.downloadedsystem or {}
  downloadingModules = 0
  if downloadTimer then killTimer(downloadTimer) end
  downloadTimer = tempTimer(10, "downloadingModules = nil killTimer(downloadTimer) downloadTimer = nil")
  -- also include base install file 
  local downloadUrl = baseUrl .. string.gsub("svo (install me in module manager)"," ", "%%20") .. ".xml"
  downloadFile(downloadfolder .. "svo (install me in module manager).xml", downloadUrl)
  svo.downloadedsystem["svo (install me in module manager)"] = false
  downloadingModules = downloadingModules + 1
  --download all the modules in the modules_list
  for k,v in pairs(svo.modules_list) do
    local downloadUrl = baseUrl .. v:gsub(" ", "%%20") .. ".xml"
    downloadFile(downloadfolder .. v .. ".xml", downloadUrl)
    svo.downloadedsystem[v] = false
    downloadingModules = downloadingModules + 1
  end
  
  svo.newdownloadedversion = newversion
end