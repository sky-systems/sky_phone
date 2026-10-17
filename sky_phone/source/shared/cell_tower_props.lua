SkyPhoneCellular.TowerStates = {}

function SkyPhoneCellular.TowerKey(tower)
    return ("%.3f:%.3f:%.3f"):format(tower.Coords.x, tower.Coords.y, tower.Coords.z)
end

function SkyPhoneCellular.PropPosition(tower, offset)
    local heading = math.rad(tower.Heading or 0.0)
    local cosine, sine = math.cos(heading), math.sin(heading)
    return vector3(
        tower.Coords.x + offset.x * cosine - offset.y * sine,
        tower.Coords.y + offset.x * sine + offset.y * cosine,
        tower.Coords.z + offset.z
    )
end
