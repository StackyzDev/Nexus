--[[
    ReactiveStore.benchmark.lua
    Performance benchmarks for ReactiveStore
    
    Benchmark Categories:
    - Creation performance
    - Access performance
    - Modification performance
    - Memory usage
    - Signal propagation overhead
    - Destruction performance
    - Scalability tests
    
    Author: Stackyz
    Date: July 12th, 2025
]]

local ReactiveStore = require(script.Parent)

-- Benchmark utilities
local function measureTime(func)
    local start = tick()
    local result = func()
    local elapsed = tick() - start
    return elapsed, result
end

local function measureMemory(func)
    local measurements = {}
    
    for i = 1, 3 do
        local before = gcinfo()
        local result = func()
        local after = gcinfo()
        
        measurements[i] = {
            memory = after - before,
            result = result
        }
        
        task.wait(0.001)
    end
    
    table.sort(measurements, function(a, b) return a.memory < b.memory end)
    local median = measurements[2]
    
    return median.memory, median.result
end

local function generateTestData(depth, width)
    local function createLevel(currentDepth)
        if currentDepth <= 0 then
            return math.random(1, 1000)
        end
        
        local table = {}
        for i = 1, width do
            table["key" .. i] = createLevel(currentDepth - 1)
        end
        return table
    end
    
    return createLevel(depth)
end

local function runBenchmark(name, func, iterations)
    iterations = iterations or 1000
    
    local totalTime = 0
    local minTime = math.huge
    local maxTime = 0
    
    -- Warm-up
    for i = 1, 10 do
        func()
    end
    
    -- Actual benchmark
    for i = 1, iterations do
        local time = measureTime(func)
        totalTime = totalTime + time
        minTime = math.min(minTime, time)
        maxTime = math.max(maxTime, time)
    end
    
    local avgTime = totalTime / iterations
    
    print(string.format(
        "%s: Avg: %.4fms, Min: %.4fms, Max: %.4fms, Total: %.4fms",
        name, avgTime * 1000, minTime * 1000, maxTime * 1000, totalTime * 1000
    ))
    
    return avgTime, minTime, maxTime
end

local BenchmarkSuite = {}

function BenchmarkSuite.runAll()
    print("=== ReactiveStore Performance Benchmarks ===")
    print()
    
    BenchmarkSuite.testCreationPerformance()
    BenchmarkSuite.testAccessPerformance()
    BenchmarkSuite.testModificationPerformance()
    BenchmarkSuite.testMemoryUsage()
    BenchmarkSuite.testSignalPropagation()
    BenchmarkSuite.testDestructionPerformance()
    BenchmarkSuite.testScalability()
    BenchmarkSuite.testStressTest()
    
    print()
    print("=== Benchmark Complete ===")
end

function BenchmarkSuite.testCreationPerformance()
    print("--- Creation Performance ---")
    
    -- Primitive creation
    runBenchmark("Primitive Creation", function()
        local store = ReactiveStore.new(42)
        store:Destroy()
    end, 10000)
    
    -- Simple table creation
    runBenchmark("Simple Table Creation", function()
        local store = ReactiveStore.new({x = 1, y = 2, z = 3})
        store:Destroy()
    end, 5000)
    
    -- Nested table creation
    local nestedData = generateTestData(3, 5)
    runBenchmark("Nested Table Creation", function()
        local store = ReactiveStore.new(nestedData)
        store:Destroy()
    end, 1000)
    
    -- Deep nesting
    local deepData = generateTestData(5, 3)
    runBenchmark("Deep Nesting Creation", function()
        local store = ReactiveStore.new(deepData)
        store:Destroy()
    end, 500)
    
    print()
end

function BenchmarkSuite.testAccessPerformance()
    print("--- Access Performance ---")
    
    local store = ReactiveStore.new({
        level1 = {
            level2 = {
                level3 = {
                    value = 42
                }
            }
        }
    })
    
    -- Direct access
    runBenchmark("Direct Access", function()
        local _ = store.level1
    end, 100000)
    
    -- Deep access
    runBenchmark("Deep Access", function()
        local _ = store.level1.level2.level3.value
    end, 50000)
    
    -- GetRawValue access
    runBenchmark("GetRawValue Access", function()
        local _ = store.level1:GetRawValue()
    end, 100000)
    
    store:Destroy()
    print()
