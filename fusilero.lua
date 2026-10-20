
-- ============================================================
-- ROL FUSILERO v7
-- CC:Androids 1.3.0 / Forge 1.20.1 / Create: Gunsmithing
--
-- Correcciones:
--   * No contabiliza android.attack() como disparo.
--   * No simula recargas ni consume municion ficticiamente.
--   * Mantiene patrulla, objetivos, repostaje y comandos.
--   * Conserva la API Lua documentada de CC:Androids.
--
-- LIMITACION:
--   El disparo y la recarga NTGL requieren integracion Java.
-- ============================================================

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

local COMBAT_RANGE_SQ = 14 * 14
local MIN_RANGE_SQ = 4 * 4
local FIRE_COOLDOWN = 0.5

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

local TARGET_TYPES = {
    "minecraft:zombie",
    "minecraft:skeleton",
    "minecraft:spider",
    "minecraft:creeper",
    "minecraft:witch",
    "minecraft:drowned",
    "minecraft:husk",
    "minecraft:stray",
    "minecraft:phantom",
    "minecraft:pillager",
    "minecraft:vindicator",
    "minecraft:evoker",
    "minecraft:ravager",
    "minecraft:cave_spider",
    "minecraft:silverfish",
    "minecraft:blaze",
    "minecraft:ghast",
    "minecraft:magma_cube",
    "minecraft:hoglin",
    "minecraft:zoglin",
    "minecraft:wither_skeleton",
    "minecraft:guardian",
    "minecraft:elder_guardian",
    "minecraft:shulker",
    "minecraft:vex",
    "minecraft:warden",
    "minecraft:endermite",
    "minecraft:slime",
    "minecraft:piglin_brute",
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

local ROLE_DROPS = {}

for _, item in ipairs(CGS_WEAPONS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = {
        match = item, kind = "weapon"
    }
end

for _, item in ipairs(CGS_AMMO) do
    ROLE_DROPS[#ROLE_DROPS + 1] = {
        match = item, kind = "ammo"
    }
end

for _, item in ipairs(CREATE_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = {
        match = item, kind = "backtank"
    }
end

for _, item in ipairs(FOOD_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = {
        match = item, kind = "food"
    }
end

for _, item in ipairs(POTION_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = {
        match = item, kind = "potion"
    }
end

local lastFireTime = 0
local lastTarget = nil
local roleDropIndex = 1
local lastUnsupportedNotice = 0

local function apiFailed(value)
    return type(value) == "table" and value[1] == true
end

local function slotInfo(index)
    local ok, name, occupied = pcall(android.getSlotInfo, index)
    if not ok then
        return nil, false
    end

    local normalized = type(name) == "string"
        and name:lower() or ""

    local exists = normalized ~= ""
        and normalized ~= "minecraft:air"
        and normalized ~= "air"

    if type(occupied) == "boolean" then
        exists = exists and occupied
    end

    return name, exists
end

local function handInfo()
    local ok, name, count = pcall(android.getHandInfo, "main")
    if not ok or type(name) ~= "string" then
        return nil, 0
    end

    local lower = name:lower()
    if lower == "" or lower == "air"
        or lower == "minecraft:air" then
        return nil, 0
    end

    return name, tonumber(count) or 0
end

local function matchesList(name, list)
    if type(name) ~= "string" then
        return false
    end

    local lower = name:lower()
    for _, item in ipairs(list) do
        if lower:find(item, 1, true) then
            return true
        end
    end

    return false
end

local function isRoleWeapon(name)
    return matchesList(name, CGS_WEAPONS)
end

local function findEmptySlot(exclude)
    for index = 0, 8 do
        if index ~= exclude then
            local _, occupied = slotInfo(index)
            if not occupied then
                return index
            end
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
            if not occupied then
                return index
            end
        end
    end
    return nil
end

local function findSlotWithItem(list)
    for index = 0, 8 do
        local name, occupied = slotInfo(index)
        if occupied and matchesList(name, list) then
            return index
        end
    end
    return nil
end

-- Disparo: no llamar a attack(), porque es cuerpo a cuerpo.
-- La API Lua de CC:Androids no ofrece disparo NTGL.
local function fireAt(mob)
    if not mob or not mob.uuid then
        return false
    end

    local weapon = handInfo()
    if not weapon or not isRoleWeapon(weapon) then
        return false
    end

    local now = os.clock()
    if now - lastUnsupportedNotice >= 15 then
        print("Arma detectada: " .. weapon)
        print("Disparo NTGL no disponible desde la API Lua.")
        print("No se contabiliza ningun disparo ficticio.")
        lastUnsupportedNotice = now
    end

    lastFireTime = now
    return false
end

-- Recarga: no fingir que la recarga ha ocurrido.
local function tryReload()
    local weapon = handInfo()
    if weapon and isRoleWeapon(weapon) then
        if os.clock() - lastUnsupportedNotice >= 15 then
            print("Recarga NTGL pendiente de integracion Java.")
            lastUnsupportedNotice = os.clock()
        end
    end
    return false
end

local function engage(mob)
    local self = android.getSelf()
    if not self or not mob then
        return
    end

    local dx = mob.posX - self.posX
    local dy = mob.posY - self.posY
    local dz = mob.posZ - self.posZ
    local distSq = dx * dx + dy * dy + dz * dz

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

local function tryHeal()
    local self = android.getSelf()
    if not self or not self.health or self.health >= HEAL_AT then
        return
    end

    local heldName = handInfo()
    local tempSlot

    if heldName then
        tempSlot = findEmptySlot()
        if not tempSlot then
            return
        end

        local ok, result = pcall(android.storeItem, tempSlot)
        if not ok or apiFailed(result) then
            return
        end
    end

    local targetSlot = findSlotWithItem(POTION_ITEMS)
    if not targetSlot then
        targetSlot = findSlotWithItem(FOOD_ITEMS)
    end

    if targetSlot then
        pcall(android.equipSlot, targetSlot)
        print("Comida/pocion equipada. HP=" .. tostring(self.health))
    end

    -- No se consume automáticamente: CC:Androids no documenta
    -- una función de uso de objeto en la mano.
    if tempSlot then
        local held = handInfo()
        if not held then
            pcall(android.equipSlot, tempSlot)
        else
            local empty = findEmptySlot(tempSlot)
            if empty then
                pcall(android.storeItem, empty)
                pcall(android.equipSlot, tempSlot)
            end
        end
    end
end

local function collectRoleDrop(drop)
    if not drop then
        return false
    end

    local heldName = handInfo()
    if heldName then
        return false
    end

    local ok, result = pcall(android.pickup, drop.match)
    if not ok or apiFailed(result) then
        return false
    end

    local pickedName = handInfo()
    if not pickedName then
        return false
    end

    if drop.kind == "weapon" then
        print("Arma recogida: " .. pickedName)
        return true
    end

    local destination = findAnyEmptySlot()
    if not destination then
        print("Sin ranura para guardar: " .. pickedName)
        return false
    end

    local stored, err = pcall(android.storeItem, destination)
    if not stored or apiFailed(err) then
        print("No se pudo guardar: " .. pickedName)
        return false
    end

    print("Objeto guardado: " .. pickedName)
    return true
end

local function collectRoleDrops()
    local drop = ROLE_DROPS[roleDropIndex]
    collectRoleDrop(drop)
    roleDropIndex = roleDropIndex % #ROLE_DROPS + 1
end

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

    if handInfo() then
        return false, "mano ocupada; no se mueve el arma"
    end

    local ok, result = pcall(android.equipSlot, fuelSlot)
    if not ok or apiFailed(result) then
        return false, "no se pudo equipar combustible"
    end

    local before = android.fuelLevel()
    local called, fuelResult = pcall(android.refuel, 1)
    local after = android.fuelLevel()

    -- Si queda combustible en la mano, intenta devolverlo a su ranura.
    local held = handInfo()
    if held then
        local stored, storeResult = pcall(android.storeItem, fuelSlot)
        if not stored or apiFailed(storeResult) then
            print("AVISO: combustible restante en la mano.")
        end
    end

    if not called then
        return false, tostring(fuelResult)
    end

    if after > before then
        return true, "fuel -> " .. tostring(after)
    end

    return false, "el combustible no aumento"
end

local function reportLoadout()
    print("=== Fusilero v7 ===")
    print("Arma en mano: " .. tostring(handInfo() or "VACIA"))
    print("--- Stash 0-8 ---")

    for index = 0, 8 do
        local name, occupied = slotInfo(index)
        if occupied then
            local label = "r" .. index .. ": " .. tostring(name)
            if matchesList(name, CGS_AMMO) then
                label = label .. " [AMMO]"
            elseif isRoleWeapon(name) then
                label = label .. " [WEAPON]"
            elseif name:lower():find("redstone", 1, true) then
                label = label .. " [FUEL]"
            end
            print(label)
        else
            print("r" .. index .. ": [vacia]")
        end
    end

    print("Objetivos: " .. #TARGET_TYPES)
    print("Disparo/recarga requieren integracion NTGL.")
    print("====================")
end

local function parseOwners(input)
    local owners, names = {}, {}

    for part in tostring(input):gmatch("[^,\n]+") do
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
        if not file then
            return nil
        end

        local owners, names = parseOwners(file.readAll())
        file.close()

        if #names == 0 then
            return nil
        end

        print("Propietarios: " .. #names)
        return owners
    end

    print("Jugadores autorizados, separados por comas:")
    local owners, names = parseOwners(read())

    while #names == 0 do
        print("Escribe al menos un nombre:")
        owners, names = parseOwners(read())
    end

    local file = fs.open(OWNERS_FILE, "w")
    if not file then
        return nil
    end

    file.write(table.concat(names, "\n") .. "\n")
    file.close()

    print("Propietarios guardados.")
    return owners
end

local function waitForStop()
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.enter then
            return
        end
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

                elseif command == "resume"
                    or command == "patrol" then
                    state.mode = "patrol"

                elseif command == "return" then
                    state.mode = "return"
                    android.cancelTask()

                elseif command == "status" then
                    local cur = android.getSelf()
                    pcall(android.sendChatMessage,
                        unitName .. " | v7 | " .. state.mode
                        .. " | HP=" .. tostring(cur.health)
                        .. " | fuel=" .. tostring(android.fuelLevel())
                        .. " | arma=" .. tostring(handInfo() or "-")
                        .. " | disparo NTGL=no integrado")

                elseif command == "dump" then
                    local lines = {
                        "MANO: " .. tostring(handInfo() or "vacia")
                    }

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

local function findHostile()
    local self = android.getSelf()
    local closest, closestType, closestDistance

    for _, mobType in ipairs(TARGET_TYPES) do
        local ok, mob = pcall(android.getClosestMob, mobType)

        if ok and type(mob) == "table"
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
                tryHeal()
                lastHealAttempt = os.clock()
            end

            if os.clock() - lastRoleDropScan >= PICKUP_SCAN_DELAY then
                collectRoleDrops()
                lastRoleDropScan = os.clock()
            end

            local fuel = android.fuelLevel()

            if fuel < REFUEL_AT
                and os.clock() - lastRefuelAttempt >= REFUEL_RETRY_DELAY then

                local success, reason = refuelWithoutDroppingWeapon()
                lastRefuelAttempt = os.clock()
                fuel = android.fuelLevel()

                if success then
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
                        lastFireTime = 0

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
    print("Fusilero v7 detenido.")
end

local ok, err = pcall(main)

if not ok then
    pcall(android.cancelTask)
    print("Error: " .. tostring(err))
end
