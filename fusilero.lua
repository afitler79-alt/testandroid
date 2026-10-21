-- ═══════════════════════════════════════════════════════════════
-- ROL FUSILERO v9.1 (CC:Androids 1.3.0 / Forge 1.20.1)
-- NTGL 3.1.2: left click=disparo, right click=recarga
-- Stash: 11 ranuras (0-10). Redstone se busca en cualquier ranura.
-- Munición: en la HOTBAR del android (no en la stash).
-- Enter detiene y cancela la tarea activa.
-- ═══════════════════════════════════════════════════════════════

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 6
local REFUEL_AT = 20
local REFUEL_RETRY_DELAY = 5
local STASH_SIZE = 11          -- Ranuras: 0-10
local PICKUP_SCAN_DELAY = 0.8
local HEAL_AT = 12
local HEAL_RETRY_DELAY = 8
local RETREAT_HEALTH = 6
local ALERT_DELAY = 10
local OWNERS_FILE = "owners.cfg"

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local COMBAT_RANGE_SQ = 14 * 14
local MIN_RANGE_SQ = 4 * 4
local FIRE_COOLDOWN = 0.5
local RELOAD_COOLDOWN = 3

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
    ["cbc:ballistic_pistol"] = 8,
    ["cbc:ballistic_carbine"] = 16,
    ["cbc:ballistic_shotgun"] = 2,
    ["cbc:ballistic_sniper"] = 1,
    ["cbc:ballistic_gatling"] = 64,
    ["cbc:ballistic_grenade_launcher"] = 4,
    ["cbc:ballistic_minigun"] = 100,
    ["cbc:ballistic_cannon"] = 1,
}

-- ═══════════════════════════════════════════════════════════════
-- ARMAS
-- ═══════════════════════════════════════════════════════════════
local CGS_WEAPONS = {
    "cgs:flintlock", "cgs:revolver", "cgs:shotgun",
    "cgs:nailgun", "cgs:gatling", "cgs:blazegun",
    "cgs:launcher", "cgs:pneumatic_hammer", "cgs:frag_grenade",
}

local CBC_WEAPONS = {
    "cbc:ballistic_pistol", "cbc:ballistic_carbine",
    "cbc:ballistic_shotgun", "cbc:ballistic_sniper",
    "cbc:ballistic_gatling", "cbc:ballistic_grenade_launcher",
    "cbc:ballistic_minigun", "cbc:ballistic_cannon",
}

