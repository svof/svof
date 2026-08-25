-- sysDownloadDone fires for every download the profile makes, so check that
-- this one is ours before acting - the same guard svo.update_http_done uses.
--
-- This exists because installing is asynchronous. The engine used to call
-- installPackage(url) and echo "installed, please restart" on the next line,
-- which printed whether the download succeeded or 404'd. Announcing from the
-- install engine means the message reports what actually happened.
--
-- The body is deliberately tiny, and everything real happens one turn later.
-- Host::raiseEvent copies the raw TScript* list and walks it (Host.cpp:1823),
-- and svof has THREE scripts on sysDownloadDone, not one: this,
-- ndb.support and ndb.downloaded_file. Uninstalling svof from inside the walk
-- deletes all three TScripts, and raiseEvent then calls the next, freed one -
-- a use-after-free that crashed Mudlet 4.22.0 in 5 of 18 runs, always right
-- after the success line:
--
--   SIGSEGV, fault address 0x18
--   rip -> Tree<TScript>::isActive()   (Tree.h:243)
--       <- TScript::callEventHandler   (TScript.cpp:94)
--       <- Host::raiseEvent            (Host.cpp:1825)
--
-- Deferring by tempTimer(0, ...) lets raiseEvent finish its walk before any
-- package is touched: 0 crashes in 15 runs, update still completes. Mudlet's
-- PTB no longer crashes here, so this is fixed upstream, but it affects
-- everyone on a released Mudlet until that ships.
function svo.update_download_done(_, path)
  if not svo.update_target or path ~= svo.update_target then return end

  local target, version = svo.update_target, svo.update_version
  svo.update_target, svo.update_version = nil, nil

  tempTimer(0, function()
    svo.install_downloaded_package(target, version)
  end)
end
