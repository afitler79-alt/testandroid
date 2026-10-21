-- ═══════════════════════════════════════════════════════════════
-- FUSILERO v18 (CC:Androids 1.3.0 / NTGL 3.1.2)
-- Ranuras FIJAS. No escanea constantemente.
-- Solo equipa cuando ha

El ce falta problema es que el escaneo por `equipSlot` (refuel, combate).
-- Left=disparo+recarga | Right=apuntar
-- ═════en todas las ranuras es **destructivo**: equipa y desequipa todo ══════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURACIÓN: pon tus ranucada 15s, por eso "cambia de item" constantemente.

Solución: usar `getSlotInfo` solo para saber si una ranura está **ocupada** (no para el nombre), y solo usar `equras aquí (0-8)
-- ═══════════════════════════════════════════════════════════════
local FUEL_SLOT = 0       -- Ranura con REDSTONE (polvo)
local WEAPON_SLOT = 1   ipSlot`+`getHandInfo` de forma **puntual** (  -- Ranura con ARMAuna sola ranura) cuando nece CGS/CBC
-- ═════════════════sita refuel o equipar arma.

```lua
-- ═══════════════════════════════════════════════

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 8
loca══════════════════════════════════════════════════════════════
-- FUSILERO v18
-- CC:Androids 1.3.0 / NTl REFUEL_AT = 20
local REFUEL_RETRY_DELAY = 15
local STASH_SIZE = 9
local RETREAT_HEALTH = 6
local ALERT_DELAY = 10
local ATTACK_TIMEOUT = 15
local FIRE_COOLGL 3.1.2
-- No escanea masivamente. Usa getSlotInfo para ocupación,
-- equipSlot+getHandInfo solo puDOWN = 0.5
local AIM_BEFORE_SHOT = true
local AIM_DELAntual (1 ranura a la vez).
-- Left=disparo+recarga | Right=apuntar
Y = 0.3
local COMBAT_RANGE_SQ = 14*14
local MIN_RANGE_SQ = 4*4
local OWNERS_FILE = "owners.cfg"

-- ═══════════════════════════════════════════════════════════════

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 8
local REFUEL_AT = 20
local REFUEL_RET-- ═══════════════════════════════════════════════════════════════
local WEAPONS = {
    "cgs:flintlock","cgs:revolver","cgs:shotgun","cgs:nailgun",
    "cgsRY_DELAY = 15
local STASH_SIZE = 9
local RETREAT_HEALTH = 6
local ALERT_DELAY = 10
local ATTACK_TIMEOUT = 15
local FIRE_COOLDOWN = 0.5
local AIM_BEFORE_SHOT = true
local AIM_DELAY = 0.3
local COMBAT_RANGE_SQ :gatling","cgs:blazegun","cgs:launcher",
    "cgs:pneumatic_hammer","cgs:frag_grenade",
    "cbc:ballistic_pistol","cbc:ballistic_carbine",
    "cbc:ballistic_shotgun","cbc:ballistic_sniper",
    "cbc:ballistic_gatling","cbc:ballistic_grenade_launcher",
 = 14*14
local MIN_RANGE_SQ = 4*4
local OWNERS_FILE = "owners.cfg"
local FUEL_SLOT = 0
local WEAPON_SLOT = 1

local WEAPONS = {
    "cgs:flintlock","cgs:revo   "cbc:ballistic_minigun","cbc:ballistic_cannon",
}
local WEAPlver","cgs:shotgunON_NAMES = {
","cgs:na    "filgun",
lintlock","revolver","sho    "cgs:gatling"tgun","nailgun","gatling",
   ,"cgs:blazegun","cgs:launcher",
     "blazegun","launcher","pneumatic hammer","frag grenade",
    "ballistic pisto"cgs:pneumatic_hammer","cgs:frag_grenade",
l","ballistic ca    "cbc:balrbine","ballistic slistic_pistohotgun",
 l","cbc:ballistic   "ballistic snipe_carbine",
r","ballistic ga    "cbc:btling","ballistic minigun",
    "ballisticallistic_shotgun","cbc:ballistic_sniper",
 grenade launcher","ballistic cannon",
}
local AMMO_    "cbc:ballistic_gatling","cbc:ballistic_grenade_launcher",
    "IDS = {
    "cgs:flintlock_bullet","cgs:revolver_round","cgs:shotgun_round",
    "cgscbc:ballistic_minigun","cbc:ballistic_cannon",
}

local WEAPON_NAMES = {
    "flintlock","revolver","shotgun","nailgun",:nail","cgs:gatling_round","cgs:piercing_revolver_round",
    "cgs:incendiary_shotgun_round","cgs:paper_cartridge","cgs:paper_shot",
    "cgs:round_rev"gatling",
    "blazegun","launcher","pneumatic hammer","frag grenade",
    "ballistic pistol","ballistic carbine","ballistic shotgun",
    "ballistic sniper","ballistic gatling","ballistic minigun",
    "ballistic grenade launcher","ballistic cannon",
}

olver","cgs:round_revolver_piercing","cgs:round_revolver_blank",
    "cgs:round_shotgun","cgs:round_shotgun_flechette",
    "cgs:round_shotgun_flechette_steel","cgs:round_shotgun_incendiary",
    "cgs:round_shotgun_blank","cgs:round_gatling","cgs:rlocal AMMO_IDS = {
    "cgs:flintlock_bullet","cgs:revolver_round","cgs:shotgun_round",
    "cgs:nail","cgs:gatling_round","cgs:piercing_revolver_round",
    "cgs:incendiary_shotgun_round","cgs:paper_cartridge","cgs:paper_shot",
    "cgs:round_revolver","cgs:round_revolver_piercing","cgs:round_revolver_blank",
ound_gatling_piercing",
    "cgs:round_gatling_blank","cgs:nail_steel","cgs:rocket",
    "cgs:rocket_small","cgs:spear","cgs:lead_balls",
    "cgs:shell_gatling","cgs:shell_revolver","cgs:shell_shotgun",
    "cbc:ballistic_pistol_round","cbc:ballistic_carbine_round",
    "cbc:ballistic_shotgun_shell","cbc:ballistic_sniper_round",
    "cbc:ballistic_gatling_    "cgs:round_shotgun","cgs:round_shotgun_flechette",
    "cgs:round_shotgun_flechette_steel","cgs:round_shotgun_incendiary",
    "cgs:round_shotgun_blank","cgs:round_gatling","cgs:round_gatling_piercing",
    "cgs:round_gatling_blank","cgs:nail_steel","cgs:rocket",
    "cgs:rocket_small","cgs:spear","cgs:lead_balls",
    "cgs:shell_gatling","cgs:shell_revolver","cgs:shell_shotgun",
    "cbc:ballistiround","cbc:ballistic_grenade",
    "cbc:ballistic_minigun_round","cbc:cannon_shot",
}
local FOOD_IDS = {
    "minecraft:cooked_beef","minecraft:cooked_porkchop",
    "minecraft:cooked_chicken","minecraft:cooked_mutton",
    "minecraft:golden_carrot","minecraft:golden_apple",
    "minecraft:bread","minecraft:cookec_pistol_round","cbc:ballistic_carbine_round",
    "d_cod","minecraft:cooked_sacbc:ballistic_shotglmon",
}
locaun_shell","l POTION_IDS = {"minecraft:potion","minecraft:splascbc:ballistic_sniper_round",
    "cbc:ballistic_gatling_round","cbc:ballistich_potion"}

local TARGETS = {
    "minecraft:zombie","minecraft:skeleton","minecraft:spider",
    "minecraft:creeper","minecraft:witch","minecraft:d_grenade",
    "cbc:ballistic_minigun_round","cbc:cannon_shot",
}

local FOOD_IDS = {
    "minecraft:cooked_beef","minecraft:cooked_porkchop",
    "minecraft:cooked_chicken","minecraft:cooked_mrowned",
    "minecraft:husk","minecraft:stray","minecraft:phantom",
    "minecraft:pillager","minecraft:vindicator","minecraft:evoker",
    "minecraft:ravager","minecraft:cave_spider","minecraft:silverfish",
    "minecraft:blaze","minecraft:ghast","minecraft:magma_cube",
    "minecraft:hoglin","minecraft:zutton",
    "minecraft:golden_carrot","minecraft:golden_apple",
    "minecraft:bread","minecraft:cooked_cod","minecraft:cooked_salmon",
}
local POTION_IDS = {"minecraft:potion","minecraft:splash_potion"}

local TARGETS = {
    "minecraft:zombie","minecraft:skeleton","minecraft:spider",
    "minecraft:creeper","minecraft:witch","minecraft:drowned",
    "minecraft:husk","minecraft:stray","minecraft:poglin","minecraft:wither_skeleton",
    "minecraft:guardian","minecraft:shulker","minecraft:vex",
    "minecraft:warden","minecraft:endermite","minecraft:slime",
    "minecraft:piglin_brute",
    "alexsmobs:bone_serpent","alexsmobs:crimson_mosquito",
    "alexsmobs:centipede_head","alexsmobs:mimicube",
    "alexsmobs:soul_vulture","alexsmobs:guster","alexsmobs:warped_mosco",
    "alexsmobs:straddler","alexsmobs:dropbear"hantom",
    "minecraft:pillager","minecraft:vindicator","minecraft:evoker",
    "minecraft:ravager","minecraft:cave_spider","minecraft:silverfish",
    "minecraft:blaze","minecraft:ghast","minecraft:magma_cube",
    "minecraft:hoglin","minecraft:zoglin","minecraft:wither_skeleton",
    "minecraft:guardian","minecraft:shulker","minecraft:vex",
    "minecraft:warden","minecraft:endermite","minecraft:slime",
    "minecraft:piglin_brute",
    "alexsmobs:bone_serpent","alexsmobs:crimson_mosquito",
    "alexsmobs:centipede_head","alexsmobs:mimicube",
    "alexsmobs:soul_vulture","alexsmobs:guster","alexsmobs:warped,"alexsmobs:void_worm",
    "alexsmobs:rocky_roller","alexsmobs:skelewag","alexsmobs:farseer",
    "alexsmobs:skreecher","alexsmobs:murmur",
    "ars_nouveau:wilden_hunter","ars_nouveau:wilden_stalker",
    "ars_nouveau:wilden_guardian","ars_nouveau:wilden_boss",
    "northstar:frozen_zombie","northstar:mars_worm",
    "northstar:mars_cobra","northstar:mercury_raptor",
    "northstar:venus_mimic","northstar:venus_scorpion",
    "quark:forgotten","quark:wraith",
    "vampirism_mosco",
    "alexsmobs:straddler","alexsmobs:dropbear","alexsmobs:void_worm",
    "alexsmobs:rocky_roller","alexsmobs:skelewag","alexsmobs:farseer",
    "alexsmobs:skreecher","alexsmobs:murmur",
    "ars_nouveau:wilden_hunter","ars_nouveau:wilden_stalker",
    "ars_nouveau:wilden_guardian","ars_nouveau:wilden_boss",
    "northstar:frozen_zombie","northstar:mar:vampire","vampirism:ghoul","werewolves:werewolf",
}

-- ═══════════════════════════════════════════════════════════════
local lastFire = 0
local lastTarget = nil
local inCombat = false
local lastCombatEnd = 0
local attackStart = 0

local function fail(v) return type(v)=="table" and v[1]==true end

local function hand()
    local ok,n,c = pcall(android.getHandInfo,"main")
    if not ok or type(n)~="string" then return nil,0 end
    local l=n:lower()
    if l=="" ors_worm",
    "northstar:mars_cobra","northstar:mercury_raptor",
    "northstar:venus_mimic","northstar:venus_scorpion",
    "quark:forgotten","quark:wraith",
    "vampirism:vampire","vampirism:ghoul","werewolves:werewolf",
}

local lastFire = 0
local lastTarget = nil
local inCombat = false
local lastCombatEnd = 0
local attackStart = 0
local lastRefuelAttempt = 0
local lastWepCheck = 0
local lastAlert = 0

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function fail(v) return type(v)=="table" and v[1]==true end

 l=="air" or l=="minecraft:air" then return nil,0 end
    return n, tonumber(c) or 0
end

local function isAmmo(n)
    if type(n)~="string" then return false end
    local l=n:lower()
    for _,i in ipairs(AMMO_IDS) do if l:find(i,1,true) then return true end end
    if l:find("round",1,true) then return true end
    if l:find("bullet",1,true) then return true end
    if l:find("cartridge",1,true) then return true end
    if l:find("shell",1,true) then return true end
    if l:find("nail",1,true) and not l:find("nailgun",1,true) then return true end
    return false
end

local function isWep(n)
    if type(n)~="string" then return false end
    if isAmmo(n) then return false end
    local l=n:lower()
    for _,i in ipairs(WEAPONS) do if l:find(i,1,true) then return true end end
    for _,i in ipairs(WEAPON_NAMES) do if l==i then return true end end
    return false
end

local function hand()
    local ok,n,c = pcall(android.getHandInfo,"main")
    if not ok or type(n)~="string" then return nil,0 end
    local l=n:lower()
    if l=="" or l=="air" or l=="minecraft:air" then return nil,0 end
    return n, tonumber(c) or 0
end

local function isAmmo(n)
    if type(n)~="string" then return false end
    local l=n:lower()
    for _,i in ipairs(AMMO_IDS) do if l:find(i,1,true) then return true end end
    if l:find("round",1,true) then return true end
    if l:find("bullet",1,true) then return true end
    if l:find("cartridge",1,true) then return true end
    if l:find("shell",1,true) then return true end
    if l:find("nail",1,true) and not l:find("nailgun",1,true) then return true end
    return false
end

local function isWep(n)
    if type(n)~="string" then return false end
    if isAmmo(n) then return false end
    local l=n:lower()
    for _,i in ipairs(WEAPONS) do if l:find(i,1,true) then return true end end
    for _,i in ipairs(WEAPON_NAMES) do if l==i then return true end end
    return false
end

local function isFuel(n)
    if type(n)~="string" then return false end
    local l=n:lower()
local function isFuel(n)
    if type(n)~="string" then return false end
    local l=n:lower()
    if l:find("redstone torch",1,true) then return false end
    if l:find("redstone_torch",1,true) then return false end
    return l:find("redstone",1,true)~=nil
end

-- ═══════════════════════════════════════════════════════════════
-- EQUIPAR ARMA (solo desde WEAPON_SLOT fijo)
-- ═══════════════════════════════════════════════════════════════
local function equipWeapon()
    local h = hand()
    if h and isWep(h) then return true end

    -- Guardar lo que hay en mano en FUEL_SLOT si está libre, o en otra
    local tmp = nil
    if h then
        if not pcall(function()
            local ok,r = pcall(android.equipSlot, FUEL_SLOT)
            if ok and not fail(r) then pcall(android.storeItem, FUEL_SLOT) return true end
        if l:find("redstone torch",1,true) then return false end
    if l:find("redstone_torch",1,true) then return false end
    return l:find("redstone",1,true)~=nil
end

-- getSlotInfo: solo para saber si está ocupada (no da nombre)
local function occupied(i)
    local ok,r = pcall(android.getSlotInfo,i)
    if not ok then return false end
    if type(r)=="boolean" then return r end
    if type(r)=="string" then
        local l=r:lower()
        return l~="" and l~="empty" and l~="minecraft:air" and l~="air" and l~="a"
    end
    return false
    end) then tmp = nil end
        -- Buscar ranura libre para guardar
        for i=0,STASH_SIZE-1 do
            if i ~= WEAPON_SLOT then
                local ok,r = pcall(android.equipSlot,i)
                if ok and not fail(r) then
                    pcall(android.storeItem,i)
                else
                    tmp = i
                    break
                end
            end
        end
        if not tmp then return false end
        pcall(android.storeItem,tmp)
    end

    -- Equipar arma desde WEAPON_SLOT
    local ok,r = pcall(android.equipSlot,WEAPON_SLOT)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return false
    end

    local nw = hand()
    if nw and isWep(nw) then
        return true
    end
    -- No es un arma, devolver
    ifend

-- Equipar UNA ranura, verificar, devolver. Solo 1 ranura.
local function peekSlot(i)
    local h = hand()
    local tmp
    if h then
        tmp = findEmpty(i)
        if not tmp then return nil end
        pcall(android.storeItem,tmp)
    end
    local ok,r = pcall(android.equipSlot,i)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return nil
    end
    local n = hand()
    if n then
        pcall(android.storeItem,i)
    end
    if tmp then
        local h2 = hand()
        if not h2 then pcall(android.equipSlot,tmp)
        else
            local e = findEmpty(tmp)
            if e then pcall(android.storeItem,e) pcall(android.equipSlot,tmp) end
        end
    end
    return n
end

local function findEmpty(exclude)
    for i=0,STASH_SI nw then pcall(android.storeItem,WEAPON_SLOT) end
    if tmp then pcall(android.equipSlot,tmp) end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- REFUEL (solo desde FUEL_SLOT fijo)
-- ═══════════════════════════════════════════════════════════════
local function doRefuel()
    if inCombat then return end
    if os.clock()-lastCombatEnd < 5 then return end

    -- Guardar arma si la hay
    local h = hand()
    local tmp = nil
    if h then
        for i=0,STASH_SIZE-1 do
            if i ~= FUEL_SLOT then
                local ok,r = pcall(android.equipSlot,i)
                if ok and not failZE-1 do
        if i~=exclude and not occupied(i) then return i end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- EQUIPAR ARMA (solo toca WEAPON_SLOT)
-- ═══════════════════════════════════════════════════════════════
local function equipWeapon()
    local h = hand()
    if h and isWep(h) then return true end

    -- Verificar si WEAPON_SLOT tiene un arma
    local n = peekSlot(WEAPON_SLOT)
    if not n or not isWep(n) then
        -- Buscar en otra ranura
        for i=0,STASH_SIZE-1 do
            if i~=WEAPON_SLOT and occupied(i) then
                n = peekSlot(i)
                if n and isWep(n) then
                  (r) then
                    pcall(android.storeItem,i)
                else
                    tmp = i
                    break
                end
            end
        end
        if not tmp then return end
        pcall(android.storeItem,tmp)
    end

    -- Equipar fuel
    local ok,r = pcall(android.equipSlot,FUEL_SLOT)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return
    end

    local n = hand()
    if not n or not isFuel(n) then
        if n then pcall(android.storeItem,FUEL_SLOT) end
        if tmp then pcall(android.equipSlot,tmp) end
        print("Refuel: r"..FUEL_SLOT.." no tiene redstone ("..tostring(n)..")")
        return
    end

    local before = android.fuelLevel()
    pcall(android.refuel,1)
   WEAPON_SLOT = i
                    break
                end
            end
        end
    end

    if not n or not isWep(n) then return false end

    -- Guardar lo que hay en mano
    local h2 = hand()
    local tmp
    if h2 then
        tmp = findEmpty(WEAPON_SLOT)
        if not tmp then return false end
        pcall(android.storeItem,tmp)
    end

    local ok,r = pcall(android.equipSlot,WEAPON_SLOT)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return false
    end

    local nw = hand()
    if nw   local after = android.fuelLevel()

    -- Devolver
    local rem = hand()
    if rem then pcall(android.storeItem,FUEL_SLOT) end
    if tmp then pcall(android.equipSlot,tmp) end

    if after > before then
        print("Fuel → "..tostring(after))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local function findMob()
    local s = android.getSelf()
    local best, bestType, bestD
    for _,t in ipairs(TARGETS) do
        local ok,m = pcall(android.getClosestMob,t)
        if ok and type(m)=="table" and m.uuid and m.posX then
            local dx=m.posX-s.posX
            local dy=m.posY-s.posY
            local dz=m.posZ-s.posZ
            local d=dx*dx+dy*dy+dz*dz
            if not bestD or d<bestD then
                best,bestType,bestD and isWep(nw) then
        print("Arma: "..nw)
        return true
    end
    if nw then pcall(android.storeItem,WEAPON_SLOT) end
    if tmp then pcall(android.equipSlot,tmp) end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- REFUEL (solo toca FUEL_SLOT)
-- ═══════════════════════════════════════════════════════════════
local function doRefuel()
    if inCombat then return end
    if os.clock()-lastCombatEnd < 5 then return end

    -- Verificar si FUEL_SLOT tiene redstone
    local n = peekSlot(FUEL_SLOT)
    if not n or not isFuel(n) then
        -- Buscar en otra ranura
        for i=0,STASH_SIZE-1 do
            if i~=FUEL_SLOT and occupied(i) then
                n = peekSlot(i)
                if n and isFuel(n) then
                    FUEL_SLOT = i
                    break
                end
            end
        end
    end

    if not n or not isFuel(n) then
        print("REFUEL: sin redstone en stash.")
        return
    end

    local h = hand()
    local tmp
    if h then
        tmp = findEmpty(FUEL_SLOT)
        if not tmp then return end
        pcall(android.storeItem,tmp)
    end

    local ok,r = pcall(android.e = m,t,d
            end
        end
    end
    return best, bestType
end

local function combat(mob)
    local s = android.getSelf()
    if not s or not mob then return end

    local dx=mob.posX-s.posX
    local dy=mob.posY-s.posY
    local dz=mob.posZ-s.posZ
    local d=dx*dx+dy*dy+dz*dz

    local w = hand()
    if not w or not isWep(w) then
        equipWeapon()
        if d > MIN_RANGE_SQ then
            android.moveTo({x=mob.posX,y=mob.posY,z=mob.posZ})
        end
        return
    end

    if d > COMBAT_RANGE_SQ then
        android.moveTo({x=mob.posX,y=mob.posY,z=mob.posZ})
    elseif d < MIN_RANGE_SQ then
        android.moveTo({
            x=s.posX+(s.posX-mob.posX)*0.5,
            y=s.posY,
            z=s.posZ+(s.posZ-mob.posZ)*0.5,
        })
    else
        local now = os.clock()
        if now - lastFire < FIRE_COOLDOWN then return end
        if AIM_BEFORE_SHOT then
            pcall(android.useEntity,mob.uuid)
            sleep(AIM_DELAY)
        end
        local ok,r = pcall(android.attack,mob.uuid)
        if ok and not fail(r) then lastFire = now end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CONTROL
-- ═════════quipSlot,FUEL_SLOT)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return
    end

    local before = android.fuelLevel()
    pcall(android.refuel,1)
    local after = android.fuelLevel()

    local rem = hand()
    if rem then pcall(android.storeItem,FUEL_SLOT) end
    if tmp then pcall(android.equipSlot,tmp) end

    if after > before then
        print("Fuel → "..tostring(after))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- COMBATE
-- ═══════════════════════════════════════════════════════════════
local function findMob()
    local s = android.getSelf()
    local best, bestType, bestD
    for _,t in ipairs(TARGETS) do
        local ok,m = pcall(android.getClosestMob,t)
        if ok and type(m)=="table" and m.uuid and m.posX then
            local dx=m.posX-s.posX
            local dy=m.posY-s.posY
            local dz=m.posZ-s.posZ
            local d=dx*dx+dy*dy+dz*dz
            if not bestD or d<bestD then
                best,bestType,bestD = m,t,d
            end
    ══════════════════════════════════════════════════════
local function parseOwners(input)
    local o,names={},{}
    for p in tostring(input):gmatch("[^,\n]+") do
        local n=p:match("^%s*(.-)%s*$")
        if n~="" and not o[n:lower()] then o[n:lower()]=true names[#names+1]=n end
    end
    return o,names
end

local function loadOwners()
    if fs.exists(OWNERS_FILE) then
        local f=fs.open(OWNERS_FILE,"r")
        if not f then return nil end
        local o,n=parseOwners(f.readAll()) f.close()
        if #n==0 then return nil end
        return o
    end
    print("Jugadores (comas):")
     end
    end
    return best, bestType
end

local function combat(mob)
    local s = android.getSelf()
    if not s or not mob then return end

    local dx=mob.posX-s.posX
    local dy=mob.posY-s.posY
    local dz=mob.posZ-s.posZ
    local d=dx*dx+dy*dy+dz*dz

    local w = hand()
    if not w or not isWep(w) then
        equipWeapon()
        if d > MIN_RANGE_SQ then
            android.moveTo({x=mob.posX,y=mob.posY,z=mob.posZ})
        end
         local o,n=parseOwners(read())
    while #n==0 do o,n=parseOwners(read()) end
    local f=fs.open(OWNERS_FILE,"w")
    if not f then return nil end
    f.write(table.concat(n,"\n").."\n") f.close()
    return o
end

local function waitStop()
    while true do
        local _,k=os.pullEvent("key")
        if k==keys.enter then return end
  return
    end

    if d > COMBAT_RANGE_SQ then
        android.moveTo({x=mob.posX,y=mob.posY,z=mob.posZ})
    elseif d < MIN_RANGE_SQ then
        android.moveTo({
            x=s.posX+(s.posX-mob.posX)*0.5,
            y=s.posY,
            z=s.posZ+(s.posZ-mob.posZ)*0.5,
        })
    else
         end
end

local function listen(unit,state,owners)
    local un=tostring(unit.name or "Android")
    while true do
        local _,d=os.pullEvent("onChatMessage")
        if type(d)=="table" and owners[tostring(d.senderName or ""):lower()] then
            local t,c=tostring(d.message or ""):match("^!jarvis%s+(.+)%s+(%S+)$")
            if t and c and (t:lower()=="all" or t:lower()==un:   local now = os.clock()
        if now - lastFire < FIRE_COOLDOWN then return end
        if AIM_BEFORE_SHOT then
            pcall(android.useEntity,mob.uuid)
            sleep(AIM_DELAY)
        end
        local ok,r = pcall(android.attack,mob.uuid)
        if ok and not fail(r) then lastFire = now end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CONTROL
-- ═lower()) then
                c=c:lower()
                if c=="hold" then state.mode="hold" android.cancelTask()
                elseif c=="resume" or c=="patrol" then state.mode="patrol"
                elseif c=="return" then state.mode="return" androi════════════════════════════════d.cancelTask()
                elseif c=══════════════════════════════
local function parseOwne="status" then
                    local s=android.getSelfrs(input)
    local o,names={},{}
    for p in tostri() local w=hand()
                    pcall(android.sendChatMessage,un.."|"..stang(input):gmatch("[^,\n]+") do
        local n=p:mate.mode
                        .."|HP="..tostring(s.health)
                        .."|fuel="..tostring(android.fuelLevel())
                        .tch("^%s*(.-)%s*$")
        if n~="" and not o[n:lower()] then o[n:lower()]=true names[#names+1."|wep="..tostring(w or "—")
                        .."|combat="..tostring(inCombat))
                end
            end
        end
    end
end

]=n end
    end
    return o,names
end

local function loadOwners()
    if fs.exists(OWNERS_FILE) then
        local f=fs.open(OWNERS_FILE,"r")
  -- ═══════════════════════════════════════════════════════════════
-- MAIN
-- ═══════════════════════════════════════════════════════════════
local function main()
    local s = and      if not f then return nil end
        local o,n=parseOwners(f.readAll()) f.close()
        if #n==0 then return nil end
        return o
    end
    roid.getSelf()
    local home = {print("Jugadox=s.posX,res (comas):")
    local o,n=parseOwners(read())
    while #n==0 do o,n=parseOwners(read()) end
    local f=fs.open(OWNERS_FILE,"w")
    if not f then return nil end
    f.write(table.concat(n,"\n").."\n") f.close()
    return o
end

local function waitStop()
    while true do
        local _,k=os.pullEvent("key")
        if k==keys.enter then return end
    end
end

local function listen(unit,state,owners)
    local un=tostring(unit.name or "Android")
    while true do
        local _,d=os.pullEvent("onChatMessage")
        if type(d)=="table" and owners[tostring(d.senderName or "y=s.posY,"):lower()] then
   z=s.posZ}
    local state = {mode="patrol"}
    local owners = loadOwners()
    if not owners then print("Sin owners.") return end

    print("═══ v18 ═══")
    print("FUEL_SLOT="..FUEL_SLOT.." WEAPON_SLOT="..WEAPON_SLOT)
    print("Mano: "..tostring(hand() or "VACÍA"))
    print("═══════════")

    -- Equipar arma al arrancar
    equipWeapon()

    local points = {
        {x=home.x+PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z+PATROL_RADIUS},
        {x=home.x-PATROL_RADIUS,y=home.y,z=home.z},
           local t,c=tostring(d.message or ""):match("^!jarvis%s+(.+)%s+(%S+)$")
            if t and c and (t:lower()=="all" or t:lower()==un:lower()) then
                c=c:lower()
                if c=="hold" then state.mode="hold" android.cancelTask()
                elseif c=="resume" or c=="patrol" then state.mode="patrol"
                elseif c=="return" then state.mode=      {x=home.x,y=home.y,z=home.z-PATROL_RADIUS},
    }
    local np=1
    local lastRefuel=0
    local lastAlert=0
    local lastWep=0

    parallel.waitForAny(
        function()
            while true do
                local self=android.getSelf()
                local task=android.currentTask()
                local now=os.clock()

                if task=="attacking" and lastTarget then
                    if now-attackStart>ATTACK_TIMEOUT then
                        android.cancelTask() task="idle"
                        lastTarget=nil inCombat=false lastCombatEnd=now
                    end
                end

                if self.health and self.hea"return" android.cancelTask()
                elseif c=="status" then
                    local s=android.getSelf() local w=hand()
                    pcall(android.sendChatMessage,un.."|"..state.mode
                        .."|HP="..tostring(s.health)
                        .."|fuel="..tostring(android.fuelLevel())
                        .."|wep="..tostring(w or "—")
                        .."|fuelSlot="..FUEL_SLOT.."|wepSlot="..WEAPON_SLOT)
                elseif c=="dump" then
                    local lines={"MANO:"..tostring(hand() or "—")}
                    for i=0,STASH_SIZE-1 do
                        if occupied(i) then
                         lth<=RETREAT_HEALTH and task~="idle" then
                    android.cancelTask() task="idle"
                    if now-lastAlert>=ALERT_DELAY then
                        pcall(android.sendChatMessage,"HP bajo. Replegando.")
                        lastAlert=now
                    end
                end

                if task~="idle" then sleep(SCAN_DELAY) return end

                local mob,mobType=findMob()
                local wasC=inCombat
                inCombat=(mob~=nil)
                if wasC and not inCombat then lastCombatEnd=now end

                -- Equipar arma (cada 15s si no la tiene)
                if not inCombat and now-lastWep>=15 then
                    local w=hand()
                    if not w or not isWep(   local n=peekSlot(i)
                            lines[#lines+1]="r"..i..":"..tostring(n or "?")
                        else
                            lines[#lines+1]="r"..i..":"
                        end
                    end
                    pcall(android.sendChatMessage,table.concat(lines," "))
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN
-- ═══════════════════════════════════════════════════════════════
local function main()
    local s = android.getSelf()
    local home = {x=s.posX,y=s.posY,z=s.posZ}
    local state = {mode="patrol"}
    local owners = loadOwners()
    if not owners then print("Sin owners.") return end

    -- Verificación inicial (solo 2 ranuras: FUEL_SLOT y WEAPON_SLOT)
    local fn = pew) then
                        equipWeapon()
                    end
                    lastWep=now
                end

                -- Refuel
                local fuel=android.fuelLevel()
                if fuel<REFUEL_AT and now-lastRefuel>=REFUEL_RETRY_DELAY
                    and not inCombat and (now-lastCombatEnd)>=5 then
                    doRefuel()
                    lastRefuel=now
                    fuel=android.fuelLevel()
                end

                -- Lógica
                if fuel<1 then
                    sleep(SCAN_DELAY)
                elseif state.mode=="return" or (self.health and self.health<=RETREAT_HEALTH) then
                    lastTarget=nil
                    android.moveTo(home)
                elseif state.mode=="patrol" then
                    if mob then
                        if lastTarget~=mob.uuid then
                            lastTarget=mob.uuid
                            attackStart=now
                            if now-lastAlert>=ALERT_DELAY then
                                pcall(android.sendChatMessage,"ALERTA: "..mobType)
                                lastAlert=now
                            end
                        end
                        combat(mob)
                    else
                        lastTarget=nil
                        android.moveTo(points[np])
                        np=np%#points+1
                    end
                elseif state.mode=="hold" then
                    lastTarget=nil
                end
                sleep(SCAN_DELAY)
       ekSlot(FUEL_SLOT)
    local wn = peekSlot(WEAPON_SLOT)
    print("═══ v18 ═══")
    print("Mano: "..tostring(hand() or "VACÍA"))
    print("r"..FUEL_SLOT..": "..tostring(fn or "vacía"))
    print("r"..WEAPON_SLOT..": "..tostring(wn or "vacía"))
    if not fn or not isFuel(fn) then
        print("!! Pon REDSTONE en r"..FUEL_SLOT.." !!")
    end
    if not wn or not isWep(wn) then
        print("!! Pon ARMA en r"..WEAPON_SLOT.." !!")
    end
    print("═══════════")

    local points = {
        {x=home.x+PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z+PATROL_RADIUS},
        {x=home.x-PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z-PATROL_RADIUS},
    }
    local np=1

    parallel.waitForAny(
        function()
            while true do
                  end
        end,
        waitStop,
        function() listen(s,state,owners) end
    )
    android.cancelTask()
    print("Detenido.")
end

local ok,err=pcall(main)
if not ok then
    pcall(android.cancelTask)
    print("Error: "..tostring(err))
end   
