-- FUSILERO v23 (completo, solo leftClick)
-- CC:Androids 1.3.0 / Create: Gunsmithing
-- Disparo y recarga con leftClick. No usa attack, useEntity, use ni useItem.
-- ATENCION: no he podido verificar que leftClick dispare el arma NTGL
-- y no haga melee. Prueba primero con !jarvis all test.
--
-- Chat (solo owners):
--   !jarvis all hold | patrol | return | status | test

local SCAN_DELAY     = 0.8
local PATROL_RADIUS  = 8
local REFUEL_AT      = 20
local REFUEL_RETRY   = 15
local STASH_SIZE     = 9
local RETREAT_HEALTH = 6
local ALERT_DELAY    = 10
local FIRE_COOLDOWN  = 1.5   -- segundos entre disparos
local FIRE_HOLD      = 0.3   -- tiempo que se mantiene el clic de disparo
local RELOAD_TIME    = 2.0   -- segundos que dura la recarga
local SHOTS_PER_MAG  = 6     -- disparos antes de recargar (ajustar a tu arma)
local MAX_RANGE      = 18    -- si el mob esta mas lejos, te acercas
local STOP_RANGE     = 10    -- te acercas hasta esta distancia
local OWNERS_FILE    = "owners.cfg"

local FIRE_METHOD    = "leftClick"
local RELOAD_METHOD  = "leftClick"

-- Metodos que nunca se llaman
local FORBIDDEN = {
    attack=true, useEntity=true, use=true, useItem=true, leftClickEntity=true,
}

local CGS_PREFIX = "cgs:"
local CGS_WEAPON_IDS = {
    "cgs:flintlock", "cgs:revolver", "cgs:shotgun", "cgs:nailgun",
    "cgs:gatling", "cgs:blazegun", "cgs:launcher", "cgs:hammer",
    "cgs:frag_grenade",
}

local TARGETS = {
    "minecraft:zombie","minecraft:skeleton","minecraft:spider","minecraft:creeper",
    "minecraft:witch","minecraft:drowned","minecraft:husk","minecraft:stray",
    "minecraft:phantom","minecraft:pillager","minecraft:vindicator","minecraft:evoker",
    "minecraft:ravager","minecraft:cave_spider","minecraft:silverfish","minecraft:blaze",
    "minecraft:ghast","minecraft:magma_cube","minecraft:hoglin","minecraft:zoglin",
    "minecraft:wither_skeleton","minecraft:guardian","minecraft:shulker","minecraft:vex",
    "minecraft:warden","minecraft:endermite","minecraft:slime","minecraft:piglin_brute",
}

local AMMO_WORDS = {
    "round","bullet","cartridge","shell","nail_","rocket","spear","lead_balls","paper_shot",
}

-- nombres visibles (getHandInfo puede devolver "Revolver" en vez de "cgs:revolver")
local ALIASES = {
    {"revolver","revólver"},
    {"shotgun","escopeta"},
    {"gatling"},
    {"nailgun","clavadora"},
    {"flintlock","pistola de chispa","pedernal"},
    {"blazegun"},
    {"launcher","lanzador"},
    {"frag_grenade","frag grenade","granada"},
    {"pneumatic","hammer","martillo"},
}

local lastFire   = 0
local lastErr    = 0
local shotsFired = 0
local lastTarget = nil

-- ---------------------------------------------------------------- utilidades
local function fail(v) return type(v)=="table" and v[1]==true end

local function hasFn(name) return type(android[name])=="function" end

local function hand()
    local ok,n,c=pcall(android.getHandInfo,"main")
    if not ok or type(n)~="string" then return nil,0 end
    local l=n:lower()
    if l=="" or l=="air" or l=="minecraft:air" then return nil,0 end
    return n, tonumber(c) or 0
end

local function isAmmo(n)
    local l=tostring(n):lower()
    for _,w in ipairs(AMMO_WORDS) do
        if l:find(w,1,true) then return true end
    end
    return false
end

-- rango (1 = mejor) si es un arma CGS conocida, o nil
local function weaponRank(n)
    if type(n)~="string" or isAmmo(n) then return nil end
    local l=n:lower()
    for rank,al in ipairs(ALIASES) do
        for _,a in ipairs(al) do
            if l:find(a,1,true) then return rank end
        end
    end
    return nil
