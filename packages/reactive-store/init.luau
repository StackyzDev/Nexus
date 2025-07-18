--[[
    ReactiveStore.lua
    Reactive system for observing changes in nested data structures.
    Allows creating observable state trees with signal-based notifications.
    
    Features:
    - Automatic wrapping of nested tables
    - Signal-based notifications via .Changed
    - Deep observation with parent propagation
    - Iterable via pairs()
    - Controlled access and strict typing
    - Recursive :Destroy() method
    - Memory leak prevention
    - Support for primitive and complex values
    
    Author: Stackyz (Optimized)
    Date: July 12th, 2025
]]

local Signal = require(script.Parent.Signal)
local Assert = require(script.Parent.Assert)
local UniqueTag = require(script.Parent.UniqueTag)

-- Unique keys to avoid conflicts
local DATA_KEY = UniqueTag("ReactiveStore::Data")
local VALUE_KEY = UniqueTag("ReactiveStore::Value")
local DESTROYED_KEY = UniqueTag("ReactiveStore::Destroyed")

local ReactiveStore = {}
ReactiveStore.__index = ReactiveStore

-- Type checking cache
local TYPE_TABLE = "table"
local TYPE_FUNCTION = "function"

--[[
    Creates a new ReactiveStore wrapping a value
    @param value: any - Value to be wrapped
    @param parent: Signal? - Parent signal for propagation
    @return ReactiveStore
]]
function ReactiveStore.new(value: any, parent: any?): any
    Assert.new(value ~= nil, "ReactiveStore: value cannot be nil")
    
    local self = {}
    
    -- Initialize internal components
    self.Changed = Signal.new()
    self[DESTROYED_KEY] = false
    
    -- Determine if value is table or primitive
    local isTable = typeof(value) == TYPE_TABLE
    self[DATA_KEY] = isTable and {} or false
    self[VALUE_KEY] = value

    if parent then
        self.Changed:Connect(function(...)
            parent:Fire(...)
        end)
    end
    
    -- Recursive wrapping for tables
    if isTable then
        for key, val in pairs(value) do
            self[DATA_KEY][key] = ReactiveStore.new(val, self.Changed)
        end
    end
    
    setmetatable(self, ReactiveStore)
    return self
end

--[[
    Legacy method for compatibility
]]
function ReactiveStore.wrap(value: any, parent: any?): any
    return ReactiveStore.new(value, parent)
end

--[[
    Property access (metamethod __index)
]]
function ReactiveStore:__index(key: any): any
    -- Check if destroyed
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to access destroyed object", 2)
    end
    
    -- Access to class methods
    if ReactiveStore[key] then
        return ReactiveStore[key]
    end
    
    -- Only allow data access if it's a table
    if self[DATA_KEY] then
        return self[DATA_KEY][key]
    else
        error("ReactiveStore: attempt to index primitive value", 2)
    end
end

--[[
    Property modification (metamethod __newindex)
]]
function ReactiveStore:__newindex(key: any, newValue: any)
    -- Check if destroyed
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to modify destroyed object", 2)
    end
    
    -- Only allow modification if it's a table
    if not self[DATA_KEY] then
        error("ReactiveStore: attempt to modify primitive value", 2)
    end
    
    -- Destroy previous value if exists
    local oldWrapper = self[DATA_KEY][key]
    local oldValue = nil
    
    if oldWrapper then
        oldValue = oldWrapper:GetRawValue()
        oldWrapper:Destroy()
    end
    
    -- Create new wrapper for the value
    self[DATA_KEY][key] = ReactiveStore.new(newValue, self.Changed)
    self[VALUE_KEY][key] = newValue
    
    -- Fire change events
    self.Changed:Fire(key, self[DATA_KEY][key], oldValue)
end

--[[
    Iteration via pairs() (metamethod __iter)
]]
function ReactiveStore:__iter()
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to iterate destroyed object", 2)
    end
    
    if not self[DATA_KEY] then
        error("ReactiveStore: attempt to iterate primitive value", 2)
    end
    
    return next, self[DATA_KEY]
end

