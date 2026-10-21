-- ═══════════════════════════════════════════════════════════════
-- FUSILERO v17 FINAL
-- CC:Androids 1.3.0 / Forge 1.20.1 / NTGL 3.1.2
-- Left=disparo+recarga | Right=apuntar
-- Escaneo: equipSlot directo (no depende de getSlotInfo)
-- Enter detiene.
-- ═══════════════════════════════════════════════════════════════

local SCAN_DELAY = 0.8
local PATROL_RADIUS = 8
local REFUEL_AT = 20
local REFUEL_RETRY_DELAY = 15
local STASH_SIZE = 11
local RETREAT_HEALTH = 6
local ALERT_DELAY = 10
local ATTACK_TIMEOUT = 15
local FIRE_COOLDOWN = 0.5
local AIM_BEFORE_SHOT = true
local AIM_DELAY = 0.3
local COMBAT_RANGE_SQ = 14*14
local MIN_RANGE_SQ = 4*4
local OWNERS_FILE = "owners.cfg"

-- ═══════════════════════════════════════════════════════════════
-- ITEMS
-- ═══════════════════════════════════════════════════════════════
local WEAPONS = {
    "cgs:flintlock","cgs:revolver","cgs:shotgun","cgs:nailgun",
    "cgs:gatling","cgs:blazegun","cgs:launcher",
    "cgs:pneumatic_hammer","cgs:frag_grenade",
    "cbc:ballistic_pistol","cbc:ballistic_carbine",
    "cbc:ballistic_shotgun","cbc:ballistic_sniper",
    "cbc:ballistic_gatling","cbc:ballistic_grenade_launcher",
    "cbc:ballistic_minigun","cbc:ballistic_cannon",
}

local WEAPON_NAMES = {
    "flintlock","revolver","shotgun","nailgun","gatling",
    "blazegun","launcher","pneumatic hammer","frag grenade",
    "ballistic pistol","ballistic carbine","ballistic shotgun",
    "ballistic sniper","ballistic gatling","ballistic minigun",
    "ballistic grenade launcher","ballistic cannon",
}

local AMMO_IDS = {
    "cgs:flintlock_bullet","cgs:revolver_round","cgs:shotgun_round",
    "cgs:nail","cgs:gatling_round","cgs:piercing_revolver_round",
    "cgs:incendiary_shotgun_round","cgs:paper_cartridge","cgs:paper_shot",
    "cgs:round_revolver","cgs:round_revolver_piercing","cgs:round_revolver_blank",
    "cgs:round_shotgun","cgs:round_shotgun_flechette",
    "cgs:round_shotgun_flechette_steel","cgs:round_shotgun_incendiary",
    "cgs:round_shotgun_blank","cgs:round_gatling","cgs:round_gatling_piercing",
    "cgs:round_gatling_blank","cgs:nail_steel","cgs:rocket",
    "cgs:rocket_small","cgs:spear","cgs:lead_balls",
    "cgs:shell_gatling","cgs:shell_revolver","cgs:shell_shotgun",
    "cbc:ballistic_pistol_round","cbc:ballistic_carbine_round",
    "cbc:ballistic_shotgun_shell","cbc:ballistic_sniper_round",
    "cbc:ballistic_gatling_round","cbc:ballistic_grenade",
    "cbc:ballistic_minigun_round","cbc:cannon_shot",
}

local FOOD_IDS = {
    "minecraft:cooked_beef","minecraft:cooked_porkchop",
    "minecraft:cooked_chicken","minecraft:cooked_mutton",
    "minecraft:golden_carrot","minecraft:golden_apple",
    "minecraft:bread","minecraft:cooked_cod","minecraft:cooked_salmon",
}

local POTION_IDS = {"minecraft:potion","minecraft:splash_potion"}

