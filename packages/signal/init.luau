-- -----------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--   stackyz  - July 8th, 2025 - Modified for Nexus.                          --
-- -----------------------------------------------------------------------------

export type Connection = {
	Connected: boolean,

	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
}

export type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	FireImmediate: (self: Signal<T...>, T...) -> (),

	Connect: (self: Signal<T...>, func: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, func: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,

	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

-- Reusable coroutine used to minimize the cost of spawning new threads
local FreeThread: (thread | false)? = false

-- Detects whether the environment supports deferred tasks
local IsDeferred: boolean = false

do
	local bindable = Instance.new("BindableEvent")
	-- This trick forces a deferred execution context,
	-- allowing us to check if `task.defer` is available
	bindable.Event:Connect(function()
		IsDeferred = true
	end)
	bindable:Fire()
	bindable:Destroy()
end

-- Executes a function in the reusable thread and puts it back
local function acquireThread(func: (...any) -> (), ...: any): ()
	local thread = FreeThread
	FreeThread = nil

	func(...)

	-- Return the thread to the pool
	FreeThread = thread
end

-- Entry point for the coroutine runner that loops infinitely,
-- waiting to be resumed with new functions to execute
local function runEventHandler(...: any): ()
	acquireThread(...)

	while true do
		acquireThread(coroutine.yield())
	end
end

local Connection = {} :: Connection
Connection.__index = Connection

-- Disconnects the connection from the linked list of listeners
function Connection:Disconnect()
	if self.Connected then
		self.Connected = false
		local signal = self._signal
		if signal._headListener == self then
			-- Special case: this listener is the head of the list
			signal._headListener = self._next
		else
			-- Traverse the list to unlink this connection
			local prev = signal._headListener
			while prev do
				if prev._next == self then
					prev._next = self._next
					break
				end
				prev = prev._next
			end
		end
	end
end

-- Alias method: Allow Destroy() to behave identically to Disconnect().
-- This matches the behavior of built-in RBXScriptConnection and improves API familiarity.
Connection.Destroy = Connection.Disconnect

-- Makes Connection strict: no new fields or undefined access allowed
setmetatable(Connection, {
	__index = function(_, key)
		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	-- Initializes a new signal with an empty linked list of listeners
	return setmetatable({
		_headListener = false,
		_proxyListener = false,
	}, Signal)
end

function Signal.Is(signal: any): boolean
	return type(signal) == "table" and getmetatable(signal) == Signal
end

function Signal.Wrap<T...>(rbxSignal: RBXScriptSignal): Signal<T...>
	-- Wraps a built-in RBXScriptSignal so it can behave like a custom signal
	if typeof(rbxSignal) ~= "RBXScriptSignal" then
		error("Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " .. typeof(rbxSignal))
	end

	local signal = Signal.new()
	signal._proxy = signal:Connect(function(...)
		rbxSignal:Fire(...)
	end)
	return signal
end

function Signal:Connect<T...>(func: (T...) -> ()): Connection
	-- Inserts the listener at the head of the linked list
	local connection = setmetatable({
		Connected = true,
		_func = func,
		_next = nil,
		_signal = self,
	}, Connection)
	connection._next, self._headListener = self._headListener, connection
	return connection
end

function Signal:Once<T...>(func: (T...) -> ()): Connection
	-- Connects a function that auto-disconnects after first call
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		func(...)
	end)
	return connection
end

function Signal:Wait<T...>(): T...
	-- Pauses the current coroutine until the signal is fired
	local running = coroutine.running()
	self:Once(function(...)
		task.spawn(running, ...) -- Resumes original coroutine with args
	end)
	return coroutine.yield()
end

function Signal:FireImmediate<T...>(...: T...)
	local listener = self._headListener
	while listener do
		if listener.Connected then
			-- If no coroutine is available, create one that loops handlers
			if not FreeThread then
				FreeThread = coroutine.create(runEventHandler)
			end

			-- Pass the function and args to the thread runner
			task.spawn(FreeThread, listener._func, ...)
		end
		listener = listener._next
	end
end

function Signal:FireDeferred<T...>(...: T...)
	local listener = self._headListener
	while listener do
		if listener.Connected then
			-- Uses Roblox's built-in deferred execution
			task.defer(listener._func, ...)
		end
		listener = listener._next
	end
end

-- Disconnects all listeners in the list
function Signal:DisconnectAll()
	local listener = self._headListener
	self._headListener = false
	while listener do
		listener.Connected = false
		listener = listener._next
	end
end

-- Cleans up the signal entirely
function Signal:Destroy()
	self:DisconnectAll()
	table.clear(self)
	setmetatable(self, nil)
end

-- Choose FireImmediate or FireDeferred depending on engine behavior
Signal.Fire = Signal[if IsDeferred then "FireDeferred" else "FireImmediate"]

-- Alias method: Allow ConnectOnce() as an alternative name for Once().
-- Improves API discoverability and naming clarity for new users.
Signal.ConnectOnce = Signal.Once

-- Makes Signal strict: throws on undefined access or mutation
setmetatable(Signal, {
	__index = function(_, key)
		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key)
		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

return table.freeze({
	new = Signal.new,
	Wrap = Signal.Wrap,
	Is = Signal.Is,
})
