local lfs = require("lfs")
local expat = require("lxp")

local workDir = arg[1]

local function printHelp()
    print("Program to validate the script syntax in Mudlet XML files.")
    print("Usage:")
    print("   lua validate-syntax.lua <svof directory>")
    print("Example:")
    print("   lua validate-syntax.lua $HOME/git/svof/")
end

if workDir == "-h" or workDir == "--help" then
    printHelp()
    return
end

-- function to find out, whether the XML element name belongs to a Mudlet object type.
-- These might be the actual types or groups of them (e.g. TriggerGroup)
local function isMudletObjectType(elementName)
    return elementName:find("^Trigger") or
        elementName:find("^Alias") or
        elementName:find("^Script") or
        elementName:find("^Timer") or
        elementName:find("^Key") or
        elementName:find("^Button")
end


-- record the state of error checking
local foundError = false

-- function to initialize the XML parser callbacks. It is a function to keep the state variables
-- local. No need to let anybody know the filthy details.
local function initializeXmlParserCallbacks()
    -- state variables:
    -- keeps track of the current object type, used in error messages
    local mudletObjectType = nil
    -- keeps track of the name of the current mudlet object, used in error messages
    local mudletObjectName = nil
    -- keeps track of the current XML tag, otherwise the tag conten (character data) does not
    -- know, which tag it belongs to
    local currentXmlTag = nil

    local callbacks = {
        -- callback for strings and CDATA blocks inside tags.
        -- we basically only care about the content of name or script tags
        CharacterData = function (_, value)

            -- record the name of the current mudlet object and bail out
            if  currentXmlTag == "name" then
                mudletObjectName = value
                return
            -- skip character data of tags we don't care about
            elseif currentXmlTag ~= "script" then
                return
            end

            -- get rid of leading spaces, so we can skip empty script blocks
            value = value:gsub("^%s+", "")
            if value == "" then
                return
            end

            -- make lua load the string inside the scrip block. It will complain about any syntax error
            local f, error = loadstring(value)
            if not f then
                print("Error in " .. mudletObjectType .. " '" .. mudletObjectName .. "': " .. error)
                foundError = true
            end
        end,

        -- callback to record the parent XML tag of the next called callback
        StartElement = function (_, elementName)
            currentXmlTag = elementName
            if isMudletObjectType(elementName) then
                mudletObjectType = elementName
            end
        end,

        -- we are done with the XML tag and go backwards in the tree, so discard unneeded information
        EndElement = function (_, elementName)
            currentXmlTag = nil
            if mudletObjectType == elementName then
                mudletObjectType = nil
                mudletObjectName = nil
            end
        end,
    }

    return callbacks
end
local callbacks = initializeXmlParserCallbacks()

-- function to check, whether the given working directory is a valid directory.
local function checkWorkingDirectory(workDir)
    local workDirMode = assert(lfs.attributes(workDir, "mode"))

    if workDirMode ~= "directory" then
        error("working directory '" .. workDir .."' is not a directory but a(n) ".. workDirMode)
    end
end

-- function to read the content of a given file
local function readFileContent(fileName)
    io.input(fileName)
    local fileContent = io.read("*a")
    io.close()
    return fileContent
end

-- function to do something (run the XML parser) on the file content
local function handleFileContent(content)
    local parser = expat.new(callbacks)
    parser:parse(content)
end

-- function to handle a found file. If the file name does not end on .xml, this is a noop
local function handleXmlFile(fileName)
    if fileName:find(".xml$") then
        print(fileName)
        local content = readFileContent(fileName)
        handleFileContent(content)
    end
end

checkWorkingDirectory(workDir)
print("looking for files in " .. workDir)
lfs.chdir(workDir)
for file in lfs.dir(workDir) do
    handleXmlFile(file)
end

os.exit(foundError and 1 or 0)