--[[
    ReactiveStore.spec.lua
    Comprehensive test suite for ReactiveStore using TestEZ
    
    Test Coverage:
    - Basic functionality
    - Error handling
    - Memory management
    - Signal propagation
    - Edge cases
    - Performance characteristics
    
    Author: Stackyz
    Date: July 12th, 2025
]]

local ReactiveStore = require(script.Parent)

return function()
    describe("ReactiveStore", function()
        
        describe("Constructor", function()
            it("should create a new ReactiveStore with primitive value", function()
                local store = ReactiveStore.new(42)
                
                expect(store).to.be.ok()
                expect(store:GetRawValue()).to.equal(42)
                expect(store:IsPrimitive()).to.equal(true)
                expect(store:IsTable()).to.equal(false)
                expect(store:IsDestroyed()).to.equal(false)
            end)
            
            it("should create a new ReactiveStore with table value", function()
                local data = {x = 1, y = 2}
                local store = ReactiveStore.new(data)
                
                expect(store).to.be.ok()
                expect(store:GetRawValue()).to.equal(data)
                expect(store:IsTable()).to.equal(true)
                expect(store:IsPrimitive()).to.equal(false)
                expect(store:IsDestroyed()).to.equal(false)
            end)
            
            it("should wrap nested tables automatically", function()
                local data = {
                    player = {
                        name = "John",
                        stats = {
                            health = 100,
                            mana = 50
                        }
                    }
                }
                
                local store = ReactiveStore.new(data)
                
                expect(store.player).to.be.ok()
                expect(store.player:IsTable()).to.equal(true)
                expect(store.player.name:GetRawValue()).to.equal("John")
                expect(store.player.stats.health:GetRawValue()).to.equal(100)
            end)
            
            it("should throw error when value is nil", function()
                expect(function()
                    ReactiveStore.new(nil)
                end).to.throw()
            end)
        end)
        
        describe("Property Access", function()
            it("should allow access to table properties", function()
                local store = ReactiveStore.new({x = 10, y = 20})
                
                expect(store.x:GetRawValue()).to.equal(10)
                expect(store.y:GetRawValue()).to.equal(20)
            end)
            
            it("should throw error when accessing primitive as table", function()
                local store = ReactiveStore.new(42)
                
                expect(function()
                    local _ = store.x
                end).to.throw()
            end)
            
            it("should return nil when accessing destroyed object", function()
                local store = ReactiveStore.new({x = 1})
                store:Destroy()
                
                expect(store.x).to.equal(nil)
            end)
        end)
        
        describe("Property Modification", function()
            it("should allow modification of table properties", function()
                local store = ReactiveStore.new({x = 10})
                
                store.x = 20
                expect(store.x:GetRawValue()).to.equal(20)
            end)
            
            it("should fire change events on modification", function()
                local store = ReactiveStore.new({x = 10})
                local changeCount = 0
                local lastKey, lastNewValue, lastOldValue
                
                store.Changed:Connect(function(key, newValue, oldValue)
                    changeCount = changeCount + 1
                    lastKey = key
                    lastNewValue = newValue
                    lastOldValue = oldValue
                end)
                
                store.x = 20
                
                expect(changeCount).to.equal(1)
                expect(lastKey).to.equal("x")
                expect(lastNewValue:GetRawValue()).to.equal(20)
                expect(lastOldValue).to.equal(10)
            end)
            
            it("should destroy old wrapper when replacing value", function()
                local store = ReactiveStore.new({x = {y = 1}})
                local oldWrapper = store.x
                
                store.x = {z = 2}
                
                expect(function()
                    oldWrapper:IsDestroyed()
                end).to.throw()

                expect(store.x.z:GetRawValue()).to.equal(2)
            end)
            
            it("should throw error when modifying primitive", function()
                local store = ReactiveStore.new(42)
                
                expect(function()
                    store.x = 10
                end).to.throw()
            end)
            
            it("should allow assignment to destroyed object (becomes regular table)", function()
                local store = ReactiveStore.new({x = 1})
                store:Destroy()
                
                store.x = 10
                expect(store.x).to.equal(10)
            end)
        end)
        
        describe("Iteration", function()
            it("should support pairs() iteration", function()
                local data = {a = 1, b = 2, c = 3}
                local store = ReactiveStore.new(data)
                
                local count = 0
                for key, value in store do
                    count = count + 1
                    expect(value:GetRawValue()).to.equal(data[key])
                end
                
                expect(count).to.equal(3)
            end)
            
            it("should throw error when iterating primitive", function()
                local store = ReactiveStore.new(42)
                
                expect(function()
                    for _ in store do end
                end).to.throw()
            end)
            
            it("should allow iteration on destroyed object (becomes regular table)", function()
                local store = ReactiveStore.new({x = 1})
                store:Destroy()
            
                local count = 0
                for _ in store do 
                    count = count + 1 
                end
                
                expect(count).to.be.equal(1)
            end)
        end)
        
        describe("Utility Methods", function()
            it("should return correct keys", function()
                local store = ReactiveStore.new({a = 1, b = 2, c = 3})
                local keys = store:GetKeys()
                
                expect(#keys).to.equal(3)
                expect(table.find(keys, "a")).to.be.ok()
                expect(table.find(keys, "b")).to.be.ok()
                expect(table.find(keys, "c")).to.be.ok()
            end)
            
            it("should check key existence correctly", function()
                local store = ReactiveStore.new({x = 1})
                
                expect(store:HasKey("x")).to.equal(true)
                expect(store:HasKey("y")).to.equal(false)
            end)
            
            it("should return correct size", function()
                local store = ReactiveStore.new({a = 1, b = 2, c = 3})
                
                expect(store:GetSize()).to.equal(3)
                
                store.d = 4
                expect(store:GetSize()).to.equal(4)
            end)
            
            it("should remove keys correctly", function()
                local store = ReactiveStore.new({x = 1, y = 2})
                local changeCount = 0
                
                store.Changed:Connect(function()
                    changeCount = changeCount + 1
                end)
                
                store:RemoveKey("x")
                
                expect(store:HasKey("x")).to.equal(false)
                expect(store:HasKey("y")).to.equal(true)
                expect(changeCount).to.equal(1)
            end)
        end)
        
        describe("Signal Propagation", function()
            it("should propagate changes to parent", function()
                local store = ReactiveStore.new({
                    nested = {
                        value = 10
                    }
                })
                
                local parentChangeCount = 0
                local childChangeCount = 0
                
                store.Changed:Connect(function()
                    parentChangeCount = parentChangeCount + 1
                end)
                
                store.nested.Changed:Connect(function()
                    childChangeCount = childChangeCount + 1
                end)
                
                store.nested.value = 20
                
                expect(childChangeCount).to.equal(1)
                expect(parentChangeCount).to.equal(1)
            end)
            
            it("should handle deep nesting correctly", function()
                local store = ReactiveStore.new({
                    level1 = {
                        level2 = {
                            level3 = {
                                value = 1
                            }
                        }
                    }
                })
                
                local rootChangeCount = 0
                store.Changed:Connect(function()
                    rootChangeCount = rootChangeCount + 1
                end)
                
                store.level1.level2.level3.value = 2
                
                expect(rootChangeCount).to.equal(1)
            end)
        end)
        
        describe("Memory Management", function()
            it("should destroy properly", function()
                local store = ReactiveStore.new({x = {y = 1}})
                local nested = store.x

                expect(store:IsDestroyed()).to.equal(false)
                expect(nested:IsDestroyed()).to.equal(false)
                
                store:Destroy()
                
                expect(function()
                    store:IsDestroyed()
                end).to.throw()

                expect(function()
                    nested:IsDestroyed()
                end).to.throw()
            end)
            
            it("should handle multiple destroy calls", function()
                local store = ReactiveStore.new({x = 1})
                
                store:Destroy()
                
                expect(function()
                    store:Destroy()
                end).to.throw()
            end)
            
            it("should clean up circular references", function()
                local store = ReactiveStore.new({})
                
                -- Create circular reference
                store.self = store:GetRawValue()
                
                -- Should not cause infinite loop
                expect(function()
                    store:Destroy()
                end).never.to.throw()
            end)
        end)
        
        describe("Error Handling", function()
            it("should provide meaningful error messages", function()
                local store = ReactiveStore.new(42)
                
                expect(function()
                    store.x = 10
                end).to.throw("attempt to modify primitive value")
                
                expect(function()
                    local _ = store.x
                end).to.throw("attempt to index primitive value")
            end)
            
            it("should handle edge cases gracefully", function()
                local store = ReactiveStore.new({})
                
                -- Empty table operations
                expect(store:GetSize()).to.equal(0)
                expect(#store:GetKeys()).to.equal(0)
                
                -- Non-existent key removal
                expect(function()
                    store:RemoveKey("nonexistent")
                end).never.to.throw()
            end)
        end)
        
        describe("String Representation", function()
            it("should provide meaningful string representation", function()
                local data = {x = 1}

                local primitiveStore = ReactiveStore.new(42)
                local tableStore = ReactiveStore.new(data)
                
                expect(tostring(primitiveStore)).to.equal("ReactiveStore<number>(42)")
                expect(tostring(tableStore)).to.equal("ReactiveStore<Table>" .. tostring(data))
            end)
        end)
        
        describe("Compatibility", function()
            it("should maintain wrap() method for compatibility", function()
                local store = ReactiveStore.wrap({x = 1})
                
                expect(store).to.be.ok()
                expect(store:IsTable()).to.equal(true)
                expect(store.x:GetRawValue()).to.equal(1)
            end)
        end)
    end)
end
