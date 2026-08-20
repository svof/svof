--
-- MySQL Workbench Doctrine Export Plugin
-- Version: 0.3.6
-- Authors: Johannes Mueller, Karsten Wutzke
-- Copyright (c) 2008-2009
--
-- http://code.google.com/p/mysql-workbench-doctrine-plugin/
--
-- This file is free software: you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation, either
-- version 3 of the License, or (at your option) any later version.
--
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library.  If not, see <http://www.gnu.org/licenses/>.
--

function string.endswith(s, suffix)
    return s:sub(#s - #suffix + 1) == suffix
end

function isPlural(s)
    -- is plural if string ends with an "s" but not with "ss"
    return string.endswith(s, "s") and not string.endswith(s, "ss") and #s > 1
end

function isSingular(s)
    -- is singular if not plural
    return not isPlural(s)
end

local t = {
    "bison", "magi", "buffalo", "deer", "fish", "sheep", "salmon", "trout", "swine", "plankton", "squid"
}
local irregularPlurals = {}
for _,v in ipairs(t) do irregularPlurals[v] = true end

function isIrregular(s)
    return irregularPlurals[s] and true or false
end

function string.singularize(s)

    -- is plural?
    if ( isPlural(s) ) then
        -- strip "s"
        s = string.sub(s, 1, #s - 1)

        -- we can't just strip the s without looking at the remaining English plural endings
        -- see http://en.wikipedia.org/wiki/English_plural

        -- if the table name ends with "e" ("coache", "hashe", "addresse", "buzze", "heroe", ...)
        if (    string.endswith(s, "che")
             or string.endswith(s, "she")
             or string.endswith(s, "sse")
             or string.endswith(s, "zze")
             or string.endswith(s, "oe") ) then

            -- strip an "e", too
            s = string.sub(s, 1, #s - 1)

        -- if table name ends with "ie"
        elseif ( string.endswith(s, "ie") ) then
            -- replace "ie" by a "y" ("countrie" -> "country", "hobbie" -> "hobby", ...)
            s = string.sub(s, 1, #s - 2) .. "y"

        elseif ( string.endswith(s, "ve") ) then
            -- replace "ve" by an "f" ("calve" -> "calf", "leave" -> "leaf", ...)
            s = string.sub(s, 1, #s - 2) .. "f"

            -- does *not* work for certain words ("knive" -> "knif", "stave" -> "staf", ...): TODO (hard)
        else
            -- do nothing ("game", "referee", "monkey", ...)

            -- note: table names like "Caches" can't be handled correctly because of the "che" rule above,
            -- that word however basically stems from French and might be considered a special case anyway
            -- also collective names like "Personnel", "Cast" (caution: SQL keyword!) can't be singularized
        end
    end

    return s
end

function string.pluralize(s)

    -- is singular?
    if ( isSingular(s) and not isIrregular(s) ) then

        -- we can't just append the s without looking at the English singular endings
        -- see https://en.wikipedia.org/wiki/English_plural

        -- if the table name ends with "ch", "sh", "ss" or "zz" ("coach", "hash", "address", "buzz", "hero", ...)
        if (    string.endswith(s, "ch")
             or string.endswith(s, "sh")
             or string.endswith(s, "ss")
             or string.endswith(s, "zz")
             or string.endswith(s, "o") ) then

            -- append "es"
            s = s .. "es"

        -- if table name ends with "y"
        elseif ( string.endswith(s, "y") ) then
            -- replace "y" with "ies" ("country" -> "countries", "hobby" -> "hobbies", ...)
            s = string.sub(s, 1, #s - 1) .. "ies"

        elseif ( string.endswith(s, "f") ) then
            -- replace "f" by an "ves" ("leaf" -> "leaves", "half" -> "halves", ...)
            s = string.sub(s, 1, #s - 1) .. "ves"
        else
            -- append "s" ("games", "referees", "monkeys", ...)
            s = s .. "s"
        end
    end

    return s
end