-- ═══════════════════════════════════════════════════════════════
-- Rol Fusilero v5 (CC:Androids 1.3.0 / Forge 1.20.1)
-- Disparo: android.attack (left click)
-- Recarga: android.useBlock (right click = simula tecla R)
-- IMPORTANTE: La munición debe estar en la HOTBAR del android
-- (no en la stash 0-8, CGS no la ve ahí).
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
local COMBAT_RANGE_SQ = 14 * 14
local MIN_RANGE_SQ = 4 * 4
local RELOAD_COOLDOWN = 3
local FIRE_COOLDOWN = 0.5

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

-- ═══════════════════════════════════════════════════════════════
-- ITEMS: Create: Gunsmithing
-- ═══════════════════════════════════════════════════════════════
local CGS_WEAPONS = {
    "cgs:flintlock", "cgs:revolver", "cgs:shotgun",
    "cgs:nailgun", "cgs:gatling", "cgs:blazegun",
    "cgs:launcher", "cgs:pneumatic_hammer", "cgs:frag_grenade",
}

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

local CREATE_ITEMS = { "create:brass_backtank" }

local FOOD_ITEMS = {
    "minecraft:cooked_beef", "minecraft:cooked_porkchop",
    "minecraft:cooked_chicken", "minecraft:cooked_mutton",
    "minecraft:golden_carrot", "minecraft:golden_apple",
    "minecraft:bread", "minecraft:cooked_cod", "minecraft:cooked_salmon",
}

local POTION_ITEMS = { "minecraft:potion", "minecraft:splash_potion" }

