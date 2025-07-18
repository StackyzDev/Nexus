local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BenchmarkRunner = {}

-- Configurações
local CONFIG = {
    BENCHMARK_SUFFIX = "%.bench$",
    PACKAGES_PATH = ReplicatedStorage.Packages,
    VERBOSE = true,
    STOP_ON_ERROR = false
}

-- Utilidades
local function stripBenchSuffix(name)
    return name:gsub(CONFIG.BENCHMARK_SUFFIX, "")
end

local function isBenchmarkFile(instance)
    return instance:IsA("ModuleScript") and instance.Name:match(CONFIG.BENCHMARK_SUFFIX)
end

local function log(message, level)
    if CONFIG.VERBOSE then
        local prefix = level == "ERROR" and "❌" or level == "WARN" and "⚠️" or "ℹ️"
        print(string.format("[%s] %s", prefix, message))
    end
end

local function safeRequire(moduleScript)
    local success, result = pcall(require, moduleScript)
    if success then
        return result
    else
        log(string.format("Failed to require %s: %s", moduleScript.Name, result), "ERROR")
        return nil
    end
end

local function runBenchmark(benchmark, name)
    log(string.format("Running benchmark: %s", name))
    
    local success, error = pcall(function()
        if type(benchmark.runAll) == "function" then
            benchmark.runAll()
        else
            log(string.format("Benchmark %s missing runAll() method", name), "WARN")
        end
    end)
    
    if not success then
        log(string.format("Benchmark %s failed: %s", name, error), "ERROR")
        return false
    end
    
    return true
end

-- Função principal
function BenchmarkRunner.run()
    log("Starting benchmark discovery...")
    
    local benchmarks = {}
    local successCount = 0
    local errorCount = 0
    
    -- Descobrir benchmarks
    for _, instance in pairs(CONFIG.PACKAGES_PATH:GetDescendants()) do
        if isBenchmarkFile(instance) then
            local benchmark = safeRequire(instance)
            if benchmark then
                table.insert(benchmarks, {
                    name = stripBenchSuffix(instance.Name),
                    module = benchmark,
                    instance = instance
                })
                log(string.format("Found benchmark: %s", instance.Name))
            end
        end
    end
    
    if #benchmarks == 0 then
        log("No benchmarks found!", "WARN")
        return
    end
    
    log(string.format("Found %d benchmark(s)", #benchmarks))
    
    -- Executar benchmarks
    for _, benchmark in ipairs(benchmarks) do
        local success = runBenchmark(benchmark.module, benchmark.name)
        
        if success then
            successCount = successCount + 1
        else
            errorCount = errorCount + 1
            
            if CONFIG.STOP_ON_ERROR then
                log("Stopping execution due to error", "ERROR")
                break
            end
        end
    end
    
    -- Relatório final
    log(string.format("Benchmark run completed: %d passed, %d failed", successCount, errorCount))
    
    return {
        total = #benchmarks,
        passed = successCount,
        failed = errorCount,
        benchmarks = benchmarks
    }
end

-- Configuração dinâmica
function BenchmarkRunner.configure(options)
    for key, value in pairs(options) do
        if CONFIG[key] ~= nil then
            CONFIG[key] = value
        end
    end
end

-- Executar automaticamente se chamado diretamente
if script == game:GetService("ServerScriptService"):FindFirstChild("BenchmarkRunner") then
    BenchmarkRunner.run()
end

return BenchmarkRunner
