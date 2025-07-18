--[[
    Assert.lua
    Utility module for runtime validation and defensive programming.

    This module provides structured assertion functions for verifying 
    types, conditions, and expectations across Nexus libraries. Unlike 
    Lua's built-in `assert`, it provides more informative error messages 
    and stack trace depth control.

    This is especially useful when building reusable packages that benefit 
    from consistent and descriptive error reporting.

    Author: Stackyz
    Date: July 9th, 2025
]]

local Assert = {}

-- Basic truthy assertion (main entrypoint)
function Assert.new(value: any, message: string?, level: number?)
	if not value then
		error(message or "Assertion failed", (level or 2) + 1)
	end
end

-- typeof validation with descriptive message
function Assert.typeof(value: any, expected: string, name: string?, level: number?)
	if typeof(value) ~= expected then
		error(string.format("%s must be a '%s', got '%s'", name or "value", expected, typeof(value)), (level or 2) + 1)
	end
end

-- Specific type assertions
function Assert.string(value: any, name: string?, level: number?)
	Assert.typeof(value, "string", name, (level or 2) + 1)
end

function Assert.number(value: any, name: string?, level: number?)
	Assert.typeof(value, "number", name, (level or 2) + 1)
end

function Assert.table(value: any, name: string?, level: number?)
	Assert.typeof(value, "table", name, (level or 2) + 1)
end

function Assert.callback(value: any, name: string?, level: number?)
	Assert.typeof(value, "function", name, (level or 2) + 1)
end

-- Accepts nil or expected type
function Assert.optional(value: any, expected: string, name: string?, level: number?)
	if value ~= nil then
		Assert.typeof(value, expected, name, (level or 2) + 1)
	end
end

-- Must match one of the provided options (==)
function Assert.oneOf(value: any, options: { any }, name: string?, level: number?)
	for _, option in ipairs(options) do
		if value == option then
			return
		end
	end

	error(
		string.format(
			"Invalid %s. Expected one of {%s}, got: %s",
			name or "value",
			table.concat(options, ", "),
			tostring(value)
		),
		(level or 2) + 1
	)
end

return Assert
