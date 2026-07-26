--[[
    Synapse.lua - Communication Signal System
    Analogy: The neural synapses connecting different regions of the brain.
    Allows decoupled cross-module communication (Events).
]]

local Synapse = {}
Synapse.__index = Synapse

local _events = {}

function Synapse.on(name, callback)
    if not _events[name] then _events[name] = {} end
    table.insert(_events[name], callback)
    
    return {
        Disconnect = function()
            local listeners = _events[name]
            if not listeners then
                return
            end

            for i, cb in ipairs(listeners) do
                if cb == callback then
                    table.remove(listeners, i)
                    if #listeners == 0 then
                        _events[name] = nil
                    end
                    break
                end
            end
        end
    }
end

function Synapse.fire(name, ...)
    if not _events[name] then return end
    local listeners = table.clone and table.clone(_events[name]) or {table.unpack(_events[name])}
    for _, callback in ipairs(listeners) do
        task.spawn(callback, ...)
    end
end

function Synapse.clear(name)
    if name == nil then
        return
    end

    _events[name] = nil
end

function Synapse.clearAll()
    table.clear(_events)
end

function Synapse.getListenerCount(name)
    local listeners = _events[name]
    return listeners and #listeners or 0
end

return Synapse

