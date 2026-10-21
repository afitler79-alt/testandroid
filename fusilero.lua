-- ═══════════════════════════════════════════════════════════════
-- ROL FUSILERO v15 FINAL (CC:Androids 1.3.0 / Forge 1.20.1)
-- NTGL: Left=disparo+recarga | Right=apuntar
--
-- CONFIGURACIÓN OBLIGATORIA:
--   Stash (11 ranuras ARRIBA del inventario del android):
--     → Redstone (polvo, NO antorcha)
--     → Arma CGS/CBC
--   Hotbar (fila ABAJO):
--     → Munición CGS/CBC
--
-- Si el redstone está en la HOTBAR, el script NO lo ve.
-- Enter detiene.
-- ═══════════════════════════════════════════════════════════════

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 8
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
local MANUAL_FUEL_SLOT = nil  -- nil = auto-detectar. Poner número para forzar.

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local COMBAT_RANGE_SQ = 14 * 14
local MIN_RANGE_SQ = 4 * 4
local FIRE_COOLDOWN = 0.5
local AIM_BEFORE_SHOT = true
local AIM_DELAY = 0.3

local MAG_CAPACITY = {
    ["cgs:flintlock"]=1,["cgs:revolver"]=6,["cgs:shotgun"]=1,
    ["cgs:nailgun"]=32,["cgs:gatling"]=32,["cgs:blazegun"]=32,
    ["cgs:launcher"]=1,["cgs:pneumatic_hammer"]=1,["cgs:frag_grenade"]=1,
    ["cbc:ballistic_pistol"]=8,["cbc:ballistic_carbine"]=16,
    ["cbc:ballistic_shotgun"]=2,["cbc:ballistic_sniper"]=1,
    ["cbc:ballistic_gatling"]=64,["cbc:ballistic_grenade_launcher"]=4,
    ["cbc:ballistic_minigun"]=100,["cbc:ballistic_cannon"]=1,
}

