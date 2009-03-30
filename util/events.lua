
local ipairs = ipairs;
local pairs = pairs;
local t_insert = table.insert;
local select = select;

module "events"

function new()
	local dispatchers = {};
	local handlers = {};
	local event_map = {};
	local function _rebuild_index() -- TODO optimize index rebuilding
		for event, _handlers in pairs(event_map) do
			local index = handlers[event];
			if index then
				for i=#index,1,-1 do index[i] = nil; end
			else index = {}; handlers[event] = index; end
			for handler in pairs(_handlers) do
				t_insert(index, handler);
			end
		end
	end;
	local function add_handler(event, handler)
		local map = event_map[event];
		if map then
			map[handler] = true;
		else
			map = {[handler] = true};
			event_map[event] = map;
		end
		_rebuild_index();
	end;
	local function remove_handler(event, handler)
		local map = event_map[event];
		if map then
			map[handler] = nil;
			_rebuild_index();
		end
	end;
	local function add_plugin(plugin)
		for event, handler in pairs(plugin) do
			add_handler(event, handler);
		end
	end;
	local function remove_plugin(plugin)
		for event, handler in pairs(plugin) do
			remove_handler(event, handler);
		end
	end;
	local function _create_dispatcher(event) -- FIXME duplicate code in fire_event
		local h = handlers[event];
		if not h then h = {}; handlers[event] = h; end
		local dispatcher = function(data)
			for _, handler in ipairs(h) do
				handler(data);
			end
		end;
		dispatchers[event] = dispatcher;
		return dispatcher;
	end;
	local function get_dispatcher(event)
		return dispatchers[event] or _create_dispatcher(event);
	end;
	local function fire_event(event, data) -- FIXME duplicates dispatcher code
		local h = handlers[event];
		if h then
			for _, handler in ipairs(h) do
				handler(data);
			end
		end
	end;
	local function get_named_arg_dispatcher(event, ...)
		local dispatcher = get_dispatcher(event);
		local keys = {...};
		local data = {};
		return function(...)
			for i, key in ipairs(keys) do data[key] = select(i, ...); end
			dispatcher(data);
		end;
	end;
	return {
		add_handler = add_handler;
		remove_handler = remove_handler;
		add_plugin = add_plugin;
		remove_plugin = remove_plugin;
		get_dispatcher = get_dispatcher;
		fire_event = fire_event;
		get_named_arg_dispatcher = get_named_arg_dispatcher;
		_dispatchers = dispatchers;
		_handlers = handlers;
		_event_map = event_map;
	};
end

return _M;