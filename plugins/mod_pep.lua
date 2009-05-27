
local jid_bare = require "util.jid".bare;
local jid_split = require "util.jid".split;
local st = require "util.stanza";
local hosts = hosts;
local user_exists = require "core.usermanager".user_exists;
local is_contact_subscribed = require "core.rostermanager".is_contact_subscribed;
local pairs, ipairs = pairs, ipairs;

local function publish(session, node, item)
	local stanza = st.message({from=session.full_jid, type='headline'})
		:tag('event', {xmlns='http://jabber.org/protocol/pubsub#event'})
			:tag('items', {node=node})
				:add_child(item)
			:up()
		:up();

	-- broadcast to resources
	stanza.attr.to = session.username..'@'..session.host;
	core_route_stanza(session, stanza);

	-- broadcast to contacts
	for jid, item in pairs(session.roster) do
		if jid and jid ~= "pending" and (item.subscription == 'from' or item.subscription == 'both') then
			stanza.attr.to = jid;
			core_route_stanza(session, stanza);
		end
	end
end

module:add_iq_handler("c2s", "http://jabber.org/protocol/pubsub", function (session, stanza)
	if stanza.attr.type == 'set' and (not stanza.attr.to or jid_bare(stanza.attr.from) == stanza.attr.to) then
		local payload = stanza.tags[1];
		if payload.name == 'pubsub' then
			payload = payload.tags[1];
			if payload and payload.name == 'publish' and payload.attr.node then
				local node = payload.attr.node;
				payload = payload.tags[1];
				if payload then
					publish(session, node, payload);
					return true;
				end -- TODO else error
			end -- TODO else error
		end
	end
	origin.send(st.error_reply(stanza, "cancel", "service-unavailable"));
end);
