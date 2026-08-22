function svo.showupdatereminder(newversion)
  -- Remember which version the reminder is offering. The click handler used to
  -- read a bare `newversion` global that nothing ever assigned - only this
  -- function's parameter has that name - so it passed nil to the installer.
  svo.pending_update_version = newversion
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
  svo.install_update(svo.pending_update_version)
end

-- Is the file we just downloaded actually a whole Mudlet package? This exists
-- so a 404 page, an error page from a proxy, or a transfer that died halfway
-- cannot get as far as uninstalling the working system.
--
-- Checking the first two bytes for "PK" was not enough. A connection dropped
-- mid-transfer still starts with the local file header, so a truncated
-- download passed - and then uninstallPackage removed svof, installPackage
-- failed on an archive with no central directory, and the profile was left
-- with nothing. Verified against a 5000-byte prefix of the real 640787-byte
-- package: it passes the two-byte test and `unzip -t` says "cannot find
-- zipfile directory".
--
-- The end-of-central-directory record is what makes a zip readable, and it is
-- the last thing written, so its presence is the cheap way to ask "did the
-- whole file arrive". It sits at the very end unless the archive carries a
-- comment, which can be up to 65535 bytes.
local EOCD = "PK\5\6"
local MAX_EOCD_OFFSET = 65557          -- 22-byte record + max comment

function svo.update_looks_like_package(path)
  local f = io.open(path, "rb")
  if not f then return false, "the downloaded file isn't there" end
  local head = f:read(4)
  local size = f:seek("end")
  if head ~= "PK\3\4" then
    f:close()
    return false, string.format("it isn't a package (%d bytes, starting %q)",
                                size or 0, tostring(head))
  end
  local tail_len = math.min(size, MAX_EOCD_OFFSET)
  f:seek("set", size - tail_len)
  local tail = f:read(tail_len) or ""
  f:close()
  if not tail:find(EOCD, 1, true) then
    return false, string.format(
      "the download is incomplete (%d bytes, no end-of-archive record)", size)
  end
  return true
end

-- Ask Mudlet what is installed rather than trusting a return value.
--
-- Host::uninstallPackage returned nothing at all until a6b1c4504, first
-- shipped in Mudlet 4.20, so `local removed = uninstallPackage("svof")` is nil
-- on every supported Mudlet older than that and the branch that told the user
-- how to recover could never fire. Host::installPackage is worse: while a
-- profile save is in flight it returns {true, ""} and defers the real work, so
-- its "true" means "accepted", not "installed".
function svo.package_installed(name)
  for _, n in ipairs(getPackages() or {}) do
    if n == name then return true end
  end
  return false
end

-- Downloads the package, then installs it from the local file. Announcing the
-- result is svo.update_download_done / svo.update_download_error's job.
--
-- This used to be uninstallPackage("svof") followed by installPackage(url) and
-- an immediate "installed, please restart". Both halves were wrong. The
-- download is asynchronous - installPackage(url) returns before it resolves -
-- so the success line printed on a 404 as readily as on a success, and the
-- uninstall had already removed the running system by then. A failed update
-- left the profile with no svof at all and a green message saying it had
-- worked.
--
-- The uninstall still has to happen - Mudlet refuses to install over an
-- existing package - but it belongs in svo.install_downloaded_package, once
-- the replacement is on disk and has been checked, not out here in front of an
-- asynchronous download that may never arrive.
function svo.install_update(version, url)
  version = version or svo.pending_update_version
  url = url or svo.pending_update_url or svo.update_package_url(svo.pending_update_tag or version)

  if svo.update_target then
    svo.echof("Already downloading Svof %s - hold on.", tostring(svo.update_version))
    return
  end

  svo.echof("Installing Svof %s...", tostring(version))

  -- config is saved first: anything unsaved would be lost across the restart
  if svo.signals and svo.signals.saveconfig then
    pcall(function() svo.signals.saveconfig:emit() end)
  end

  svo.update_version = version
  svo.update_target = getMudletHomeDir() .. "/svof-update.mpackage"

  -- downloadFile returns nil, reason if it will not even start, and raises no
  -- event in that case. pcall's `ok` is true either way, so branching on it
  -- alone left svo.update_target set forever: every later attempt, including a
  -- hand-typed vupdate, answered "Already downloading" until Mudlet restarted.
  local ok, started, why = pcall(downloadFile, svo.update_target, url)
  if not ok then why = started end
  if not ok or not started then
    svo.update_target, svo.update_version = nil, nil
    svo.echof("Couldn't start the download for Svof %s: %s", tostring(version), tostring(why))
    return
  end

  if svo.updatelabel then
    svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Downloading Svof...<p>]])
  end
