#!/usr/bin/lua

-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

-- get release version from command line
local args = {...}
local systemversion = args[1]

-- update version in docs
io.input("doc/conf.py")
t = io.read("*all")
t = string.gsub(t, [[version = '.-']], string.format("version = '%s'", systemversion))
t = string.gsub(t, [[release = '.-']], string.format("release = '%s'", systemversion))
io.output("doc/conf.py")
io.write(t)


-- make
os.execute([[cd doc && sphinx-build -b html -d _build/doctrees . _build/html]])
