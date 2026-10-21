-- ═══════════════════════════════════════════════════════════════
-- ROL FUSILERO v13.1 (CC:Androids 1.3.0 / Forge 1.20.1)
-- NTGL 3.1.2: Left=disparo+recarga | Right=apuntar
-- NO ataca sin arma CGS/CBC en mano.
-- Si tiene munición en mano, la guarda y busca el arma.
-- Stash: 11 ranuras (0-10). Escaneo dinámico.
-- Munición: en la HOTBAR del android.
-- Enter detiene y cancela la tarea activa.
-- ═══════════════════════════════════════════════════════════════

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 5
local REFUEL_AT = 20
local REFUEL_RETRY_DELAY = 15
local REFUEL_SAFE_RADIUS_SQ = 20*20
local STASH_SIZE = 11
local PICKUP_SCAN_DELAY = 0.8
local HEAL_AT = 12
local HEAL_RETRY_DELAY = 8
local RETREAT_HEALTH = 6
local ALERT_DELAY = 10
local ATTACK_TIMEOUT = 15
local OWNERS_FILE = "owners.cfg"

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local COMBAT_RANGE_SQ = 14 * 14
local MIN_RANGE_SQ = 4 * 4
local FIRE_COOLDOWN = 0.5
local AIM_BEFORE_SHOT = true
local AIM_DELAY = 0.3

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

local WEAPON_DISPLAY_NAMES = {
    "flintlock", "revolver", "shotgun", "nailgun", "gatling",
    "blazegun", "launcher", "pneumatic hammer", "frag grenade",
    "ballistic pistol", "ballistic carbine", "ballistic shotgun",
    "ballistic sniper", "ballistic gatling", "ballistic minigun",
    "ballistic grenade launcher", "ballistic cannon",
}

