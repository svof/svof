function svo.showupdatereminder(newversion)
  --svo.announceupdates = nil
  svo.updatelabel = svo.updatelabel or Geyser.Label:new({
    name = "svo.updatelabel",
    x = "-340px", y = "-115px",
    width = "320px", height = "110px",
  })

  svo.doupdatelabel = svo.doupdatelabel or Geyser.Label:new({
    name = "svo.doupdatelabel",
    x = "25%", y = "-30px",
    width = "20%", height = "20px",
  }, svo.updatelabel)

  svo.dontupdatelabel = svo.dontupdatelabel or Geyser.Label:new({
    name = "svo.dontupdatelabel",
    x = "55%", y = "-30px",
    width = "20%", height = "20px",
  }, svo.updatelabel)

  -- grey to black shade, top to bottom
  svo.updatelabel:setStyleSheet([[
      margin: 0px;
      padding: 2px;

      /* Vertical gradient */
      background: qlineargradient(
          x1: 0, y1: 0, x2: 0, y2: 1,
          stop: 0 #3c3c3c, stop: 1 #232323
      );

      border: none;
      border-radius: 4px;

      color: #ffffff;

    qproperty-alignment: 'AlignTop | AlignHCenter';
    qproperty-wordWrap: true;
    font-family: 'Ubuntu','Calibri',serif;
  ]])

  svo.doupdatelabel:setStyleSheet([[
    border-radius: 4px;
    border-style: double;
    border-width: 2px;
    border-color: green;
    font-family: monospace;
  ]])

  svo.dontupdatelabel:setStyleSheet([[
    border-radius: 4px;
    border-style: double;
    border-width: 2px;
    border-color: grey;
    font-family: monospace;
  ]])

  svo.updatelabel:echo(string.format([[<p align="center" style="font-size:10pt; color:white">Hey, a new Svof (%s) is available for download!<br><br>Install and restart now, or install later?<p>]], newversion))

  svo.doupdatelabel:echo([[<p align="center" style="font-size:8pt; color:white">Install</p]])

  svo.dontupdatelabel:echo([[<p align="center" style="font-size:8pt; color:white">Later</p]])

  svo.updatelabel:show()
  svo.doupdatelabel:show()
  svo.dontupdatelabel:show()

  svo.doupdatelabel:setClickCallback("svo_doupdate_click")
  svo.dontupdatelabel:setClickCallback("svo_dontupdate_click")
end

function svo_dontupdate_click()
  svo.updatelabel:hide()
  svo.doupdatelabel:hide()
  svo.dontupdatelabel:hide()
end

function svo_doupdate_click()
  svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Updating Svo...<p>]])
  svo.doupdatelabel:hide()
  svo.dontupdatelabel:hide()
  svo.downloadnewsystem(newversion)
end

function svo.installsystem(filename)
    local moduleName = filename:match("(svo \(.+\))\.xml$")
    downloadingModules = downloadingModules - 1
    svo.downloadedsystem[moduleName] = true
    if downloadingModules and downloadingModules ~= 0 then return end
    local dlDir = getMudletHomeDir() .. "/svo/downloads/"
    local installDir = getModulePath("svo (install me in module manager)") 
    installDir= installDir:sub(1, #installDir-38)
    for k in lfs.dir(installDir) do
      if k:ends(".xml") then
        os.remove(installDir .. k)
      end
    end
    for k,v in pairs(svo.downloadedsystem) do 
      if v then
        os.rename(dlDir .. k .. ".xml", installDir .. k .. ".xml")
        reloadModule(k)
        svo.downloadedsystem[k] = nil
      end
    end
    svo.echof("New version installed and ready to go! Please restart mudlet to finalize cleanup.")
    
    if svo.updatelabel and svo.announceupdates == "checking" then 
    svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Svof updated! Please restart Mudlet.<p>]])
    svo.updatelabel:setStyleSheet([[
        margin: 0px;
        padding: 2px;

        /* Vertical gradient */
        background: qlineargradient(
            x1: 0, y1: 0, x2: 0, y2: 1,
            stop: 0 #3c3c3c, stop: 1 #232323
        );

        border: none;
        border-radius: 4px;

        color: #ffffff;

      qproperty-alignment: 'AlignVCenter | AlignHCenter';
      qproperty-wordWrap: true;
      font-family: 'Ubuntu','Calibri',serif;
    ]])
		
		tempTimer(10, function() svo.updatelabel:hide() end)
  end
end