end

function BenchmarkSuite.testModificationPerformance()
    print("--- Modification Performance ---")
    
    local store = ReactiveStore.new({})
    
    -- Property assignment
    runBenchmark("Property Assignment", function()
        store.testKey = math.random(1, 1000)
    end, 10000)
    
    -- Property replacement
    runBenchmark("Property Replacement", function()
        store.testKey = {newValue = math.random(1, 1000)}
    end, 5000)
    
    -- Key removal
    runBenchmark("Key Removal", function()
        store.tempKey = 123
        store:RemoveKey("tempKey")
    end, 5000)
    
    store:Destroy()
    print()
end

function BenchmarkSuite.testMemoryUsage()
    print("--- Memory Usage ---")
    
    -- Primitive memory usage
    local primitiveMemory = measureMemory(function()
        local stores = {}
        for i = 1, 1000 do
            stores[i] = ReactiveStore.new(i)
        end
        return stores
    end)
    
    print(string.format("Primitive Stores (1000): %.2f KB", primitiveMemory))
    
    -- Table memory usage
    local tableMemory = measureMemory(function()
        local stores = {}
        for i = 1, 1000 do
            stores[i] = ReactiveStore.new({x = i, y = i * 2})
        end
        return stores
    end)
    
    print(string.format("Table Stores (1000): %.2f KB", tableMemory))
    
    -- Memory cleanup test
    local stores = {}
    for i = 1, 1000 do
        stores[i] = ReactiveStore.new({x = i, y = {z = i}})
    end
    
    local beforeCleanup = gcinfo()
    for i = 1, 1000 do
        stores[i]:Destroy()
    end
    stores = nil
    local afterCleanup = gcinfo()
    
    print(string.format("Memory Cleanup: %.2f KB freed", beforeCleanup - afterCleanup))
    print()
end

function BenchmarkSuite.testSignalPropagation()
    print("--- Signal Propagation Performance ---")
    
    local store = ReactiveStore.new({
        level1 = {
            level2 = {
                level3 = {
                    value = 0
                }
            }
        }
    })
    
    local changeCount = 0
    store.Changed:Connect(function()
        changeCount = changeCount + 1
    end)
    
    -- Signal propagation overhead
    runBenchmark("Signal Propagation", function()
        store.level1.level2.level3.value = math.random(1, 1000)
    end, 5000)
    
    print(string.format("Total change events fired: %d", changeCount))
    
    -- Multiple listeners overhead
    local multiStore = ReactiveStore.new({value = 0})
    for i = 1, 100 do
        multiStore.Changed:Connect(function() end)
    end
    
    runBenchmark("Multiple Listeners (100)", function()
        multiStore.value = math.random(1, 1000)
    end, 1000)
    
    store:Destroy()
    multiStore:Destroy()
    print()
end

function BenchmarkSuite.testDestructionPerformance()
    print("--- Destruction Performance ---")
    
    -- Simple destruction
    runBenchmark("Simple Destruction", function()
        local store = ReactiveStore.new({x = 1, y = 2, z = 3})
        store:Destroy()
    end, 5000)
    
    -- Nested destruction
    local nestedData = generateTestData(4, 4)
    runBenchmark("Nested Destruction", function()
        local store = ReactiveStore.new(nestedData)
        store:Destroy()
    end, 1000)
    
    -- Mass destruction
    runBenchmark("Mass Destruction (100 stores)", function()
        local stores = {}
        for i = 1, 100 do
            stores[i] = ReactiveStore.new({x = i, y = {z = i}})
        end
        for i = 1, 100 do
            stores[i]:Destroy()
        end
    end, 100)
    
    print()
end

