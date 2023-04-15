-- client side

local PlayerData = {}
local isInOrg = false
local isInZone = false
local invited = nil
local currentBitka = nil
local zonesBlips = {}
local dead = false
local greenZone = false

ESX = nil

local function RefreshBlips()
    for k, v in pairs(zonesBlips) do
        RemoveBlip(v)
    end
    zonesBlips = {}
    if isInOrg then
        for i=1, #Config.Zones, 1 do
            local blip = AddBlipForRadius(Config.Zones[i].coords.x, Config.Zones[i].coords.y, Config.Zones[i].coords.z, Config.Zones[i].radius)
            SetBlipColour(blip, 1)
            SetBlipAlpha(blip, 100)
            zonesBlips[i] = blip
        end
    end 
end

Citizen.CreateThread(function()

	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) 
			ESX = obj 
		end)
		Citizen.Wait(250)
	end

    while not ESX.IsPlayerLoaded() do
        Citizen.Wait(100)
    end
    PlayerData = ESX.GetPlayerData()
    LocalPlayer.state:set('currentSphere', nil, true)
    LocalPlayer.state:set('inBitka', nil, true)
    SetupZones()
    if PlayerData.hiddenjob and PlayerData.hiddenjob.name:find("org") then
        isInOrg = true
    else
        isInOrg = false
    end
    RefreshBlips()  
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    if PlayerData.hiddenjob and PlayerData.hiddenjob.name:find("org") then
        isInOrg = true
    else
        isInOrg = false
    end
    RefreshBlips()
end)

RegisterNetEvent('esx:setHiddenJob')
AddEventHandler('esx:setHiddenJob', function(job)
    PlayerData.hiddenjob = job
    if PlayerData.hiddenjob and PlayerData.hiddenjob.name:find("org") then
        isInOrg = true
    else
        isInOrg = false
    end
    RefreshBlips()
    if isInZone and isInOrg and LocalPlayer.state.currentSphere then
        TriggerServerEvent('Fineeasz_bitki:exit', LocalPlayer.state.currentSphere)
        Wait(250)
        TriggerServerEvent('Fineeasz_bitki:enter', LocalPlayer.state.currentSphere)
    end
end)


