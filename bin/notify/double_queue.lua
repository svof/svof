---------------------------------------------------------------------------------
-- Copyright (C) 2010 Tiago Katcipis <tiagokatcipis@gmail.com>
-- Copyright (C) 2010 Paulo Pizarro  <paulo.pizarro@gmail.com>
-- 
-- author Paulo Pizarro  <paulo.pizarro@gmail.com>
-- author Tiago Katcipis <tiagokatcipis@gmail.com>

-- This file is part of LuaNotify.

-- LuaNotify is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- LuaNotify is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.

-- You should have received a copy of the GNU Lesser General Public License
-- along with LuaNotify.  If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

---
-- @class module
-- @name ordered_set
-- @description DoubleQueue Class.
-- @author <a href="mailto:tiagokatcipis@gmail.com">Tiago Katcipis</a>
-- @author <a href="mailto:paulo.pizarro@gmail.com">Paulo Pizarro</a>
-- @copyright 2010 Tiago Katcipis, Paulo Pizarro.

local setmetatable = setmetatable

module(...)

-----------------------------------------------------
-- Class attributes and methods goes on this table --
-----------------------------------------------------
local DoubleQueue = {}

------------------------------------
-- Metamethods goes on this table --
------------------------------------
local DoubleQueue_mt = { __index = DoubleQueue }


--------------------------
-- Constructor function --
--------------------------

function new ()
    local object = {}
    -- set the metatable of the new object as the DoubleQueue_mt table (inherits DoubleQueue).
    setmetatable(object, DoubleQueue_mt)

    -- create all the instance state data.
    object.data          = {}
    object.data_position = {}
    object.first         = 1 
    object.last          = 0
    return object
end

---------------------------
-- Class private methods --
---------------------------
local function refresh_first(self)
    while(self.first <= self.last) do
        if(self.data[self.first]) then
            return true
        end
        self.first = self.first + 1
    end
end


--------------------------
-- Class public methods --
--------------------------
function DoubleQueue:is_empty()
    return self.first > self.last
end

function DoubleQueue:push_front(data)
    if(self.data_position[data]) then
        return
    end
    self.first = self.first - 1
    self.data[self.first]    = data
    self.data_position[data] = self.first
end

function DoubleQueue:push_back(data)
    if(self.data_position[data]) then
        return
    end
    self.last = self.last + 1
    self.data[self.last]     = data
    self.data_position[data] = self.last
end

function DoubleQueue:get_iterator()
    local first = self.first
    local function iterator()
        while(first <= self.last) do
            local data = self.data[first]
            first = first + 1
            if(data) then
                return data
            end
        end    
    end 
    return iterator
end

function DoubleQueue:remove(data)
    if(not self.data_position[data]) then
        return 
    end
    self.data[self.data_position[data]] = nil
    self.data_position[data]            = nil
    refresh_first(self)
end

