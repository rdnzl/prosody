local array = {};

local array_mt = { __index = array, __tostring = function (array) return array:concat(", "); end };
local function new_array(_, t)
	return setmetatable(t or {}, array_mt);
end

setmetatable(array, { __call = new_array });

function array:map(func, t2)
	local t2 = t2 or array{};
	for k,v in ipairs(self) do
		t2[k] = func(v);
	end
	return t2;
end

function array:filter(func, t2)
	local t2 = t2 or array{};
	for k,v in ipairs(self) do
		if func(v) then
			t2:push(v);
		end
	end
	return t2;
end


array.push = table.insert;
array.pop = table.remove;
array.sort = table.sort;
array.concat = table.concat;
array.length = function (t) return #t; end

function array:random()
	return self[math.random(1,#self)];
end

function array:shuffle()
	local len = #self;
	for i=1,#self do
		local r = math.random(i,len);
		self[i], self[r] = self[r], self[i];
	end
end

function array:reverse()
	local len = #self-1;
	for i=len,1,-1 do
		self:push(self[i]);
		self:pop(i);
	end
end

_G.array = array 