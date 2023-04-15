

-- server side

ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local playerStates = {}
local bitkaKills = {}
local Killers = {}
local PlayersInBitka = {}


RegisterNetEvent('Fineeasz_bitki:enter')
AddEventHandler('Fineeasz_bitki:enter', function(currentSphere)
    local src = source
    SetPlayerState(src, 'currentSphere', currentSphere)
end)

RegisterNetEvent('Fineeasz_bitki:exit')
AddEventHandler('Fineeasz_bitki:exit', function(currentSphere)
    local src = source
    SetPlayerState(src, 'currentSphere', 0)
end)

ESX.RegisterServerCallback('Fineeasz_bitki:getAvailableOrgs', function(source, cb, sphere)
    local src = source
    local currentSphere = GetPlayerState(src, 'currentSphere') or 0
    local orgsData = GetOrgsData(src, currentSphere)


    print(table.unpack(orgsData))

    cb(orgsData)
end)

RegisterServerEvent('Fineeasz_bitki:inviteToBitka')
AddEventHandler('Fineeasz_bitki:inviteToBitka', function(info)
    local src = source
    local encodedInfo = json.encode(info)    
    local decodedInfo = json.decode(encodedInfo)
    local receiverPlayer = decodedInfo.receiverPlayers[1]

    TriggerClientEvent("Fineeasz_bitki:inviteToBitka", receiverPlayer.value, info)
end)


RegisterServerEvent('Fineeasz_bitki:startBitka')
AddEventHandler('Fineeasz_bitki:startBitka', function(info)
    local src = source
    local selectedZone = tonumber(json.encode(info.zone))
    local bitkaId = math.random(11111111, 99999999)
    
    local initiatorOrg = info.initiator
    local receiverOrg = info.receiver

    bitkaKills[bitkaId] = {
        [initiatorOrg] = 0,
        [receiverOrg] = 0
    }

    AddPlayersToBitkaTable(bitkaId, info)    

    for i, receiver in ipairs(info.receiverPlayers) do
        SetPlayerAndVehicleRoutingBucket(receiver.value, bitkaId)
        TriggerClientEvent('Fineeasz_bitki:TP', receiver.value, selectedZone, "team1Position")
        TriggerClientEvent("Fineeasz_bitki:startBitka", receiver.value, info)
        SetPlayerState(receiver.value, 'currentBitka', bitkaId)
    end
      
    for i, initiator in ipairs(info.initiatorPlayers) do
        SetPlayerAndVehicleRoutingBucket(initiator.value, bitkaId)
        TriggerClientEvent('Fineeasz_bitki:TP', initiator.value, selectedZone, "team2Position")
        TriggerClientEvent("Fineeasz_bitki:startBitka", initiator.value, info)
        SetPlayerState(initiator.value, 'currentBitka', bitkaId)
    end
end)


RegisterServerEvent('Fineeasz_bitki:kill')
AddEventHandler('Fineeasz_bitki:kill', function(bitka, killerId)
    local playerId = source
    local player = ESX.GetPlayerFromId(playerId)
    local killer = ESX.GetPlayerFromId(killerId)

    local bitkaState = GetPlayerState(killer.source, "currentBitka")
    local initiatorOrg = bitka.initiator
    local receiverOrg = bitka.receiver
    local killerOrg

    -- Check if killer exists, otherwise assign the kill to the opposing team
    if killer then
        killerOrg = killer.hiddenjob.name
    else
        if player.hiddenjob.name == initiatorOrg then
            killerOrg = receiverOrg
        else
            killerOrg = initiatorOrg
        end
    end

    if bitkaState then 
        if not Killers[bitkaState] then
            Killers[bitkaState] = {}
        end

        local killerFound = false
        for i, v in ipairs(Killers[bitkaState]) do
            if v.name == killer.name then
                v.kills = v.kills + 1
                killerFound = true
                break
            end
        end

        if not killerFound then
            table.insert(Killers[bitkaState], {
                name = killer.name,
                kills = 1,
                org = killerOrg
            })
        end

        if not bitkaKills[bitkaState][killerOrg] then
            bitkaKills[bitkaState][killerOrg] = {}
        end

        bitkaKills[bitkaState][killerOrg] = bitkaKills[bitkaState][killerOrg] + 1

        local vehicles = GetAllVehicles()

        for i,vehicle in ipairs(vehicles) do
            if GetEntityRoutingBucket(vehicle) == tonumber(bitkaState) then
                SetEntityRoutingBucket(vehicle, 0)
            end
        end

        if IsBitkaOver(bitkaState, killer, player) then
            local winner = GetBitkaWinner(bitkaState, initiatorOrg, receiverOrg)
            local loser = GetBitkaLoser(bitkaState, initiatorOrg, receiverOrg)

            for i, p in ipairs(bitka.receiverPlayers) do
                TriggerClientEvent('chatMessage', p.value, "^3^*👑Ekipa ".. winner .." Wygrala bitke")
            end

            for i, p in ipairs(bitka.initiatorPlayers) do
                TriggerClientEvent('chatMessage', p.value, "^3^*👑Ekipa ".. winner .." Wygrala bitke")
                -- TriggerEvent("esx_rpchat:sendProximityMessage", "bitka", p.value, nil, { winner })
            end

            if winner == initiatorOrg then
                for i, p in ipairs(bitka.initiatorPlayers) do
                    TriggerClientEvent("Fineeasz_bitki:lootingTime", p.value, true)
                    SetPlayerAndVehicleRoutingBucket(p.value, 0)
                    TriggerEvent('hypex_ambulancejob:hypexrevive', p.value)
                end
            elseif winner == receiverOrg then
                for i, p in ipairs(bitka.receiverPlayers) do
                    TriggerClientEvent("Fineeasz_bitki:lootingTime", p.value, true)
                    SetPlayerAndVehicleRoutingBucket(p.value, 0)
                    TriggerEvent('hypex_ambulancejob:hypexrevive', p.value)
                end
            end
            
            if winner ~= initiatorOrg then
                for i, p in ipairs(bitka.initiatorPlayers) do
                    TriggerClientEvent("Fineeasz_bitki:lootingTime", p.value, false)
                    TriggerEvent('hypex_ambulancejob:hypexrevive', p.value)
                    SetPlayerAndVehicleRoutingBucket(p.value, 0)
                end
            elseif winner ~= receiverOrg then
                for i, p in ipairs(bitka.receiverPlayers) do
                    TriggerClientEvent("Fineeasz_bitki:lootingTime", p.value, false)
                    TriggerEvent('hypex_ambulancejob:hypexrevive', p.value)
                    SetPlayerAndVehicleRoutingBucket(p.value, 0)
                end
            end
        end
    end
end)


