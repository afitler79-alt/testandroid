-- Rol Fusilero (CC:Androids 1.3.0 / Forge 1.20.1).
-- Patrulla un circuito corto y ataca solo los tipos de criaturas de TARGET_TYPES.
-- Ejecutar en la terminal del androide. Enter detiene y cancela su tarea activa.

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 6
local REFUEL_AT = 20
local REFUEL_RETRY_DELAY = 5

-- Lista explícita de hostiles. Añade aquí los IDs que quieras autorizar.
local TARGET_TYPES = {
    "zombie", "skeleton", "spider", "creeper", "witch", "drowned",
    "husk", "stray", "phantom", "pillager", "vindicator", "evoker",
    "ravager", "cave_spider", "silverfish", "blaze", "ghast",
    "magma_cube", "hoglin", "zoglin", "wither_skeleton", "guardian",
    "elder_guardian", "shulker", "vex", "warden",
}

local function waitForStop()
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.enter then return end
    end
end

local function findHostile()
    local self = android.getSelf()
    local closest, closestType, closestDistance

    for _, mobType in ipairs(TARGET_TYPES) do
        local mob = android.getClosestMob(mobType)
        if mob and mob.uuid and mob.posX and mob.posY and mob.posZ then
            local dx = mob.posX - self.posX
            local dy = mob.posY - self.posY
            local dz = mob.posZ - self.posZ
            local distance = dx * dx + dy * dy + dz * dz

            if not closestDistance or distance < closestDistance then
                closest, closestType, closestDistance = mob, mobType, distance
            end
        end
    end
    return closest, closestType
end

local function patrol(home)
    local points = {
        { x = home.x + PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z + PATROL_RADIUS },
        { x = home.x - PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z - PATROL_RADIUS },
    }
    local nextPoint = 1
    local lastRefuelAttempt = -REFUEL_RETRY_DELAY

    print("Rol Fusilero activo: patrulla y combate básico.")
    print("Objetivos autorizados: " .. #TARGET_TYPES .. " tipos de criatura.")
    print("Autorrepostaje al bajar de " .. REFUEL_AT .. " unidades de combustible.")
    print("Pulsa ENTER para detener.")

    while true do
        -- currentTask() devuelve "idle" cuando la tarea de movimiento/ataque termina.
        if android.currentTask() == "idle" then
            local fuel = android.fuelLevel()
            if fuel < REFUEL_AT and os.clock() - lastRefuelAttempt >= REFUEL_RETRY_DELAY then
                -- refuel() usa combustible de la mano principal. pcall permite seguir
                -- funcionando si la mano está vacía o contiene un objeto no válido.
                -- Se consume una unidad por intento y luego se vuelve a comprobar el nivel.
                local beforeRefuel = fuel
                local ok, failed, result = pcall(android.refuel, 1)
                lastRefuelAttempt = os.clock()
                fuel = android.fuelLevel()
                if ok and not failed and fuel > beforeRefuel then
                    print("Autorrepostaje completado. Combustible: " .. tostring(fuel))
                else
                    local reason = ok and tostring(result or "objeto no válido") or tostring(failed)
                    print("No se pudo repostar: " .. reason .. ". Pon redstone/combustible compatible en la mano principal.")
                end
            end

            if fuel < 1 then
                -- No iniciar tareas que requieren movimiento sin combustible.
                sleep(SCAN_DELAY)
            else
                local mob, mobType = findHostile()
                if mob then
                    print("Contacto hostil: " .. mobType .. ". Interceptando.")
                    android.attack(mob.uuid)
                else
                    android.moveTo(points[nextPoint])
                    nextPoint = nextPoint % #points + 1
                end
            end
        end
        sleep(SCAN_DELAY)
    end
end

local function main()
    local self = android.getSelf()
    local home = { x = self.posX, y = self.posY, z = self.posZ }

    parallel.waitForAny(function() patrol(home) end, waitForStop)
    android.cancelTask()
    print("Fusilero detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error en Fusilero: " .. tostring(err))
end
