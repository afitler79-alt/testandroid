-- ═══════════════════════════════════════════════════════════════
-- ROL FUSILERO v8 (CC:Androids 1.3.0 / Forge 1.20.1)
-- Armas Minecraft vanilla: melee + arco.
--   Melee: android.attack(uuid)  → left click → golpea
--   Arco:  android.useEntity(uuid) → right click → dispara flecha
-- Flechas: deben estar en la hotbar/inventario del android.
-- Enter detiene y cancela la tarea activa.
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

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local COMBAT_RANGE_SQ = 14 * 14   -- Rango arco (~14 bloques)
local MELEE_RANGE_SQ = 4 * 4      -- Rango melee (~4 bloques)
local MIN_RANGE_SQ = 2 * 2        -- No acercarse a menos de 2 bloques
local FIRE_COOLDOWN = 0.5         -- Pausa entre disparos/golpes

-- ═══════════════════════════════════════════════════════════════
-- ARMAS VANILLA
-- ═══════════════════════════════════════════════════════════════
local MELEE_WEAPONS = {
    "minecraft:iron_sword",
    "minecraft:diamond_sword",
    "minecraft:netherite_sword",
    "minecraft:stone_sword",
    "minecraft:iron_axe",
    "minecraft:diamond_axe",
    "minecraft:netherite_axe",
    "minecraft:stone_axe",
    "minecraft:iron_pickaxe",
    "minecraft:diamond_pickaxe",
    "minecraft:netherite_pickaxe",
    "minecraft:stone_pickaxe",
    "minecraft:iron_shovel",
    "minecraft:diamond_shovel",
    "minecraft:netherite_shovel",
    "minecraft:stone_shovel",
    "minecraft:trident",
}

local RANGED_WEAPONS = {
    "minecraft:bow",
    "minecraft:crossbow",
}

-- ═══════════════════════════════════════════════════════════════
-- MUNICIÓN
-- ═══════════════════════════════════════════════════════════════
local AMMO_ITEMS = {
    "minecraft:arrow",
    "minecraft:spectral_arrow",
    "minecraft:tipped_arrow",
    "minecraft:fire_charge",
}

-- ═══════════════════════════════════════════════════════════════
-- OTROS ITEMS (recogida)
-- ═══════════════════════════════════════════════════════════════
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

local SHIELD_ITEM = "minecraft:shield"

-- ═══════════════════════════════════════════════════════════════
-- TABLA DE RECOGIDA
-- ═══════════════════════════════════════════════════════════════
local ROLE_DROPS = {}

