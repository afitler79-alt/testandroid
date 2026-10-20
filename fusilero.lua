
-- ═══════════════════════════════════════════════════════════════
-- ROL FUSILERO v6
-- CC:Androids 1.3.0 / Forge 1.20.1
-- Create: Gunsmithing
--
-- Disparo: android.attack(uuid)
-- Recarga: requiere confirmar la API real de CGS.
-- Munición: en la hotbar del android.
-- ENTER: detiene el programa y cancela la tarea.
-- ═══════════════════════════════════════════════════════════════

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 6

local REFUEL_AT = 20
local REFUEL_RETRY_DELAY = 5
local FUEL_SLOT = 7

local PICKUP_SCAN_DELAY = 0.8
local HEAL_AT = 12
local HEAL_RETRY_DELAY = 8
local RETREAT_HEALTH = 6
local ALERT_DELAY = 10
local OWNERS_FILE = "owners.cfg"

-- COMBATE
local COMBAT_RANGE_SQ = 14 * 14
local MIN_RANGE_SQ = 4 * 4
local FIRE_COOLDOWN = 0.5
local RELOAD_COOLDOWN = 3

-- Evita contar como disparo una llamada fallida.
-- Estas capacidades son estimaciones del cargador.
local MAG_CAPACITY = {
    ["cgs:flintlock"] = 1,
    ["cgs:revolver"] = 6,
    ["cgs:shotgun"] = 1,
    ["cgs:nailgun"] = 32,
    ["cgs:gatling"] = 32,
    ["cgs:blazegun"] = 32,
    ["cgs:launcher"] = 1,
    ["cgs:pneumatic_hammer"] = 1,
    ["cgs:frag_grenade"] = 1,
}

local CGS_WEAPONS = {
    "cgs:flintlock",
    "cgs:revolver",
    "cgs:shotgun",
    "cgs:nailgun",
    "cgs:gatling",
    "cgs:blazegun",
    "cgs:launcher",
    "cgs:pneumatic_hammer",
    "cgs:frag_grenade",
}

local CGS_AMMO = {
    "cgs:paper_cartridge",
    "cgs:paper_shot",
    "cgs:round_revolver",
    "cgs:round_revolver_piercing",
    "cgs:round_revolver_blank",
    "cgs:round_shotgun",
    "cgs:round_shotgun_flechette",
    "cgs:round_shotgun_flechette_steel",
    "cgs:round_shotgun_incendiary",
    "cgs:round_shotgun_blank",
    "cgs:round_gatling",
    "cgs:round_gatling_piercing",
    "cgs:round_gatling_blank",
    "cgs:nail",
    "cgs:nail_steel",
    "cgs:rocket",
    "cgs:rocket_small",
    "cgs:spear",
    "cgs:lead_balls",
    "cgs:shell_gatling",
    "cgs:shell_revolver",
    "cgs:shell_shotgun",
}

local CREATE_ITEMS = {
    "create:brass_backtank",
}

local FOOD_ITEMS = {
    "minecraft:cooked_beef",
    "minecraft:cooked_porkchop",
    "minecraft:cooked_chicken",
    "minecraft:cooked_mutton",
    "minecraft:golden_carrot",
    "minecraft:golden_apple",
    "minecraft:bread",
    "minecraft:cooked_cod",
    "minecraft:cooked_salmon",
}

local POTION_ITEMS = {
    "minecraft:potion",
    "minecraft:splash_potion",
}

local ROLE_DROPS = {}

for _, w in ipairs(CGS_WEAPONS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = w, kind = "weapon" }
end

for _, a in ipairs(CGS_AMMO) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = a, kind = "ammo" }
end

for _, b in ipairs(CREATE_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = b, kind = "backtank" }
end

for _, f in ipairs(FOOD_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = f, kind = "food" }
end

for _, p in ipairs(POTION_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = p, kind = "potion" }
end

