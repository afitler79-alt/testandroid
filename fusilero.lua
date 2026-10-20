-- Rol Fusilero (CC:Androids 1.3.0 / Forge 1.20.1).
-- Patrulla un circuito corto y ataca solo los tipos de criaturas de TARGET_TYPES.
-- Ejecutar en la terminal del androide. Enter detiene y cancela su tarea activa.

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 6

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
    for _, mobType in ipairs(TARGET_TYPES) do
        local mob = android.getClosestMob(mobType)
        if mob and mob.uuid then return mob, mobType end
    end
    return nil, nil
end

local function patrol(home)
    local points = {
        { x = home.x + PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z + PATROL_RADIUS },
        { x = home.x - PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z - PATROL_RADIUS },
    }
    local nextPoint = 1

    print("Rol Fusilero activo: patrulla y combate básico.")
    print("Objetivos autorizados: " .. #TARGET_TYPES .. " tipos de criatura.")
    print("Pulsa ENTER para detener.")

    while true do
        if android.currentTask() == "idle" then
            local mob, mobType = findHostile()
            if mob then
                print("Contacto hostil: " .. mobType .. ". Interceptando.")
                android.attack(mob.uuid)
            else
                android.moveTo(points[nextPoint])
                nextPoint = nextPoint % #points + 1
            end
        end
        sleep(SCAN_DELAY)
    end
end

local function main()
    local self = android.getSelf()
    local home = { x = self.posX, y = self.posY, z = self.posZ }

    if android.fuelLevel() < 1 then
        print("Sin combustible. Pon combustible en la mano principal y reinicia Fusilero.")
        return
    end

    parallel.waitForAny(function() patrol(home) end, waitForStop)
    android.cancelTask()
    print("Fusilero detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error en Fusilero: " .. tostring(err))
end