function BenchmarkSuite.testScalability()
    print("--- Scalability Tests ---")
    
    -- Wide tables (many properties)
    local wideData = {}
    for i = 1, 1000 do
        wideData["prop" .. i] = i
    end
    
    local wideTime = measureTime(function()
        local store = ReactiveStore.new(wideData)
        store:Destroy()
    end)
    
    print(string.format("Wide Table (1000 props): %.4fms", wideTime * 1000))
    
    -- Deep nesting
    local deepData = generateTestData(10, 2)
    local deepTime = measureTime(function()
        local store = ReactiveStore.new(deepData)
        store:Destroy()
    end)
    
    print(string.format("Deep Nesting (10 levels): %.4fms", deepTime * 1000))
    
    -- Mixed complexity
    local complexData = {
        users = {},
        settings = {
            graphics = {
                resolution = "1920x1080",
                quality = "high",
                effects = {
                    shadows = true,
                    reflections = true,
                    particles = true
                }
            },
            audio = {
                master = 1.0,
                sfx = 0.8,
                music = 0.6
            }
        },
        gameState = {
            level = 1,
            score = 0,
            inventory = {}
        }
    }
    
    -- Add many users
    for i = 1, 100 do
        complexData.users["user" .. i] = {
            name = "User" .. i,
            level = i,
            stats = {
                health = 100,
                mana = 50,
                experience = i * 100
            }
        }
    end
    
    -- Add inventory items
    for i = 1, 50 do
        complexData.gameState.inventory["item" .. i] = {
            name = "Item" .. i,
            quantity = math.random(1, 10),
            rarity = math.random(1, 5)
        }
    end
    
    local complexTime = measureTime(function()
        local store = ReactiveStore.new(complexData)
        store:Destroy()
    end)
    
    print(string.format("Complex Data Structure: %.4fms", complexTime * 1000))
    
    print()
end

function BenchmarkSuite.testStressTest()
    print("--- Stress Tests ---")
    
    -- Rapid modifications
    local store = ReactiveStore.new({})
    local stressTime = measureTime(function()
        for i = 1, 10000 do
            store["key" .. (i % 100)] = i
        end
    end)
    
    print(string.format("Rapid Modifications (10,000): %.4fms", stressTime * 1000))
    
    -- Rapid access
    local accessTime = measureTime(function()
        for i = 1, 10000 do
            local _ = store["key" .. (i % 100)]
        end
    end)
    
    print(string.format("Rapid Access (10,000): %.4fms", accessTime * 1000))
    
    -- Signal stress test
    local signalStore = ReactiveStore.new({value = 0})
    local eventCount = 0
    
    for i = 1, 10 do
        signalStore.Changed:Connect(function()
            eventCount = eventCount + 1
        end)
    end
    
    local signalTime = measureTime(function()
        for i = 1, 1000 do
            signalStore.value = i
        end
    end)
    
    print(string.format("Signal Stress (1,000 changes, 10 listeners): %.4fms", signalTime * 1000))
    print(string.format("Total events fired: %d", eventCount))
    
    -- Memory stress test
    local memoryStores = {}
    local memoryTime = measureTime(function()
        for i = 1, 1000 do
            memoryStores[i] = ReactiveStore.new({
                id = i,
                data = generateTestData(3, 3)
            })
        end
    end)
    
    print(string.format("Memory Stress (1,000 complex stores): %.4fms", memoryTime * 1000))
    
    -- Cleanup
    local cleanupTime = measureTime(function()
        for i = 1, 1000 do
            memoryStores[i]:Destroy()
        end
    end)
    
    print(string.format("Cleanup Time: %.4fms", cleanupTime * 1000))
    
    store:Destroy()
    signalStore:Destroy()
    
    print()
end

