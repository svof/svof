-- sysDownloadDone fires for every download the profile makes, so check that
-- this one is ours before acting - the same guard svo.update_http_done uses.
--
-- This exists because installing is asynchronous. The engine used to call
-- installPackage(url) and echo "installed, please restart" on the next line,
-- which printed whether the download succeeded or 404'd. Announcing from here
-- means the message reports what actually happened.
function svo.update_download_done(_, path)
  if not svo.update_target or path ~= svo.update_target then return end

  local target, version = svo.update_target, svo.update_version
  svo.update_target, svo.update_version = nil, nil

  -- A download that "succeeded" is not necessarily a package. A 404 page or a
  -- captive-portal redirect arrives as a perfectly good file, and uninstalling
  -- the running system for one of those is how the previous version left
  -- profiles with no svof at all. Check before touching anything.
  local sane, why = svo.update_looks_like_package(target)
  if not sane then
    svo.echof("Downloaded Svof %s but %s - keeping the version you have.",
              tostring(version), why)
    if svo.updatelabel then svo.updatelabel:hide() end
    return
  end

  -- Mudlet will NOT install a package over an existing one. Host::installPackage
  -- checks mInstalledPackages twice: once on the archive name, and again after
  -- reading the package's own config.lua. muddler writes mpackage = [[svof]]
  -- into that file, so svof-update.mpackage clears the first check and is
  -- refused by the second every single time. The old flow got away with
  -- uninstalling first; doing it here is safe in the way the old flow was not,
  -- because by now the replacement is already on disk and verified.
  local removed = uninstallPackage("svof")

  -- installPackage returns nil, msg rather than raising, so pcall's `ok` is
  -- true for a refusal and the success line below printed unconditionally:
  -- click Install, restart, still on the old version, no error, and the check
  -- re-offers the same update forever. Branch on the returned value, not on
  -- `ok` - the same lesson svo.remove_legacy_modules had to learn about
  -- uninstallModule.
  local ok, installed, err = pcall(installPackage, target)
  if not ok then
    svo.echof("Downloaded Svof %s but couldn't install it: %s", tostring(version), tostring(installed))
    if svo.updatelabel then svo.updatelabel:hide() end
    return
  end
  if not installed then
    svo.echof("Downloaded Svof %s but Mudlet refused to install it: %s",
              tostring(version), tostring(err))
    if removed then
      svo.echof("The version you had was removed to make room for it. The package is at %s - install it by hand to get back.", target)
    end
    if svo.updatelabel then svo.updatelabel:hide() end
    return
  end

  cecho("\n<green_yellow>Svof: installed " .. tostring(version) ..
        ". Please restart Mudlet to finish.\n")

  if svo.updatelabel then
    svo.updatelabel:echo([[<p align="center" style="font-size:10pt; color:white">Svof updated! Please restart Mudlet.<p>]])
    tempTimer(10, function() if svo.updatelabel then svo.updatelabel:hide() end end)
  end
end
