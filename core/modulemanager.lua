
local log = require "util.logger".init("modulemanager")

local loadfile, pcall = loadfile, pcall;
local setmetatable, setfenv, getfenv = setmetatable, setfenv, getfenv;
local pairs, ipairs = pairs, ipairs;
local t_insert = table.insert;
local type = type;

local tostring, print = tostring, print;

local _G = _G;
local debug = debug;

module "modulemanager"

local handler_info = {};
local handlers = {};
					
local modulehelpers = setmetatable({}, { __index = _G });

local function _add_iq_handler(module, origin_type, xmlns, handler)
	handlers[origin_type] = handlers[origin_type] or {};
	handlers[origin_type].iq = handlers[origin_type].iq or {};
	if not handlers[origin_type].iq[xmlns] then
		handlers[origin_type].iq[xmlns]= handler;
		handler_info[handler] = module;
		log("debug", "mod_%s now handles tag 'iq' with query namespace '%s'", module.name, xmlns);
	else
		log("warning", "mod_%s wants to handle tag 'iq' with query namespace '%s' but mod_%s already handles that", module.name, xmlns, handler_info[handlers[origin_type].iq[xmlns]].module.name);
	end
end

function modulehelpers.add_iq_handler(origin_type, xmlns, handler)
	if not (origin_type and handler and xmlns) then return false; end
	if type(origin_type) == "table" then
		for _, origin_type in ipairs(origin_type) do
			_add_iq_handler(getfenv(2).module, origin_type, xmlns, handler);
		end
		return;
	end
	_add_iq_handler(getfenv(2).module, origin_type, xmlns, handler);
end

local function _add_handler(module, origin_type, tag, xmlns, handler)
	handlers[origin_type] = handlers[origin_type] or {};
	if not handlers[origin_type][tag] then
		handlers[origin_type][tag] = handlers[origin_type][tag] or {};
		handlers[origin_type][tag][xmlns]= handler;
		handler_info[handler] = module;
		log("debug", "mod_%s now handles tag '%s'", module.name, tag);
	elseif handler_info[handlers[origin_type][tag]] then
		log("warning", "mod_%s wants to handle tag '%s' but mod_%s already handles that", module.name, tag, handler_info[handlers[origin_type][tag]].module.name);
	end
end

function modulehelpers.add_handler(origin_type, tag, xmlns, handler)
	if not (origin_type and tag and xmlns and handler) then return false; end
	if type(origin_type) == "table" then
		for _, origin_type in ipairs(origin_type) do
			_add_handler(getfenv(2).module, origin_type, tag, xmlns, handler);
		end
		return;
	end
	_add_handler(getfenv(2).module, origin_type, tag, xmlns, handler);
end

function load(name)
	local mod, err = loadfile("plugins/mod_"..name..".lua");
	if not mod then
		log("error", "Unable to load module '%s': %s", name or "nil", err or "nil");
		return nil, err;
	end
	
	local pluginenv = setmetatable({ module = { name = name } }, { __index = modulehelpers });
	
	setfenv(mod, pluginenv);
	local success, ret = pcall(mod);
	if not success then
		log("error", "Error initialising module '%s': %s", name or "nil", ret or "nil");
		return nil, err;
	end
	return true;
end

function handle_stanza(origin, stanza)
	local name, xmlns, origin_type = stanza.name, stanza.attr.xmlns, origin.type;
	
	if name == "iq" and xmlns == "jabber:client" and handlers[origin_type] then
		log("debug", "Stanza is an <iq/>");
		local child = stanza.tags[1];
		if child then
			local xmlns = child.attr.xmlns or xmlns;
			log("debug", "Stanza of type %s from %s has xmlns: %s", name, origin_type, xmlns);
			local handler = handlers[origin_type][name] and handlers[origin_type][name][xmlns];
			if handler then
				log("debug", "Passing stanza to mod_%s", handler_info[handler].name);
				return handler(origin, stanza) or true;
			end
		end
	elseif handlers[origin_type] then
		local handler = handlers[origin_type][name];
		if handler then
			handler = handler[xmlns];
			if handler then
				log("debug", "Passing stanza to mod_%s", handler_info[handler].name);
				return handler(origin, stanza) or true;
			end
		end
	end
	log("debug", "Stanza unhandled by any modules, xmlns: %s", stanza.attr.xmlns);
	return false; -- we didn't handle it
end

do
	local event_handlers = {};
	
	function modulehelpers.add_event_hook(name, handler)
		if not event_handlers[name] then
			event_handlers[name] = {};
		end
		t_insert(event_handlers[name] , handler);
	end
	
	function fire_event(name, ...)
		local event_handlers = event_handlers[name];
		if event_handlers then
			for name, handler in ipairs(event_handlers) do
				handler(...);
			end
		end
	end
end

return _M;
