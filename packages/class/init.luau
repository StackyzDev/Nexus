local Class = {}
Class.__index = Class

function Class:new(...)
	if self.__singleton then
		error("Cannot instantiate singleton class \"" .. tostring(self.__classname or "<Unnamed>") .. "\"", 2)
	end
	
	local inst = setmetatable({}, self)
	if inst.init then
		inst:init(...)
	end
	return inst
end

function Class:extend(subclass)
	subclass.__index = subclass
	subclass.__super = self
	setmetatable(subclass, {__index = self})
	return subclass
end

function Class:IsA(className: string)
	local cls = self
	while typeof(cls) == "table" do
		if rawget(cls.__index, "__classname") == className then
			return true
		end
		cls = getmetatable(cls)
	end
	return false
end

function Class:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

return Class
