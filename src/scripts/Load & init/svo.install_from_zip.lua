-------------------------------------------------
--         Put your Lua functions here.        --
--                                             --
-- Note that you can also use external Scripts --
-------------------------------------------------
local templocation = getMudletHomeDir() .. "/svo/downloads/temp/"

-- deletedir credit: https://stackoverflow.com/a/43407750/72944
local deletedir =
  function(dir)
    for file in lfs.dir(dir) do
      local file_path = dir .. '/' .. file
      if file ~= "." and file ~= ".." then
        if lfs.attributes(file_path, 'mode') == 'file' then
          os.remove(file_path)
        elseif lfs.attributes(file_path, 'mode') == 'directory' then
          deletedir(file_path)
        end
      end
    end
    lfs.rmdir(dir)
  end

local function maketemplocation(location)
  if lfs.attributes(location) then
    deletedir(location)
  end
  return lfs.mkdir(location)
end

local function getmoduleslist(location)
  return svo.pl.dir.getfiles(location, "*.xml")
end

local function get_names_from_paths(locations, location)
	-- get a list of module names from their locations
	local modules_list = svo.pl.tablex.imap(string.sub, locations, #location+1)
	-- strip the final .xml as well
	modules_list = svo.pl.tablex.imap(string.sub, modules_list, 1, -5)
	return modules_list
end

function svo.install_all_modules_in(location)
  if not string.ends(location, '/') then
    location = location .. "/"
  end
  local modules_locations_list = getmoduleslist(location)
  local modules_list = get_names_from_paths(modules_locations_list, location)
  -- if Mudlet does not support syncModule(), ask the person to do it manually
  local warn_manual_sync
  -- install missing modules & sync if Mudlet supports it
  for i, modulelocation in ipairs(modules_locations_list) do
    tempTimer(
      0,
      function()
        local s, m = installModule(modulelocation)
        if syncModule then
          syncModule(modules_list[i])
        else
          if warn_manual_sync then
            killTimer(warn_manual_sync)
          end
          warn_manual_sync = tempTimer(0, svo.ask_to_sync_manual)
        end
      end
    )
  end
end

function svo.install_from_zip(ziplocation)
  svo.signals.saveconfig:emit()
  -- check that zip is present
  if not io.exists(ziplocation) then
    return nil, "input file zip is missing"
  end
  -- create temporary location to extract zip into
  if not maketemplocation(templocation) then
    return nil, "couldn't create temporary download location"
  end
  -- extract zip into said temporary location
  unzip(ziplocation, templocation)
  -- install all modules
  svo.install_all_modules_in(templocation)
  -- delete temporary location
  deletedir(templocation)
  -- reset the loaded flag
  svo.systemloaded = nil
  -- happy times
  svo_init_system()
end