local ALL_WEAPONS = {}
for _, w in ipairs(CGS_WEAPONS) do ALL_WEAPONS[#ALL_WEAPONS+1] = w end
for _, w in ipairs(CBC_WEAPONS) do ALL_WEAPONS[#ALL_WEAPONS+1] = w end

-- ═══════════════════════════════════════════════════════════════
-- MUNICIÓN
-- ═══════════════════════════════════════════════════════════════
local CGS_AMMO = {
    "cgs:paper_cartridge", "cgs:paper_shot",
    "cgs:round_revolver", "cgs:round_revolver_piercing", "cgs:round_revolver_blank",
    "cgs:round_shotgun", "cgs:round_shotgun_flechette", "cgs:round_shotgun_flechette_steel",
    "cgs:round_shotgun_incendiary", "cgs:round_shotgun_blank",
    "cgs:round_gatling", "cgs:round_gatling_piercing", "cgs:round_gatling_blank",
    "cgs:nail", "cgs:nail_steel",
    "cgs:rocket", "cgs:rocket_small",
    "cgs:spear", "cgs:lead_balls",
    "cgs:shell_gatling", "cgs:shell_revolver", "cgs:shell_shotgun",
}

local CBC_AMMO = {
    "cbc:ballistic_pistol_round", "cbc:ballistic_carbine_round",
    "cbc:ballistic_shotgun_shell", "cbc:ballistic_sniper_round",
    "cbc:ballistic_gatling_round", "cbc:ballistic_grenade",
    "cbc:ballistic_minigun_round", "cbc:cannon_shot",
    "cbc:explosive_cannon_shot", "cbc:incendiary_cannon_shot",
}

local ALL_AMMO = {}
for _, a in ipairs(CGS_AMMO) do ALL_AMMO[#ALL_AMMO+1] = a end
for _, a in ipairs(CBC_AMMO) do ALL_AMMO[#ALL_AMMO+1] = a end

-- ═══════════════════════════════════════════════════════════════
-- OTROS ITEMS
-- ═══════════════════════════════════════════════════════════════
local FOOD_ITEMS = {
    "minecraft:cooked_beef", "minecraft:cooked_porkchop",
    "minecraft:cooked_chicken", "minecraft:cooked_mutton",
    "minecraft:golden_carrot", "minecraft:golden_apple",
    "minecraft:bread", "minecraft:cooked_cod", "minecraft:cooked_salmon",
    "farmersdelight:beef_ribs", "farmersdelight:meat_on_a_stick",
    "farmersdelight:harvest_stew", "farmersdelight:chocolate_bar",
}

local POTION_ITEMS = {
    "minecraft:potion", "minecraft:splash_potion",
}

-- ═══════════════════════════════════════════════════════════════
-- RECOGIDA
-- ═══════════════════════════════════════════════════════════════
local ROLE_DROPS = {}
for _, w in ipairs(ALL_WEAPONS) do ROLE_DROPS[#ROLE_DROPS+1] = { match=w, kind="weapon" } end
for _, a in ipairs(ALL_AMMO) do ROLE_DROPS[#ROLE_DROPS+1] = { match=a, kind="ammo" } end
for _, f in ipairs(FOOD_ITEMS) do ROLE_DROPS[#ROLE_DROPS+1] = { match=f, kind="food" } end
for _, p in ipairs(POTION_ITEMS) do ROLE_DROPS[#ROLE_DROPS+1] = { match=p, kind="potion" } end

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
    "vampirism:vampire", "vampirism:ghoul",
    "werewolves:werewolf",
}

-- ═══════════════════════════════════════════════════════════════
-- ESTADO
-- ═══════════════════════════════════════════════════════════════
local lastFireTime = 0
local lastReloadTime = 0
local shotsFired = 0
local currentMagCap = 8
local lastTarget = nil
local roleDropIndex = 1
local reloadFailCount = 0

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

local function isWeapon(name)
    return matchesList(name, ALL_WEAPONS)
end

-- BUSCA RANURA VACÍA (0 a 10)
local function findEmptySlot(exclude)
    for index = 0, STASH_SIZE - 1 do
        if index ~= exclude then
            local _, occupied = slotInfo(index)
            if not occupied then return index end
        end
    end
    return nil
end

local function findAnyEmptySlot(excludeA, excludeB)
    for index = 0, STASH_SIZE - 1 do
        if index ~= excludeA and index ~= excludeB then
            local _, occupied = slotInfo(index)
            if not occupied then return index end
        end
    end
    return nil
end

local function findSlotWithItem(list)
    for index = 0, STASH_SIZE - 1 do
        local name, occupied = slotInfo(index)
        if occupied and matchesList(name, list) then
            return index
        end
    end
    return nil
end

-- BUSCA REDSTONE EN CUALQUIER RANURA (0-10)
local function findRedstoneSlot()
    for index = 0, STASH_SIZE - 1 do
        local name, occupied = slotInfo(index)
        if occupied and name and name:lower():find("redstone", 1, true) then
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
    currentMagCap = 8
    return currentMagCap
end

-- ═══════════════════════════════════════════════════════════════
-- COMBATE (NTGL)
-- ═══════════════════════════════════════════════════════════════
local function fireAt(mob)
    local now = os.clock()
    if now - lastFireTime < FIRE_COOLDOWN then return false end

    local weapon = handInfo()
    if not weapon or not isWeapon(weapon) then return false end

    local ok, result = pcall(android.attack, mob.uuid)
    if not ok or apiFailed(result) then return false end

    lastFireTime = now
    shotsFired = shotsFired + 1
    return true
end

local function tryReload(mob)
    local now = os.clock()
    if now - lastReloadTime < RELOAD_COOLDOWN then return false end

    local cap = getMagCapacity()
    if shotsFired < cap then return false end

    local success = false

    if mob and mob.uuid then
        local ok, result = pcall(android.useEntity, mob.uuid)
        if ok and not apiFailed(result) then success = true end
    end

    if not success then
        local self = android.getSelf()
        local bx = math.floor(self.posX)
        local by = math.floor(self.posY) - 1
        local bz = math.floor(self.posZ)
        local ok, result = pcall(android.useBlock, bx, by, bz)
        if ok and not apiFailed(result) then success = true end
    end

    if not success then
        local self = android.getSelf()
        local bx = math.floor(self.posX) + 1
        local by = math.floor(self.posY)
        local bz = math.floor(self.posZ)
        local ok, result = pcall(android.useBlock, bx, by, bz)
        if ok and not apiFailed(result) then success = true end
    end

    lastReloadTime = now

    if success then
        shotsFired = 0
        reloadFailCount = 0
        print("Recarga OK (mag=" .. tostring(cap) .. ")")
    else
        reloadFailCount = reloadFailCount + 1
        if reloadFailCount == 3 then
            print("AVISO: 3 recargas fallidas. ¿Munición en la HOTBAR?")
        end
        shotsFired = 0
    end
    return success
end

local function engage(mob)
    local self = android.getSelf()
    if not self or not mob then return end

    local dx = mob.posX - self.posX
    local dy = mob.posY - self.posY
    local dz = mob.posZ - self.posZ
    local distSq = dx*dx + dy*dy + dz*dz

    tryReload(mob)

    if distSq > COMBAT_RANGE_SQ then
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
        print("Comida/poción equipada. HP=" .. tostring(self.health))
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
        print("Arma recogida: " .. pickedName)
        return true
    end

    local destination = findAnyEmptySlot()
    if not destination then return false end

    local stored, err = pcall(android.storeItem, destination)
    if not stored or apiFailed(err) then return false end

    print("Guardado: " .. pickedName .. " → r" .. tostring(destination))
    return true
end

local function collectRoleDrops()
    local drop = ROLE_DROPS[roleDropIndex]
    collectRoleDrop(drop)
    roleDropIndex = roleDropIndex % #ROLE_DROPS + 1
end

-- ═══════════════════════════════════════════════════════════════
-- REPOSTAJE (busca redstone en cualquier ranura 0-10)
-- ═══════════════════════════════════════════════════════════════
local function refuelWithoutDroppingWeapon()
    local fuelSlot = findRedstoneSlot()
    if not fuelSlot then
        return false, "sin redstone en ninguna ranura"
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
    if held then pcall(android.storeItem, fuelSlot) end
    if tempSlot then pcall(android.equipSlot, tempSlot) end

    if not called then return false, tostring(fuelResult) end
    if after > before then return true, "fuel → " .. tostring(after) end
    return false, "no aumentó"
end

-- ═══════════════════════════════════════════════════════════════
-- INFORME
-- ═══════════════════════════════════════════════════════════════
local function reportLoadout()
    local weapon = handInfo()
    print("═══ Fusilero v9.1 ═══")
    print("Arma: " .. tostring(weapon or "VACÍA"))
    if weapon and isWeapon(weapon) then
        print("→ NTGL: left=disparo, right=recarga")
    elseif weapon then
        print("⚠ No es arma CGS/CBC")
    end

    print("--- Stash (0-" .. tostring(STASH_SIZE-1) .. ") ---")
    for index = 0, STASH_SIZE - 1 do
        local name, occupied = slotInfo(index)
        if occupied then
            local label = "r" .. index .. ": " .. tostring(name)
            if name:lower():find("redstone", 1, true) then label = label .. " [FUEL]"
            elseif matchesList(name, ALL_AMMO) then label = label .. " [AMMO]"
            elseif isWeapon(name) then label = label .. " [GUN]"
            end
            print(label)
        else
            print("r" .. index .. ": [vacia]")
        end
    end
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
                    pcall(android.sendChatMessage,
                        unitName .. " | v9.1 | " .. state.mode
                        .. " | HP=" .. tostring(cur.health)
                        .. " | fuel=" .. tostring(android.fuelLevel())
                        .. " | arma=" .. tostring(w or "—")
                        .. " | shots=" .. tostring(shotsFired) .. "/" .. tostring(currentMagCap))
                elseif command == "dump" then
                    local lines = { "MANO: " .. tostring(handInfo() or "vacia") }
                    for i = 0, STASH_SIZE - 1 do
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
                    print("Repostaje → " .. tostring(fuel))
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
                        if os.clock() - lastAlert >= ALERT_DELAY then
                            pcall(android.sendChatMessage,
                                "ALERTA: " .. mobType .. " → fuego.")
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
    print("Fusilero v9.1 detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error: " .. tostring(err))
end   
