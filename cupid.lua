
-----------------------------------------------------
-- Cupid Configuration
-----------------------------------------------------

local config = {

	always_use = true,

	console_key = 96,
	console_override_print = true,
	console_height = 0.33,
	enable_remote = true
}

-----------------------------------------------------
-- Cupid Hooking 
-----------------------------------------------------

local cupid_error = function(...) error(...) end
local main_args = {...}

local wraped_love = {}
local cupid_stubs = {}
local game_funcs = {}
local protected_funcs = {'update','draw','keyreleased','keypressed','load'}
local function protector(table, key, value)
	for k,v in pairs(protected_funcs) do
		if ( v == key ) then
			game_funcs[key] = value
			return
		end
	end
	rawset(table, key, value)
end

local mods = {}
local modules = {}

local loaded = false

local g = nil

local function retaining(...)
	local values = {}
	g.push()
	for k,v in pairs({...}) do
		if type(v) == "function" then
			 v()
		elseif type(v) == "string" then
			values[v] = {g["get" .. v]()}
		end 
	end
	for k,v in pairs(values) do if #v > 0 then g["set" .. k](unpack(v)) end end
	g.pop()
end

local function cupid_load(args)
	local use = true

	if use then
		setmetatable(cupid_stubs, {__index = love})
		setmetatable(wraped_love, {__index = cupid_stubs, __newindex = protector})
		love = wraped_love
		for k,v in pairs(protected_funcs) do
			cupid_stubs[v] = function(...)
				if g == nil then g = love.graphics end
				local result = {}
				local arg = {...}
				local paused = false
				for km,vm in pairs(modules) do
					if vm["paused"] and vm["paused"](vm,...) == true then paused = true end
				end
				for km,vm in pairs(modules) do
					if vm["pre-" .. v] and vm["pre-" .. v](vm,...) == false then return end
				end
				
				for km,vm in pairs(modules) do
						if vm["arg-" .. v] then arg = {vm["arg-" .. v](vm,...)} end
				end

				if game_funcs[v] and not paused then
					result = {select(1,xpcall(
						function() return game_funcs[v](unpack(arg)) end, cupid_error
					))}
				end
				for km,vm in pairs(modules) do if vm["post-" .. v] then vm["post-" .. v](vm,...) end end
				return unpack(result)
			end
		end

		table.insert(modules, {
		--	["arg-update"] = function(self,dt) return dt / 8 end
		})


		local function load_modules(what)
			local mod = mods[what]()
			mod:init()
			modules[what] = mod
		end

		load_modules("console")
		if config.enable_remote then
			load_modules("remote")
		end

		load_modules("error")
	else
		love.load = nil
	end

end

-----------------------------------------------------
-- Commands
-----------------------------------------------------
local function cupid_print(str,color) print(str) end

