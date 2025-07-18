--[[
    UniqueTag.lua
    Represents an opaque, strictly protected tag object with a name (optional).
    Used solely for identity comparison or symbolic tagging. Always unique.

    Author: Stackyz
    Date: July 9th, 2025
]]

local function UniqueTag(name: string?)
	local label = name or "UnnamedTag"

	-- Create a new unique table that represents this tag instance
	local tag = {}

	return setmetatable(tag, {
		-- Blocks reading of undefined members
		__index = function(_, key)
			error(("Attempt to get UniqueTag::%s (not a valid member)"):format(tostring(key)), 2)
		end,

		-- Blocks writing of any member
		__newindex = function(_, key)
			error(("Attempt to set UniqueTag::%s (not a valid member)"):format(tostring(key)), 2)
		end,

		--- For debugging/logging only
		__tostring = function()
			return tostring(label)
		end,
	})
end

return UniqueTag
