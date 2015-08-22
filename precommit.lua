#!/usr/bin/lua

-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.


-- copy to template
os.execute([[cp '/home/vadi/Games/Mudlet/svo (install the zip, not me).xml' '/home/vadi/Games/Mudlet/svo template/svo (install the zip, not me).xml']])

-- docs
assert(io.input("/home/vadi/Games/Mudlet/svo/generate.lua"))
t = io.read("*all")
systemversion = string.match(t, [[version *= "(.-)"]])

-- update version in docs
io.input("/home/vadi/Games/Mudlet/svo/doc/conf.py")
t = io.read("*all")
t = string.gsub(t, [[version = '.-']], string.format("version = '%s'", systemversion))
t = string.gsub(t, [[release = '.-']], string.format("release = '%s'", systemversion))
io.output("/home/vadi/Games/Mudlet/svo/doc/conf.py")
io.write(t)


-- make
os.execute([[cd ~/Games/Mudlet/svo/doc && sphinx-build -j 4 -b html -d _build/doctrees   . _build/html]])

-- update ndb cache listing
package.path = package.path .. ";../mm/doc/?.lua"
gl     = require"parse_glossary"
pretty = require"pl.pretty"

local data = gl.striptrailinglines(gl.readfile("doc/namedb.rst"))

local f = io.open([[/home/vadi/Games/Mudlet/svo template/ndb-help.lua]], "w+")
f:write(pretty.write(data))
f:close()

f = io.open([[/home/vadi/mudlet-data/profiles/svo/Vadimuses svo/ndb-help.lua]], "w+")
f:write(pretty.write(data))
f:close()