-- ═══════════════════════════════════════════════════════════════
-- MUNICIÓN
-- ═══════════════════════════════════════════════════════════════
local CGS_AMMO = {
    "cgs:paper_cartridge", "cgs:paper_shot",
    "cgs:flintlock_bullet", "cgs:revolver_round",
    "cgs:shotgun_round", "cgs:nail", "cgs:gatling_round",
    "cgs:piercing_revolver_round", "cgs:incendiary_shotgun_round",
    "cgs:round_revolver", "cgs:round_revolver_piercing", "cgs:round_revolver_blank",
    "cgs:round_shotgun", "cgs:round_shotgun_flechette",
    "cgs:round_shotgun_flechette_steel", "cgs:round_shotgun_incendiary",
    "cgs:round_shotgun_blank",
    "cgs:round_gatling", "cgs:round_gatling_piercing", "cgs:round_gatling_blank",
    "cgs:nail_steel", "cgs:rocket", "cgs:rocket_small",
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

local AMMO_DISPLAY_NAMES = {
    "flintlock bullet", "revolver round", "shotgun round",
    "gatling round", "piercing revolver round",
    "incendiary shotgun round", "steel nail",
}

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

local FOOD_DISPLAY_NAMES = {
    "cooked beef", "cooked porkchop", "cooked chicken", "cooked mutton",
    "golden carrot", "golden apple", "bread", "cooked cod", "cooked salmon",
    "beef ribs", "meat on a stick", "harvest stew", "chocolate bar",
}

local POTION_ITEMS = { "minecraft:potion", "minecraft:splash_potion" }
local POTION_DISPLAY_NAMES = { "potion", "splash potion" }

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
local shotsFired = 0
local currentMagCap = 8
local lastTarget = nil
local roleDropIndex = 1
local cachedFuelSlot = nil
local cachedWeaponSlot = nil
local lastFuelScan = 0
local lastWeaponScan = 0
local SCAN_CACHE_TIME = 10
local inCombat = false
local lastCombatEnd = 0
local attackStartTime = 0

-- ═══════════════════════════════════════════════════════════════
-- UTILIDADES
-- ═══════════════════════════════════════════════════════════════
local function apiFailed(value)
    return type(value) == "table" and value[1] == true
end

local function slotOccupied(index)
    local ok, result = pcall(android.getSlotInfo, index)
    if not ok then return false end
    if type(result) == "boolean" then return result end
    if type(result) == "string" then
        return result ~= "" and result ~= "Empty"
            and result ~= "minecraft:air" and result ~= "air"
            and result ~= "a"
    end
    return false
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

-- ═══════════════════════════════════════════════════════════════
-- DETECCIÓN DE ITEMS
-- ═══════════════════════════════════════════════════════════════
local function isAmmo(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    for _, item in ipairs(ALL_AMMO) do
        if lower:find(item, 1, true) then return true end
    end
    for _, item in ipairs(AMMO_DISPLAY_NAMES) do
        if lower == item then return true end
    end
    if lower:find("round", 1, true) then return true end
    if lower:find("cartridge", 1, true) then return true end
    if lower:find("bullet", 1, true) then return true end
    if lower:find("shell", 1, true) then return true end
    if lower:find("nail", 1, true) and not lower:find("nailgun", 1, true) then return true end
    return false
end

local function isWeapon(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    if isAmmo(name) then return false end
    for _, item in ipairs(ALL_WEAPONS) do
        if lower:find(item, 1, true) then return true end
    end
    for _, item in ipairs(WEAPON_DISPLAY_NAMES) do
        if lower == item then return true end
    end
    return false
end

local function isRedstone(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    if lower:find("redstone_torch", 1, true) then return false end
    return lower:find("redstone", 1, true) ~= nil
end

local function isFood(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    for _, item in ipairs(FOOD_ITEMS) do
        if lower:find(item, 1, true) then return true end
    end
    for _, item in ipairs(FOOD_DISPLAY_NAMES) do
        if lower == item then return true end
    end
    return false
end

local function isPotion(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    for _, item in ipairs(POTION_ITEMS) do
        if lower:find(item, 1, true) then return true end
    end
    for _, item in ipairs(POTION_DISPLAY_NAMES) do
        if lower == item then return true end
    end
    return false
end

local function findEmptySlot(exclude)
    for index = 0, STASH_SIZE - 1 do
        if index ~= exclude then
            if not slotOccupied(index) then return index end
        end
    end
    return nil
end

local function findAnyEmptySlot(excludeA, excludeB)
    for index = 0, STASH_SIZE - 1 do
        if index ~= excludeA and index ~= excludeB then
            if not slotOccupied(index) then return index end
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
-- ESCANEO DINÁMICO
-- ═══════════════════════════════════════════════════════════════
local function findRedstoneSlot()
    local now = os.clock()
    if cachedFuelSlot and (now - lastFuelScan) < SCAN_CACHE_TIME then
        return cachedFuelSlot
    end

    local heldName = handInfo()
    local tempSlot
    if heldName then
        tempSlot = findEmptySlot()
        if not tempSlot then
            cachedFuelSlot = nil
            lastFuelScan = now
            return nil
        end
        pcall(android.storeItem, tempSlot)
    end

    local found = nil
    for index = 0, STASH_SIZE - 1 do
        if slotOccupied(index) then
            local ok, result = pcall(android.equipSlot, index)
            if ok and not apiFailed(result) then
                local name = handInfo()
                if name and isRedstone(name) then
                    found = index
                    break
                end
                pcall(android.storeItem, index)
            end
        end
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

    cachedFuelSlot = found
    lastFuelScan = now
    return found
end

local function findWeaponSlot()
    local now = os.clock()
    if cachedWeaponSlot and (now - lastWeaponScan) < SCAN_CACHE_TIME then
        return cachedWeaponSlot
    end

    local heldName = handInfo()
    local tempSlot
    if heldName then
        tempSlot = findEmptySlot()
        if not tempSlot then
            cachedWeaponSlot = nil
            lastWeaponScan = now
            return nil
        end
        pcall(android.storeItem, tempSlot)
    end

    local found = nil
    for index = 0, STASH_SIZE - 1 do
        if slotOccupied(index) then
            local ok, result = pcall(android.equipSlot, index)
            if ok and not apiFailed(result) then
                local name = handInfo()
                if name and isWeapon(name) then
                    found = index
                    break
                end
                pcall(android.storeItem, index)
            end
        end
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

    cachedWeaponSlot = found
    lastWeaponScan = now
    return found
end

local function ensureWeapon()
    local held = handInfo()
    if held and isWeapon(held) then return true end

    -- Si tiene munición u otro item en la mano, guardarlo
    if held then
        local stashSlot = findAnyEmptySlot()
        if stashSlot then
            pcall(android.storeItem, stashSlot)
            if isAmmo(held) then
                print("Munición guardada en r" .. stashSlot .. " (no es arma)")
            end
        end
    end

    local weaponSlot = findWeaponSlot()
    if not weaponSlot then
        -- Diagnóstico: mostrar qué hay en la stash
        print("ensureWeapon: SIN ARMA en stash. Contenido:")
        for i = 0, STASH_SIZE - 1 do
            if slotOccupied(i) then
                local ok, eq = pcall(android.equipSlot, i)
                if ok and not apiFailed(eq) then
                    local n = handInfo()
                    if n then
                        print("  r" .. i .. ": " .. n
                            .. " [wep=" .. tostring(isWeapon(n))
                            .. " ammo=" .. tostring(isAmmo(n)) .. "]")
                    end
                    pcall(android.storeItem, i)
                end
            end
        end
        return false
    end

    local tempSlot
    local held2 = handInfo()
    if held2 then
        tempSlot = findEmptySlot(weaponSlot)
        if not tempSlot then return false end
        pcall(android.storeItem, tempSlot)
    end

    local ok, result = pcall(android.equipSlot, weaponSlot)
    if not ok or apiFailed(result) then
        if tempSlot then pcall(android.equipSlot, tempSlot) end
        return false
    end

    local newWeapon = handInfo()
    if newWeapon and isWeapon(newWeapon) then
        print("Arma equipada: " .. newWeapon)
        cachedWeaponSlot = nil
        lastWeaponScan = os.clock()
        return true
    end

    if newWeapon then pcall(android.storeItem, weaponSlot) end
    if tempSlot then pcall(android.equipSlot, tempSlot) end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- REPOSTAJE INTELIGENTE
-- ═══════════════════════════════════════════════════════════════
local function isAreaSafe()
    local self = android.getSelf()
    for _, mobType in ipairs(TARGET_TYPES) do
        local ok, mob = pcall(android.getClosestMob, mobType)
        if ok and type(mob) == "table" and mob.uuid and mob.posX then
            local dx = mob.posX - self.posX
            local dy = mob.posY - self.posY
            local dz = mob.posZ - self.posZ
            if (dx*dx + dy*dy + dz*dz) < REFUEL_SAFE_RADIUS_SQ then
                return false
            end
        end
    end
    return true
end

local function refuel()
    if inCombat then return false, "en combate" end
    if (os.clock() - lastCombatEnd) < 5 then return false, "post-combate" end

    local fuelSlot = findRedstoneSlot()
    if not fuelSlot then return false, "sin redstone en stash" end

    local heldName = handInfo()
    local tempSlot
    if heldName then
        tempSlot = findEmptySlot(fuelSlot)
        if not tempSlot then return false, "sin ranura libre" end
        local ok, err = pcall(android.storeItem, tempSlot)
        if not ok or apiFailed(err) then return false, "no se guardó" end
    end

    local ok, result = pcall(android.equipSlot, fuelSlot)
    if not ok or apiFailed(result) then
        if tempSlot then pcall(android.equipSlot, tempSlot) end
        return false, "no se equipó r" .. fuelSlot
    end

    local name = handInfo()
    if not name or not isRedstone(name) then
        if name then pcall(android.storeItem, fuelSlot) end
        if tempSlot then pcall(android.equipSlot, tempSlot) end
        return false, "r" .. fuelSlot .. " no es redstone (" .. tostring(name) .. ")"
    end

    local before = android.fuelLevel()
    local called, fuelResult = pcall(android.refuel, 1)
    local after = android.fuelLevel()

    local remaining = handInfo()
    if remaining then pcall(android.storeItem, fuelSlot) end
    if tempSlot then pcall(android.equipSlot, tempSlot) end

    if not called then return false, tostring(fuelResult) end
    if after > before then
        cachedFuelSlot = fuelSlot
        return true, "fuel → " .. tostring(after)
    end
    return false, "no aumentó"
end

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local function fireAt(mob)
    local now = os.clock()
    if now - lastFireTime < FIRE_COOLDOWN then return false end

    local weapon = handInfo()
    if not weapon or not isWeapon(weapon) then
        ensureWeapon()
        return false
    end

    if AIM_BEFORE_SHOT then
        pcall(android.useEntity, mob.uuid)
        sleep(AIM_DELAY)
    end

    local ok, result = pcall(android.attack, mob.uuid)
    if not ok or apiFailed(result) then return false end

    lastFireTime = now
    shotsFired = shotsFired + 1
    return true
end

local function engage(mob)
    local self = android.getSelf()
    if not self or not mob then return end

    local dx = mob.posX - self.posX
    local dy = mob.posY - self.posY
    local dz = mob.posZ - self.posZ
    local distSq = dx*dx + dy*dy + dz*dz

    local weapon = handInfo()

    -- Sin arma: guardar munición si la hay, buscar arma, SIEMPRE moverse
    if not weapon or not isWeapon(weapon) then
        ensureWeapon()
        if distSq > MIN_RANGE_SQ then
            android.moveTo({ x = mob.posX, y = mob.posY, z = mob.posZ })
        end
        return
    end

    -- Con arma
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
    if inCombat then return end

    local heldName = handInfo()
    local tempSlot
    if heldName then
        tempSlot = findEmptySlot()
        if not tempSlot then return end
        local ok, result = pcall(android.storeItem, tempSlot)
        if not ok or apiFailed(result) then return end
    end

    local found = false
    for index = 0, STASH_SIZE - 1 do
        if slotOccupied(index) then
            local ok, eq = pcall(android.equipSlot, index)
            if ok and not apiFailed(eq) then
                local name = handInfo()
                if name and (isPotion(name) or isFood(name)) then
                    print("Comida/poción (r" .. index .. "). HP=" .. tostring(self.health))
                    found = true
                    break
                end
                pcall(android.storeItem, index)
            end
        end
    end

    if not found and tempSlot then
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
    if inCombat then return false end

    local heldName = handInfo()
    if heldName then return false end

    local ok, result = pcall(android.pickup, drop.match)
    if not ok or apiFailed(result) then return false end

    local pickedName = handInfo()
    if not pickedName then return false end

    if drop.kind == "weapon" then
        print("Arma recogida: " .. pickedName)
        cachedWeaponSlot = nil
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
-- INFORME
-- ═══════════════════════════════════════════════════════════════
local function reportLoadout()
    local weapon = handInfo()
    print("═══ Fusilero v13.1 ═══")
    print("Arma: " .. tostring(weapon or "VACÍA"))
    if weapon then
        print("  isWeapon=" .. tostring(isWeapon(weapon))
            .. " isAmmo=" .. tostring(isAmmo(weapon)))
    end
    print("Refuel: solo sin hostiles a <20 bloques")
    print("Timeout: " .. ATTACK_TIMEOUT .. "s")
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
    print("Jugadores autorizados (comas):")
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
                        unitName .. " | v13.1 | " .. state.mode
                        .. " | HP=" .. tostring(cur.health)
                        .. " | fuel=" .. tostring(android.fuelLevel())
                        .. " | arma=" .. tostring(w or "—")
                        .. " | wep=" .. tostring(isWeapon(w or ""))
                        .. " | ammo=" .. tostring(isAmmo(w or ""))
                        .. " | combat=" .. tostring(inCombat))
                elseif command == "rescan" then
                    cachedFuelSlot = nil
                    cachedWeaponSlot = nil
                    lastFuelScan = 0
                    lastWeaponScan = 0
                    pcall(android.sendChatMessage, "Rescan OK.")
                elseif command == "dump" then
                    local lines = { "MANO: " .. tostring(handInfo() or "vacia") }
                    for i = 0, STASH_SIZE - 1 do
                        local occ = slotOccupied(i)
                        lines[#lines + 1] = "r" .. i .. ":" .. (occ and "x" or ".")
                    end
                    pcall(android.sendChatMessage, "INV: " .. table.concat(lines, " "))
                end
            end
        end
    end
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
    local lastWeaponCheck = 0

    reportLoadout()
    print("Comandos: !jarvis " .. tostring(unit.name or "Android")
        .. " hold|resume|return|status|dump|rescan")
    print("ENTER para detener.")

    while true do
        local self = android.getSelf()
        local task = android.currentTask()
        local now = os.clock()

        -- TIMEOUT de ataque
        if task == "attacking" and lastTarget then
            if now - attackStartTime > ATTACK_TIMEOUT then
                android.cancelTask()
                task = "idle"
                lastTarget = nil
                inCombat = false
                lastCombatEnd = now
                print("Timeout ataque; cancelando.")
            end
        end

        -- Retirada crítica
        if self.health and self.health <= RETREAT_HEALTH and task ~= "idle" then
            android.cancelTask()
            task = "idle"
            if now - lastAlert >= ALERT_DELAY then
                pcall(android.sendChatMessage,
                    "ALERTA: HP=" .. tostring(self.health) .. ". Replegando.")
                lastAlert = now
            end
        end

        if task == "idle" then
            local mob, mobType = findHostile()
            local wasInCombat = inCombat
            inCombat = (mob ~= nil)

            if wasInCombat and not inCombat then
                lastCombatEnd = now
                shotsFired = 0
            end

            -- Mantenimiento (solo sin combate)
            if not inCombat and now - lastWeaponCheck >= 10 then
                ensureWeapon()
                lastWeaponCheck = now
            end

            if not inCombat and now - lastHealAttempt >= HEAL_RETRY_DELAY then
                tryHeal()
                lastHealAttempt = now
            end

            if not inCombat and now - lastRoleDropScan >= PICKUP_SCAN_DELAY then
                collectRoleDrops()
                lastRoleDropScan = now
            end

            -- Refuel inteligente
            local fuel = android.fuelLevel()
            if fuel < REFUEL_AT
                and now - lastRefuelAttempt >= REFUEL_RETRY_DELAY
                and not inCombat
                and (now - lastCombatEnd) >= 5
                and isAreaSafe() then
                local success, reason = refuel()
                lastRefuelAttempt = now
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
                if mob then
                    if lastTarget ~= mob.uuid then
                        lastTarget = mob.uuid
                        shotsFired = 0
                        attackStartTime = now
                        if now - lastAlert >= ALERT_DELAY then
                            pcall(android.sendChatMessage,
                                "ALERTA: " .. mobType .. " → fuego.")
                            lastAlert = now
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
    print("Fusilero v13.1 detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error: " .. tostring(err))
end   
