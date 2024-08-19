local Effect = {}

function Effect:Init(data)
    print("init", data)

    local Origin = data.position print("Origin:", Origin)

end

function Effect:Think()
    print("wow")
end

ACE_DefineParticles("test", Effect )