end

-- Replaces the old system with the downloaded one, and reports what actually
-- happened rather than what was asked for.
--
-- Mudlet will not install a package over an existing one: Host::installPackage
-- checks mInstalledPackages on the archive name and again on the package's own
-- config.lua, and muddler writes mpackage = [[svof]] into that file, so the
-- second check refuses svof-update.mpackage every time. The old system
-- therefore has to go first - but only once the replacement is on disk and has
-- been verified, never in front of an asynchronous download that may not
-- arrive.
--
-- Both calls are asked about by their effect, not their return value. See
-- svo.package_installed.
local UNINSTALL_ATTEMPTS = 4

function svo.install_downloaded_package(target, version, attempt)
  attempt = attempt or 1

  if attempt == 1 then
    local sane, why = svo.update_looks_like_package(target)
    if not sane then
      svo.echof("Downloaded Svof %s but %s - keeping the version you have.",
                tostring(version), why)
      if svo.updatelabel then svo.updatelabel:hide() end
      return
    end
  end

  pcall(uninstallPackage, "svof")

  -- A refused uninstall is fatal, not something to carry on past. Mudlet
  -- declines while a profile save is in flight and says so by returning false
  -- on 4.20+ and by returning nothing before that, so this used to read as
  -- success: the install that followed was then refused as "already
  -- installed", installPackage answered true anyway, and the user was told
  -- Svof had updated while nothing had changed - restart, still on the old
  -- version, and the check re-offers the same update forever. Mudlet saves the
  -- profile after every package install and uninstall, each measured at 100 to
  -- 200ms, so the window is ordinary. The refusal is transient, which
  -- svo.remove_legacy_modules already knew and this path did not.
  if svo.package_installed("svof") then
    if attempt < UNINSTALL_ATTEMPTS then
      tempTimer(2, function()
        svo.install_downloaded_package(target, version, attempt + 1)
      end)
      return
    end
    svo.echof("Mudlet wouldn't let go of the installed Svof to make room for %s "
              .. "- it stays busy saving the profile. Nothing was changed, "
              .. "you're still on %s. Try again in a moment.",
              tostring(version), tostring(svo.version))
    if svo.updatelabel then svo.updatelabel:hide() end
    return
  end

  local ok, err = pcall(installPackage, target)

  -- installPackage's own answer proves nothing either: it returns {true, ""}
  -- and defers when a save is in flight, and returns nil, msg rather than
  -- raising when it refuses. Ask what is installed.
  if not svo.package_installed("svof") then
    svo.echof("Downloaded Svof %s but Mudlet didn't install it: %s",
              tostring(version), tostring(ok and err or "no reason given"))
    svo.echof("Svof is not installed right now. The package is at %s - open it "
              .. "with Mudlet's Package Manager to get back.", target)
    if svo.updatelabel then svo.updatelabel:hide() end
    return
  end

  -- Only now, with the new package unpacked and listed, is the download
  -- disposable. Mudlet's own installPackageFromUrl removes it too; this used to
  -- leave 640 KB in the profile directory after every successful update.
  os.remove(target)

  cecho("\n<green_yellow>Svof: installed " .. tostring(version) ..
        ". Please restart Mudlet to finish.\n")

  if svo.updatelabel then
    svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Svof updated! Please restart Mudlet.<p>]])
    tempTimer(10, function() if svo.updatelabel then svo.updatelabel:hide() end end)
  end
end