local TARGETS = {
    "minecraft:zombie","minecraft:skeleton","minecraft:spider",
    "minecraft:creeper","minecraft:witch","minecraft:drowned",
    "minecraft:husk","minecraft:stray","minecraft:phantom",
    "minecraft:pillager","minecraft:vindicator","minecraft:evoker",
    "minecraft:ravager","minecraft:cave_spider","minecraft:silverfish",
    "minecraft:blaze","minecraft:ghast","minecraft:magma_cube",
    "minecraft:hoglin","minecraft:zoglin","minecraft:wither_skeleton",
    "minecraft:guardian","minecraft:shulker","minecraft:vex",
    "minecraft:warden","minecraft:endermite","minecraft:slime",
    "minecraft:piglin_brute",
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
    "vampirism:vampire","vampirism:ghoul","werewolves:werewolf",
}

-- ═══════════════════════════════════════════════════════════════
-- ESTADO
-- ═══════════════════════════════════════════════════════════════
local lastFire = 0
local lastTarget = nil
local inCombat = false
local lastCombatEnd = 0
local attackStart = 0
local fuelSlot = nil
local weaponSlot = nil
local lastScan = 0
local SCAN_INTERVAL = 15

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function fail(v) return type(v)=="table" and v[1]==true end

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
    if l:find("redstone torch",1,true) then return false end
    if l:find("redstone_torch",1,true) then return false end
    return l:find("redstone",1,true)~=nil
end

local function isFood(n)
    if type(n)~="string" then return false end
    local l=n:lower()
    for _,i in ipairs(FOOD_IDS) do if l:find(i,1,true) then return true end end
    return false
end

local function isPot(n)
    if type(n)~="string" then return false end
    local l=n:lower()
    for _,i in ipairs(POTION_IDS) do if l:find(i,1,true) then return true end end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- ESCANEO: equipSlot directo en cada ranura
-- ═══════════════════════════════════════════════════════════════
local function scan()
    local h = hand()
    local saved = nil
    if h then
        for i=0,STASH_SIZE-1 do
            local ok,r = pcall(android.equipSlot,i)
            if ok and not fail(r) then
                pcall(android.storeItem,i)
            else
                saved = i
                break
            end
        end
        if not saved then return end
        pcall(android.storeItem,saved)
    end

    fuelSlot = nil
    weaponSlot = nil

    for i=0,STASH_SIZE-1 do
        local ok,r = pcall(android.equipSlot,i)
        if ok and not fail(r) then
            local n = hand()
            if n then
                if isFuel(n) and not fuelSlot then fuelSlot = i end
                if isWep(n) and not weaponSlot then weaponSlot = i end
                pcall(android.storeItem,i)
            end
        end
    end

    if saved then
        local h2 = hand()
        if not h2 then
            pcall(android.equipSlot,saved)
        else
            for i=0,STASH_SIZE-1 do
                if i~=saved then
                    local ok,r = pcall(android.equipSlot,i)
                    if ok and not fail(r) then
                        pcall(android.storeItem,i)
                    else
                        pcall(android.storeItem,i)
                        pcall(android.equipSlot,saved)
                        break
                    end
                end
            end
        end
    end
    lastScan = os.clock()
end

local function ensureScan()
    if os.clock() - lastScan >= SCAN_INTERVAL then
        scan()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- EQUIPAR ARMA
-- ═══════════════════════════════════════════════════════════════
local function equipWeapon()
    local h = hand()
    if h and isWep(h) then return true end

    ensureScan()
    if not weaponSlot then
        scan()
        if not weaponSlot then
            print("SIN ARMA EN STASH. fuelSlot="..tostring(fuelSlot))
            return false
        end
    end

    local h2 = hand()
    local tmp
    if h2 then
        for i=0,STASH_SIZE-1 do
            if i~=weaponSlot then
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

    local ok,r = pcall(android.equipSlot,weaponSlot)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return false
    end

    local nw = hand()
    if nw and isWep(nw) then
        print("Arma: "..nw)
        weaponSlot = nil
        return true
    end
    if nw then pcall(android.storeItem,weaponSlot) end
    if tmp then pcall(android.equipSlot,tmp) end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- REFUEL
