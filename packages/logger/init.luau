local EnumType = require(script.Parent.EnumType)
local Assert = require(script.Parent.Assert)

local LogLevel = EnumType.new("LogLevel", {
	"ERROR",
	"WARN",
	"INFO",
	"VERBOSE",
	"DEBUG",
	"SILLY",
})

export type LogLevel = typeof(LogLevel.DEBUG)

export type LogContext = {
	[string]: any,
}

export type LogEntry = {
	level: LogLevel,
	message: string,
	timestamp: string,
	context: LogContext,
	trace: string?,
	source: string?,
}

export type Transport = (entry: LogEntry) -> ()

local Logger = {}
Logger.__index = Logger

-- Optional: basic console transport
local function ConsoleTransport(entry: LogEntry)
	print(
		string.format(
			"[%s] [%s] %s\nContext: %s\nTraceback:\n%s\n",
			entry.timestamp,
			tostring(entry.level),
			entry.message,
			entry.context and game:GetService("HttpService"):JSONEncode(entry.context) or "none",
			entry.trace or "no traceback"
		)
	)
end

function Logger.new()
	return setmetatable({
		_level = LogLevel.INFO,
		_transports = {},
		_context = nil,
	}, Logger)
end

-- Sets the minimum log level required to emit logs
function Logger:setLevel(level: LogLevel)
	Assert.oneOf(level, LogLevel:GetEnumItems(), "log level")
	self._level = level
end

-- Adds a transport function that receives structured log entries
function Logger:addTransport(fn: Transport)
	Assert.callback(fn, "transport")
	table.insert(self._transports, fn)
end

-- Sets default context to include in all log entries
function Logger:withContext(context: LogContext): Logger
	Assert.table(context, "context")
	local clone = setmetatable({}, Logger)
	clone._level = self._level
	clone._transports = self._transports
	clone._context = context
	return clone
end

-- Emits a log entry with the given level
function Logger:_emit(level: LogLevel, message: string, context: LogContext?)
	local shouldLog = level.Value <= self._level.Value
	if not shouldLog then
		return
	end

	local info = debug.info(4, "Sl")
	local source = info and string.format("%s:%d", info[1], info[2])

	local entry: LogEntry = {
		level = level,
		message = message,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		context = context or self._context,
		trace = debug.traceback(nil, 3),
		source = source,
	}

	for _, transport in self._transports do
		transport(entry)
	end
end

function Logger:error(message: string, context: LogContext?)
	self:_emit(LogLevel.ERROR, message, context)
end

function Logger:warn(message: string, context: LogContext?)
	self:_emit(LogLevel.WARN, message, context)
end

function Logger:info(message: string, context: LogContext?)
	self:_emit(LogLevel.INFO, message, context)
end

function Logger:verbose(message: string, context: LogContext?)
	self:_emit(LogLevel.VERBOSE, message, context)
end

function Logger:debug(message: string, context: LogContext?)
	self:_emit(LogLevel.DEBUG, message, context)
end

function Logger:silly(message: string, context: LogContext?)
	self:_emit(LogLevel.SILLY, message, context)
end

return table.freeze({
	new = Logger.new,
	LogLevel = LogLevel,
	ConsoleTransport = ConsoleTransport,
})
