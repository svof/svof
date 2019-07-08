-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local M = {}

local FILE = "namedb.rst"

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.trim(s)
	if s then
		return string.gsub(s, "^%s*(.-)%s*$", "%1")
	else
		return s
	end
end

local function shouldignore(line)
	line = line:trim()
	if line:starts(".. image::") or line:starts(":align:") then
	 	return true
	end
end

function M.readfile(which)
	which = which or FILE
	local f,msg = io.open(which, "r+")

	if not f then print("parse_glossary.lua: error opening file: "..msg) return end

	local parsing_glossary
	local term_indent, definition_indent
	local current_term

	-- ordered {term = definition{}} list of tables
	local data = {}

	for line in f:lines() do
		local juststarted_glossary
		if line:starts(".. glossary::") then
			parsing_glossary = true
			juststarted_glossary = true
		end

		if parsing_glossary and not juststarted_glossary then
			-- record the indent of terms
			if line:trim() ~= "" and not term_indent then
				term_indent = line:find("%a") - 1 -- find the index of the first letter, and then subtract one to get the spaces before it
			elseif line:trim() ~= "" and not definition_indent then
				definition_indent = line:find("%a") - 1
			elseif term_indent and line:find("^"..(" "):rep(term_indent) .."%a") then
				current_term = line:trim()
			elseif line:trim() ~= "" and term_indent and not line:starts((" "):rep(term_indent)) then
				parsing_glossary = false
				break -- if there are more than 2 glossaries, only read the first one
			elseif current_term and not shouldignore(line) then
				-- just started parsing a new term? add a new row
				if not data[#data] or data[#data].term ~= current_term then
					data[#data+1] = {term = current_term}
				end

				data[#data].definition = data[#data].definition or {}
				data[#data].definition[#data[#data].definition+1] = line:trim()
			end
		end
	end

	return data
end

-- strip trailing blank "" entries
function M.striptrailinglines(data)
	for _, entry in ipairs(data) do
		while entry.definition[#entry.definition] == "" do
			entry.definition[#entry.definition] = nil
		end
	end

	return data
end

return M

-- striptrailinglines(readfile(FILE))
-- print(pretty.write(striptrailinglines(readfile(FILE))))