-- Production readiness checks
function BenchmarkSuite.productionReadinessCheck()
    print("--- Production Readiness Assessment ---")
    
    local results = {
        creation = {},
        access = {},
        modification = {},
        memory = {},
        destruction = {}
    }
    
    -- Performance thresholds (in milliseconds)
    local THRESHOLDS = {
        creation_simple = 0.1,
        creation_complex = 10,
        access_direct = 0.01,
        access_deep = 0.05,
        modification = 0.1,
        destruction = 1.0,
        memory_per_store = 1.0 -- KB
    }
    
    -- Test simple creation
    local simpleCreationTime = measureTime(function()
        local store = ReactiveStore.new({x = 1, y = 2})
        store:Destroy()
    end)
    results.creation.simple = simpleCreationTime * 1000
    
    -- Test complex creation
    local complexData = generateTestData(4, 5)
    local complexCreationTime = measureTime(function()
        local store = ReactiveStore.new(complexData)
        store:Destroy()
    end)
    results.creation.complex = complexCreationTime * 1000
    
    -- Test access performance
    local store = ReactiveStore.new({level1 = {level2 = {value = 42}}})
    
    local directAccessTime = measureTime(function()
        local _ = store.level1
    end)
    results.access.direct = directAccessTime * 1000
    
    local deepAccessTime = measureTime(function()
        local _ = store.level1.level2.value
    end)
    results.access.deep = deepAccessTime * 1000
    
    -- Test modification performance
    local modificationTime = measureTime(function()
        store.testProp = math.random(1, 1000)
    end)
    results.modification.time = modificationTime * 1000
    
    -- Test memory usage
    local memoryUsage = measureMemory(function()
        local stores = {}
        for i = 1, 100 do
            stores[i] = ReactiveStore.new({x = i, y = i * 2})
        end
        return stores
    end)
    results.memory.per_store = memoryUsage / 100
    
    -- Test destruction performance
    local destructionTime = measureTime(function()
        local testStore = ReactiveStore.new(generateTestData(3, 4))
        testStore:Destroy()
    end)
    results.destruction.time = destructionTime * 1000
    
    store:Destroy()
    
    -- Evaluation
    print("Performance Results:")
    print(string.format("  Simple Creation: %.4fms (threshold: %.1fms)", 
          results.creation.simple, THRESHOLDS.creation_simple))
    print(string.format("  Complex Creation: %.4fms (threshold: %.1fms)", 
          results.creation.complex, THRESHOLDS.creation_complex))
    print(string.format("  Direct Access: %.4fms (threshold: %.2fms)", 
          results.access.direct, THRESHOLDS.access_direct))
    print(string.format("  Deep Access: %.4fms (threshold: %.2fms)", 
          results.access.deep, THRESHOLDS.access_deep))
    print(string.format("  Modification: %.4fms (threshold: %.1fms)", 
          results.modification.time, THRESHOLDS.modification))
    print(string.format("  Memory Usage: %.2fKB per store (threshold: %.1fKB)", 
          results.memory.per_store, THRESHOLDS.memory_per_store))
    print(string.format("  Destruction: %.4fms (threshold: %.1fms)", 
          results.destruction.time, THRESHOLDS.destruction))
    
    -- Overall assessment
    local issues = {}
    
    if results.creation.simple > THRESHOLDS.creation_simple then
        table.insert(issues, "Simple creation too slow")
    end
    if results.creation.complex > THRESHOLDS.creation_complex then
        table.insert(issues, "Complex creation too slow")
    end
    if results.access.direct > THRESHOLDS.access_direct then
        table.insert(issues, "Direct access too slow")
    end
    if results.access.deep > THRESHOLDS.access_deep then
        table.insert(issues, "Deep access too slow")
    end
    if results.modification.time > THRESHOLDS.modification then
        table.insert(issues, "Modification too slow")
    end
    if results.memory.per_store > THRESHOLDS.memory_per_store then
        table.insert(issues, "Memory usage too high")
    end
    if results.destruction.time > THRESHOLDS.destruction then
        table.insert(issues, "Destruction too slow")
    end
    
    print()
    if #issues == 0 then
        print("✅ PRODUCTION READY - All performance thresholds met")
    else
        print("⚠️  PRODUCTION CONCERNS - Issues found:")
        for _, issue in ipairs(issues) do
            print("  - " .. issue)
        end
    end
    
    print()
end

-- Memory leak detection
function BenchmarkSuite.memoryLeakTest()
    print("--- Memory Leak Detection ---")
    
    local function createAndDestroyStores(count)
        local stores = {}
        for i = 1, count do
            stores[i] = ReactiveStore.new({
                id = i,
                nested = {
                    value = i,
                    deep = {
                        data = string.rep("x", 100)
                    }
                }
            })
        end
        
        for i = 1, count do
            stores[i]:Destroy()
        end
        
        stores = nil
        task.wait(0.001)
    end
    
    -- Baseline measurement
    local baseline = gcinfo()
    
    -- Run multiple cycles
    for cycle = 1, 5 do
        createAndDestroyStores(100)
        local current = gcinfo()
        local leaked = current - baseline
        
        print(string.format("Cycle %d: %.2fKB total, %.2fKB leaked", 
              cycle, current, leaked))
        
        if leaked > 50 then -- 50KB threshold
            print("⚠️  Potential memory leak detected!")
        end
    end
    
    print()
end

-- Run all benchmarks
return BenchmarkSuite
