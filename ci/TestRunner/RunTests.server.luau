local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ServerScriptService.Packages.TestEZ)

TestEZ.TestBootstrap:run({ ReplicatedStorage.Packages })