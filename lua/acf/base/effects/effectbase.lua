

if SERVER then
    util.AddNetworkString("ACE_Effect_Network")
end

local Effectdata = {
    ceffectdata = true,
    data = {}
}

function Effectdata:Set( id, value)
    if not value then return end
    if value ~= value then return end
    self.data[id] = value
end

-- Creates a new effectData
function ACE_Effectdata()
    return table.Copy(Effectdata)
end

local function iseffectdata()
    return not Effectdata[ceffectdata]
end

local function encode(data)
    return util.Compress(util.TableToJSON(data))
end

function ACE_CreateEffect( effect_name, effectdata )
    if not isstring(effect_name) then ErrorNoHalt("invalid effect name!") return end
    if not iseffectdata() then ErrorNoHalt("The provided effectdata is invalid!") return end

    local data = effectdata.data
    if next(data) then

        -- Network it to CLIENT if called on SERVER
        if SERVER then

            local packet = { name = effect_name, data = data }

            PrintTable(packet)
            
            local Compressed = encode(packet)

            net.Start("ACE_Effect_Network", true)
                net.WriteData(Compressed)
            net.Broadcast()
            return
        end
            -- Continue by getting the effect
        local Edata = ACE.ParticleEffects[effect_name]

        if isfunction(Edata.Init) then
            local data = packet.data
            Edata:Init(data)
        end
    else
        print("no data provided")
    end
end

if CLIENT then

    local function decode(data)
        return util.JSONToTable(util.Decompress(data))
    end

    net.Receive("ACE_Effect_Network", function(len)

        local Compressed = net.ReadData(len / 8)
        local packet = decode(Compressed)

        if istable(packet) then
            PrintTable(packet)

            local name = packet.name
            local data = packet.data
            local Edata = table.Copy(ACE.ParticleEffects[name])
            
            if isfunction(Edata.Init) then
                Edata:Init(data)
            end
        else
            print("Not a valid table!")
        end

    end)

end
