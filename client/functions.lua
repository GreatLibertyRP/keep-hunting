function createCustomBlips(data)
    for _, v in pairs(data) do
        -- create Blips
        if v.BlipsCoords ~= nill then
            Blip = AddBlipForCoord(v.BlipsCoords.x, v.BlipsCoords.y, v.BlipsCoords.z)
        else
            Blip = AddBlipForCoord(v.coord.x, v.coord.y, v.coord.z)
        end
        SetBlipAsShortRange(Blip, true)
        if v.radius ~= nil then
            SetBlipSprite(Blip, 141)

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(v.name)
            EndTextCommandSetBlipName(Blip)
            local RadiusBlip = AddBlipForRadius(v.coord.x, v.coord.y, v.coord.z, v.radius)
            print(v.radius)
            AddCircleZone(v.name, v.llegal, v.coord, v.radius, {
                name = "circle_zone",
                debugPoly = true
            })
            SetBlipRotation(RadiusBlip, 0)

            if v.llegal == false then
                SetBlipColour(RadiusBlip, 1)
            else
                SetBlipColour(RadiusBlip, 4)
            end

            SetBlipAlpha(RadiusBlip, 64)
        else
            SetBlipSprite(Blip, 442)

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Sell Meat")
            EndTextCommandSetBlipName(Blip)
        end
        SetBlipDisplay(Blip, 4)
        SetBlipScale(Blip, 0.6)
        SetBlipColour(Blip, 49)
    end
end

-- init qb-target for selling spots 
function initSellspotsQbTargets(sellspot)
    for _, v in pairs(Config.SellSpots) do
        -- spwan seller npcs
        exports['qb-target']:SpawnPed({
            [_] = v.SellerNpc
        })

        -- init qb-target for sellers
        exports['qb-target']:AddTargetModel(v.SellerNpc.model, {
            options = {{
                event = "cad-hunting:client:sellREQ",
                icon = "fas fa-sack-dollar",
                label = "Sell MMMMMMEATTTTTTTT"
            }},
            distance = 1.5
        })
    end
end

-- init qb-target for hunted animals
function initAnimalsTargting()
    for _, v in pairs(Config.Animals) do
        exports['qb-target']:AddTargetModel(v.model, {
            options = {{
                icon = "fas fa-sack-dollar",
                label = "slaughter",
                data = entity,
                canInteract = function(entity)
                    if not IsPedAPlayer(entity) then
                        local res = (entity and IsEntityDead(entity))
                        return res
                    end
                end,
                action = function(entity)
                    if IsPedAPlayer(entity) then
                        return false
                    end
                    TriggerEvent('cad-hunting:client:slaughterAnimal', entity)
                end
            }},
            distance = 1.5
        })
    end
end

-- match hash with out animal list
function getAnimalMatch(hash)
    for _, v in pairs(Config.Animals) do
        if (v.hash == hash) then
            return v
        end
    end
end

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(0)
    end
end

function weightedRandom(Rarities)
    local Index = math.random()
    local HighestRarity = "Common"

    for RarityName, Value in pairs(Rarities) do
        if Index >= Value and Value >= Rarities[HighestRarity] then
            HighestRarity = RarityName
        end
    end

    return HighestRarity
end

-- animals Smart Flee

function createThreadAnimalTraveledDistanceToBaitTracker(BaitCoord, entity)
    Citizen.CreateThread(function()
        local finished = false
        while not IsPedDeadOrDying(entity) and not finished do
            local spawnedAnimalCoords = GetEntityCoords(entity)
            if #(BaitCoord - spawnedAnimalCoords) < 1 then
                ClearPedTasks(entity)
                Citizen.Wait(1500)
                TaskStartScenarioInPlace(entity, "WORLD_DEER_GRAZING", 0, true)
                Citizen.SetTimeout(Config.AnimalsEatingSpeed, function()
                    finished = true
                end)
            end
            if #(spawnedAnimalCoords - GetEntityCoords(PlayerPedId())) < Config.AnimalsFleeView then
                ClearPedTasks(entity)
                TaskSmartFleePed(entity, PlayerPedId(), 600.0, -1)
                finished = true
            end
            Citizen.Wait(1000)
        end
        if not IsPedDeadOrDying(entity) then
            TaskSmartFleePed(entity, PlayerPedId(), 600.0, -1)
        end
    end)
end

-- 
function getSpawnLocation(coord)
    local radius = Config.baitSpawnDistance
    local safeCoord, outPosition
    local foundSafeSpot = true
    local index = 0

    -- try to get spwan postion 
    -- while foundSafeSpot == true and index <= 100 do
    --     local x = coord.x + math.random(-radius, radius)
    --     local y = coord.y + math.random(-radius, radius)
    --     safeCoord, outPosition = GetSafeCoordForPed(x, y, coord.z, false, 16)
    --     if outPosition.x ~= 0 or outPosition.y ~= 0 or outPosition.z ~= 0 then
    --         foundSafeSpot = false
    --     end
    --     index = index + 1
    -- end
    while foundSafeSpot == true and index <= 100 do
        posX = coord.x + math.random(-radius, radius)
        posY = coord.y + math.random(-radius, radius)
        Z = coord.z + 999.0
        heading = math.random(0, 359) + .0
        ground, posZ = GetGroundZFor_3dCoord(posX + .0, posY + .0, Z, 1)

        safeCoord, outPosition = GetSafeCoordForPed(posX, posY, Z, false, 16)
        foundSafeSpot = safeCoord
        index = index + 1
    end
    return vector4(posX, posY, posZ, heading)
end

function createDespawnThread(baitAnimal)
    Citizen.CreateThread(function()
        local finished = false
        while finished == false do
            local plyPed = PlayerPedId()
            local coord = GetEntityCoords(plyPed)

            local animalCoord = GetEntityCoords(baitAnimal)
            local distance = #(coord - animalCoord)
            print(distance)
            if distance >= 500 then
                SetModelAsNoLongerNeeded(baitAnimal)
                SetPedAsNoLongerNeeded(baitAnimal) -- despawn when player no longer in the area
                finished = true
            end
            Wait(750)
        end
    end)
end

-- function handleDecorator(animal)
--     if (DecorExistOn(animal, "lastshot")) then
--         DecorSetInt(animal, "lastshot", GetPlayerServerId(PlayerId()))
--     else
--         DecorRegister("lastshot", 3)
--         DecorSetInt(animal, "lastshot", GetPlayerServerId(PlayerId()))
--     end
-- end

-- function isKillMine(animal)
--     if (DecorExistOn(animal, "lastshot")) then
--         local aid = DecorGetInt(animal, "lastshot")
--         local id = GetPlayerServerId(PlayerId())
--         return (aid == id)
--     end
-- end