--[[
    String representation (metamethod __tostring)
]]
function ReactiveStore:__tostring(): string
    if self[DESTROYED_KEY] then
        return "ReactiveStore<DESTROYED>"
    end
    
    if self[DATA_KEY] then
        return "ReactiveStore<Table>" .. tostring(self[VALUE_KEY])
    else
        return "ReactiveStore<" .. typeof(self[VALUE_KEY]) .. ">(" .. tostring(self[VALUE_KEY]) .. ")"
    end
end

--[[
    Gets the raw value without wrapping
    @return any
]]
function ReactiveStore:GetRawValue(): any
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to access value of destroyed object", 2)
    end
    
    return self[VALUE_KEY]
end

--[[
    Checks if the store is a table
    @return boolean
]]
function ReactiveStore:IsTable(): boolean
    return self[DATA_KEY] and not self[DESTROYED_KEY]
end

--[[
    Checks if the store is primitive
    @return boolean
]]
function ReactiveStore:IsPrimitive(): boolean
    return not (self[DATA_KEY] or self[DESTROYED_KEY])
end

--[[
    Checks if the store was destroyed
    @return boolean
]]
function ReactiveStore:IsDestroyed(): boolean
    return self[DESTROYED_KEY]
end

--[[
    Gets all keys (tables only)
    @return array
]]
function ReactiveStore:GetKeys(): {any}
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to access keys of destroyed object", 2)
    end
    
    if not self[DATA_KEY] then
        error("ReactiveStore: attempt to get keys of primitive value", 2)
    end
    
    local keys = {}
    for key in self[DATA_KEY] do
        table.insert(keys, key)
    end
    
    return keys
end

--[[
    Removes a specific key (tables only)
    @param key: any - Key to be removed
]]
function ReactiveStore:RemoveKey(key: any)
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to remove key from destroyed object", 2)
    end
    
    if not self[DATA_KEY] then
        error("ReactiveStore: attempt to remove key from primitive value", 2)
    end
    
    local oldWrapper = self[DATA_KEY][key]
    if oldWrapper then
        local oldValue = oldWrapper:GetRawValue()
        oldWrapper:Destroy()
        self[DATA_KEY][key] = nil
        self[VALUE_KEY][key] = nil
        
        -- Fire removal events
        self.Changed:Fire(key, nil, oldValue)
    end
end

--[[
    Checks if a key exists (tables only)
    @param key: any - Key to check
    @return boolean
]]
function ReactiveStore:HasKey(key: any): boolean
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to check key in destroyed object", 2)
    end
    
    if not self[DATA_KEY] then
        return false
    end
    
    return self[DATA_KEY][key] ~= nil
end

--[[
    Gets the number of elements (tables only)
    @return number
]]
function ReactiveStore:GetSize(): number
    if self[DESTROYED_KEY] then
        error("ReactiveStore: attempt to get size of destroyed object", 2)
    end
    
    if not self[DATA_KEY] then
        error("ReactiveStore: attempt to get size of primitive value", 2)
    end
    
    local count = 0
    for _ in pairs(self[DATA_KEY]) do
        count = count + 1
    end
    
    return count
end

--[[
    Destroys the ReactiveStore and releases resources
]]
function ReactiveStore:Destroy()
    if self[DESTROYED_KEY] then
        return -- Already destroyed
    end
    
    -- Mark as destroyed first to avoid loops
    self[DESTROYED_KEY] = true
    
    -- Destroy signal
    if self.Changed then
        self.Changed:Destroy()
    end
    
    -- Recursively destroy all children
    if self[DATA_KEY] then
        for key, wrapper in self[DATA_KEY] do
            if wrapper and typeof(wrapper.Destroy) == TYPE_FUNCTION then
                wrapper:Destroy()
            end
            rawset(self[DATA_KEY], key, nil)
            if self[VALUE_KEY] then
                self[VALUE_KEY][key] = nil
            end
        end
    end
    
    -- Clear all references
    self[DATA_KEY] = nil
    self[VALUE_KEY] = nil
    self.Changed = nil
    
    -- Remove metatable
    setmetatable(self, nil)
end

return ReactiveStore
