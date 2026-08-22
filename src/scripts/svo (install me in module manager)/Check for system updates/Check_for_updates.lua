-- Update checking against the GitHub releases API.
--
-- The system used to fetch a version file, then download 24 module xmls, drop
-- the old ones and reload each module. As a package none of that is needed:
-- Mudlet can install a package straight from a URL, so checking is one HTTP
-- request and updating is uninstall + install.

-- Where the in-client update comes from. This has to be the same place the
-- README and doc/index.rst send people to download from, and while the
-- converted system is being play tested that is the testing fork: build.yml's
-- release job is deliberately gated to it, so nothing published from svof/svof
-- can carry a svof.mpackage yet. Both move back together when that gate does.
--
-- Until the first package release exists anywhere, the check is honest but
-- inert - svo.update_http_done says so rather than offering a download url
-- that would 404.
svo.update_repo = svo.update_repo or "TheLastDarkthorne/svof"

-- The newest published release of that repository. There is no release-channel
-- mapping any more - svo.conf.releasechannel selected between GitHub Pages
-- directories, which is not how any of this works now - so the comment that
-- described one has gone with it.
function svo.update_api_url()
  return string.format("https://api.github.com/repos/%s/releases/latest", svo.update_repo)
end

-- Fallback only - svo.update_http_done prefers the asset url the release
-- itself carries. `tag` must be the raw tag_name: GitHub asset urls are
-- tag-exact, so passing a "v" stripped version here 404s against a release
-- published as "v65".
function svo.update_package_url(tag)
  return string.format("https://github.com/%s/releases/download/%s/svof.mpackage",
    svo.update_repo, tag)
end

-- Does this sysGetHttpDone/sysGetHttpError belong to our check?
--
-- Comparing url == svo.update_api_url() alone wedged the check permanently.
-- Mudlet follows redirects and reports the FINAL url, and GitHub 301s the
-- releases API whenever a repository is renamed or transferred - so both
-- handlers returned early, svo.checkingupdates stayed true, and every later
-- vupdate printed nothing at all until Mudlet was restarted. Requiring a check
-- to be in flight keeps this from claiming somebody else's response.
function svo.update_response_is_ours(url)
  if not svo.checkingupdates then return false end
  if url == svo.update_api_url() then return true end
  return type(url) == "string" and url:match("/releases/latest$") ~= nil
end

-- How long an automatic check counts for. svo.classchange sets systemloaded
-- false and re-runs svo_init_system, which re-raises "svo system loaded",
-- which runs the check again - one api.github.com request per class change,
-- including every trip in and out of dragonform, against an unauthenticated
-- limit of 60 an hour. The old channel was a static GitHub Pages file and
-- unmetered, so nothing needed throttling before. A hand-typed vupdate is
-- never throttled.
local AUTO_CHECK_INTERVAL = 3600

-- A check that neither completes nor errors would otherwise leave
-- svo.checkingupdates true for the session, which is the same permanent
-- lockout by another route.
local CHECK_TIMEOUT = 60

-- Versions are plain integers ("64"), but compare component-wise anyway so a
-- later move to 1.2.3 style does not silently stop offering updates - comparing
-- those as strings would make "1.10" look older than "1.9".
function svo.version_newer(candidate, current)
  local function parts(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
  end
  local a, b = parts(candidate), parts(current)
  for i = 1, math.max(#a, #b) do
    local x, y = a[i] or 0, b[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

-- called on "svo system loaded" and by the vupdate alias.
--
-- `automatic` marks the event-driven call, which fires again on every class
-- change - see AUTO_CHECK_INTERVAL.
function svo.checkforupdates(kind, automatic)
  if svo.checkingupdates then return end
  if not getHTTP then
    -- getHTTP arrived in Mudlet 4.10.0, but getPackageInfo, which the version
    -- comparison below leans on, is 4.12 - so 4.12 is the real floor.
    svo.echof("Your Mudlet is too old to check for updates - please update to 4.12 or newer.")
    return
  end

  if automatic then
    local now = os.time()
    if svo.lastupdatecheck and (now - svo.lastupdatecheck) < AUTO_CHECK_INTERVAL then
      return
    end
    -- stamped before the request, so a failing check throttles too
    svo.lastupdatecheck = now
  end

  svo.checkingupdates = true
  svo.announceupdates = (kind == "checking" or kind == "force") and kind or nil

  tempTimer(CHECK_TIMEOUT, function()
    if svo.checkingupdates then
      svo.checkingupdates = false
      svo.announceupdates = nil
    end
  end)

  if kind == "checking" then
    svo.echof("Checking for updates...")
  elseif kind == "force" then
    svo.echof("Reinstalling the latest release...")
  end

  -- Same shape as downloadFile: getHTTP returns nil, reason on a refused start
  -- and raises no event, so dropping the return left svo.checkingupdates true
  -- forever and every later check returned in silence.
  local ok, started, why = pcall(getHTTP, svo.update_api_url())
  if not ok then why = started end
  if not ok or not started then
    svo.checkingupdates = false
    if svo.announceupdates then
      svo.echof("Couldn't check for updates: %s", tostring(why))
    end
    svo.announceupdates = nil
  end
end