-- OBJETIVOS
local TARGET_TYPES = {
    "zombie", "skeleton", "spider", "creeper", "witch", "drowned",
    "husk", "stray", "phantom", "pillager", "vindicator", "evoker",
    "ravager", "cave_spider", "silverfish", "blaze", "ghast",
    "magma_cube", "hoglin", "zoglin", "wither_skeleton", "guardian",
    "elder_guardian", "shulker", "vex", "warden", "endermite", "slime",
    "piglin_brute",
    "alexsmobs:bone_serpent",
    "alexsmobs:crimson_mosquito",
    "alexsmobs:centipede_head",
    "alexsmobs:mimicube",
    "alexsmobs:soul_vulture",
    "alexsmobs:guster",
    "alexsmobs:warped_mosco",
    "alexsmobs:straddler",
    "alexsmobs:dropbear",
    "alexsmobs:void_worm",
    "alexsmobs:rocky_roller",
    "alexsmobs:skelewag",
    "alexsmobs:farseer",
    "alexsmobs:skreecher",
    "alexsmobs:murmur",
    "ars_nouveau:wilden_hunter",
    "ars_nouveau:wilden_stalker",
    "ars_nouveau:wilden_guardian",
    "ars_nouveau:wilden_boss",
    "northstar:frozen_zombie",
    "northstar:mars_worm",
    "northstar:mars_cobra",
    "northstar:mercury_raptor",
    "northstar:venus_mimic",
    "northstar:venus_scorpion",
    "quark:forgotten",
    "quark:wraith",
}

-- ESTADO
local lastFireTime = 0
local lastReloadTime = 0
local shotsFired = 0
local currentMagCap = 8
local lastTarget = nil
local roleDropIndex = 1
local reloadFailCount = 0

-- UTILIDADES
local function slotInfo(index)
    local ok, name = pcall(android.getSlotInfo, index)
    if not ok then return nil, false end

    local normalized = type(name) == "string" and name:lower() or ""
    local occupied = normalized ~= ""
        and normalized ~= "minecraft:air"
        and normalized ~= "air"
        and normalized ~= "false"

    return name, occupied
end

local function apiFailed(value)
    return value == true
        or (type(value) == "table" and value[1] == true)
end

local function handInfo()
    local ok, name, count = pcall(android.getHandInfo, "main")
    if not ok then return nil, 0 end

    if type(name) ~= "string" or name == ""
        or name:lower() == "minecraft:air"
        or name:lower() == "air" then
        return nil, 0
    end

    return name, tonumber(count) or 0
end

local function isRoleWeapon(itemName)
    if type(itemName) ~= "string" then return false end
    local lower = itemName:lower()

    for _, w in ipairs(CGS_WEAPONS) do
        if lower:find(w, 1, true) then return true end
    end

    return false
end

local function matchesList(itemName, list)
    if type(itemName) ~= "string" then return false end
    local lower = itemName:lower()

    for _, item in ipairs(list) do
        if lower:find(item, 1, true) then return true end
    end

    return false
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

local function findAnyEmptySlot(excludeA, excludeB)
    for index = 0, 8 do
        if index ~= FUEL_SLOT
            and index ~= excludeA
            and index ~= excludeB then
            local _, occupied = slotInfo(index)
            if not occupied then return index end
        end
    end

    return nil
end

local function findSlotWithItem(itemList)
    for index = 0, 8 do
        local name, occupied = slotInfo(index)
        if occupied and name and matchesList(name, itemList) then
            return index
        end
    end

    return nil
end

local function getMagCapacity()
    local name = handInfo()

    if name then
        local lower = name:lower()

        for key, cap in pairs(MAG_CAPACITY) do
            if lower:find(key, 1, true) then
                currentMagCap = cap
                return cap
            end
        end
    end

    return currentMagCap
end

-- COMBATE
local function fireAt(mob)
    local now = os.clock()

    if now - lastFireTime < FIRE_COOLDOWN then
        return false
    end

    if not mob or not mob.uuid then return false end

    local name = handInfo()
    if not name or not isRoleWeapon(name) then
        return false
    end

    local ok, result = pcall(android.attack, mob.uuid)

    if not ok then
        print("Error de ataque: " .. tostring(result))
        return false
    end

    if apiFailed(result) then
        print("Ataque rechazado por CC:Androids.")
        return false
    end

    lastFireTime = now
    shotsFired = shotsFired + 1

    return true
end

