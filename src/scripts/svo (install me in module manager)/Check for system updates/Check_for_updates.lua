-- Update checking against the GitHub releases API.
--
-- The system used to fetch a version file, then download 24 module xmls, drop
-- the old ones and reload each module. As a package none of that is needed:
-- Mudlet can install a package straight from a URL, so checking is one HTTP
-- request and updating is uninstall + install.

svo.update_repo = svo.update_repo or "svof/svof"

-- Where a release channel maps to a different repo or tag, adjust here. The
-- default channel uses the newest published release.
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

-- called on "svo system loaded" and by the vupdate alias
function svo.checkforupdates(kind)
  if svo.checkingupdates then return end
  if not getHTTP then
    svo.echof("Your Mudlet is too old to check for updates - please update to 4.11 or newer.")
    return
  end

  svo.checkingupdates = true
  svo.announceupdates = (kind == "checking" or kind == "force") and kind or nil

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
