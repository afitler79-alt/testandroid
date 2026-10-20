-- Rol Fusilero (CC:Androids 1.3.0 / Forge 1.20.1).
-- Patrulla un circuito corto y ataca solo los tipos de criaturas de TARGET_TYPES.
-- Funciona de forma autónoma desde la terminal del androide; no requiere el ordenador central.
-- El control por Pocket/chat es opcional. Enter detiene y cancela su tarea activa.

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 6
local REFUEL_AT = 20
local REFUEL_RETRY_DELAY = 5
-- Perfil de inventario Fusilero: ranuras de mochila CC:Androids (0-8).
-- Deja combustible compatible en FUEL_SLOT; reserva los demás índices para equipo.
local FUEL_SLOT = 7
local AMMO_SLOTS = { 1, 2, 3 }
local WEAPON_MATCH = "cgs:flintlock"
-- Solo se recogen objetos de esta lista. pickup() acepta un fragmento del ID.
-- El Flintlock de Create: Gunsmithing usa cartuchos de papel.
local ROLE_DROPS = {
    { match = "cgs:flintlock", kind = "weapon" },
    { match = "cgs:paper_cartridge", kind = "ammo" },
}
local RETREAT_HEALTH = 6
local ALERT_DELAY = 10
-- Debe coincidir con el prefijo que manda el Messenger del Pocket Computer.
local COMMANDER_NAME = "Android Mobile"

-- Lista explícita de hostiles. Añade aquí los IDs que quieras autorizar.
local TARGET_TYPES = {
    "zombie", "skeleton", "spider", "creeper", "witch", "drowned",
    "husk", "stray", "phantom", "pillager", "vindicator", "evoker",
    "ravager", "cave_spider", "silverfish", "blaze", "ghast",
    "magma_cube", "hoglin", "zoglin", "wither_skeleton", "guardian",
    "elder_guardian", "shulker", "vex", "warden", "endermite", "slime",
    "piglin_brute",

    -- Alex's Mobs: entidades registradas como monstruos/hostiles en el mod.
    "alexsmobs:bone_serpent", "alexsmobs:crimson_mosquito",
    "alexsmobs:centipede_head", "alexsmobs:mimicube", "alexsmobs:soul_vulture",
    "alexsmobs:guster", "alexsmobs:warped_mosco", "alexsmobs:straddler",
    "alexsmobs:dropbear", "alexsmobs:void_worm", "alexsmobs:rocky_roller",
    "alexsmobs:skelewag", "alexsmobs:farseer", "alexsmobs:skreecher",
    "alexsmobs:murmur",

    -- Ars Nouveau: solo los cuatro Wilden hostiles; no familiares ni invocaciones.
    "ars_nouveau:wilden_hunter", "ars_nouveau:wilden_stalker",
    "ars_nouveau:wilden_guardian", "ars_nouveau:wilden_boss",

    -- Northstar: zombis y fauna peligrosa de los planetas.
    "northstar:frozen_zombie", "northstar:mars_worm", "northstar:mars_cobra",
    "northstar:mercury_raptor", "northstar:venus_mimic", "northstar:venus_scorpion",

    -- Quark; se excluye Foxhound porque puede estar domesticado.
    "quark:forgotten", "quark:wraith",
}

local function slotInfo(index)
    local ok, name = pcall(android.getSlotInfo, index)
    if not ok then return nil, false end
    local normalized = type(name) == "string" and name:lower() or ""
    return name, normalized ~= "" and normalized ~= "minecraft:air" and normalized ~= "air"
end

local function apiFailed(value)
    return value == true or (type(value) == "table" and value[1] == true)
end

local function handInfo()
    local ok, name, count = pcall(android.getHandInfo, "main")
    if not ok then return nil, 0 end
    if type(name) ~= "string" or name == "" or name:lower() == "minecraft:air" or name:lower() == "air" then
        return nil, 0
    end
    return name, tonumber(count) or 0
end

local function findEmptySlot(exclude)
    for index = 0, 8 do
        if index ~= exclude then
            local _, occupied = slotInfo(index)
            if not occupied then return index end
        end
    end
    return nil
end

local function findAmmoSlot()
    for _, index in ipairs(AMMO_SLOTS) do
        local _, occupied = slotInfo(index)
        if not occupied then return index end
    end
    return nil
end

local function findAnyEmptySlot(excludeA, excludeB)
    for index = 0, 8 do
        if index ~= FUEL_SLOT and index ~= excludeA and index ~= excludeB then
            local _, occupied = slotInfo(index)
            if not occupied then return index end
        end
    end
    return nil
end