-- RECARGA
-- No se declara una recarga exitosa sin una API confirmada.
-- useBlock solo intenta usar un bloque; no garantiza pulsar R.
local function tryReload(mob)
    local now = os.clock()

    if now - lastReloadTime < RELOAD_COOLDOWN then
        return false
    end

    local cap = getMagCapacity()
    if shotsFired < cap then return false end

    lastReloadTime = now
    reloadFailCount = reloadFailCount + 1

    if reloadFailCount == 1 or reloadFailCount % 3 == 0 then
        print("Cargador agotado: " .. tostring(handInfo()))
        print("Recarga CGS pendiente de confirmar.")
        print("Comprueba la municion compatible en la hotbar.")
    end

    -- Se conserva el contador para no simular una recarga.
    return false
end

local function engage(mob)
    local self = android.getSelf()
    local dx = mob.posX - self.posX
    local dy = mob.posY - self.posY
    local dz = mob.posZ - self.posZ
    local distSq = dx * dx + dy * dy + dz * dz

    if shotsFired >= getMagCapacity() then
        tryReload(mob)
        return
    end

    if distSq > COMBAT_RANGE_SQ then
        android.moveTo({
            x = mob.posX,
            y = mob.posY,
            z = mob.posZ
        })
    elseif distSq < MIN_RANGE_SQ then
        android.moveTo({
            x = self.posX + (self.posX - mob.posX) * 0.5,
            y = self.posY,
            z = self.posZ + (self.posZ - mob.posZ) * 0.5
        })
    else
        fireAt(mob)
    end
end

-- SUPERVIVENCIA
local function tryHeal()
    local self = android.getSelf()
    if not self.health or self.health >= HEAL_AT then return end

    local heldName = handInfo()
    local tempSlot

    if heldName then
        tempSlot = findEmptySlot()
        if not tempSlot then return end

        local ok, result = pcall(android.storeItem, tempSlot)
        if not ok or apiFailed(result) then return end
    end

    local targetSlot = findSlotWithItem(POTION_ITEMS)
    if not targetSlot then
        targetSlot = findSlotWithItem(FOOD_ITEMS)
    end

    if targetSlot then
        pcall(android.equipSlot, targetSlot)
        print("Comida/pocion equipada. HP=" .. tostring(self.health))
    end

    if tempSlot then
        pcall(android.equipSlot, tempSlot)
    end
end

-- RECOGIDA
local function collectRoleDrop(drop)
    if not drop then return false end

    local heldName = handInfo()
    if heldName and not isRoleWeapon(heldName) then
        return false
    end

    local destination = findAnyEmptySlot()
    if destination == nil then return false end

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

    if called and not apiFailed(result) and pickedName then
        if drop.kind == "weapon" and not temporarySlot then
            print("Arma recogida y equipada: " .. pickedName)
            return true
        end

        local stored, storeErr = pcall(android.storeItem, destination)

        if not stored or apiFailed(storeErr) then
            if temporarySlot then
                pcall(android.equipSlot, temporarySlot)
            end
            return false
        end

        print("Objeto recogido: " .. pickedName)
    end

    if temporarySlot then
        pcall(android.equipSlot, temporarySlot)
    end

    return called and not apiFailed(result) and pickedName ~= nil
end

local function collectRoleDrops()
    local drop = ROLE_DROPS[roleDropIndex]
    collectRoleDrop(drop)
    roleDropIndex = roleDropIndex % #ROLE_DROPS + 1
end

-- REPOSTAJE
local function findFuelSlot()
    local name, occupied = slotInfo(FUEL_SLOT)

    if occupied and name
        and name:lower():find("redstone", 1, true) then
        return FUEL_SLOT
    end

    return nil
end

local function refuelWithoutDroppingWeapon()
    local fuelSlot = findFuelSlot()

    if not fuelSlot then
        return false, "sin redstone en r" .. FUEL_SLOT
    end

    local heldName = handInfo()
    local temporarySlot

    if heldName then
        if not isRoleWeapon(heldName) then
            return false, "mano sin arma CGS"
        end

        temporarySlot = findEmptySlot(fuelSlot)
        if not temporarySlot then return false, "sin ranura libre" end

        local ok, err = pcall(android.storeItem, temporarySlot)
        if not ok or apiFailed(err) then
            return false, "no se guardo el arma"
        end
    end

    local equipped, equipErr = pcall(android.equipSlot, fuelSlot)

    if not equipped or apiFailed(equipErr) then
        if temporarySlot then pcall(android.equipSlot, temporarySlot) end
        return false, "no se equipo el combustible"
    end

    local before = android.fuelLevel()
    local called, result = pcall(android.refuel, 1)
    local after = android.fuelLevel()

    local fuelName = handInfo()
    if fuelName then pcall(android.storeItem, fuelSlot) end

    if temporarySlot then
        pcall(android.equipSlot, temporarySlot)
    end

    if not called then return false, tostring(result) end
    if apiFailed(result) then return false, "rechazado" end

    return after > before, "fuel -> " .. tostring(after)
