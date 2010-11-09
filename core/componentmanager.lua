-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local prosody = _G.prosody;
local log = require "util.logger".init("componentmanager");
local certmanager = require "core.certmanager";
local configmanager = require "core.configmanager";
local modulemanager = require "core.modulemanager";
local jid_split = require "util.jid".split;
local fire_event = prosody.events.fire_event;
local events_new = require "util.events".new;
local st = require "util.stanza";
local prosody, hosts = prosody, prosody.hosts;
local uuid_gen = require "util.uuid".generate;

local pairs, setmetatable, type, tostring = pairs, setmetatable, type, tostring;

local components = {};

local disco_items = require "util.multitable".new();
local NULL = {};

module "componentmanager"

local function default_component_handler(origin, stanza)
	log("warn", "Stanza being handled by default component; bouncing error for: %s", stanza:top_tag());
	if stanza.attr.type ~= "error" and stanza.attr.type ~= "result" then
		origin.send(st.error_reply(stanza, "wait", "service-unavailable", "Component unavailable"));
	end
end

function load_enabled_components(config)
	local defined_hosts = config or configmanager.getconfig();
		
	for host, host_config in pairs(defined_hosts) do
		if host ~= "*" and ((host_config.core.enabled == nil or host_config.core.enabled) and type(host_config.core.component_module) == "string") then
			hosts[host] = create_component(host);
			components[host] = default_component_handler;
			local ok, err = modulemanager.load(host, host_config.core.component_module);
			if not ok then
				log("error", "Error loading %s component %s: %s", tostring(host_config.core.component_module), tostring(host), tostring(err));
			else
				fire_event("component-activated", host, host_config);
				log("debug", "Activated %s component: %s", host_config.core.component_module, host);
			end
		end
	end
end

if prosody and prosody.events then
	prosody.events.add_handler("server-starting", load_enabled_components);
end

function create_component(host, component, events)
	-- TODO check for host well-formedness
	return { type = "component", host = host, s2sout = {},
			events = events or events_new(),
			dialback_secret = configmanager.get(host, "core", "dialback_secret") or uuid_gen(),
			disallow_s2s = configmanager.get(host, "core", "disallow_s2s"); };
end

function register_component(host, component)
	if not hosts[host] or hosts[host].type == 'component' then
		local old_events = hosts[host] and hosts[host].events;

		components[host] = component;
		hosts[host] = create_component(host, component, old_events);

		-- Add events object if not already one
		if not hosts[host].events then
			hosts[host].events = old_events or events_new();
		end

		if not hosts[host].dialback_secret then
			hosts[host].dialback_secret = configmanager.get(host, "core", "dialback_secret") or uuid_gen();
		end

		-- add to disco_items
		if not(host:find("@", 1, true) or host:find("/", 1, true)) and host:find(".", 1, true) then
			disco_items:set(host:sub(host:find(".", 1, true)+1), host, true);
		end
		modulemanager.load(host, "dialback");
		modulemanager.load(host, "tls");
		log("debug", "component added: "..host);
		return hosts[host];
	else
		log("error", "Attempt to set component for existing host: "..host);
	end
end

function deregister_component(host)
	if components[host] then
		modulemanager.unload(host, "tls");
		modulemanager.unload(host, "dialback");
		local host_config = configmanager.getconfig()[host];
		if host_config and ((host_config.core.enabled == nil or host_config.core.enabled) and type(host_config.core.component_module) == "string") then
			-- Set default handler
			components[host] = default_component_handler;
		else
			-- Component not in config, or disabled, remove
			hosts[host] = nil; -- FIXME do proper unload of all modules and other cleanup before removing
			components[host] = nil;
		end
		-- remove from disco_items
		if not(host:find("@", 1, true) or host:find("/", 1, true)) and host:find(".", 1, true) then
			disco_items:remove(host:sub(host:find(".", 1, true)+1), host);
		end
		log("debug", "component removed: "..host);
		return true;
	else
		log("error", "Attempt to remove component for non-existing host: "..host);
	end
end

function get_children(host)
	return disco_items:get(host) or NULL;
end

return _M;