local function OpenBitkiMenu()
    if cooldown then
        ESX.ShowNotification('Nie możesz tak często otwierać menu bitek')
        return
    end
    cooldown = true
    Citizen.CreateThread(function()
        Wait(10000)
        cooldown = false
    end)
    ESX.TriggerServerCallback('Fineeasz_bitki:getAvailableOrgs', function(cb)
        local elements = {}
        if cb == nil then return ESX.ShowNotification('Nie ma zadnych organizacji na tym obszarze do bitki') end 
        for _, data in pairs(cb) do
            local own = PlayerData.hiddenjob.name == data.name
            if own and data.playerCount < 7 then
                return ESX.ShowNotification('Potrzebujesz conajmniej 8 osób w ekipie aby rozpoczać bitkę')
            else
                if data.playerCount >= 7 then
                    table.insert(elements, {label = data.label .. (own and ' [Twoja org]' or ''), value = data.name, players = data.players, own = own })
                end
            end
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bitki_menu', {
            title = 'Dostępne organizacje',
            align = 'left',
            elements = elements
        }, function(data, menu)
            if not data.current.own then
                local ranking = false
                local addonLooting = false
                local isLooting = false
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bitki_settings_menu', {
                    title = 'Ustawienia bitki',
                    align = 'left',
                    elements = {
                        -- {label = 'Rankingowa - ' .. (ranking and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>'), value = 'ranking', state = ranking},
                        {label = 'Lootwanie - ' .. (isLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>'), value = 'isLooting', state = isLooting},
                        {label = 'Dodatkowy czas lootowania - ' .. (addonLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>'), value = 'looting', state = addonLooting},
                        {label = '<span style="font-weight: bold">Potwierdź</span>', value = 'confirm'}
                    }
                }, function(data2, menu2)
                    local newData = data2.current
                    if data2.current.value == 'looting' then
                        addonLooting = not addonLooting
                        newData.label = 'Dodatkowy czas lootowania - ' .. (addonLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')
                        newData.state = addonLooting
                        menu2.update({value = data2.current.value}, newData)
		                menu2.refresh()
                    elseif data2.current.value == 'isLooting' then
                        isLooting = not isLooting
                        newData.label = 'Lootowanie - ' .. (isLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')
                        newData.state = isLooting
                        menu2.update({value = data2.current.value}, newData)
		                menu2.refresh()
                    elseif data2.current.value == 'confirm' then
                        local myPlayers = {}
                        local enemyPlayers = {}
                        local elements3 = {
                            {label = '<span style="font-weight: bold;">Twoja drużyna</span>'}
                        }
                        for i=1, #elements, 1 do
                            if elements[i].own then
                                for _, player in pairs(elements[i].players) do
                                    table.insert(elements3, player)
                                    table.insert(myPlayers, player)
                                end
                            end
                        end
                        table.insert(elements3, {label = '<span style="font-weight: bold;">Drużyna przeciwna</span>'})
                        for _, player in pairs(data.current.players) do
                            table.insert(elements3, player)
                            table.insert(enemyPlayers, player)
                        end
                        table.insert(elements3, {label = '<span style="font-weight: bold;">Ustawienia</span>'})
                        --table.insert(elements3, {label = 'Rankingowa - ' .. (ranking and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')})
                        table.insert(elements3, {label = 'Lootowanie - ' .. (isLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')})
                        table.insert(elements3, {label = 'Dodatkowy czas lootowania - ' .. (addonLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')})
                        table.insert(elements3, {label = '<span style="font-weight: bold;">Potwierdź</span>', value = 'confirm'})
                        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bitki_finish_menu', {
                            title = 'Bitka z ' .. data.current.label,
                            align = 'left',
                            elements = elements3
                        }, function(data3, menu3)
                            if data3.current.value == 'confirm' then
                                local info = {
                                    ranking = ranking,
                                    addonLooting = addonLooting,
                                    isLooting = isLooting,
                                    initiator = PlayerData.hiddenjob.name,
                                    initiatorLabel = PlayerData.hiddenjob.label,
                                    initiatorPlayers = myPlayers,
                                    receiver = data.current.value,
                                    receiverLabel = data.current.label,
                                    receiverPlayers = enemyPlayers,
                                    zone = LocalPlayer.state.currentSphere
                                }
                                TriggerServerEvent('Fineeasz_bitki:inviteToBitka', info)
                                ESX.UI.Menu.CloseAll()
                            end
                        end, function(data3, menu3)
                            menu3.close()
                        end)
                    end
                end, function(data2, menu2)
                    menu2.close()
                end)
            end
        end, function(data, menu)
            menu.close()
        end)

    end, LocalPlayer.state.currentSphere)
end

local zones = {}

if Config.Debug then
    Citizen.CreateThread(function()
        while true do
            Wait(1)
            for k, v in pairs(zones) do
                v:marker()
            end
        end
    end)
end

local function insideLoop(zone)
    if isInZone then return end
    isInZone = true
    CreateThread(function()
        while isInZone and isInOrg do
            Citizen.Wait(1)
            if #(GetEntityCoords(PlayerPedId()) - zone.coords) > zone.radius - 20.0 then
                zone:marker()
            else
                Wait(500)
            end
        end
    end)
end

local function onEnter(self)
    Citizen.CreateThread(function()
        if not greenZone then
            greenZone = true
            while greenZone do
                Wait(1000)
                if not currentBitka then
                    SetLocalPlayerAsGhost(true)
                else
                    SetLocalPlayerAsGhost(false)
                end
            end
            SetLocalPlayerAsGhost(false)
        end
    end)
    if not isInOrg then return end
    TriggerServerEvent('Fineeasz_bitki:enter', self.id)
    LocalPlayer.state:set('currentSphere', self.id, true)
    insideLoop(self)
end

local function onExit(self)
    greenZone = false
    if not isInOrg then return end
    isInZone = false
    LocalPlayer.state:set('currentSphere', nil, true)
    TriggerServerEvent('Fineeasz_bitki:exit', self.id)
    if ESX.UI.Menu.GetOpened('default', GetCurrentResourceName(), 'bitki_menu') ~= nil then
        ESX.UI.Menu.CloseAll()
    end

    if currentBitka ~= nil then
        if not LocalPlayer.state.dead then
            SetEntityHealth(PlayerPedId(), 0)
        end
        Wait(500)
    end
end

function SetupZones()
    for i=1, #Config.Zones, 1 do
        local data = Config.Zones[i]
        data.onEnter = onEnter
        data.onExit = onExit
        zones[#zones + 1] = Spheres.create(data)
    end
end

local hasInvited = false

RegisterNetEvent('Fineeasz_bitki:inviteToBitka', function(info)
    if hasInvited then
        return TriggerServerEvent('Fineeasz_bitki:isInvited', info)
    end
    if LocalPlayer.state.currentSphere == info.zone then
        hasInvited = true
        local time = 15000
        ESX.ShowNotification('Otrzymałeś propozycję bitki od ' .. info.initiatorLabel)
        invited = info
        OpenAcceptMenu()
        Citizen.CreateThread(function()
            local accepted = nil
            while time > 0 and invited ~= nil do
                Citizen.Wait(1)
                time -= 10
            end
            invited = nil
            hasInvited = nil
            if ESX.UI.Menu.GetOpened('default', GetCurrentResourceName(), 'accept_bitki_menu') ~= nil then
                ESX.UI.Menu.CloseAll()
            end
        end)
    end
end)

RegisterCommand("bitkardy", function()
    if PlayerData.hiddenjob.grade >= 3 then
        if currentBitka == nil and isInZone and isInOrg and LocalPlayer.state.currentSphere then
            OpenBitkiMenu()
        end
    end
end)


function OpenAcceptMenu()
    local p = promise.new()
    local elements = {
        {label = '<span style="font-weight: bold;">Twoja drużyna</span>'}
    }
    for i=1, #invited.receiverPlayers, 1 do
        table.insert(elements, invited.receiverPlayers[i])
    end
    table.insert(elements,  {label = '<span style="font-weight: bold;">Drużyna przeciwna</span>'})
    for i=1, #invited.initiatorPlayers, 1 do
        table.insert(elements, invited.initiatorPlayers[i])
    end
    table.insert(elements, {label = '<span style="font-weight: bold;">Ustawienia</span>'})
    --table.insert(elements, {label = 'Rankingowa - ' .. (invited.ranking and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')})
    table.insert(elements, {label = 'Lootowanie - ' .. (invited.isLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')})
    table.insert(elements, {label = 'Dodatkowy czas lootowania - ' .. (invited.addonLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')})
    table.insert(elements, {label = '<span style="font-weight: bold;">Odrzuć</span>', value = 'reject'})
    table.insert(elements, {label = '<span style="font-weight: bold;">Potwierdź</span>', value = 'confirm'})
    ESX.UI.Menu.CloseAll()
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'accept_bitki_menu', {
        title = 'Bitka z ' .. invited.initiatorLabel,
        align = 'left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'confirm' then
            p:resolve(true)
            TriggerServerEvent("Fineeasz_bitki:startBitka", invited)
            menu.close()
        elseif data.current.value == 'reject' then
            p:resolve(false)
            menu.close()
        end
    end, function(data, menu)
        p:resolve(nil)
        menu.close()
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('Fineeasz_bitki:startBitka', function(info)
    if PlayerData.hiddenjob.name ~= info.receiver and PlayerData.hiddenjob.name ~= info.initiator then
        return 
    end
    ESX.ShowNotification('Trwa bitka: ' .. info.receiverLabel .. ' kontra ' .. info.initiatorLabel)
    dead = false
    currentBitka = info
    SetEntityHealth(PlayerPedId(), 200)
    LocalPlayer.state:set('inBitka', info.id, true)
    FreezeEntityPosition(PlayerPedId(), true)
    local vehicle = GetVehiclePedIsIn(PlayerPedId())
    if vehicle ~= 0 then
        FreezeEntityPosition(vehicle, true)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleFixed(vehicle)
    end
    ESX.Scaleform.ShowFreemodeMessage('3', '', 1)
    ESX.Scaleform.ShowFreemodeMessage('2', '', 1)
    ESX.Scaleform.ShowFreemodeMessage('1', '', 1)
    FreezeEntityPosition(vehicle, false)
    FreezeEntityPosition(PlayerPedId(), false)
    ESX.Scaleform.ShowFreemodeMessage('~r~Bitka rozpoczęta', '', 3)
end)

function KillBitka(killer)
    if currentBitka ~= nil then
        Wait(500)
        TriggerServerEvent('Fineeasz_bitki:kill', currentBitka, killer)
    end
end

AddEventHandler('esx:onPlayerDeath', function(data)
    if not dead then
        KillBitka(data.killerServerId)
        dead = true
    end
end)

RegisterNetEvent('Fineeasz_bitki:lootingTime', function(isWin)
    local time = currentBitka.addonLooting and Config.ExtraLootingTime or Config.LootingTime
    ESX.Scaleform.ShowFreemodeMessage(isWin and 'Wygrałeś' or 'Przegrałeś', (isWin and currentBitka.isLooting) and 'Masz ' .. time .. ' sekund na lootowanie' or '', 3)
    currentBitka = nil
    dead = false
    LocalPlayer.state:set('inBitka', nil, true)
    if currentBitka.isLooting then
        exports["hash_taskbar"]:taskBar(time * 1000 - 2000, "Czas na lootowanie", true, function(cb) 
            print("Ustawiono currentBitka na nil")
            currentBitka = nil
            dead = false
            LocalPlayer.state:set('inBitka', nil, true)
            TriggerClientEvent('hypex_ambulancejob:hypexrevive')
            ESX.ShowNotification('Bitka się zakończyła')
        end)
    else
        print("Ustawiono currentBitka na nil")
        currentBitka = nil
        dead = false
        LocalPlayer.state:set('inBitka', nil, true)
        TriggerClientEvent('hypex_ambulancejob:hypexrevive')
        ESX.ShowNotification('Bitka się zakończyła')
    end
end)

RegisterNetEvent('Fineeasz_bitki:exitCurrentBitka', function()
    currentBitka = nil
    LocalPlayer.state:set('inBitka', nil, true)
    dead = false
end)

RegisterNetEvent('Fineeasz_bitki:killers', function(killers)
    for i=1, #killers, 1 do
        local killer = killers[i]
        local message = killer.org.. " " .. killer.name .. " zabil " .. killer.kills .. " osob"
        TriggerEvent('chatMessage', message, {132, 3, 252})
    end    
end)

RegisterNetEvent('Fineeasz_bitki:fixVeh', function(veh)
    -- local vehicle = NetworkGetEntityFromNetworkId(veh)
    -- if vehicle and DoesEntityExist(vehicle) then
    --     SetVehicleEngineHealth(vehicle, 1000.0)
    --     SetVehicleUndriveable(vehicle, false)
    --     SetVehicleFixed(vehicle)
    -- end
end)


RegisterNetEvent('Fineeasz_bitki:TP', function(z, obj)
    local a = Config.Zones[z][obj]
    local coords = a[math.random(1, #a)]
    local playerPed = PlayerPedId()
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)

    if playerVehicle ~= 0 then
        SetEntityCoords(playerVehicle, coords.x, coords.y, coords.z)
        SetEntityHeading(playerVehicle, coords.w)
        SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
        SetEntityHeading(playerPed, coords.w)
        dead = false
    else
        SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
        SetEntityHeading(playerPed, coords.w)
        dead = false
    end
end)