for _, item in ipairs(MELEE_WEAPONS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = item, kind = "weapon" }
end
for _, item in ipairs(RANGED_WEAPONS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = item, kind = "weapon" }
end
for _, item in ipairs(AMMO_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = item, kind = "ammo" }
end
for _, item in ipairs(FOOD_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = item, kind = "food" }
end
for _, item in ipairs(POTION_ITEMS) do
    ROLE_DROPS[#ROLE_DROPS + 1] = { match = item, kind = "potion" }
end

-- ═══════════════════════════════════════════════════════════════
-- TARGETS
-- ═══════════════════════════════════════════════════════════════
local TARGET_TYPES = {
    "minecraft:zombie", "minecraft:skeleton", "minecraft:spider",
    "minecraft:creeper", "minecraft:witch", "minecraft:drowned",
    "minecraft:husk", "minecraft:stray", "minecraft:phantom",
    "minecraft:pillager", "minecraft:vindicator", "minecraft:evoker",
    "minecraft:ravager", "minecraft:cave_spider", "minecraft:silverfish",
    "minecraft:blaze", "minecraft:ghast", "minecraft:magma_cube",
    "minecraft:hoglin", "minecraft:zoglin", "minecraft:wither_skeleton",
    "minecraft:guardian", "minecraft:elder_guardian", "minecraft:shulker",
    "minecraft:vex", "minecraft:warden", "minecraft:endermite",
    "minecraft:slime", "minecraft:piglin_brute",
    "alexsmobs:bone_serpent", "alexsmobs:crimson_mosquito",
    "alexsmobs:centipede_head", "alexsmobs:mimicube",
    "alexsmobs:soul_vulture", "alexsmobs:guster", "alexsmobs:warped_mosco",
    "alexsmobs:straddler", "alexsmobs:dropbear", "alexsmobs:void_worm",
    "alexsmobs:rocky_roller", "alexsmobs:skelewag", "alexsmobs:farseer",
    "alexsmobs:skreecher", "alexsmobs:murmur",
    "ars_nouveau:wilden_hunter", "ars_nouveau:wilden_stalker",
    "ars_nouveau:wilden_guardian", "ars_nouveau:wilden_boss",
    "northstar:frozen_zombie", "northstar:mars_worm",
    "northstar:mars_cobra", "northstar:mercury_raptor",
    "northstar:venus_mimic", "northstar:venus_scorpion",
    "quark:forgotten", "quark:wraith",
}

-- ═══════════════════════════════════════════════════════════════
-- ESTADO
-- ═══════════════════════════════════════════════════════════════
local lastFireTime = 0
local lastTarget = nil
local roleDropIndex = 1

-- ═══════════════════════════════════════════════════════════════
-- UTILIDADES
-- ═══════════════════════════════════════════════════════════════
local function apiFailed(value)
    return type(value) == "table" and value[1] == true
end

local function slotInfo(index)
    local ok, name = pcall(android.getSlotInfo, index)
    if not ok then return nil, false end
    local normalized = type(name) == "string" and name:lower() or ""
    local occupied = normalized ~= ""
        and normalized ~= "minecraft:air"
        and normalized ~= "air"
    return name, occupied
end

local function handInfo()
    local ok, name, count = pcall(android.getHandInfo, "main")
    if not ok or type(name) ~= "string" then return nil, 0 end
    local lower = name:lower()
    if lower == "" or lower == "air" or lower == "minecraft:air" then
        return nil, 0
    end
    return name, tonumber(count) or 0
end

local function matchesList(name, list)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    for _, item in ipairs(list) do
        if lower:find(item, 1, true) then return true end
    end
    return false
end

local function isMeleeWeapon(name)
    return matchesList(name, MELEE_WEAPONS)
end

local function isRangedWeapon(name)
    return matchesList(name, RANGED_WEAPONS)
end

local function isAnyWeapon(name)
    return isMeleeWeapon(name) or isRangedWeapon(name)
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
        if index ~= FUEL_SLOT and index ~= excludeA and index ~= excludeB then
            local _, occupied = slotInfo(index)
            if not occupied then return index end
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

local function hasAmmo()
    -- Flechas en stash (para diagnóstico)
    for index = 0, 8 do
        local name, occupied = slotInfo(index)
        if occupied and matchesList(name, AMMO_ITEMS) then
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════

-- MELEE: left click al mob
local function meleeAttack(mob)
    local now = os.clock()
    if now - lastFireTime < FIRE_COOLDOWN then return false end

    local weapon = handInfo()
    if not weapon or not isMeleeWeapon(weapon) then return false end

    local ok, result = pcall(android.attack, mob.uuid)
    if not ok or apiFailed(result) then return false end

    lastFireTime = now
    return true
end

-- ARCO/CROSSBOW: right click al mob (dispara flecha)
local function rangedAttack(mob)
    local now = os.clock()
    if now - lastFireTime < FIRE_COOLDOWN then return false end

    local weapon = handInfo()
    if not weapon or not isRangedWeapon(weapon) then return false end

    local ok, result = pcall(android.useEntity, mob.uuid)
    if not ok or apiFailed(result) then return false end

    lastFireTime = now
    return true
end

-- Decide qué tipo de ataque usar según el arma en mano
local function fireAt(mob)
    local weapon = handInfo()
    if not weapon then return false end

    if isRangedWeapon(weapon) then
        return rangedAttack(mob)
    elseif isMeleeWeapon(weapon) then
        return meleeAttack(mob)
    end
    return false
end

local function engage(mob)
    local self = android.getSelf()
    if not self or not mob then return end

    local dx = mob.posX - self.posX
    local dy = mob.posY - self.posY
    local dz = mob.posZ - self.posZ
    local distSq = dx * dx + dy * dy + dz * dz

    local weapon = handInfo()
    local rangeSq

    if weapon and isRangedWeapon(weapon) then
        rangeSq = COMBAT_RANGE_SQ  -- 14 bloques
    else
        rangeSq = MELEE_RANGE_SQ   -- 4 bloques
    end

    if distSq > rangeSq then
        android.moveTo({ x = mob.posX, y = mob.posY, z = mob.posZ })
    elseif distSq < MIN_RANGE_SQ then
        android.moveTo({
            x = self.posX + (self.posX - mob.posX) * 0.5,
            y = self.posY,
            z = self.posZ + (self.posZ - mob.posZ) * 0.5,
        })
    else
        fireAt(mob)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SUPERVIVENCIA
-- ═══════════════════════════════════════════════════════════════
local function tryHeal()
    local self = android.getSelf()
    if not self or not self.health or self.health >= HEAL_AT then return end

    local heldName = handInfo()
    local tempSlot

    if heldName then
        tempSlot = findEmptySlot()
        if not tempSlot then return end
        local ok, result = pcall(android.storeItem, tempSlot)
        if not ok or apiFailed(result) then return end
    end

    local targetSlot = findSlotWithItem(POTION_ITEMS)
    if not targetSlot then targetSlot = findSlotWithItem(FOOD_ITEMS) end

    if targetSlot then
        pcall(android.equipSlot, targetSlot)
        print("Comida/pocion equipada. HP=" .. tostring(self.health))
    end

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

-- ═══════════════════════════════════════════════════════════════
-- RECOGIDA
-- ═══════════════════════════════════════════════════════════════
local function collectRoleDrop(drop)
    if not drop then return false end

    local heldName = handInfo()
    if heldName then return false end

    local ok, result = pcall(android.pickup, drop.match)
    if not ok or apiFailed(result) then return false end

    local pickedName = handInfo()
    if not pickedName then return false end

    if drop.kind == "weapon" then
        print("Arma recogida: " .. pickedName .. " (equipada)")
        return true
    end

    local destination = findAnyEmptySlot()
    if not destination then
        print("Sin ranura libre para: " .. pickedName)
        return false
    end

    local stored, err = pcall(android.storeItem, destination)
    if not stored or apiFailed(err) then
        print("No se pudo guardar: " .. pickedName)
        return false
    end

    print("Guardado: " .. pickedName .. " → r" .. tostring(destination))
    return true
end

local function collectRoleDrops()
    local drop = ROLE_DROPS[roleDropIndex]
    collectRoleDrop(drop)
    roleDropIndex = roleDropIndex % #ROLE_DROPS + 1
end

-- ═══════════════════════════════════════════════════════════════
-- REPOSTAJE
-- ═══════════════════════════════════════════════════════════════
local function findFuelSlot()
    local name, occupied = slotInfo(FUEL_SLOT)
    if occupied and name and name:lower():find("redstone", 1, true) then
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
    local tempSlot

    if heldName then
        tempSlot = findEmptySlot(fuelSlot)
        if not tempSlot then
            return false, "sin ranura libre para guardar el arma"
        end
        local ok, err = pcall(android.storeItem, tempSlot)
        if not ok or apiFailed(err) then
            return false, "no se guardó el arma"
        end
    end

    local ok, result = pcall(android.equipSlot, fuelSlot)
    if not ok or apiFailed(result) then
        if tempSlot then pcall(android.equipSlot, tempSlot) end
        return false, "no se equipó el combustible"
    end

    local before = android.fuelLevel()
    local called, fuelResult = pcall(android.refuel, 1)
    local after = android.fuelLevel()

    local held = handInfo()
    if held then
        pcall(android.storeItem, fuelSlot)
    end

    if tempSlot then
        pcall(android.equipSlot, tempSlot)
    end

    if not called then return false, tostring(fuelResult) end
    if after > before then return true, "fuel → " .. tostring(after) end
    return false, "no aumentó"
end

-- ═══════════════════════════════════════════════════════════════
-- INFORME
-- ═══════════════════════════════════════════════════════════════
local function reportLoadout()
    local weapon = handInfo()
    print("═══ Fusilero v8 ═══")
    print("Arma: " .. tostring(weapon or "VACÍA"))

    if weapon then
        if isMeleeWeapon(weapon) then
            print("Tipo: MELEE (left click)")
        elseif isRangedWeapon(weapon) then
            print("Tipo: ARCO (right click, necesita flechas)")
        else
            print("Tipo: NO RECONOCIDO")
        end
    end

    print("--- Stash 0-8 ---")
    for index = 0, 8 do
        local name, occupied = slotInfo(index)
        if occupied then
            local label = "r" .. index .. ": " .. tostring(name)
            if matchesList(name, AMMO_ITEMS) then label = label .. " [AMMO]"
            elseif isMeleeWeapon(name) then label = label .. " [MELEE]"
            elseif isRangedWeapon(name) then label = label .. " [RANGED]"
            elseif name:lower():find("redstone", 1, true) then label = label .. " [FUEL]"
            end
            print(label)
        else
            print("r" .. index .. ": [vacia]")
        end
    end

    print("Flechas en stash: " .. (hasAmmo() and "SÍ" or "NO (ponlas en hotbar)"))
    print("Objetivos: " .. #TARGET_TYPES)
    print("═══════════════════")
end

-- ═══════════════════════════════════════════════════════════════
-- CONTROL REMOTO
-- ═══════════════════════════════════════════════════════════════
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
        if not file then return nil end
        local owners, names = parseOwners(file.readAll())
        file.close()
        if #names == 0 then return nil end
        print("Propietarios: " .. #names)
        return owners
    end
    print("Jugadores autorizados (separados por comas):")
    local owners, names = parseOwners(read())
    while #names == 0 do
        print("Escribe al menos un nombre:")
        owners, names = parseOwners(read())
    end
    local file = fs.open(OWNERS_FILE, "w")
    if not file then return nil end
    file.write(table.concat(names, "\n") .. "\n")
    file.close()
    print("Guardado.")
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
                tostring(data.message or ""):match("^!jarvis%s+(.+)%s+(%S+)$")
            if target and command
                and (target:lower() == "all" or target:lower() == unitName:lower()) then
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
                    local w = handInfo()
                    local wType = "—"
                    if w then
                        if isMeleeWeapon(w) then wType = "melee"
                        elseif isRangedWeapon(w) then wType = "arco" end
                    end
                    pcall(android.sendChatMessage,
                        unitName .. " | v8 | " .. state.mode
                        .. " | HP=" .. tostring(cur.health)
                        .. " | fuel=" .. tostring(android.fuelLevel())
                        .. " | arma=" .. tostring(w or "—") .. " (" .. wType .. ")")
                elseif command == "dump" then
                    local lines = { "MANO: " .. tostring(handInfo() or "vacia") }
                    for i = 0, 8 do
                        local n, o = slotInfo(i)
                        lines[#lines + 1] = "r" .. i .. ": " .. (o and tostring(n) or "[vacia]")
                    end
                    pcall(android.sendChatMessage, "INV: " .. table.concat(lines, " | "))
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- BÚSQUEDA DE HOSTILES
-- ═══════════════════════════════════════════════════════════════
local function findHostile()
    local self = android.getSelf()
    local closest, closestType, closestDistance

    for _, mobType in ipairs(TARGET_TYPES) do
        local ok, mob = pcall(android.getClosestMob, mobType)
        if ok and type(mob) == "table"
            and mob.uuid and mob.posX and mob.posY and mob.posZ then
            local dx = mob.posX - self.posX
            local dy = mob.posY - self.posY
            local dz = mob.posZ - self.posZ
            local distSq = dx*dx + dy*dy + dz*dz
            if not closestDistance or distSq < closestDistance then
                closest, closestType, closestDistance = mob, mobType, distSq
            end
        end
    end
    return closest, closestType
end

-- ═══════════════════════════════════════════════════════════════
-- BUCLE PRINCIPAL
-- ═══════════════════════════════════════════════════════════════
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

        -- Retirada crítica
        if self.health and self.health <= RETREAT_HEALTH and task ~= "idle" then
            android.cancelTask()
            task = "idle"
            if os.clock() - lastAlert >= ALERT_DELAY then
                pcall(android.sendChatMessage,
                    "ALERTA: HP=" .. tostring(self.health) .. ". Replegando.")
                lastAlert = os.clock()
            end
        end

        if task == "idle" then
            -- Curarse
            if os.clock() - lastHealAttempt >= HEAL_RETRY_DELAY then
                tryHeal()
                lastHealAttempt = os.clock()
            end

            -- Recogida
            if os.clock() - lastRoleDropScan >= PICKUP_SCAN_DELAY then
                collectRoleDrops()
                lastRoleDropScan = os.clock()
            end

            -- Repostaje
            local fuel = android.fuelLevel()
            if fuel < REFUEL_AT
                and os.clock() - lastRefuelAttempt >= REFUEL_RETRY_DELAY then
                local success, reason = refuelWithoutDroppingWeapon()
                lastRefuelAttempt = os.clock()
                fuel = android.fuelLevel()
                if success then
                    print("Repostaje → " .. tostring(fuel))
                else
                    print("Repostaje: " .. tostring(reason))
                end
            end

            -- Lógica principal
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
                                "ALERTA: " .. mobType .. " → combatiendo.")
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

-- ═══════════════════════════════════════════════════════════════
-- MAIN
-- ═══════════════════════════════════════════════════════════════
local function main()
    local self = android.getSelf()
    local home = { x = self.posX, y = self.posY, z = self.posZ }
    local state = { mode = "patrol" }
    local owners = loadOwners()
    if not owners then
        print("No se pudieron cargar los propietarios.")
        return
    end

    parallel.waitForAny(
        function() patrol(home, state, self) end,
        waitForStop,
        function() listenForCommands(self, state, owners) end
    )
    android.cancelTask()
    print("Fusilero v8 detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error: " .. tostring(err))
end   