local cupid_commands = {
	env = {
		mode = function(...) g.setMode(...) end,
		quit = function(...) love.event.quit() end,
		dir = function(what)
			local lst = {}
			for k,v in pairs(what) do table.insert(lst,k) end
			return "[" .. table.concat(lst, ", ") .. "]"
		end
	},
	["docommand"] = function(self, cmd)
		local xcmd = cmd
		if not (
			xcmd:match("end") or xcmd:match("do") or 
			xcmd:match("do") or xcmd:match("function") 
			or xcmd:match("return") or xcmd:match("=") 
		) then
			xcmd = "return " .. xcmd
		end
		local func, why = loadstring(xcmd,"*")
		if not func then
			return false, why
		end
		local xselect = function(x, ...) return x, {...} end
		setfenv(func,self.env)
		local ok, result = xselect(pcall(func))
		if not ok then
			return false, result[1]
		end

		if type(result[1]) == "function" and not xcmd:match("[()=]") then
			ok, result = xselect(pcall(result[1]))
			if not ok then 
				return false, result[1]
			end
		end
		
		if ( #result > 0 ) then
			local strings = {}
			for k,v in pairs(result) do strings[k] = tostring(v) end
			return true, table.concat(strings, " , ")
		end

		return true, "nil"
	end,
	["add"] = function(self, name, cmd)
		rawset(self.env, name, cmd)
	end


}

setmetatable(cupid_commands.env, {__index = _G, __newindex = _G})


-----------------------------------------------------
-- Module Reloader
-----------------------------------------------------

local cupid_keep_package = {}
for k,v in pairs(package.loaded) do cupid_keep_package[k] = true end

local cupid_keep_global = {}
for k,v in pairs(_G) do cupid_keep_global[k] = true end

local function cupid_reload(keep_globals)
	-- Unload packages that got loaded
	for k,v in pairs(package.loaded) do 
		if not cupid_keep_package[k] then package.loaded[k] = nil end
	end
	
	if not keep_globals then
		for k,v in pairs(_G) do 
			if not cupid_keep_global[k] then _G[k] = nil end
		end
	end

	if modules.error then modules.error.lasterror = nil end

	if ( main_args[1] == "main" ) then
		game = loadfile('game.lua', 'bt')
	else
		game = loadfile('main.lua', 'bt')
	end

	xpcall(game, cupid_error)
	if love.load then love.load() end
	return true
end
cupid_commands:add("reload", function(...) return cupid_reload(...) end)

-----------------------------------------------------
-- Module Console
-----------------------------------------------------

mods.console = function() return {
	buffer = "",
	shown = false,
	lastkey = "",
	log = {},
	history = {},
	history_idx = 0,
	lines = 12,
	["init"] = function(self)
		if config.console_override_print then
			print = function(...) 
				local strings = {}
				for k,v in pairs({...}) do strings[k] = tostring(v) end
				self:print(unpack(strings))
			end
		end
		cupid_print = function(str, color) self:print(str, color) end
	end,
	["post-load"] = function(self)
	end,
	["post-draw"] = function(self)
		if not self.shown then return end
		if self.height ~= g.getHeight() * config.console_height then
			self.height = g.getHeight() * config.console_height
			self.lineheight = self.height / self.lines
			self.font = g.newFont("UbuntuMono-R.ttf",self.lineheight)
		end
		retaining("Color","Font", function()
			g.setColor(0,0,0,120)
			g.rectangle("fill", 0, 0, g.getWidth(), self.height)
			g.setColor(0,0,0,120)
			g.rectangle("line", 0, 0, g.getWidth(), self.height)
			if self.font then g.setFont(self.font) end
			local es = self.lineheight
			local xo = 5
			local idx = 1
			for k,v in ipairs(self.log) do
				g.setColor(0,0,0)
				local width, lines = g.getFont():getWrap(v[1], g.getWidth())
				idx = idx + lines

				g.printf(v[1], xo, self.height - idx*es, g.getWidth() - xo * 2, "left")
				g.setColor(unpack(v[2]))
				g.printf(v[1], xo-1, self.height - idx*es, g.getWidth() - xo * 2, "left")
			end
			g.setColor(0,0,0)
			g.print("> " .. self.buffer .. "_", xo, self.height - es)
			g.setColor(255,255,255)
			g.print("> " .. self.buffer .. "_", xo - 1, self.height - es - 1)
		end)
	end,
	["pre-keypressed"] = function(self, key, unicode)
		self.lastkey = unicode
		if unicode == config.console_key then 
			self:toggle()
			return false
		end

		if not self.shown then return true end
		
		if unicode == 13 or unicode == 10 then
			if ( #self.buffer > 0 ) then
				self:docommand(self.buffer)
				self.buffer = ""
			else
				self:toggle()
			end
		elseif unicode == 127 or unicode == 8 then
			self.buffer = self.buffer:sub(0, -2)
		elseif #key == 1 then
			self.buffer = self.buffer .. string.char(unicode)
		elseif key == "up" then
			if self.history_idx < #self.history then
				self.history_idx = self.history_idx + 1		
				self.buffer = self.history[self.history_idx]
			end
		elseif key == "down" then
			if self.history_idx > 0 then
				self.history_idx = self.history_idx - 1		
				self.buffer = self.history[self.history_idx] or ""
			end
		end
		return false
	end,
	["pre-keyreleased"] = function(self, key)
		if key == "escape" and self.shown then
			self:toggle()
			return false
		end
		if self.shown then return false end
	end,
	["docommand"] = function(self, cmd)
		self.history_idx = 0
		table.insert(self.history, 1, cmd)
		self:print("> " .. cmd, {200, 200, 200})
		local ok, result = cupid_commands:docommand(cmd)
		self:print(result, ok and {255, 255, 255} or {255, 0, 0})
	end,
	["toggle"] = function(self) self.shown = not self.shown end,
	["print"] = function(self, what, color)
		table.insert(self.log, 1, {what, color or {255,255,255,255}})
		for i=self.lines+1,#self.log do self.log[i] = nil end
	end
} end


-----------------------------------------------------
-- Remote Commands over UDP
-----------------------------------------------------

-- This command is your friend!
-- watchmedo-2.7 shell-command --command='echo reload | nc -u localhost 10173' .

mods.remote = function()
	local socket = require("socket")
	if not socket then return nil end
	return {
	["init"] = function(self)
		self.socket = socket.udp() 
		self.socket:setsockname("127.0.0.1",10173)
		self.socket:settimeout(0)
	end,
	["post-update"] = function(self)
		local a, b = self.socket:receive(100)
		if a then
			print("Remote: " .. a)
			cupid_commands:docommand(a)
		end
	end
	}
end

-----------------------------------------------------
-- Module Error Handler
-----------------------------------------------------


mods.error = function() return {
	["init"] = function(self)
		cupid_error = function(...) self:error(...) end
	end,
	["error"] = function(self, msg) 
		
		local obj = {msg = msg, traceback = debug.traceback()}
		cupid_print(obj.msg, {255, 0, 0})
		if not self.always_ignore then self.lasterror = obj end
		return msg
	end,
	["paused"] = function(self) return self.lasterror ~= nil end,
	["post-draw"] = function(self)
		if not self.lasterror then return end
		retaining("Color", "Font", function()
			local ox = g.getWidth() * 0.1;
			local oy = g.getWidth() * 0.1;
			if self.height ~= g.getHeight() * config.console_height then
				self.height = g.getHeight() * config.console_height
				self.font = g.newFont("UbuntuMono-R.ttf",g.getHeight() / 40)
			end
			local hh = g.getHeight() / 20
			g.setColor(0, 0, 0, 128)
			g.rectangle("fill", ox,oy, g.getWidth()-ox*2, g.getHeight()-ox*2)
			g.setColor(0, 0, 0, 255)
			g.rectangle("fill", ox,oy, g.getWidth()-ox*2, hh)
			g.setColor(0, 0, 0, 255)
			g.rectangle("line", ox,oy, g.getWidth()-ox*2, g.getHeight()-ox*2)
			g.setColor(255, 255, 255, 255)
			local msg = string.format("%s\n\n%s\n\n\n[C]ontinue, [A]lways, [R]eload, [E]xit",
				self.lasterror.msg, self.lasterror.traceback)
			if self.font then g.setFont(self.font) end
			g.setColor(255, 255, 255, 255)
			g.print("[Lua Error]", ox*1.1+1, oy*1.1+1)
			g.setColor(0, 0, 0, 255)
			g.printf(msg, ox*1.1+1, hh + oy*1.1+1, g.getWidth() - ox * 2.2, "left")
			g.setColor(255, 255, 255, 255)
			g.printf(msg, ox*1.1, hh + oy*1.1, g.getWidth() - ox * 2.2, "left")
		end)
	end,
	["post-keypressed"] = function(self, key, unicode) 
		if not self.lasterror then return end
		if key == "r" then 
			self.lasterror = nil
			cupid_reload() 
		elseif key == "c" then
			self.lasterror = nil 
		elseif key == "a" then
			self.lasterror = nil 
			self.always_ignore = true
		elseif key == "e" then
			love.event.push("quit")
		end
	end

} end

-----------------------------------------------------
-- All Done!  Have fun :)
-----------------------------------------------------

if ( main_args[1] == "main" ) then
	game = loadfile('game.lua', 'bt')
	game(main_args)
	love.main = cupid_load
else
	cupid_load()
end
	loaded = true