-- Recoge solo los IDs de ROLE_DROPS. Aparta el arma en una ranura libre,
-- guarda el botín en mochila y restaura el arma principal al terminar.
local function collectRoleDrop(drop)
    local heldName = handInfo()
    if drop.kind == "ammo" and not heldName then return false end
    if heldName and WEAPON_MATCH ~= "" and not heldName:lower():find(WEAPON_MATCH:lower(), 1, true) then
        return false
    end

    local destination
    if drop.kind == "ammo" then
        destination = findAmmoSlot()
    elseif heldName then
        destination = findAnyEmptySlot()
    end
    if drop.kind == "ammo" and not destination then return false end
    if heldName and not destination then return false end

    local temporarySlot
    if heldName then
        temporarySlot = findEmptySlot(FUEL_SLOT)
        if not temporarySlot or temporarySlot == destination then
            temporarySlot = findAnyEmptySlot(destination)
        end
        if not temporarySlot then return false end
        local stored, storeErr = pcall(android.storeItem, temporarySlot)
        if not stored or apiFailed(storeErr) then return false end
    end

    local called, result = pcall(android.pickup, drop.match)
    local pickedName = handInfo()
    if called and not apiFailed(result) and pickedName and drop.kind == "weapon" and not temporarySlot then
        print("Recogido " .. pickedName .. "; queda equipada en la mano principal.")
        return true
    end

    if called and not apiFailed(result) and pickedName then
        local stored, storeErr = pcall(android.storeItem, destination)
        if not stored or apiFailed(storeErr) then
            -- Si almacenar falla, conservar el objeto en mano es más seguro que soltarlo.
            if temporarySlot then pcall(android.equipSlot, temporarySlot) end
            print("No pude guardar " .. drop.match .. "; quedó en la mano.")
            return false
        end
        if not pickedName:lower():find(drop.match:lower(), 1, true) then
            print("Recogido " .. pickedName .. " en ranura " .. destination .. " (revisa el filtro " .. drop.match .. ").")
        else
            print("Recogido " .. pickedName .. " en ranura " .. destination .. ".")
        end
    end

    if temporarySlot then
        local restored, restoreErr = pcall(android.equipSlot, temporarySlot)
        if not restored or apiFailed(restoreErr) then
            print("Aviso: no pude restaurar el arma desde la ranura " .. temporarySlot .. ".")
        end
    elseif not pickedName then
        -- Sin objeto en mano y sin recogida, no hay nada que restaurar.
    end
    return called and not apiFailed(result) and pickedName ~= nil
end

local function collectRoleDrops()
    for _, drop in ipairs(ROLE_DROPS) do
        -- La mano debe estar libre durante pickup(); collectRoleDrop la libera
        -- de forma temporal y devuelve el arma a la mano principal.
        collectRoleDrop(drop)
    end
end

local function findFuelSlot()
    local name, occupied = slotInfo(FUEL_SLOT)
    if occupied and name and name:lower():find("redstone", 1, true) then return FUEL_SLOT end
    return nil
end

-- Refuelling consumes the main-hand stack in CC:Androids. Temporarily stow
-- the held weapon in a free stash slot, refuel from the configured fuel slot,
-- then restore both stacks. If there is no safe empty slot, do nothing.
local function refuelWithoutDroppingWeapon()
    local fuelSlot = findFuelSlot()
    if not fuelSlot then return false, "sin redstone compatible en ranura " .. FUEL_SLOT end

    local heldName = handInfo()
    local temporarySlot
    if heldName then
        if WEAPON_MATCH ~= "" and not heldName:lower():find(WEAPON_MATCH:lower(), 1, true) then
            return false, "la mano principal no contiene el arma configurada"
        end
        temporarySlot = findEmptySlot(fuelSlot)
        if not temporarySlot then return false, "sin ranura libre para guardar el arma temporalmente" end
        local ok, err = pcall(android.storeItem, temporarySlot)
        if not ok or apiFailed(err) then return false, "no se pudo guardar el arma: " .. tostring(err) end
    end

    local equipped, equipErr = pcall(android.equipSlot, fuelSlot)
    if not equipped or apiFailed(equipErr) then
        if temporarySlot then pcall(android.equipSlot, temporarySlot) end
        return false, "no se pudo equipar el combustible: " .. tostring(equipErr)
    end

    local before = android.fuelLevel()
    local called, result, resultLevel = pcall(android.refuel, 1)
    local after = android.fuelLevel()

    -- Refuel may consume the last item, leaving the hand empty. Store any
    -- remainder back into its now-empty source slot before restoring the weapon.
    local fuelName = handInfo()
    if fuelName then pcall(android.storeItem, fuelSlot) end
    if temporarySlot then
        local restored, restoreErr = pcall(android.equipSlot, temporarySlot)
        if not restored or apiFailed(restoreErr) then
            return false, "combustible procesado, pero no se pudo restaurar el arma: " .. tostring(restoreErr)
        end
    end

    if not called then return false, tostring(result) end
    if apiFailed(result) then
        return false, tostring(resultLevel or (type(result) == "table" and result[2]) or "CC:Androids rechazó el combustible")
    end
    return after > before, "combustible " .. tostring(after)
end