end

-- INFORME
local function reportLoadout()
    local weapon = handInfo()

    print("=== Fusilero v6 ===")
    print("Arma en mano: " .. tostring(weapon or "VACIA"))

    if weapon and not isRoleWeapon(weapon) then
        print("AVISO: la mano no tiene un arma CGS.")
    end

    print("--- Stash 0-8 ---")

    for index = 0, 8 do
        local name, occupied = slotInfo(index)
        local label = "r" .. index .. ": "

        if occupied then
            label = label .. tostring(name)

            if name:lower():find("redstone", 1, true) then
                label = label .. " [FUEL]"
            elseif matchesList(name, CGS_AMMO) then
                label = label .. " [AMMO]"
            elseif matchesList(name, CGS_WEAPONS) then
                label = label .. " [WEAPON]"
            end
        else
            label = label .. "[vacia]"
        end

        print(label)
    end

    print("La municion debe estar en la hotbar del android.")
    print("Objetivos: " .. #TARGET_TYPES)
    print("====================")
end

-- CONTROL REMOTO
local function parseOwners(input)
    local owners, names = {}, {}

    for part in tostring(input):gmatch("[^,]+") do
        local name = part:match("^%s*(.-)%s*$")

        if name ~= "" and not owners[name:lower()] then
            owners[name:lower()] = true
            names[#names + 1] = name
        end
    end

    return owners, names
end

local function loadOwners()
    if fs.exists(OWNERS_FILE) then
        local file = fs.open(OWNERS_FILE, "r")
        if not file then return nil end

        local owners, names = parseOwners(file.readAll())
        file.close()

        if #names == 0 then return nil end

        print("Propietarios: " .. #names)
        return owners
    end

    print("Nombres de jugadores autorizados, separados por comas:")
    local owners, names = parseOwners(read())

    while #names == 0 do
        print("Escribe al menos un nombre:")
        owners, names = parseOwners(read())
    end

    local file = fs.open(OWNERS_FILE, "w")
    if not file then return nil end

    file.write(table.concat(names, "\n") .. "\n")
    file.close()

    print("Propietarios guardados.")
    return owners
end

local function waitForStop()
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.enter then return end
    end
end

local function listenForCommands(unit, state, owners)
    local unitName = tostring(unit.name or "Android")

    while true do
        local _, data = os.pullEvent("onChatMessage")

        if type(data) == "table"
            and owners[tostring(data.senderName or ""):lower()] then

            local target, command =
                tostring(data.message or ""):match(
                    "^!jarvis%s+(.+)%s+(%S+)$"
                )

            if target and command
                and (target:lower() == "all"
                or target:lower() == unitName:lower()) then

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
                    local cur = android.getSelf()

                    pcall(android.sendChatMessage,
                        unitName .. " | v6 | " .. state.mode
                        .. " | HP=" .. tostring(cur.health)
                        .. " | fuel=" .. tostring(android.fuelLevel())
                        .. " | arma=" .. tostring(handInfo() or "-")
                        .. " | disparos=" .. tostring(shotsFired)
                        .. "/" .. tostring(currentMagCap))

                elseif command == "dump" then
                    local lines = {}
                    local w = handInfo()

                    lines[#lines + 1] = "MANO: " .. tostring(w or "vacia")

                    for i = 0, 8 do
                        local n, occupied = slotInfo(i)
                        lines[#lines + 1] = "r" .. i .. ": "
                            .. (occupied and tostring(n) or "[vacia]")
                    end

                    pcall(android.sendChatMessage,
                        "INV: " .. table.concat(lines, " | "))
                end
            end
        end
    end
end

-- BUSQUEDA DE HOSTILES
local function findHostile()
    local self = android.getSelf()
    local closest, closestType, closestDistance

    for _, mobType in ipairs(TARGET_TYPES) do
        local ok, mob = pcall(android.getClosestMob, mobType)

        if ok and mob and next(mob)
            and mob.uuid and mob.posX
            and mob.posY and mob.posZ then

            local dx = mob.posX - self.posX
            local dy = mob.posY - self.posY
            local dz = mob.posZ - self.posZ
            local distSq = dx * dx + dy * dy + dz * dz

            if not closestDistance or distSq < closestDistance then
                closest = mob
                closestType = mobType
                closestDistance = distSq
            end
        end
    end

    return closest, closestType
end

-- BUCLE PRINCIPAL
local function patrol(home, state, unit)
    local points = {
        { x = home.x + PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z + PATROL_RADIUS },
        { x = home.x - PATROL_RADIUS, y = home.y, z = home.z },
        { x = home.x, y = home.y, z = home.z - PATROL_RADIUS },
    }

    local nextPoint = 1
    local lastRefuelAttempt = -REFUEL_RETRY_DELAY
    local lastRoleDropScan = -PICKUP_SCAN_DELAY
    local lastAlert = -ALERT_DELAY
    local lastHealAttempt = -HEAL_RETRY_DELAY

    reportLoadout()

    print("Comandos: !jarvis " .. tostring(unit.name or "Android")
        .. " hold|resume|return|status|dump")
    print("ENTER para detener.")

    while true do
        local self = android.getSelf()
        local task = android.currentTask()

        if self.health and self.health <= RETREAT_HEALTH
            and task ~= "idle" then

            android.cancelTask()
            task = "idle"

            if os.clock() - lastAlert >= ALERT_DELAY then
                pcall(android.sendChatMessage,
                    "ALERTA: HP=" .. tostring(self.health)
                    .. ". Replegando.")
                lastAlert = os.clock()
            end
        end

        if task == "idle" then
            if os.clock() - lastHealAttempt >= HEAL_RETRY_DELAY then
                local hpBefore = self.health
                tryHeal()

                local ok, after = pcall(android.getSelf)

                if ok and after.health ~= hpBefore then
                    lastHealAttempt = os.clock()
                end
            end

            if os.clock() - lastRoleDropScan >= PICKUP_SCAN_DELAY then
                collectRoleDrops()
                lastRoleDropScan = os.clock()
            end

            local fuel = android.fuelLevel()

            if fuel < REFUEL_AT
                and os.clock() - lastRefuelAttempt >= REFUEL_RETRY_DELAY then

                local beforeFuel = fuel
                local success, reason = refuelWithoutDroppingWeapon()

                lastRefuelAttempt = os.clock()
                fuel = android.fuelLevel()

                if success and fuel > beforeFuel then
                    print("Repostaje -> " .. tostring(fuel))
                else
                    print("Repostaje: " .. tostring(reason))
                end
            end

            if fuel < 1 then
                sleep(SCAN_DELAY)

            elseif state.mode == "return"
                or (self.health and self.health <= RETREAT_HEALTH) then

                lastTarget = nil
                android.moveTo(home)

            elseif state.mode == "patrol" then
                local mob, mobType = findHostile()

                if mob then
                    if lastTarget ~= mob.uuid then
                        lastTarget = mob.uuid
                        shotsFired = 0
                        reloadFailCount = 0
                        lastFireTime = 0
                        lastReloadTime = 0

                        if os.clock() - lastAlert >= ALERT_DELAY then
                            pcall(android.sendChatMessage,
                                "ALERTA: " .. tostring(mobType)
                                .. " detectado.")
                            lastAlert = os.clock()
                        end
                    end

                    engage(mob)
                else
                    lastTarget = nil
                    android.moveTo(points[nextPoint])
                    nextPoint = nextPoint % #points + 1
                end

            elseif state.mode == "hold" then
                lastTarget = nil
            end
        end

        sleep(SCAN_DELAY)
    end
end

-- MAIN
local function main()
    local self = android.getSelf()

    local home = {
        x = self.posX,
        y = self.posY,
        z = self.posZ
    }

    local state = { mode = "patrol" }
    local owners = loadOwners()

    if not owners then
        print("No se pudieron cargar los propietarios.")
        return
    end

    parallel.waitForAny(
        function()
            patrol(home, state, self)
        end,
        waitForStop,
        function()
            listenForCommands(self, state, owners)
        end
    )

    android.cancelTask()
    print("Fusilero v6 detenido.")
end

local ok, err = pcall(main)

if not ok then
    pcall(android.cancelTask)
    print("Error: " .. tostring(err))
end
