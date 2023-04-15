Zones = {}

local function debugSphere(self)
    DrawMarker(28, self.coords.x, self.coords.y, self.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, self.radius, self.radius, self.radius, 255, 42, 24, 100, false, false, 0, false, false, false, false)
end

local function insideSphere(self, coords)
    return #(self.coords - coords) < self.radius
end

local insideZones = {}
local enteringZones = {}
local exitingZones = {}
local enteringSize = 0
local exitingSize = 0

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())

        for _, zone in pairs(Zones) do
            zone.distance = #(zone.coords - coords)
            local radius, contains = zone.radius

            if radius then
                contains = zone.distance < radius
            end

            if contains then
                if not zone.insideZone then
                    zone.insideZone = true

                    if zone.onEnter then
                        enteringSize += 1
                        enteringZones[enteringSize] = zone
                    end
                end
            else
                if zone.insideZone then
                    zone.insideZone = false
                    insideZones[zone.id] = nil

                    if zone.onExit then
                        exitingSize += 1
                        exitingZones[exitingSize] = zone
                    end
                end
            end
        end

        if exitingSize > 0 then
            table.sort(exitingZones, function(a, b)
                return a.distance > b.distance
            end)

            for i = 1, exitingSize do
                exitingZones[i]:onExit()
            end

            exitingSize = 0
            table.wipe(exitingZones)
        end

        if enteringSize > 0 then
            table.sort(enteringZones, function(a, b)
                return a.distance < b.distance
            end)

            for i = 1, enteringSize do
                enteringZones[i]:onEnter()
            end

            enteringSize = 0
            table.wipe(enteringZones)
        end

        Wait(300)
    end
end)

Spheres = {
    create = function(data)
        data.id = #Zones + 1
        data.coords = data.coords
        data.radius = (data.radius or 2) + 0.0
        data.contains = insideSphere
        data.marker = debugSphere

        Zones[data.id] = data
        return data
    end
}