local function reportLoadout()
    local weapon = handInfo()
    print("Inventario Fusilero: arma en mano=" .. tostring(weapon or "vacía") .. "; combustible=ranura " .. FUEL_SLOT .. ".")
    if WEAPON_MATCH ~= "" and weapon and not weapon:lower():find(WEAPON_MATCH:lower(), 1, true) then
        print("Aviso: configura WEAPON_MATCH para el ID de tu arma o colócala en la mano principal.")
    end
    local ammo = {}
    for _, index in ipairs(AMMO_SLOTS) do
        local name, occupied = slotInfo(index)
        if occupied then ammo[#ammo + 1] = tostring(index) .. "=" .. tostring(name) end
    end
    print("Reservas de munición (ranuras 1-3): " .. (#ammo > 0 and table.concat(ammo, ", ") or "vacías/no configuradas"))
end

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

local function listenForCommands(unit, state)
    local unitName = tostring(unit.name or "Android")
    while true do
        local _, data = os.pullEvent("onChatMessage")
        if type(data) == "table" and data.senderName == COMMANDER_NAME then
            local target, command = tostring(data.message or ""):match("^!jarvis%s+(.+)%s+(%S+)$")
            if target and command and (target:lower() == "all" or target:lower() == unitName:lower()) then
                command = command:lower()
                if command == "hold" then
                    state.mode = "hold"
                    android.cancelTask()
                elseif command == "resume" or command == "patrol" then
                    state.mode = "patrol"
                elseif command == "return" then
                    state.mode = "return"
                    android.cancelTask()
                elseif command == "status" then
                    local current = android.getSelf()
                    pcall(android.sendChatMessage, unitName .. " | Fusilero | modo=" .. state.mode .. " | salud=" .. tostring(current.health) .. " | fuel=" .. tostring(android.fuelLevel()))
                end
            end
        end
    end
end

local function patrol(home, state, unit)
    local points = {
        { x = home.x + PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z + PATROL_RADIUS },
        { x = home.x - PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z - PATROL_RADIUS },
    }
    local nextPoint = 1
    local lastRefuelAttempt = -REFUEL_RETRY_DELAY
    local lastAlert = -ALERT_DELAY

    print("Rol Fusilero activo: patrulla y combate básico.")
    print("Objetivos autorizados: " .. #TARGET_TYPES .. " tipos de criatura.")
    print("Autorrepostaje al bajar de " .. REFUEL_AT .. " unidades de combustible.")
    print("Recogida selectiva: Flintlock y cartuchos de papel; munición en ranuras 1-3.")
    reportLoadout()
    print("Comandos chat: !jarvis " .. tostring(unit.name or "Android") .. " hold|resume|return|status")
    print("Pulsa ENTER para detener.")

    while true do
        -- Retirada inmediata al terminar el paso actual si la salud es crítica.
        local self = android.getSelf()
        local task = android.currentTask()
        if self.health and self.health <= RETREAT_HEALTH and task ~= "idle" then
            android.cancelTask()
            task = "idle"
            if os.clock() - lastAlert >= ALERT_DELAY then
                pcall(android.sendChatMessage, "ALERTA: Fusilero herido (" .. tostring(self.health) .. " HP); replegándose al punto de inicio.")
                lastAlert = os.clock()
            end
        end

        -- currentTask() devuelve "idle" cuando la tarea de movimiento/ataque termina.
        if task == "idle" then
            collectRoleDrops()
            local fuel = android.fuelLevel()
            if fuel < REFUEL_AT and os.clock() - lastRefuelAttempt >= REFUEL_RETRY_DELAY then
                local beforeRefuel = fuel
                local success, reason = refuelWithoutDroppingWeapon()
                lastRefuelAttempt = os.clock()
                fuel = android.fuelLevel()
                if success and fuel > beforeRefuel then
                    print("Autorrepostaje completado. Combustible: " .. tostring(fuel))
                else
                    print("No se pudo repostar: " .. tostring(reason) .. ". Revisa la ranura de combustible y deja libre una ranura temporal.")
                end
            end

            if fuel < 1 then
                -- No iniciar tareas que requieren movimiento sin combustible.
                sleep(SCAN_DELAY)
            elseif state.mode == "return" or (self.health and self.health <= RETREAT_HEALTH) then
                android.moveTo(home)
            elseif state.mode == "patrol" then
                local mob, mobType = findHostile()
                if mob then
                    if os.clock() - lastAlert >= ALERT_DELAY then
                        pcall(android.sendChatMessage, "ALERTA 1: Fusilero detectó " .. mobType .. ". Interceptando.")
                        lastAlert = os.clock()
                    end
                    android.attack(mob.uuid)
                else
                    android.moveTo(points[nextPoint])
                    nextPoint = nextPoint % #points + 1
                end
            elseif state.mode == "hold" then
                -- Sigue en posición y escucha comandos; el repostaje se mantiene activo.
            end
        end
        sleep(SCAN_DELAY)
    end
end

local function main()
    local self = android.getSelf()
    local home = { x = self.posX, y = self.posY, z = self.posZ }
    local state = { mode = "patrol" }

    if COMMANDER_NAME == "CONFIGURAR_JUGADOR" then
        print("Control remoto desactivado: configura COMMANDER_NAME en fusilero.lua.")
    end

    parallel.waitForAny(
        function() patrol(home, state, self) end,
        waitForStop,
        function() listenForCommands(self, state) end
    )
    android.cancelTask()
    print("Fusilero detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error en Fusilero: " .. tostring(err))
end
