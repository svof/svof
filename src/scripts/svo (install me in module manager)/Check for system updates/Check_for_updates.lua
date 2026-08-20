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

-- called at startup, hourly, and by the vupdate alias
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

  getHTTP(svo.update_api_url())
end