end

local function hasItemId(n,id)
    if type(n)~="string" then return false end
    return n:lower():find(id:lower(),1,true)~=nil
end

local function isCgsWeaponName(n)
    if type(n)~="string" or isAmmo(n) then return false end
    if not hasItemId(n,CGS_PREFIX) then return false end
    for _,id in ipairs(CGS_WEAPON_IDS) do
        if hasItemId(n,id) then return true end
    end
    return false
end

local function isFuel(n)
    if type(n)~="string" then return false end
    local l=n:lower()
    if l:find("redstone_torch",1,true) or l:find("redstone torch",1,true) then return false end
    return l:find("redstone",1,true)~=nil
end

local function isHeldWeapon(h)
    return h~=nil and weaponRank(h)~=nil
end

local function isEmpty(n)
    if type(n)~="string" then return true end
    local l=n:lower()
    return l=="" or l=="empty" or l=="air" or l=="minecraft:air"
end

local function scanInventory()
    local inv={}
    for i=0,STASH_SIZE-1 do
        local ok,name,extra=pcall(android.getSlotInfo,i)
        if ok then
            if type(name)=="table" then name=name.name or name.id or name.item
            elseif type(name)=="boolean" and type(extra)=="string" then name=extra end
            inv[#inv+1]={slot=i,name=name,empty=isEmpty(name)}
        end
    end
    return inv
end

local function invSummary(inv)
    local by={}
    for _,it in ipairs(inv) do by[it.slot]=it.empty and "-" or tostring(it.name) end
    local out={}
    for i=0,STASH_SIZE-1 do out[#out+1]="r"..i.."="..tostring(by[i] or "?") end
    return table.concat(out," | ")
end

local function findFree(exclude)
    for _,it in ipairs(scanInventory()) do
        if it.slot~=exclude and it.empty then return it.slot end
    end
end

local function findFuel()
    for _,it in ipairs(scanInventory()) do
        if isFuel(it.name) then return it.slot end
    end
end

local function findWeapon()
    local inv=scanInventory()
    local cgsSlot,cgsRank
    for _,it in ipairs(inv) do
        if isCgsWeaponName(it.name) then
            local r=weaponRank(it.name) or 99
            if not cgsRank or r<cgsRank then cgsSlot,cgsRank=it.slot,r end
        end
    end
    if cgsSlot then return cgsSlot end
    local bs,br
    for _,it in ipairs(inv) do
        local r=weaponRank(it.name)
        if r and (not br or r<br) then bs,br=it.slot,r end
    end
    return bs
end

-- ---------------------------------------------------------------- equipar
local function equipWeapon()
    local h=hand()
    if isHeldWeapon(h) then return true end
    local ws=findWeapon()
    if not ws then return false end

    local tmp
    if h then
        tmp=findFree(ws)
        if not tmp then return false end
        local ok,r=pcall(android.storeItem,tmp)
        if not ok or fail(r) then return false end
    end
    local ok,r=pcall(android.equipSlot,ws)
    if not ok or fail(r) then
        if tmp then pcall(android.equipSlot,tmp) end
        return false
    end
    local nw=hand()
    if isHeldWeapon(nw) then print("Arma: "..nw) return true end
    if nw then pcall(android.storeItem,ws) end
    if tmp then pcall(android.equipSlot,tmp) end
    return false
end

local function doRefuel()
    local held=hand()
    local inHand=held and isFuel(held)
    local fs_
    if not inHand then
        fs_=findFuel()
        if not fs_ then print("Refuel: sin redstone") return end
    end
    local tmp
    if not inHand and held then
        tmp=findFree(fs_)
        if not tmp then return end
        local ok,r=pcall(android.storeItem,tmp)
        if not ok or fail(r) then return end
    end
    if not inHand then
        local ok,r=pcall(android.equipSlot,fs_)
        if not ok or fail(r) then
            if tmp then pcall(android.equipSlot,tmp) end
            return
        end
        local n=hand()
        if not n or not isFuel(n) then
            if n then pcall(android.storeItem,fs_) end
            if tmp then pcall(android.equipSlot,tmp) end
            return
        end
    end
    local before=android.fuelLevel()
    pcall(android.refuel,1)
    local after=android.fuelLevel()
    if not inHand and hand() then pcall(android.storeItem,fs_) end
    if tmp then pcall(android.equipSlot,tmp) end
    print("Fuel: "..tostring(before).." -> "..tostring(after))
end

-- ---------------------------------------------------------------- mobs
local function dist(s,m)
    local dx,dy,dz=m.posX-s.posX,m.posY-s.posY,m.posZ-s.posZ
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end

local function findMob()
    local s=android.getSelf()
    local best,bestType,bestD
    local ok,near=pcall(android.getNearbyMobs)
    if ok and type(near)=="table" then
        for _,m in pairs(near) do
            if type(m)=="table" and m.uuid and m.posX and m.posY and m.posZ then
                local label=tostring(m.name or m.type or ""):lower()
                for _,t in ipairs(TARGETS) do
                    local short=t:gsub("^[^:]+:","")
                    if label:find(t,1,true) or label:find(short,1,true) then
                        local d=dist(s,m)
                        if not bestD or d<bestD then best,bestType,bestD=m,t,d end
                        break
                    end
                end
            end
        end
    end
    return best,bestType
end

-- ---------------------------------------------------------------- disparo
local function aim(mob)
    if hasFn("lookAt") then
        if not pcall(android.lookAt,mob.uuid) then
            pcall(android.lookAt,{x=mob.posX,y=mob.posY+1,z=mob.posZ})
        end
    end
end

-- mantiene leftClick durante "hold" segundos y luego suelta
local function click(method,hold)
    if FORBIDDEN[method] or not hasFn(method) then
        return false,"metodo no disponible: "..tostring(method)
    end
    local ok,r=pcall(android[method])
    sleep(hold)
    pcall(android.cancelTask)
    if not ok then return false,tostring(r) end
    if fail(r) then return false,tostring(r[2]) end
    return true
end

local function reload()
    print("Recargando con "..RELOAD_METHOD.."...")
    local ok,err=click(RELOAD_METHOD,RELOAD_TIME)
    if ok then
        shotsFired=0
        print("Recarga lista")
    else
        print("Recarga fallida: "..tostring(err))
    end
    return ok
end

local function combat(mob)
    if not equipWeapon() then
        if os.clock()-lastErr>5 then
            print("Sin arma CGS equipable. Mano="..tostring(hand() or "VACIA"))
            lastErr=os.clock()
        end
        return false
    end

    local s=android.getSelf()
    local d=dist(s,mob)
    if d>MAX_RANGE then
        local f=(d-STOP_RANGE)/d
        pcall(android.moveTo,{
            x=s.posX+(mob.posX-s.posX)*f,
            y=s.posY+(mob.posY-s.posY)*f,
            z=s.posZ+(mob.posZ-s.posZ)*f,
        })
        return true
    end

    if shotsFired>=SHOTS_PER_MAG then
        reload()
        return true
    end

    local now=os.clock()
    if now-lastFire<FIRE_COOLDOWN then return true end

    aim(mob)
    lastFire=os.clock()
    local ok,err=click(FIRE_METHOD,FIRE_HOLD)
    if ok then
        shotsFired=shotsFired+1
    elseif os.clock()-lastErr>5 then
        print("Disparo fallido ("..FIRE_METHOD.."): "..tostring(err))
        lastErr=os.clock()
    end
    return ok
end

-- ---------------------------------------------------------------- owners / chat
local function parseOwners(input)
    local o,names={},{}
    for p in tostring(input):gmatch("[^,\n]+") do
        local n=p:match("^%s*(.-)%s*$")
        if n~="" and not o[n:lower()] then
            o[n:lower()]=true
            names[#names+1]=n
        end
    end
    return o,names
end

local function loadOwners()
    if fs.exists(OWNERS_FILE) then
        local f=fs.open(OWNERS_FILE,"r")
        if not f then return nil end
        local o,n=parseOwners(f.readAll())
        f.close()
        if #n==0 then return nil end
        return o
    end
    print("Jugadores (separados por comas):")
    local o,n=parseOwners(read())
    while #n==0 do
        print("Escribe un nombre:")
        o,n=parseOwners(read())
    end
    local f=fs.open(OWNERS_FILE,"w")
    if not f then return nil end
    f.write(table.concat(n,"\n").."\n")
    f.close()
    return o
end

local function waitStop()
    while true do
        local _,k=os.pullEvent("key")
        if k==keys.q then return end
    end
end

local function listen(unit,state,owners)
    local un=tostring(unit.name or "Android")
    while true do
        local _,d=os.pullEvent("onChatMessage")
        if type(d)=="table" and owners[tostring(d.senderName or ""):lower()] then
            local t,c=tostring(d.message or ""):match("^!jarvis%s+(%S+)%s+(%S+)")
            if t and (t:lower()=="all" or t:lower()==un:lower()) then
                c=c:lower()
                if c=="hold" then
                    state.mode="hold"
                    pcall(android.cancelTask)
                elseif c=="resume" or c=="patrol" then
                    state.mode="patrol"
                elseif c=="return" then
                    state.mode="return"
                    pcall(android.cancelTask)
                elseif c=="test" then
                    state.testShot=true
                elseif c=="status" then
                    local s=android.getSelf()
                    pcall(android.sendChatMessage,un.."|"..state.mode
                        .."|HP="..tostring(s.health)
                        .."|fuel="..tostring(android.fuelLevel())
                        .."|wep="..tostring(hand() or "-")
                        .."|shots="..tostring(shotsFired))
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- main
local function main()
    local s=android.getSelf()
    local home={x=s.posX,y=s.posY,z=s.posZ}
    local state={mode="patrol"}
    local owners=loadOwners()
    if not owners then print("Sin owners.") return end

    if hasFn(FIRE_METHOD) then
        print("Disparo y recarga: "..FIRE_METHOD)
    else
        print("ERROR: "..FIRE_METHOD.." no existe en esta version")
        return
    end
    print("Inventario: "..invSummary(scanInventory()))
    print("Pulsa Q para detener")
    equipWeapon()

    local points={
        {x=home.x+PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z+PATROL_RADIUS},
        {x=home.x-PATROL_RADIUS,y=home.y,z=home.z},
        {x=home.x,y=home.y,z=home.z-PATROL_RADIUS},
    }
    local np,lastRefuel,lastAlert=1,0,0

    parallel.waitForAny(
        function()
            while true do
                local self=android.getSelf()
                local task=android.currentTask()
                local now=os.clock()

                if self.health and self.health<=RETREAT_HEALTH and task~="idle" then
                    pcall(android.cancelTask)
                    task="idle"
                    if now-lastAlert>=ALERT_DELAY then
                        pcall(android.sendChatMessage,"HP bajo. Replegando.")
                        lastAlert=now
                    end
                end

                if task~="idle" then
                    sleep(SCAN_DELAY)
                else
                    local mob,mobType=findMob()
                    local fuel=android.fuelLevel()
                    if fuel<REFUEL_AT and now-lastRefuel>=REFUEL_RETRY then
                        doRefuel()
                        lastRefuel=now
                        fuel=android.fuelLevel()
                    end

                    if state.testShot then
                        state.testShot=false
                        if mob then
                            if equipWeapon() then
                                aim(mob)
                                local ok,err=click(FIRE_METHOD,FIRE_HOLD)
                                print("TEST "..FIRE_METHOD..": "..tostring(ok)..(ok and "" or (" "..tostring(err))))
                            else
                                print("TEST: no hay arma CGS")
                            end
                        else
                            print("TEST: no hay mob cerca")
                        end
                    elseif fuel<1 then
                        -- sin combustible
                    elseif state.mode=="return" or (self.health and self.health<=RETREAT_HEALTH) then
                        lastTarget=nil
                        pcall(android.moveTo,home)
                    elseif state.mode=="patrol" then
                        if mob then
                            if lastTarget~=mob.uuid then
                                lastTarget=mob.uuid
                                if now-lastAlert>=ALERT_DELAY then
                                    pcall(android.sendChatMessage,"ALERTA: "..tostring(mobType))
                                    lastAlert=now
                                end
                            end
                            combat(mob)
                        else
                            lastTarget=nil
                            pcall(android.moveTo,points[np])
                            np=np%#points+1
                        end
                    end
                end
                sleep
