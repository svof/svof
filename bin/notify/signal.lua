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
-- @name signal
-- @description Signal Class.
-- @author <a href="mailto:tiagokatcipis@gmail.com">Tiago Katcipis</a>
-- @author <a href="mailto:paulo.pizarro@gmail.com">Paulo Pizarro</a>
-- @copyright 2010 Tiago Katcipis, Paulo Pizarro.

local require = require
local setmetatable = setmetatable

module(...)

local queue = require "notify.double_queue"

-----------------------------------------------------
-- Class attributes and methods goes on this table --
-----------------------------------------------------
local Signal = {} 


------------------------------------
-- Metamethods goes on this table --
------------------------------------
local Signal_mt = { __index = Signal }


--------------------------
-- Constructor function --
--------------------------
function new ()
    local object = {}      
    -- set the metatable of the new object as the Signal_mt table (inherits Signal).
    setmetatable(object, Signal_mt)

    -- create all the instance state data.
    object.handlers_block  = {}
    object.handlers        = queue.new()
    object.pre_emit_funcs  = queue.new()
    object.post_emit_funcs = queue.new()
    object.signal_stopped = false
    return object
end


----------------------------------
-- Class definition and methods --
----------------------------------


---
-- Disconnects a handler function from this signal, the function will no longer be called.
-- @param handler_function – The function that will be disconnected.
function Signal:disconnect(handler_function)
    self.handlers:remove(handler_function)
    self.handlers_block[handler_function] = nil
end


---
-- Connects a handler function on this signal, all handlers connected will be called 
-- when the signal is emitted with a FIFO  behaviour (The first connected will be the first called).
-- @param handler_function – The function that will be called when this signal is emitted.
function Signal:connect(handler_function)
    if(not self.handlers_block[handler_function]) then
        self.handlers_block[handler_function] = 0
        self.handlers:push_back(handler_function)
    end
end


---
-- Does not execute the given handler function when the signal is emitted until it is unblocked. 
-- It can be called several times for the same handler function.
-- @param handler_function – The handler function that will be blocked.
function Signal:block(handler_function)
    if(self.handlers_block[handler_function]) then
        self.handlers_block[handler_function] = self.handlers_block[handler_function] + 1
    end
end


---
-- Unblocks the given handler function, this handler function will be executed on 
-- the order it was previously connected, and it will only be unblocked when 
-- the calls to unblock are equal to the calls to block.
-- @param handler_function – The handler function that will be unblocked.
function Signal:unblock(handler_function)
    if(self.handlers_block[handler_function]) then
        if(self.handlers_block[handler_function] > 0) then
            self.handlers_block[handler_function] = self.handlers_block[handler_function] - 1
        end
    end
end


---
-- Emits a signal calling the handler functions connected to this signal passing the given args.
-- @param … – A optional list of parameters, they will be repassed to the handler functions connected to this signal.
function Signal:emit(...)
    self.signal_stopped = false;

    for set_up in self.pre_emit_funcs:get_iterator() do set_up() end

    for handler in self.handlers:get_iterator() do 
        if(self.signal_stopped) then break end
        if(self.handlers_block[handler] == 0) then
            handler(...)
        end
    end

    for tear_down in self.post_emit_funcs:get_iterator() do tear_down() end
end


---
-- Typical signal emission discards handler return values completely. 
-- This is most often what you need: just inform the world about something. 
-- However, sometimes you need a way to get feedback. For instance, 
-- you may want to ask: “is this value acceptable, eh?”
-- This is what accumulators are for. Accumulators are specified to signals at emission time. 
-- They can combine, alter or discard handler return values, post-process them or even stop emission. 
-- Since a handler can return multiple values, accumulators can receive multiple args too, following 
-- Lua flexible style we give the user the freedom to do whatever he wants with accumulators.
-- @param accumulator – Function that will accumulate handlers results.
-- @param … – A optional list of parameters, they will be repassed to the handler functions connected to this signal.
function Signal:emit_with_accumulator(accumulator, ...)
    self.signal_stopped = false;

    for set_up in self.pre_emit_funcs:get_iterator() do set_up() end

    for handler in self.handlers:get_iterator() do 
        if(self.signal_stopped) then break end
        if(self.handlers_block[handler] == 0) then
            accumulator(handler(...))
        end
    end

    for tear_down in self.post_emit_funcs:get_iterator() do tear_down() end
end


---
-- Adds a pre_emit func, pre_emit functions cant be blocked, only added or removed, 
-- they cannot have their return collected by accumulators, will not receive any data passed 
-- on the emission and they are always called before ANY handler is called. 
-- This is useful when you want to perform some global task before handling an event, 
-- like opening a socket that the handlers might need to use or a database, pre_emit functions 
-- can make sure everything is ok before handling an event, reducing the need to do this check_ups 
-- inside the handler function. They are called on a queue (FIFO) policy based on the order they added.
-- @param pre_emit_func – The pre_emit function.
function Signal:add_pre_emit(pre_emit_func)
    self.pre_emit_funcs:push_back(pre_emit_func)
end


---
-- Removes the pre_emit function
-- @param pre_emit_func – The pre_emit function.
function Signal:remove_pre_emit(pre_emit_func)
    self.pre_emit_funcs:remove(pre_emit_func)
end


---
-- Adds a post_emit function, post_emit functions cant be blocked, only added or removed, 
-- they cannot have their return collected by accumulators, they will not receive any data 
-- passed on the emission and they are always called after ALL handlers where called. 
-- This is useful when you want to perform some global task after handling an event, 
-- like closing a socket that the handlers might need to use or a database or do some cleanup. 
-- post_emit functions can make sure everything is released after handling an event, 
-- reducing the need to do this check_ups inside some handler function, since some resources 
-- can be shared by multiple handlers. They are called on a stack (LIFO) policy based on the order they added.
-- @param post_emit_func – The post_emit function.
function Signal:add_post_emit(post_emit_func)
    self.post_emit_funcs:push_front(post_emit_func)
end

---
-- Removes the post_emit function
-- @param post_emit_func – The post_emit function.
function Signal:remove_post_emit(post_emit_func)
    self.post_emit_funcs:remove(post_emit_func)
end


---
-- Stops the current emission, if there is any handler left to be called by the signal it wont be called.
function Signal:stop()
    self.signal_stopped = true
end