local ROLE_DROPS = {}
for _, w in ipairs(CGS_WEAPONS) do ROLE_DROPS[#ROLE_DROPS+1] = { match=w, kind="weapon" } end
for _, a in ipairs(CGS_AMMO) do ROLE_DROPS[#ROLE_DROPS+1] = { match=a, kind="ammo" } end
for _, b in ipairs(CREATE_ITEMS) do ROLE_DROPS[#ROLE_DROPS+1] = { match=b, kind="backtank" } end
for _, f in ipairs(FOOD_ITEMS) do ROLE_DROPS[#ROLE_DROPS+1] = { match=f, kind="food" } end
for _, p in ipairs(POTION_ITEMS) do ROLE_DROPS[#ROLE_DROPS+1] = { match=p, kind="potion" } end

local ROLE_WEAPONS = {}
for _, w in ipairs(CGS_WEAPONS) do ROLE_WEAPONS[w] = true end

-- ═══════════════════════════════════════════════════════════════
-- TARGETS
-- ═══════════════════════════════════════════════════════════════
local TARGET_TYPES = {
    "zombie", "skeleton", "spider", "creeper", "witch", "drowned",
    "husk", "stray", "phantom", "pillager", "vindicator", "evoker",
    "ravager", "cave_spider", "silverfish", "blaze", "ghast",
    "magma_cube", "hoglin", "zoglin", "wither_skeleton", "guardian",
    "elder_guardian", "shulker", "vex", "warden", "endermite", "slime",
    "piglin_brute",
    "alexsmobs:bone_serpent", "alexsmobs:crimson_mosquito",
    "alexsmobs:centipede_head", "alexsmobs:mimicube", "alexsmobs:soul_vulture",
    "alexsmobs:guster", "alexsmobs:warped_mosco", "alexsmobs:straddler",
    "alexsmobs:dropbear", "alexsmobs:void_worm", "alexsmobs:rocky_roller",
    "alexsmobs:skelewag", "alexsmobs:farseer", "alexsmobs:skreecher",
    "alexsmobs:murmur",
    "ars_nouveau:wilden_hunter", "ars_nouveau:wilden_stalker",
    "ars_nouveau:wilden_guardian", "ars_nouveau:wilden_boss",
    "northstar:frozen_zombie", "northstar:mars_worm", "northstar:mars_cobra",
    "northstar:mercury_raptor", "northstar:venus_mimic", "northstar:venus_scorpion",
    "quark:forgotten", "quark:wraith",
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
local function slotInfo(index)
    local ok, name = pcall(android.getSlotInfo, index)
    if not ok then return nil, false end
    local normalized
    if type(name) == "string" then
        normalized = name:lower()
    else
        normalized = ""
    end
    local occupied = normalized ~= "" and normalized ~= "minecraft:air" and normalized ~= "air" and normalized ~= "false"
    return name, occupied
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
        if index ~= FUEL_SLOT and index ~= excludeA and index ~= excludeB then
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
        currentMagCap = 8
    end
    return currentMagCap
end

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════

-- LEFT CLICK = disparar
local function fireAt(mob)
    local now = os.clock()
    if now - lastFireTime < FIRE_COOLDOWN then return false end

    local name = handInfo()
    if not name or not isRoleWeapon(name) then
        return false
    end

    local ok, result = pcall(android.attack, mob.uuid)
    if not ok then return false end
    if apiFailed(result) then return false end

    lastFireTime = now
    shotsFired = shotsFired + 1
    return true
end

-- RIGHT CLICK = recargar (simula tecla R)
-- CGS busca munición en la HOTBAR del android (no en la stash).
local function tryReload(mob)
    local now = os.clock()
    if now - lastReloadTime < RELOAD_COOLDOWN then return false end

    local cap = getMagCapacity()
    if shotsFired < cap then return false end

    local self = android.getSelf()
    local success = false

    -- Right click al suelo (simula R)
    local bx = math.floor(self.posX)
    local by = math.floor(self.posY) - 1
    local bz = math.floor(self.posZ)
    local ok, result = pcall(android.useBlock, bx, by, bz)
    if ok and not apiFailed(result) then
        success = true
    end

    -- Si falla, probar bloque adyacente
    if not success then
        ok, result = pcall(android.useBlock, bx + 1, by, bz)
        if ok and not apiFailed(result) then success = true end
    end
    if not success then
        ok, result = pcall(android.useBlock, bx, by, bz + 1)
        if ok and not apiFailed(result) then success = true end
    end

    lastReloadTime = now

    if success then
        shotsFired = 0
        reloadFailCount = 0
        print("Recarga OK (mag=" .. tostring(cap) .. ").")
    else
        reloadFailCount = reloadFailCount + 1
        if reloadFailCount == 3 then
            print("AVISO: 3 recargas fallidas. ¿Hay munición en la HOTBAR del android?")
        end
        -- Resetear para no bloquear el disparo
        shotsFired = 0
    end
    return success
end

local function engage(mob)
    local self = android.getSelf()
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
    if not self.health or self.health >= HEAL_AT then return end

    local heldName = handInfo()
    local tempSlot
    if heldName then
        tempSlot = findEmptySlot()
        if not tempSlot then return end
        pcall(android.storeItem, tempSlot)
    end

    local targetSlot = findSlotWithItem(POTION_ITEMS)
    if not targetSlot then targetSlot = findSlotWithItem(FOOD_ITEMS) end

    if targetSlot then
        pcall(android.equipSlot, targetSlot)
        print("Equipada comida/poción (HP=" .. tostring(self.health) .. ")")
    end

    if tempSlot then
        pcall(android.equipSlot, tempSlot)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- RECOGIDA (solo armas y objetos de la stash)
-- ═══════════════════════════════════════════════════════════════
local function collectRoleDrop(drop)
    local heldName = handInfo()
    if heldName and not isRoleWeapon(heldName) then return false end

    local destination = findAnyEmptySlot(FUEL_SLOT)
    if destination == nil then return false end

    local temporarySlot
    if heldName then
        temporarySlot = findEmptySlot(FUEL_SLOT)
        if not temporarySlot or temporarySlot == destination then
            temporarySlot = findAnyEmptySlot(destination, FUEL_SLOT)
        end
        if not temporarySlot then return false end
        local stored, storeErr = pcall(android.storeItem, temporarySlot)
        if not stored or apiFailed(storeErr) then return false end
    end

    local called, result = pcall(android.pickup, drop.match)
    local pickedName = handInfo()

    if called and not apiFailed(result) and pickedName then
        if drop.kind == "weapon" and not temporarySlot then
            print("Recogido " .. pickedName .. " → equipado.")
            return true
        end
        local stored, storeErr = pcall(android.storeItem, destination)
        if not stored or apiFailed(storeErr) then
            if temporarySlot then pcall(android.equipSlot, temporarySlot) end
            return false
        end
        print("Recogido " .. pickedName .. " → r" .. tostring(destination))
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

-- ═══════════════════════════════════════════════════════════════
-- REPOSTAJE
-- ═══════════════════════════════════════════════════════════════
local function findFuelSlot()
    local name, occupied = slotInfo(FUEL_SLOT)
    if occupied and name and name:lower():find("redstone", 1, true) then return FUEL_SLOT end
    return nil
end

local function refuelWithoutDroppingWeapon()
    local fuelSlot = findFuelSlot()
    if not fuelSlot then return false, "sin redstone en r" .. FUEL_SLOT end

    local heldName = handInfo()
    local temporarySlot
    if heldName then
        if not isRoleWeapon(heldName) then
            return false, "mano no tiene arma CGS"
        end
        temporarySlot = findEmptySlot(fuelSlot)
        if not temporarySlot then return false, "sin ranura libre" end
        local ok, err = pcall(android.storeItem, temporarySlot)
        if not ok or apiFailed(err) then return false, "no se guardó el arma" end
    end

    local equipped, equipErr = pcall(android.equipSlot, fuelSlot)
    if not equipped or apiFailed(equipErr) then
        if temporarySlot then pcall(android.equipSlot, temporarySlot) end
        return false, "no se equipó el combustible"
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
    return after > before, "fuel → " .. tostring(after)
end

-- ═══════════════════════════════════════════════════════════════
-- INFORME
-- ═══════════════════════════════════════════════════════════════
local function reportLoadout()
    local weapon = handInfo()
    print("═══ Fusilero v5 ═══")
    print("Arma en mano: " .. tostring(weapon or "VACÍA"))
    if weapon and not isRoleWeapon(weapon) then
        print("⚠ La mano no tiene un arma CGS!")
    end
    print("--- Stash (0-8) ---")
    for index = 0, 8 do
        local name, occupied = slotInfo(index)
        local label = "r" .. index .. ": "
        if occupied then
            label = label .. tostring(name)
            if name:lower():find("redstone", 1, true) then label = label .. " [FUEL]"
            elseif matchesList(name, CGS_AMMO) then label = label .. " [AMMO-stash]"
            elseif matchesList(name, CGS_WEAPONS) then label = label .. " [WEAPON]"
            end
        else
            label = label .. "[vacía]"
        end
        print(label)
    end
    print("")
    print("⚠ LA MUNICIÓN DEBE ESTAR EN LA HOTBAR DEL ANDROID")
    print("  (abre su inventario y pon cartuchos en la hotbar)")
    print("  CGS no ve la stash como inventario de munición.")
    print("")
    print("Objetivos: " .. #TARGET_TYPES)
    print("═══════════════════")
end

-- ═══════════════════════════════════════════════════════════════
-- CONTROL REMOTO
-- ═══════════════════════════════════════════════════════════════
local function parseOwners(input)
    local owners, names = {}, {}
    for part in tostring(input):gmatch("[^,]+") do
        local name = part:match("^%s*(.-)%s*$")
        if name ~= "" and not owners[name:lower()] then
            owners[name:lower()] = true
            names[#names+1] = name
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
    print("Primera vez: nombres de jugadores (separados por comas):")
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
        if type(data) == "table" and owners[tostring(data.senderName or ""):lower()] then
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
                    local cur = android.getSelf()
                    pcall(android.sendChatMessage, unitName .. " | v5 | " .. state.mode
                        .. " | HP=" .. tostring(cur.health)
                        .. " | fuel=" .. tostring(android.fuelLevel())
                        .. " | arma=" .. tostring(handInfo() or "—")
                        .. " | shots=" .. tostring(shotsFired) .. "/" .. tostring(currentMagCap))
                elseif command == "dump" then
                    local lines = {}
                    local w = handInfo()
                    lines[#lines+1] = "MANO: " .. tostring(w or "vacía")
                    for i = 0, 8 do
                        local n, o = slotInfo(i)
                        lines[#lines+1] = "r" .. i .. ": " .. (o and tostring(n) or "[vacía]")
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
        local mob = android.getClosestMob(mobType)
        if mob and next(mob) and mob.uuid and mob.posX then
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
    print("Comandos: !jarvis " .. tostring(unit.name or "Android") .. " hold|resume|return|status|dump")
    print("ENTER para detener.")

    while true do
        local self = android.getSelf()
        local task = android.currentTask()

        -- Retirada crítica
        if self.health and self.health <= RETREAT_HEALTH and task ~= "idle" then
            android.cancelTask()
            task = "idle"
            if os.clock() - lastAlert >= ALERT_DELAY then
                pcall(android.sendChatMessage, "ALERTA: HP=" .. tostring(self.health) .. ". Replegando.")
                lastAlert = os.clock()
            end
        end

        if task == "idle" then
            -- Curarse
            if os.clock() - lastHealAttempt >= HEAL_RETRY_DELAY then
                local hpBefore = self.health
                tryHeal()
                if android.getSelf().health ~= hpBefore then
                    lastHealAttempt = os.clock()
                end
            end

            -- Recogida rotativa
            if os.clock() - lastRoleDropScan >= PICKUP_SCAN_DELAY then
                collectRoleDrops()
                lastRoleDropScan = os.clock()
            end

            -- Repostaje
            local fuel = android.fuelLevel()
            if fuel < REFUEL_AT and os.clock() - lastRefuelAttempt >= REFUEL_RETRY_DELAY then
                local beforeFuel = fuel
                local success, reason = refuelWithoutDroppingWeapon()
                lastRefuelAttempt = os.clock()
                fuel = android.fuelLevel()
                if success and fuel > beforeFuel then
                    print("Repostaje → " .. tostring(fuel))
                else
                    print("Repostaje: " .. tostring(reason))
                end
            end

            -- Lógica principal
            if fuel < 1 then
                sleep(SCAN_DELAY)
            elseif state.mode == "return" or (self.health and self.health <= RETREAT_HEALTH) then
                lastTarget = nil
                android.moveTo(home)
            elseif state.mode == "patrol" then
                local mob, mobType = findHostile()
                if mob and next(mob) then
                    if lastTarget ~= mob.uuid then
                        lastTarget = mob.uuid
                        shotsFired = 0
                        reloadFailCount = 0
                        if os.clock() - lastAlert >= ALERT_DELAY then
                            pcall(android.sendChatMessage, "ALERTA: " .. mobType .. " → fuego.")
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
    if not owners then return end

    parallel.waitForAny(
        function() patrol(home, state, self) end,
        waitForStop,
        function() listenForCommands(self, state, owners) end
    )
    android.cancelTask()
    print("Fusilero v5 detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error: " .. tostring(err))
end   