-- ═══════════════════════════════════════════════════════════════
local function doRefuel()
    if inCombat then return end
    if os.clock()-lastCombatEnd < 5 then return end

    ensureScan()
    if not fuelSlot then
        scan()
        if not fuelSlot then
            print("REFUEL: sin redstone en stash.")
            return
        end
    end

    local h = hand()
    local tmp
    if h then
        for i=0,STASH_SIZE-1 do
            if i~=fuelSlot then
                local ok,r = pcall(android.equipSlot,i)
                if ok and not fail(r) then
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

    local ok,r = pcall(android.equipSlot,fuelSlot)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return
    end

    local n = hand()
    if not n or not isFuel(n) then
        if n then pcall(android.storeItem,fuelSlot) end
        if tmp then pcall(android.equipSlot,tmp) end
        print("REFUEL: r"..fuelSlot.." no es redstone: "..tostring(n))
        return
    end

    local before = android.fuelLevel()
    pcall(android.refuel,1)
    local after = android.fuelLevel()

    local rem = hand()
    if rem then pcall(android.storeItem,fuelSlot) end
    if tmp then pcall(android.equipSlot,tmp) end

    if after > before then
        print("Fuel → "..tostring(after))
    else
        print("Refuel no funcionó.")
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
        if ok and not fail(r) then
            lastFire = now
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CONTROL
-- ═══════════════════════════════════════════════════════════════
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
        if type(d)=="table" and owners[tostring(d.senderName or ""):lower()] then
            local t,c=tostring(d.message or ""):match("^!jarvis%s+(.+)%s+(%S+)$")
            if t and c and (t:lower()=="all" or t:lower()==un:lower()) then
                c=c:lower()
                if c=="hold" then state.mode="hold" android.cancelTask()
                elseif c=="resume" or c=="patrol" then state.mode="patrol"
                elseif c=="return" then state.mode="return" android.cancelTask()
                elseif c=="status" then
                    local s=android.getSelf() local w=hand()
                    pcall(android.sendChatMessage,un.."|"..state.mode
                        .."|HP="..tostring(s.health)
                        .."|fuel="..tostring(android.fuelLevel())
                        .."|wep="..tostring(w or "—")
                        .."|combat="..tostring(inCombat))
                elseif c=="rescan" then
                    scan()
                    pcall(android.sendChatMessage,"Rescan: fuel="..tostring(fuelSlot).." wep="..tostring(weaponSlot))
                elseif c=="dump" then
                    local lines={"MANO:"..tostring(hand() or "—")}
                    for i=0,STASH_SIZE-1 do
                        local ok,r=pcall(android.equipSlot,i)
                        if ok and not fail(r) then
                            local n=hand()
                            lines[#lines+1]="r"..i..":"..tostring(n or "?")
                            pcall(android.storeItem,i)
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
-- BUCLE
-- ═══════════════════════════════════════════════════════════════
local function main()
    local s = android.getSelf()
    local home = {x=s.posX,y=s.posY,z=s.posZ}
    local state = {mode="patrol"}
    local owners = loadOwners()
    if not owners then print("Sin owners.") return end

    -- Escaneo inicial
    scan()
    print("═══ v17 ═══")
    print("Mano: "..tostring(hand() or "VACÍA"))
    print("fuelSlot="..tostring(fuelSlot).." weaponSlot="..tostring(weaponSlot))
    print("═══════════")

    local points = {
        {x=home.x+PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z+PATROL_RADIUS},
        {x=home.x-PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z-PATROL_RADIUS},
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

                -- Timeout
                if task=="attacking" and lastTarget then
                    if now-attackStart>ATTACK_TIMEOUT then
                        android.cancelTask() task="idle"
                        lastTarget=nil inCombat=false lastCombatEnd=now
                    end
                end

                -- Retirada
                if self.health and self.health<=RETREAT_HEALTH and task~="idle" then
                    android.cancelTask() task="idle"
                    if now-lastAlert>=ALERT_DELAY then
                        pcall(android.sendChatMessage,"HP bajo. Replegando.")
                        lastAlert=now
                    end
                end

                if task~="idle" then sleep(SCAN_DELAY) return end

                -- Detectar combate
                local mob,mobType=findMob()
                local wasC=inCombat
                inCombat=(mob~=nil)
                if wasC and not inCombat then lastCombatEnd=now end

                -- Arma (cada 15s)
                if not inCombat and now-lastWep>=15 then
                    equipWeapon()
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