local CGS_WEAPONS = {
    "cgs:flintlock","cgs:revolver","cgs:shotgun",
    "cgs:nailgun","cgs:gatling","cgs:blazegun",
    "cgs:launcher","cgs:pneumatic_hammer","cgs:frag_grenade",
}
local CBC_WEAPONS = {
    "cbc:ballistic_pistol","cbc:ballistic_carbine",
    "cbc:ballistic_shotgun","cbc:ballistic_sniper",
    "cbc:ballistic_gatling","cbc:ballistic_grenade_launcher",
    "cbc:ballistic_minigun","cbc:ballistic_cannon",
}
local ALL_WEAPONS = {}
for _,w in ipairs(CGS_WEAPONS) do ALL_WEAPONS[#ALL_WEAPONS+1]=w end
for _,w in ipairs(CBC_WEAPONS) do ALL_WEAPONS[#ALL_WEAPONS+1]=w end

local WEAPON_DISPLAY = {
    "flintlock","revolver","shotgun","nailgun","gatling",
    "blazegun","launcher","pneumatic hammer","frag grenade",
    "ballistic pistol","ballistic carbine","ballistic shotgun",
    "ballistic sniper","ballistic gatling","ballistic minigun",
    "ballistic grenade launcher","ballistic cannon",
}

local CGS_AMMO = {
    "cgs:paper_cartridge","cgs:paper_shot",
    "cgs:flintlock_bullet","cgs:revolver_round",
    "cgs:shotgun_round","cgs:nail","cgs:gatling_round",
    "cgs:piercing_revolver_round","cgs:incendiary_shotgun_round",
    "cgs:round_revolver","cgs:round_revolver_piercing","cgs:round_revolver_blank",
    "cgs:round_shotgun","cgs:round_shotgun_flechette",
    "cgs:round_shotgun_flechette_steel","cgs:round_shotgun_incendiary",
    "cgs:round_shotgun_blank",
    "cgs:round_gatling","cgs:round_gatling_piercing","cgs:round_gatling_blank",
    "cgs:nail_steel","cgs:rocket","cgs:rocket_small",
    "cgs:spear","cgs:lead_balls",
    "cgs:shell_gatling","cgs:shell_revolver","cgs:shell_shotgun",
}
local CBC_AMMO = {
    "cbc:ballistic_pistol_round","cbc:ballistic_carbine_round",
    "cbc:ballistic_shotgun_shell","cbc:ballistic_sniper_round",
    "cbc:ballistic_gatling_round","cbc:ballistic_grenade",
    "cbc:ballistic_minigun_round","cbc:cannon_shot",
    "cbc:explosive_cannon_shot","cbc:incendiary_cannon_shot",
}
local ALL_AMMO = {}
for _,a in ipairs(CGS_AMMO) do ALL_AMMO[#ALL_AMMO+1]=a end
for _,a in ipairs(CBC_AMMO) do ALL_AMMO[#ALL_AMMO+1]=a end

local AMMO_DISPLAY = {
    "flintlock bullet","revolver round","shotgun round",
    "gatling round","piercing revolver round",
    "incendiary shotgun round","steel nail",
}

local FOOD_ITEMS = {
    "minecraft:cooked_beef","minecraft:cooked_porkchop",
    "minecraft:cooked_chicken","minecraft:cooked_mutton",
    "minecraft:golden_carrot","minecraft:golden_apple",
    "minecraft:bread","minecraft:cooked_cod","minecraft:cooked_salmon",
}
local POTION_ITEMS = { "minecraft:potion","minecraft:splash_potion" }

local ROLE_DROPS = {}
for _,w in ipairs(ALL_WEAPONS) do ROLE_DROPS[#ROLE_DROPS+1]={match=w,kind="weapon"} end
for _,a in ipairs(ALL_AMMO) do ROLE_DROPS[#ROLE_DROPS+1]={match=a,kind="ammo"} end
for _,f in ipairs(FOOD_ITEMS) do ROLE_DROPS[#ROLE_DROPS+1]={match=f,kind="food"} end
for _,p in ipairs(POTION_ITEMS) do ROLE_DROPS[#ROLE_DROPS+1]={match=p,kind="potion"} end

local TARGET_TYPES = {
    "minecraft:zombie","minecraft:skeleton","minecraft:spider",
    "minecraft:creeper","minecraft:witch","minecraft:drowned",
    "minecraft:husk","minecraft:stray","minecraft:phantom",
    "minecraft:pillager","minecraft:vindicator","minecraft:evoker",
    "minecraft:ravager","minecraft:cave_spider","minecraft:silverfish",
    "minecraft:blaze","minecraft:ghast","minecraft:magma_cube",
    "minecraft:hoglin","minecraft:zoglin","minecraft:wither_skeleton",
    "minecraft:guardian","minecraft:elder_guardian","minecraft:shulker",
    "minecraft:vex","minecraft:warden","minecraft:endermite",
    "minecraft:slime","minecraft:piglin_brute",
    "alexsmobs:bone_serpent","alexsmobs:crimson_mosquito",
    "alexsmobs:centipede_head","alexsmobs:mimicube",
    "alexsmobs:soul_vulture","alexsmobs:guster","alexsmobs:warped_mosco",
    "alexsmobs:straddler","alexsmobs:dropbear","alexsmobs:void_worm",
    "alexsmobs:rocky_roller","alexsmobs:skelewag","alexsmobs:farseer",
    "alexsmobs:skreecher","alexsmobs:murmur",
    "ars_nouveau:wilden_hunter","ars_nouveau:wilden_stalker",
    "ars_nouveau:wilden_guardian","ars_nouveau:wilden_boss",
    "northstar:frozen_zombie","northstar:mars_worm",
    "northstar:mars_cobra","northstar:mercury_raptor",
    "northstar:venus_mimic","northstar:venus_scorpion",
    "quark:forgotten","quark:wraith",
    "vampirism:vampire","vampirism:ghoul",
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
local fuelWarned = false

-- ═══════════════════════════════════════════════════════════════
-- UTILIDADES
-- ═══════════════════════════════════════════════════════════════
local function apiFailed(v)
    return type(v)=="table" and v[1]==true
end

local function slotOccupied(index)
    local ok, result = pcall(android.getSlotInfo, index)
    if not ok then return false end
    if type(result) == "boolean" then return result end
    if type(result) == "string" then
        local l = result:lower()
        return l ~= "" and l ~= "empty" and l ~= "minecraft:air"
            and l ~= "air" and l ~= "a"
    end
    return false
end

local function handInfo()
    local ok, name, count = pcall(android.getHandInfo, "main")
    if not ok or type(name) ~= "string" then return nil, 0 end
    local l = name:lower()
    if l == "" or l == "air" or l == "minecraft:air" then return nil, 0 end
    return name, tonumber(count) or 0
end

local function isAmmo(name)
    if type(name) ~= "string" then return false end
    local l = name:lower()
    for _,i in ipairs(ALL_AMMO) do if l:find(i,1,true) then return true end end
    for _,i in ipairs(AMMO_DISPLAY) do if l == i then return true end end
    if l:find("round",1,true) then return true end
    if l:find("cartridge",1,true) then return true end
    if l:find("bullet",1,true) then return true end
    if l:find("shell",1,true) then return true end
    if l:find("nail",1,true) and not l:find("nailgun",1,true) then return true end
    return false
end

local function isWeapon(name)
    if type(name) ~= "string" then return false end
    local l = name:lower()
    if isAmmo(name) then return false end
    for _,i in ipairs(ALL_WEAPONS) do if l:find(i,1,true) then return true end end
    for _,i in ipairs(WEAPON_DISPLAY) do if l == i then return true end end
    return false
end

local function isRedstone(name)
    if type(name) ~= "string" then return false end
    local l = name:lower()
    if l:find("redstone_torch",1,true) then return false end
    if l:find("redstone torch",1,true) then return false end
    return l:find("redstone",1,true) ~= nil
end

local function isFood(name)
    if type(name) ~= "string" then return false end
    local l = name:lower()
    for _,i in ipairs(FOOD_ITEMS) do if l:find(i,1,true) then return true end end
    return false
end

local function isPotion(name)
    if type(name) ~= "string" then return false end
    local l = name:lower()
    for _,i in ipairs(POTION_ITEMS) do if l:find(i,1,true) then return true end end
    return false
end

local function findEmptySlot(exclude)
    for i = 0, STASH_SIZE-1 do
        if i ~= exclude and not slotOccupied(i) then return i end
    end
    return nil
end

local function findAnyEmptySlot(exA, exB)
    for i = 0, STASH_SIZE-1 do
        if i ~= exA and i ~= exB and not slotOccupied(i) then return i end
    end
    return nil
end

local function getMagCapacity()
    local n = handInfo()
    if n then
        local l = n:lower()
        for k,c in pairs(MAG_CAPACITY) do
            if l:find(k,1,true) then currentMagCap = c return c end
        end
    end
    currentMagCap = 8
    return currentMagCap
end

-- ═══════════════════════════════════════════════════════════════
-- ESCANEO
-- ═══════════════════════════════════════════════════════════════
local function scanStash()
    local held = handInfo()
    local tempSlot
    if held then
        tempSlot = findEmptySlot()
        if not tempSlot then return {} end
        pcall(android.storeItem, tempSlot)
    end

    local results = {}
    for i = 0, STASH_SIZE-1 do
        if slotOccupied(i) then
            local ok, eq = pcall(android.equipSlot, i)
            if ok and not apiFailed(eq) then
                local n = handInfo()
                if n then
                    results[i] = {
                        name = n,
                        weapon = isWeapon(n),
                        ammo = isAmmo(n),
                        fuel = isRedstone(n),
                    }
                end
                pcall(android.storeItem, i)
            end
        end
    end

    if tempSlot then
        local h = handInfo()
        if not h then
            pcall(android.equipSlot, tempSlot)
        else
            local e = findEmptySlot(tempSlot)
            if e then pcall(android.storeItem, e) pcall(android.equipSlot, tempSlot) end
        end
    end
    return results
end

local function findRedstoneSlot()
    if MANUAL_FUEL_SLOT then
        return MANUAL_FUEL_SLOT
    end
    local now = os.clock()
    if cachedFuelSlot and (now - lastFuelScan) < SCAN_CACHE_TIME then
        return cachedFuelSlot
    end
    local results = scanStash()
    for i, info in pairs(results) do
        if info.fuel then
            cachedFuelSlot = i
            lastFuelScan = now
            return i
        end
    end
    cachedFuelSlot = nil
    lastFuelScan = now
    return nil
end

local function findWeaponSlot()
    local now = os.clock()
    if cachedWeaponSlot and (now - lastWeaponScan) < SCAN_CACHE_TIME then
        return cachedWeaponSlot
    end
    local results = scanStash()
    for i, info in pairs(results) do
        if info.weapon then
            cachedWeaponSlot = i
            lastWeaponScan = now
            return i
        end
    end
    cachedWeaponSlot = nil
    lastWeaponScan = now
    return nil
end

local function ensureWeapon()
    local held = handInfo()
    if held and isWeapon(held) then return true end

    if held then
        local s = findAnyEmptySlot()
        if s then pcall(android.storeItem, s) end
    end

    local ws = findWeaponSlot()
    if not ws then
        if not fuelWarned then
            print("=========================================")
            print("SIN ARMA Y SIN FUEL EN LA STASH.")
            print("Mueve el Revolver y el Redstone a las")
            print("11 ranuras ARRIBA del inventario del")
            print("android (no la hotbar de abajo).")
            print("=========================================")
            fuelWarned = true
        end
        return false
    end

    local h2 = handInfo()
    local ts
    if h2 then
        ts = findEmptySlot(ws)
        if not ts then return false end
        pcall(android.storeItem, ts)
    end

    local ok, r = pcall(android.equipSlot, ws)
    if not ok or apiFailed(r) then
        if ts then pcall(android.equipSlot, ts) end
        return false
    end

    local nw = handInfo()
    if nw and isWeapon(nw) then
        print("Arma: " .. nw)
        cachedWeaponSlot = nil
        lastWeaponScan = os.clock()
        return true
    end
    if nw then pcall(android.storeItem, ws) end
    if ts then pcall(android.equipSlot, ts) end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- REFUEL
-- ═══════════════════════════════════════════════════════════════
local function isAreaSafe()
    local self = android.getSelf()
    for _, mt in ipairs(TARGET_TYPES) do
        local ok, mob = pcall(android.getClosestMob, mt)
        if ok and type(mob)=="table" and mob.uuid and mob.posX then
            local dx=mob.posX-self.posX
            local dy=mob.posY-self.posY
            local dz=mob.posZ-self.posZ
            if (dx*dx+dy*dy+dz*dz) < REFUEL_SAFE_RADIUS_SQ then return false end
        end
    end
    return true
end

local function refuel()
    if inCombat then return false,"combate" end
    if (os.clock()-lastCombatEnd)<5 then return false,"post-combate" end

    local fs = findRedstoneSlot()
    if not fs then
        if not fuelWarned then
            print("REFUEL: No hay redstone en la STASH (0-10).")
            print("MUEVE EL REDSTONE A LAS 11 RANURAS ARRIBA.")
            fuelWarned = true
        end
        return false,"sin redstone en stash"
    end

    local held = handInfo()
    local ts
    if held then
        ts = findEmptySlot(fs)
        if not ts then return false,"sin ranura libre" end
        local ok,e = pcall(android.storeItem, ts)
        if not ok or apiFailed(e) then return false,"no guardó" end
    end

    local ok,r = pcall(android.equipSlot, fs)
    if not ok or apiFailed(r) then
        if ts then pcall(android.equipSlot, ts) end
        return false,"no equipó r"..fs
    end

    local n = handInfo()
    if not n or not isRedstone(n) then
        if n then pcall(android.storeItem, fs) end
        if ts then pcall(android.equipSlot, ts) end
        return false,"r"..fs.." no es redstone ("..tostring(n)..")"
    end

    local before = android.fuelLevel()
    local called, fr = pcall(android.refuel, 1)
    local after = android.fuelLevel()

    local rem = handInfo()
    if rem then pcall(android.storeItem, fs) end
    if ts then pcall(android.equipSlot, ts) end

    if not called then return false,tostring(fr) end
    if after > before then
        cachedFuelSlot = fs
        fuelWarned = false
        return true,"fuel → "..tostring(after)
    end
    return false,"no aumentó"
end

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local function fireAt(mob)
    local now = os.clock()
    if now - lastFireTime < FIRE_COOLDOWN then return false end

    local w = handInfo()
    if not w or not isWeapon(w) then
        ensureWeapon()
        return false
    end

    if AIM_BEFORE_SHOT then
        pcall(android.useEntity, mob.uuid)
        sleep(AIM_DELAY)
    end

    local ok, r = pcall(android.attack, mob.uuid)
    if not ok or apiFailed(r) then return false end

    lastFireTime = now
    shotsFired = shotsFired + 1
    return true
end

local function engage(mob)
    local self = android.getSelf()
    if not self or not mob then return end

    local dx=mob.posX-self.posX
    local dy=mob.posY-self.posY
    local dz=mob.posZ-self.posZ
    local dSq=dx*dx+dy*dy+dz*dz

    local w = handInfo()
    if not w or not isWeapon(w) then
        ensureWeapon()
        if dSq > MIN_RANGE_SQ then
            android.moveTo({x=mob.posX,y=mob.posY,z=mob.posZ})
        end
        return
    end

    if dSq > COMBAT_RANGE_SQ then
        android.moveTo({x=mob.posX,y=mob.posY,z=mob.posZ})
    elseif dSq < MIN_RANGE_SQ then
        android.moveTo({
            x=self.posX+(self.posX-mob.posX)*0.5,
            y=self.posY,
            z=self.posZ+(self.posZ-mob.posZ)*0.5,
        })
    else
        fireAt(mob)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SUPERVIVENCIA / RECOGIDA
-- ═══════════════════════════════════════════════════════════════
local function tryHeal()
    local self = android.getSelf()
    if not self or not self.health or self.health >= HEAL_AT then return end
    if inCombat then return end

    local held = handInfo()
    local ts
    if held then
        ts = findEmptySlot()
        if not ts then return end
        pcall(android.storeItem, ts)
    end

    local results = scanStash()
    local found = false
    for i, info in pairs(results) do
        if info.name and (isPotion(info.name) or isFood(info.name)) then
            pcall(android.equipSlot, i)
            print("Curando (r"..i.."). HP="..tostring(self.health))
            found = true
            break
        end
    end

    if not found and ts then
        local h = handInfo()
        if not h then
            pcall(android.equipSlot, ts)
        else
            local e = findEmptySlot(ts)
            if e then pcall(android.storeItem, e) pcall(android.equipSlot, ts) end
        end
    end
end

local function collectRoleDrop(drop)
    if not drop or inCombat then return false end
    local held = handInfo()
    if held then return false end

    local ok, r = pcall(android.pickup, drop.match)
    if not ok or apiFailed(r) then return false end

    local pn = handInfo()
    if not pn then return false end

    if drop.kind == "weapon" then
        print("Arma: " .. pn)
        cachedWeaponSlot = nil
        return true
    end

    local dest = findAnyEmptySlot()
    if not dest then return false end
    local s, e = pcall(android.storeItem, dest)
    if not s or apiFailed(e) then return false end
    print("Guardado: " .. pn .. " r" .. dest)
    return true
end

local function collectRoleDrops()
    local d = ROLE_DROPS[roleDropIndex]
    collectRoleDrop(d)
    roleDropIndex = roleDropIndex % #ROLE_DROPS + 1
end

-- ═══════════════════════════════════════════════════════════════
-- HOSTILES
-- ═══════════════════════════════════════════════════════════════
local function findHostile()
    local self = android.getSelf()
    local closest, closestType, closestDist

    for _, mt in ipairs(TARGET_TYPES) do
        local ok, mob = pcall(android.getClosestMob, mt)
        if ok and type(mob)=="table" and mob.uuid and mob.posX then
            local dx=mob.posX-self.posX
            local dy=mob.posY-self.posY
            local dz=mob.posZ-self.posZ
            local dSq=dx*dx+dy*dy+dz*dz
            if not closestDist or dSq < closestDist then
                closest, closestType, closestDist = mob, mt, dSq
            end
        end
    end
    return closest, closestType
end

-- ═══════════════════════════════════════════════════════════════
-- INFORME
-- ═══════════════════════════════════════════════════════════════
local function reportLoadout()
    local w = handInfo()
    print("═══ FUSILERO v15 ═══")
    print("Mano: " .. tostring(w or "VACÍA"))
    if w then
        print("  wep="..tostring(isWeapon(w)).." ammo="..tostring(isAmmo(w)))
    end
    print("--- STASH ---")
    local results = scanStash()
    local any = false
    for i, info in pairs(results) do
        any = true
        print("  r"..i..": "..info.name
            .." [wep="..tostring(info.weapon)
            .." fuel="..tostring(info.fuel).."]")
    end
    if not any then
        print("  *** STASH VACÍA ***")
        print("  Mueve el REDSTONE y el ARMAS a las 11")
        print("  ranuras ARRIBA del inventario del android.")
        print("  (La hotbar de ABAJO no la ve la API)")
    end
    print("Objetivos: "..#TARGET_TYPES)
    print("═══════════════════")
end

-- ═══════════════════════════════════════════════════════════════
-- CONTROL
-- ═══════════════════════════════════════════════════════════════
local function parseOwners(input)
    local owners, names = {}, {}
    for part in tostring(input):gmatch("[^,\n]+") do
        local n = part:match("^%s*(.-)%s*$")
        if n ~= "" and not owners[n:lower()] then
            owners[n:lower()] = true
            names[#names+1] = n
        end
    end
    return owners, names
end

local function loadOwners()
    if fs.exists(OWNERS_FILE) then
        local f = fs.open(OWNERS_FILE,"r")
        if not f then return nil end
        local o, n = parseOwners(f.readAll())
        f.close()
        if #n == 0 then return nil end
        return o
    end
    print("Jugadores (comas):")
    local o, n = parseOwners(read())
    while #n == 0 do
        print("Escribe un nombre:")
        o, n = parseOwners(read())
    end
    local f = fs.open(OWNERS_FILE,"w")
    if not f then return nil end
    f.write(table.concat(names,"\n").."\n")
    f.close()
    return o
end

local function waitForStop()
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.enter then return end
    end
end

local function listenForCommands(unit, state, owners)
    local un = tostring(unit.name or "Android")
    while true do
        local _, data = os.pullEvent("onChatMessage")
        if type(data)=="table" and owners[tostring(data.senderName or ""):lower()] then
            local target, cmd = tostring(data.message or ""):match("^!jarvis%s+(.+)%s+(%S+)$")
            if target and cmd and (target:lower()=="all" or target:lower()==un:lower()) then
                cmd = cmd:lower()
                if cmd == "hold" then
                    state.mode="hold" android.cancelTask()
                elseif cmd=="resume" or cmd=="patrol" then
                    state.mode="patrol"
                elseif cmd=="return" then
                    state.mode="return" android.cancelTask()
                elseif cmd=="status" then
                    local c=android.getSelf() local w=handInfo()
                    pcall(android.sendChatMessage,
                        un.." | v15 | "..state.mode
                        .." | HP="..tostring(c.health)
                        .." | fuel="..tostring(android.fuelLevel())
                        .." | arma="..tostring(w or "—")
                        .." | wep="..tostring(isWeapon(w or ""))
                        .." | combat="..tostring(inCombat))
                elseif cmd=="rescan" then
                    cachedFuelSlot=nil cachedWeaponSlot=nil
                    lastFuelScan=0 lastWeaponScan=0
                    fuelWarned=false
                    pcall(android.sendChatMessage,"Rescan OK.")
                elseif cmd=="dump" then
                    local lines={"MANO: "..tostring(handInfo() or "vacia")}
                    for i=0,STASH_SIZE-1 do
                        lines[#lines+1]="r"..i..":"..(slotOccupied(i) and "x" or ".")
                    end
                    pcall(android.sendChatMessage,"INV: "..table.concat(lines," "))
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- BUCLE
-- ═══════════════════════════════════════════════════════════════
local function patrol(home, state, unit)
    local points = {
        {x=home.x+PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z+PATROL_RADIUS},
        {x=home.x-PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z-PATROL_RADIUS},
    }
    local nextPoint = 1
    local lastRefuel = -REFUEL_RETRY_DELAY
    local lastPickup = -PICKUP_SCAN_DELAY
    local lastAlert = -ALERT_DELAY
    local lastHeal = -HEAL_RETRY_DELAY
    local lastWepCheck = 0

    reportLoadout()
    print("Comandos: !jarvis "..tostring(unit.name or "Android")
        .." hold|resume|return|status|dump|rescan")
    print("ENTER para detener.")

    while true do
        local self = android.getSelf()
        local task = android.currentTask()
        local now = os.clock()

        if task=="attacking" and lastTarget then
            if now - attackStartTime > ATTACK_TIMEOUT then
                android.cancelTask()
                task="idle" lastTarget=nil
                inCombat=false lastCombatEnd=now
                print("Timeout ataque.")
            end
        end

        if self.health and self.health <= RETREAT_HEALTH and task~="idle" then
            android.cancelTask() task="idle"
            if now - lastAlert >= ALERT_DELAY then
                pcall(android.sendChatMessage,
                    "ALERTA: HP="..tostring(self.health).." Replegando.")
                lastAlert = now
            end
        end

        if task == "idle" then
            local mob, mobType = findHostile()
            local wasC = inCombat
            inCombat = (mob ~= nil)

            if wasC and not inCombat then
                lastCombatEnd = now
                shotsFired = 0
            end

            if not inCombat and now - lastWepCheck >= 10 then
                ensureWeapon()
                lastWepCheck = now
            end

            if not inCombat and now - lastHeal >= HEAL_RETRY_DELAY then
                tryHeal()
                lastHeal = now
            end

            if not inCombat and now - lastPickup >= PICKUP_SCAN_DELAY then
                collectRoleDrops()
                lastPickup = now
            end

            local fuel = android.fuelLevel()
            if fuel < REFUEL_AT
                and now - lastRefuel >= REFUEL_RETRY_DELAY
                and not inCombat
                and (now - lastCombatEnd) >= 5
                and isAreaSafe() then
                local s, r = refuel()
                lastRefuel = now
                fuel = android.fuelLevel()
                if s then print("Fuel → "..tostring(fuel)) end
            end

            if fuel < 1 then
                sleep(SCAN_DELAY)
            elseif state.mode=="return"
                or (self.health and self.health<=RETREAT_HEALTH) then
                lastTarget=nil
                android.moveTo(home)
            elseif state.mode=="patrol" then
                if mob then
                    if lastTarget ~= mob.uuid then
                        lastTarget = mob.uuid
                        shotsFired = 0
                        attackStartTime = now
                        if now - lastAlert >= ALERT_DELAY then
                            pcall(android.sendChatMessage,
                                "ALERTA: "..mobType.." → fuego.")
                            lastAlert = now
                        end
                    end
                    engage(mob)
                else
                    lastTarget = nil
                    android.moveTo(points[nextPoint])
                    nextPoint = nextPoint % #points + 1
                end
            elseif state.mode=="hold" then
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
    local home = {x=self.posX,y=self.posY,z=self.posZ}
    local state = {mode="patrol"}
    local owners = loadOwners()
    if not owners then
        print("Sin propietarios.")
        return
    end

    parallel.waitForAny(
        function() patrol(home, state, self) end,
        waitForStop,
        function() listenForCommands(self, state, owners) end
    )
    android.cancelTask()
    print("Fusilero v15 detenido.")
end

local ok, err = pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error: "..tostring(err))
end   