-- FUNCTIONS 

function GetBitkaLoser(bitkaId, initiatorOrg, receiverOrg)
    local team1Kills = bitkaKills[bitkaId][initiatorOrg]
    local team2Kills = bitkaKills[bitkaId][receiverOrg]
    if team1Kills > team2Kills then
        return receiverOrg
    elseif team2Kills > team1Kills then
        return initiatorOrg
    else
        return nil
    end
end

function AddPlayersToBitkaTable(bitkaId, info)
    if not PlayersInBitka[bitkaId] then
        PlayersInBitka[bitkaId] = {}
    end

    local initiatorOrg = info.initiator
    local receiverOrg = info.receiver

    if not PlayersInBitka[bitkaId][initiatorOrg] then
        PlayersInBitka[bitkaId][initiatorOrg] = {}
    end

    if not PlayersInBitka[bitkaId][receiverOrg] then
        PlayersInBitka[bitkaId][receiverOrg] = {}
    end

    for i, initiator in ipairs(info.initiatorPlayers) do
        table.insert(PlayersInBitka[bitkaId][initiatorOrg], initiator)
    end

    for i, receiver in ipairs(info.receiverPlayers) do
        table.insert(PlayersInBitka[bitkaId][receiverOrg], receiver)
    end

    return nil
end

function IsBitkaOver(bitkaId, killer, deadPlayer)
    local killerOrg = killer.hiddenjob.name
    local deadPlayerOrg = deadPlayer.hiddenjob.name

    local killerOrgKills = bitkaKills[bitkaId][killerOrg] 
    local killerOrgPlayersCount = #PlayersInBitka[bitkaId][killerOrg]

    local deadPlayerOrgKills = bitkaKills[bitkaId][deadPlayerOrg] 
    local deadPlayerOrgPlayersCount = #PlayersInBitka[bitkaId][deadPlayerOrg]

    return killerOrgKills == deadPlayerOrgPlayersCount
end

function GetBitkaWinner(bitkaId, initiatorOrg, receiverOrg)
    local team1Kills = bitkaKills[bitkaId][initiatorOrg]
    local team2Kills = bitkaKills[bitkaId][receiverOrg]
    if team1Kills > team2Kills then
        return initiatorOrg
    elseif team2Kills > team1Kills then
        return receiverOrg
    else
        return nil
    end
end

function GetOrgsData(src, sphere)
    local orgsData = {}
    local xPlayers = ESX.GetPlayers()
    local krolarekXplayer = ESX.GetPlayerFromId(src)
    local krolarekOrg = krolarekXplayer.hiddenjob.name

    for _, playerId in pairs(xPlayers) do
        local currentPlayer = ESX.GetPlayerFromId(playerId)
        local orgName, orgLabel = currentPlayer.hiddenjob.name, currentPlayer.hiddenjob.label
        local currentSphere = GetPlayerState(playerId, 'currentSphere') or nil

        if currentSphere == sphere and (src == playerId or krolarekOrg == orgName or krolarekOrg ~= orgName) then

            local foundOrg = false
            for _, orgData in ipairs(orgsData) do
                if orgData.name == orgName then
                    foundOrg = true
                    orgData.playerCount = orgData.playerCount + 1
                    table.insert(orgData.players, {
                        label = currentPlayer.name,
                        value = currentPlayer.source,
                    })
                    break
                end
            end

            if not foundOrg then
                local orgData = {
                    name = orgName,
                    label = orgLabel,
                    players = {},
                    playerCount = 1 + 20
                }
                table.insert(orgsData, orgData)
                table.insert(orgData.players, {
                    label = currentPlayer.name,
                    value = currentPlayer.source,
                })
            end
        end
    end

    return orgsData
end

function SetPlayerState(player, key, value)
    if not playerStates[player] then
        playerStates[player] = {}
    end

    playerStates[player][key] = value

    -- print("Updated player state for " .. GetPlayerName(player) .. ": " .. key .. " = " .. tostring(value))
end

function GetPlayerState(player, key)
    if not playerStates[player] then return nil end

    return playerStates[player][key]
end

function SetPlayerAndVehicleRoutingBucket(player, bucket)
    SetPlayerRoutingBucket(player, bucket)
    local ped = GetPlayerPed(player)
    local vehicle = GetVehiclePedIsIn(ped, false)
    SetEntityRoutingBucket(vehicle, bucket)
end

-- RegisterCommand("checkucket", function(src)
--     print(GetPlayerName(src).. " BUCKET: " .. GetPlayerRoutingBucket(src))
-- end)
