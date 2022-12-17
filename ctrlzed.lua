local heroes = false
local checkCount = 0
local menu = 1
local Orb
local _OnWaypoint = {}
local _OnVision = {}
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local spellcast = {state = 1, mouse = mousePos}
local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6, [ITEM_7] = HK_ITEM_7,}
local barHeight, barWidth, barXOffset, barYOffset = 8, 103, 0, 0
local Allies, Enemies, Turrets, Units = {}, {}, {}, {}
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300
local charging = false
local wClock = 0
local clock = os.clock
local Latency = Game.Latency
local ping = Latency() * 0.001
local MyHeroRange = myHero.range + myHero.boundingRadius * 2
local DrawCircle = Draw.Circle
local DrawColor = Draw.Color
local DrawText = Draw.Text
local ControlCastSpell = Control.CastSpell
local GameCanUseSpell = Game.CanUseSpell
local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameObjectCount = Game.ObjectCount
local GameObject = Game.Object
local GameParticleCount = Game.ParticleCount
local GameParticle = Game.Particle
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile
local GameIsChatOpen = Game.IsChatOpen
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300
local MathSqrt = math.sqrt
local MathHuge = math.huge
local TableInsert = table.insert
local TableRemove = table.remove
--_G.LATENCY = 0.05
local werror=0

function LoadUnits()
	for i = 1, GameHeroCount() do
		local unit = GameHero(i); Units[i] = {unit = unit, spell = nil}
		if unit.team ~= myHero.team then TableInsert(Enemies, unit)
		elseif unit.team == myHero.team and unit ~= myHero then TableInsert(Allies, unit) end
	end
	for i = 1, GameTurretCount() do
		local turret = GameTurret(i)
		if turret and turret.isEnemy then TableInsert(Turrets, turret) end
	end
end

local function CheckLoadedEnemyies()
	local count = 0
	for i, unit in ipairs(Enemies) do
        if unit and unit.isEnemy then
		count = count + 1
		end
	end
	return count
end

local function ConvertToHitChance(menuValue, hitChance)
    return menuValue == 1 and _G.PremiumPrediction.HitChance.High(hitChance)
    or menuValue == 2 and _G.PremiumPrediction.HitChance.VeryHigh(hitChance)
    or _G.PremiumPrediction.HitChance.Immobile(hitChance)
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and GameCanUseSpell(spell) == 0
end

function GetMode()
    if Orb == 1 then
        if combo == 1 then
            return 'Combo'
        elseif harass == 2 then
            return 'Harass'
        elseif lastHit == 3 then
            return 'Lasthit'
        elseif laneClear == 4 then
            return 'Clear'
        end
    elseif Orb == 2 then
		if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			return "Combo"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			return "Harass"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
			return "Clear"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
			return "LastHit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		end
    elseif Orb == 3 then
        return GOS:GetMode()
    elseif Orb == 4 then
        return _G.gsoSDK.Orbwalker:GetMode()
	elseif Orb == 5 then
	  return _G.PremiumOrbwalker:GetMode()
	end

    if _G.SDK then
        return
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
        or
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
        or
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "Clear"
        or
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "Clear"
        or
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
        or
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or nil

	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetMode()
	end
	return nil
end

function GetTarget(range)
	if Orb == 1 then
		if myHero.ap > myHero.totalDamage then
			return EOW:GetTarget(range, EOW.ap_dec, myHero.pos)
		else
			return EOW:GetTarget(range, EOW.ad_dec, myHero.pos)
		end
	elseif Orb == 2 and TargetSelector then
		if myHero.ap > myHero.totalDamage then
			return TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
		else
			return TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
		end
	elseif _G.GOS then
		if myHero.ap > myHero.totalDamage then
			return GOS:GetTarget(range, "AP")
		else
			return GOS:GetTarget(range, "AD")
        end
    elseif _G.gsoSDK then
		return _G.gsoSDK.TS:GetTarget()

	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetTarget(range)
	end

	if _G.SDK then
		if myHero.ap > myHero.totalDamage then
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
		else
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
		end
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetTarget(range)
	end
end

local function SetAttack(bool)
	if _G.EOWLoaded then
		EOW:SetAttacks(bool)
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetAttack(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetAttack(bool)
	else
		GOS.BlockAttack = not bool
	end

end

local function SetMovement(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetMovement(bool)
	else
		GOS.BlockMovement = not bool
	end
end

local function GetDistanceSqr(p1, p2)
	if not p1 then return MathHuge end
	p2 = p2 or myHero
	local dx = p1.x - p2.x
	local dz = (p1.z or p1.y) - (p2.z or p2.y)
	return dx*dx + dz*dz
end

local function GetDistance(p1, p2)
	p2 = p2 or myHero
	return MathSqrt(GetDistanceSqr(p1, p2))
end

local function GetDistance2D(p1,p2)
	return MathSqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

local function IsRecalling(unit)
	for i = 1, 63 do
	local buff = unit:GetBuff(i)
		if buff.count > 0 and buff.name == "recall" and Game.Timer() < buff.expireTime then
			return true
		end
	end
	return false
end

local function MyHeroNotReady()
    return myHero.dead or GameIsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or IsRecalling(myHero)
end

--[[
local currSpell = myHero.activeSpell
if currSpell and currSpell.valid and myHero.isChanneling then
print ("Width:  "..myHero.activeSpell.width)
print ("Speed:  "..myHero.activeSpell.speed)
print ("Delay:  "..myHero.activeSpell.animation)
print ("range:  "..myHero.activeSpell.range)
print ("Name:  "..myHero.activeSpell.name)
end
]]
--[[
for i = 0, myHero.buffCount do
	local buff = myHero:GetBuff(i)
	if buff.name == "" then
	--print(buff.name)
		print("Typ:  "..buff.type)
		print("Name:  "..buff.name)
		print("Start:  "..buff.startTime)
		print("Expire:  "..buff.expireTime)
		print("Dura:  "..buff.duration)
		print("Stacks:  "..buff.stacks)
		print("Count:  "..buff.count)
		print("Id:  "..buff.sourcenID)
		print("SouceName:  "..buff.sourceName)
	end
end
]]
local IsLoaded = false
Callback.Add("Tick", function()
	if heroes == false then
		local EnemyCount = CheckLoadedEnemyies()
		if EnemyCount < 1 then
			LoadUnits()
		else
			heroes = true
		end
	else
		if not IsLoaded then
			LoadScript()
			DelayAction(function()
				if not Menu.Pred then return end
				if Menu.Pred.Change:Value() == 1 then
					require('GamsteronPrediction')
				elseif Menu.Pred.Change:Value() == 2 then
					require('PremiumPrediction')
				else
					require('GGPrediction')
				end
			end, 1)
			IsLoaded = true
		end
	end
end)

local DrawTime = false
Callback.Add("Draw", function()
	if heroes == false then
		Draw.Text(myHero.charName.." is Loading !!", 24, myHero.pos2D.x - 50, myHero.pos2D.y + 195, Draw.Color(255, 255, 0, 0))
	else
		if not DrawTime then
			Draw.Text(myHero.charName.." is Ready !!", 24, myHero.pos2D.x - 50, myHero.pos2D.y + 195, Draw.Color(255, 0, 255, 0))
			DelayAction(function()
			DrawTime = true
			end, 4.0)
		end
	end
end)
local function GetEnemyHeroes()
	local _EnemyHeroes = {}
	for i = 1, GameHeroCount() do
		local unit = GameHero(i)
		if unit.team ~= myHero.team then
			TableInsert(_EnemyHeroes, unit)
		end
	end
	return _EnemyHeroes
end

local function GetEnemyHeroesinrange(range)
	local _EnemyHeroes = {}
	for i = 1, GameHeroCount() do
		local unit = GameHero(i)
		local Range = range * range
		if unit.team ~= myHero.team and GetDistanceSqr(myHero.pos,unit.pos)<Range then
			TableInsert(_EnemyHeroes, unit)
		end
	end
	return _EnemyHeroes
end

local function GetTarget2(unit)
	return _G.SDK.TargetSelector:GetTarget(unit, 1)

end

local function GetAllyHeroes() 
	local _AllyHeroes = {}
	for i = 1, GameHeroCount() do
		local unit = GameHero(i)
		if unit.isAlly and not unit.isMe then
			TableInsert(_AllyHeroes, unit)
		end
	end
	return _AllyHeroes
end

local function GetEnemyCount(range, pos)
	local count = 0
	for i, hero in ipairs(GetEnemyHeroes()) do
	local Range = range * range
		if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

local function IsUnderTurret(unit, radius)
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        local Bradius = radius or unit.boundingRadius / 2
		local range = (turret.boundingRadius + 750 + Bradius)
        if turret.isEnemy and not turret.dead then
            if turret.pos:DistanceTo(unit.pos) < range then
                return true
            end
        end
    end
    return false
end

local function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

local function GetEnergy()
	local currentEnergyNeeded = 0
	
	if Ready(_Q) then
		currentEnergyNeeded = currentEnergyNeeded + myHero:GetSpellData(_Q).mana
	end
	if Ready(_W) then
		currentEnergyNeeded = currentEnergyNeeded + myHero:GetSpellData(_W).mana
	end
	if Ready(_E) then
		currentEnergyNeeded = currentEnergyNeeded + myHero:GetSpellData(_E).mana
	end
	return currentEnergyNeeded
end



local function GetDamage(spell)
	local damage = 0
	local AD = myHero.bonusDamage
	
	if spell == HK_Q then
		if GameCanUseSpell(_Q) == 0 then
			damage = damage + ((myHero:GetSpellData(_Q).level * 35 + 45) + 1.1*AD)
			if Ready(_W) then
				damage=damage*2
			end
		end
	elseif spell == HK_E then
		if GameCanUseSpell(_E) == 0 then
			damage = damage + ((myHero:GetSpellData(_E).level * 20 + 50) + AD * 0.65)
		end
	elseif spell == HK_R then
		if GameCanUseSpell(_R) == 0 then
			damage = damage + myHero.totalDamage * 0.65
		end
	elseif spell == "Elec" then
		local baseDmg = 30+(150/(17*(myHero.levelData.lvl)))
		local bonusDmg = (myHero.ap * 0.25)+(myHero.bonusDamage*0.4)
		local value = baseDmg + bonusDmg 
		--print("aery",value)
		damage = value
	elseif spell == "q2" then
		damage = damage + ((myHero:GetSpellData(_Q).level * 35 + 45) + 1.1*AD)*0.6
	elseif spell == Ignite then
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and GameCanUseSpell(SUMMONER_1) == 0 then
			damage = damage +  (50 + 20 * myHero.levelData.lvl)
		elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and GameCanUseSpell(SUMMONER_2) == 0 then
			damage = damage +  (50 + 20 * myHero.levelData.lvl)
		end	
	end
	return damage
end

local function OnProcessSpell()
	for i = 1, #Units do
		local unit = Units[i].unit; local last = Units[i].spell; local spell = unit.activeSpell
		if spell and last ~= (spell.name .. spell.endTime) and unit.activeSpell.isChanneling then
			Units[i].spell = spell.name .. spell.endTime; return unit, spell
		end
	end
	return nil, nil
end

local DamageLib         = _G.SDK.Damage

local Rtarget 		= 	{}
local R1casted 		= 	false
local SpellsLoaded 	= 	false 
local Qdmg 			= 	0
local Wshadow 		= 	nil
local Rshadow 		= 	nil
local QEKillable 	= 	false
local UltKillable 	= 	false
local WTime = 0
local RTime = 0
local W2Time = 0
local laststate=0
function LoadScript()
	--OnProcessSpell()
	Menu = MenuElement({type = MENU, id = "ctrlczed".. myHero.charName, name = myHero.charName})
	Menu:MenuElement({name = " ", drop = {"Version 1.0"}})			
	
	--ComboMenu  
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.Combo:MenuElement({id = "QKey", name = "[Q] semimanual cast key", value = false, toggle=false,key=string.byte("S") })
	Menu.Combo:MenuElement({id = "WKey", name = "[W] semimanual cast at target key", value = false, toggle=false,key=string.byte("A") })
	Menu.Combo:MenuElement({id = "SaveQ", name = "smart save [Q] for hitting max shureikins ", value = false, toggle=true,key=string.byte("Capslock")})
	Menu.Combo:MenuElement({id = "UseW", name = "[W]", value = false})
	Menu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})
	Menu.Combo:MenuElement({id = "Change", name = "[E] Logic", value = 2, drop = {"Auto [E]", "ComboKey [E]"}})	
	
	Menu:MenuElement({type = MENU, id = "Lasthit", name = "Farm"})
	Menu.Lasthit:MenuElement({id = "UseQ", name = "[Q] lasthit", value = true})
	--UltSettings
	Menu.Combo:MenuElement({type = MENU, id = "Ult", name = "Ultimate Settings"})
	Menu.Combo.Ult:MenuElement({id = "UseR", name = "All Ult Option On/Off", value = false})	
	Menu.Combo.Ult:MenuElement({name = " ", drop = {"Ult-Logic: Calc. completely possible Dmg"}})	
	Menu.Combo.Ult:MenuElement({id = "IGN", name = "Use Ignite for KS and active Ult", value = false})			
	Menu.Combo.Ult:MenuElement({id = "UseRTower", name = "Kill[R] Dive under Tower", value = false})
	Menu.Combo.Ult:MenuElement({id = "UseW1", name = "W1 to get in range", value = false})	
	Menu.Combo.Ult:MenuElement({id = "UseR2", name = "[R2]or[W2] Back after donate deathmark", value = false})	
	Menu.Combo.Ult:MenuElement({id = "UseRBack", name = "[R2]Back if Zed Hp low", value = false})
	Menu.Combo.Ult:MenuElement({id = "Hp", name = "[R2]Back if Zed Hp lower than -->", value = 15, min = 0, max = 100, identifier = "%"})	

	--HarassMenu
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})	
	Menu.Harass:MenuElement({id = "UseQ", name = "[Q]", value = true})	
	Menu.Harass:MenuElement({id = "UseW", name = "[W1]", value = true})	
	Menu.Harass:MenuElement({id = "UseE", name = "[E]", value = true})	
	Menu.Harass:MenuElement({id = "Change", name = "[E] Logic", value = 2, drop = {"Auto [E]", "HarassKey [E]"}})	
	Menu.Harass:MenuElement({id = "Mana", name = "Min Energy to Harass", value = 40, min = 0, max = 100, identifier = "%"})

	--KillSteal
	Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
	Menu.ks:MenuElement({id = "UseQE", name = "KS: [W1]>[E]>[Q]", value = true})

	Menu:MenuElement({type = MENU, id = "spells", name = "Evade"})
	Menu.spells:MenuElement({id = "wblock", name = "Evade[W] MousePos", value =false})		
	Menu.spells:MenuElement({id = "rblock", name = "Evade[R] if not ready [W]", value = false})
	for i, enemy in ipairs(GetEnemyHeroes()) do
		Menu.spells:MenuElement({type = MENU, id = enemy.charName, name = enemy.charName})	
	end	
	
	--Prediction
	Menu:MenuElement({type = MENU, id = "Pred", name = "Prediction"})
	Menu.Pred:MenuElement({name = " ", drop = {"After change Prediction Typ press 2xF6"}})	
	Menu.Pred:MenuElement({id = "Change", name = "Change Prediction Typ", value = 3, drop = {"Gamsteron Prediction", "Premium Prediction", "GGPrediction"}})	
	Menu.Pred:MenuElement({id = "PredQ", name = "Hitchance[Q]", value = 1, drop = {"Normal", "High", "Immobile"}})	
	Menu.Pred:MenuElement({id = "PredW", name = "Hitchance[W]", value = 1, drop = {"Normal", "High", "Immobile"}})	

	--Drawing 
	Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
	Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
	Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = true})	
	Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
	Menu.Drawing:MenuElement({id = "KillText", name = "Draw Kill Text onScreen/Minimap", value = true})	


	QData ={Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 55, Range = 900, Speed = 900,  Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}
	}
	
	QspellData = {speed = 900, range = 900, delay = 0.25, radius = 55, type = "linear",  collision = {"minion"}
	}
	
	WData ={
	Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 290, Range = 900, Speed = 2500, Collision = false
	}
	
	WspellData = {speed = 2500, range = 900, delay = 0.25, radius = 290, type = "linear", collision = {nil}
	}	

	Callback.Add("Tick", function() Tick() end)
	Callback.Add("Draw", function() Drawing() end)	
end

function LoadBlockSpells()
	for i, t in ipairs(GetEnemyHeroes()) do
		if t then		
			for slot = 0, 3 do
			local enemy = t
			local spellName = enemy:GetSpellData(slot).name
				if slot == 0 and Menu.spells[enemy.charName] then
					Menu.spells[enemy.charName]:MenuElement({ id = spellName, name = "Block [Q]", value = false })
				end
				if slot == 1 and Menu.spells[enemy.charName] then
					Menu.spells[enemy.charName]:MenuElement({ id = spellName, name = "Block [W]", value = false })
				end
				if slot == 2 and Menu.spells[enemy.charName] then
					Menu.spells[enemy.charName]:MenuElement({ id = spellName, name = "Block [E]", value = false })
				end
				if slot == 3 and Menu.spells[enemy.charName] then
					Menu.spells[enemy.charName]:MenuElement({ id = spellName, name = "Block [R]", value = true })
				end			
			end
		end
	end
end

local function HasrBuff(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count>0 and buff.name=="ZedR2" and buff.duration>7.2 then
            print(buff.name, buff.duration, buff.count)
			return true
        end
    end
    return false
end

function Tick()
--print(myHero:GetSpellData(_R).toggleState)
if not SpellsLoaded then 
	LoadBlockSpells()
	SpellsLoaded = true
end
--print( (myHero:GetSpellData(_W).cd - myHero:GetSpellData(_W).currentCd))

	if Rshadow == nil and (RTime + 5) < GameTimer() and myHero:GetSpellData(_R).toggleState==2 and HasrBuff(myHero) then
		print("1")
		Rshadow=myHero.pos
		RTime=GameTimer()
	end
	if  Rshadow ~= nil then
	--print(myHero:GetSpellData(_R).toggleState)
		if myHero:GetSpellData(_R).toggleState==0 and laststate ==2 then
			Rshadow=lastplace
			laststate= myHero:GetSpellData(_R).toggleState
			print("trying")
		else
			 laststate= myHero:GetSpellData(_R).toggleState
			 lastplace=myHero.pos	
		end
	end
	if Menu.Combo.QKey:Value() then Q() end
--	print(myHero:GetSpellData(_W).cd - myHero:GetSpellData(_W).currentCd)
	if (myHero:GetSpellData(_W).cd - myHero:GetSpellData(_W).currentCd)<3 then
		if Wshadow == nil then --and (WTime + 5) < GameTimer() then
			for i = 1, Game.MissileCount() do
				local missile = Game.Missile(i)
				if missile and (missile.missileData.name == "ZedWMissile") then
                   print("creating wshadow")
					Wshadow=Vector(missile.missileData.endPos.x,missile.missileData.endPos.y,missile.missileData.endPos.z)
					werror=0
					WTime = GameTimer()
					return
				end
			end
		elseif myHero:GetSpellData(_W).toggleState==0 and (W2Time + 4) < GameTimer() and (WTime + 6) > GameTimer() then
		print("3")
			for u = 1, Game.ParticleCount() do --if you want to detect ground spells such as brand W, but needs spellname database list (incl. width), since particles lack needed data
				local particle = Game.Particle(u)
				if particle and particle.name:find("Zed_Base_Clone_idle") then
					Wshadow=particle.pos
					werror=0
					W2Time=GameTimer()
				--	WTime = GameTimer()
					return
				end
			end
		end
		
	end
	
UpdateTotalDamage()

if MyHeroNotReady() then return end
local Mode = GetMode()
	if Control.IsKeyDown(Menu.Combo.WKey:Key()) then
		local target = GetTarget2(1800)
		if target and Ready(_W) and (myHero:GetSpellData(_W).name == "ZedW" or wincrement==true) then --or ( Wshadow ~= nil and (WTime + 0.3) < GameTimer() )) then
			Control.CastSpell(HK_W, target.pos:Extended(myHero.pos,-150))
		end
		wincrement=false
	end
	if Control.IsKeyDown(Menu.Combo.WKey:Key())==false then
	    wincrement=true
	end
	if Mode == "Combo" then
		if not QEKillable then
			Ult()
		end
			--if not UltKillable then
			if Menu.Combo.UseQ:Value() or Menu.Combo.QKey:Value()  then Q() end
			if Menu.Combo.UseW:Value() then W() end
			if Menu.Combo.Change:Value() == 2 then
				E()
			end	
		--end
		
	elseif Mode == "Harass" then
		if Menu.Harass.UseW:Value() then hW() end
		if Menu.Harass.Change:Value() == 2 and Menu.Harass.UseE:Value()  then
			E()
		end	
	elseif Mode == "LastHit" and Ready(_Q) and Menu.Lasthit.UseQ:Value()  then
		Lasthit()
	end
	
	if R1casted and myHero:GetSpellData(_R).name == "ZedR2" then
		Control.CastSpell(HK_R)
		R1casted = false
	end	

	if Wshadow ~= nil and (WTime + 5.3) < GameTimer() then
		--WTime 	= 0
		W2Time 	= 0
		Wshadow = nil
	end
	
	if Rshadow ~= nil and (RTime + 7.8) < GameTimer() then
		RTime 	= 0
		Rshadow = nil
	end			
	
	if Menu.Combo.Change:Value() == 1 or Menu.Harass.Change:Value() == 1 then
		AutoE()
	end	

	if Menu.ks.UseQE:Value() then
		QEKill()
	end

	if Ready(_W) and Menu.spells.wblock:Value() and SpellsLoaded == true then
		EvadeW()
	end	

	if Ready(_R) and (not Ready(_W) or not Menu.spells.wblock:Value()) and Menu.spells.rblock:Value() and SpellsLoaded == true then
		EvadeR()
	end	
	AutoBack()
end

function Lasthit()
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(1000)
	for i = 1, #minions do
		local minion = minions[i]
		if IsValid(minion) then
		 local value=GetDamage("q2")
			local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.24+GetDistance(myHero.pos, minion.pos)/1700)
			if hp<value and hp>0 and GetDistance(myHero.pos, minion.pos) > 250  then
					local prediction = _G.PremiumPrediction:GetPrediction(myHero, minion, {
					hitChance = 0.5,
					speed = 1700,
					range = 900,
					delay = .25,
					radius = 50,
					collision = false,
					type = "linear"
				})

				if _G.PremiumPrediction.HitChance.Low(prediction.HitChance) then
					_G.Control.CastSpell(HK_Q, prediction.CastPos)
					return
				end
			end
		end
	end
end	
local function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

function EvadeW()
local unit, spell = OnProcessSpell()
	if unit and unit.isEnemy and myHero.pos:DistanceTo(unit.pos) < 3000 and spell then
		if unit.activeSpell and unit.activeSpell.valid and
		(unit.activeSpell.target == myHero.handle or 
		GetDistance(unit.activeSpell.placementPos, myHero.pos) <= myHero.boundingRadius * 2 + unit.activeSpell.width) and not 
		string.find(unit.activeSpell.name:lower(), "attack") then
			for j = 0, 3 do
				local cast = unit:GetSpellData(j)
				if Menu.spells[unit.charName][cast.name] and Menu.spells[unit.charName][cast.name]:Value() and cast.name == unit.activeSpell.name then
					local startPos = unit.activeSpell.startPos
					local placementPos = unit.activeSpell.placementPos
					local width = 0
					if unit.activeSpell.width > 0 then
						width = unit.activeSpell.width
					else
						width = 100
					end
					local CastPos = unit.activeSpell.startPos
					local PlacementPos = unit.activeSpell.placementPos
					local VCastPos = Vector(CastPos.x, CastPos.y, CastPos.z)
					local VPlacementPos = Vector(PlacementPos.x, PlacementPos.y, PlacementPos.z)
				--	local distance = GetDistance(myHero.pos, placementPos)	
					local point, isOnSegment = ClosestPointOnLineSegment(myHero.pos, VPlacementPos, VCastPos)
					local point2, isOnSegment2 = ClosestPointOnLineSegment(myHero.pos:Extended(mousePos,600), VPlacementPos, VCastPos)
					local distCheck = GetDistance(myHero.pos, point)
					local distCheck2 = GetDistance(myHero.pos:Extended(mousePos,600), point2)
					if unit.activeSpell.target == myHero.handle then
						CastEvadeW()
						return
					else
						if distCheck <= width + myHero.boundingRadius+ 30 and (myHero:GetSpellData(_W).name == "ZedW2" or distCheck <= width + myHero.boundingRadius+30) then
							CastEvadeW()
						break
						end
					end							
				end
			end
		end
	end
end

function CastEvadeW()	
	Control.CastSpell(HK_W, mousePos)
	WTime = GameTimer()
	DelayAction(function()
		Control.CastSpell(HK_W)
	end,0.2)		
end

function EvadeR()
local unit, spell = OnProcessSpell()
	if unit and unit.isEnemy and myHero.pos:DistanceTo(unit.pos) < 3000 and spell then
		if unit.activeSpell and unit.activeSpell.valid and
		(unit.activeSpell.target == myHero.handle or 
		GetDistance(unit.activeSpell.placementPos, myHero.pos) <= myHero.boundingRadius * 2 + unit.activeSpell.width) and not 
		string.find(unit.activeSpell.name:lower(), "attack") then
			for j = 0, 3 do
				local cast = unit:GetSpellData(j)
				if Menu.spells[unit.charName][cast.name] and Menu.spells[unit.charName][cast.name]:Value() and cast.name == unit.activeSpell.name then
					local startPos = unit.activeSpell.startPos
					local placementPos = unit.activeSpell.placementPos
					if unit.activeSpell.target == myHero.handle then
                    	CastEvadeR()
                    	return
                    end
					local width = 0
					if unit.activeSpell.width > 0 then
						width = unit.activeSpell.width
					else
						width = 100
					end
					local VCastPos = Vector(CastPos.x, CastPos.y, CastPos.z)
					local VPlacementPos = Vector(PlacementPos.x, PlacementPos.y, PlacementPos.z)
					local point, isOnSegment = ClosestPointOnLineSegment(myHero.pos, VPlacementPos, VCastPos)
					local distCheck = GetDistance(myHero.pos, point)

                    if distCheck <= width + myHero.boundingRadius+30 then
                        CastEvadeR()
                    break
                    end

				end
			end
		end
	end
end

function CastEvadeR()
	for i, enemy in ipairs(GetEnemyHeroes()) do
		if enemy and myHero.pos:DistanceTo(enemy.pos) <= 625 and IsValid(enemy) then
			Control.CastSpell(HK_R, enemy)
			R1casted = true
		end
	end
end	

function HasElec(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("electrocute.lua") then
--print("elec")
		return true
        end
    end
    return false
end
local comboDamageData = {}
local comboQEData = {}
local dataTick = GameTimer()

function UpdateTotalDamage()

	if(dataTick > GameTimer()) then return end

	local enemies = GetEnemyHeroesinrange(1800)
	if(#enemies > 0) then
		for _, enemy in pairs(enemies) do
			if(enemy and enemy.valid and IsValid(enemy)) then
				comboDamageData[enemy.name],comboQEData[enemy.name]= GetTotalDamage(enemy)

			end
		end

		dataTick = GameTimer() + 0.5
	end
end

function CalculatePhysicalDamage(target, damage)
    if target and damage then
        local targetArmor = target.armor * myHero.armorPenPercent - myHero.armorPen
        local damageReduction = 100 / (100 + targetArmor)
        if targetArmor < 0 then
            damageReduction = 2 - (100 / (100 - targetArmor))
        end
        damage = damage * damageReduction
        return damage
    end
    return 0
end

 function GetTotalDamage(target)
 			local Qdmg2		= Ready(_Q) and GetDamage(HK_Q) or 0
 			local Edmg2 	= Ready(_E) and GetDamage(HK_E) or 0
 			local IGdmg 	= GetDamage(Ignite) or 0
 			local Rdmg 		= Ready(_R) and GetDamage(HK_R) or 0
 			local Elect 	= HasElec(myHero) and GetDamage(Elec) or 0
 			local physical	= myHero.totalDamage
 			local magical 	= myHero.ap
 			local TotalDmg 	= (Qdmg2 + Elect + Edmg2 + Rdmg + IGdmg + ((Qdmg2 + Edmg2 + physical)*(0.1 + 0.15 * myHero:GetSpellData(_R).level)) + ((physical + magical) * 2)) - (target.hpRegen*3)
 			local QEDmg 	= (Qdmg2 + Elect + Edmg2 +physical) - (target.hpRegen*3)
    return CalculatePhysicalDamage(target, TotalDmg), CalculatePhysicalDamage(target, QEDmg)
end

 --[[  function GetQEDamage(target)
     			local Qdmg2		= Ready(_Q) and GetDamage(HK_Q) or 0
     			local Edmg2 	= Ready(_E) and GetDamage(HK_E) or 0
     			local IGdmg 	= GetDamage(Ignite) or 0
     			local Qdmg 		= Ready(_Q) and DamageLib:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL ,Qdmg2) or 0
     			local Edmg 		= Ready(_E) and DamageLib:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL ,Edmg2) or 0
     			local Rdmg 		= Ready(_R) and GetDamage(HK_R) or 0
     			local Elect 	= HasElec(myHero) and GetDamage(Elec) or 0
     			local elecdmg   = DamageLib:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL ,Elect) or 0
     			local physical	= myHero.totalDamage
     			local magical 	= myHero.ap
     			local QEDmg 	= (Qdmg2 + elecdmg+ Edmg2 +physical) - (target.hpRegen*3)
        return
    end
--]]


function Drawing()
	if myHero.dead then return end
	if Wshadow ~= nil and myHero:GetSpellData(_W).toggleState == 2 and werror==0 and (WTime+5>GameTimer()) then
		local wspos=Wshadow:To2D()
		DrawText("W", 32, wspos.x, wspos.y,DrawColor(255, 255, 255, 255))
		
	end
	if Rshadow ~= nil and myHero:GetSpellData(_R).toggleState == 2 then
		local rspos=Rshadow:To2D()
		DrawText("R", 32, rspos.x, rspos.y,DrawColor(255, 255, 100, 100))
		
	end
	if Menu.Drawing.DrawR:Value() and Ready(_R) then
	DrawCircle(myHero, 625, 1, DrawColor(255, 225, 255, 10))
	end                                                 
	if Menu.Drawing.DrawQ:Value() and Ready(_Q) then
	DrawCircle(myHero, 900, 1, DrawColor(225, 225, 0, 10))
	end
	if Menu.Drawing.DrawW:Value() and Ready(_W) then
	DrawCircle(myHero, 650, 1, DrawColor(225, 225, 0, 10))
	end		
	if Menu.Drawing.DrawE:Value() and Ready(_E) then
	DrawCircle(myHero, 290, 1, DrawColor(225, 225, 125, 10))
	end	
	mhp=myHero.pos:To2D()
	if Menu.Combo.SaveQ:Value() then
        Draw.Text("Save Q ",30,mhp.x,mhp.y-30,Draw.Color(255 ,0,255,0))
    else
        Draw.Text("Use Q",30,mhp.x,mhp.y-30,Draw.Color(255 ,255,0,0))

    end
	if Menu.Drawing.KillText:Value() then
	local currentEnergyNeeded = GetEnergy()
		for i, target in ipairs(GetEnemyHeroesinrange(1500)) do
			if Ready(_R) and comboDamageData[target.name]~= nil and ( (myHero:GetSpellData(_R).cd - myHero:GetSpellData(_R).currentCd>3) or HasBuff(target,"zedrtargetmark"))then
				if myHero.pos:DistanceTo(target.pos) <= 2000 and IsValid(target) and target.health < comboDamageData[target.name] and myHero.mana > currentEnergyNeeded then
					DrawText("Kill", 24, target.pos2D.x, target.pos2D.y-50,DrawColor(255, 255, 0, 0))
					DrawText("Kill", 10, target.posMM.x - 15, target.posMM.y - 15,DrawColor(255, 255, 0, 0))	
				elseif  myHero.pos:DistanceTo(target.pos) <= 2000 and IsValid(target) then
					DrawText(math.floor(((target.health-comboDamageData[target.name])/target.maxHealth)*100).."%", 24, target.pos2D.x, target.pos2D.y-50,DrawColor(255, 255, 255, 255))
				end
			elseif comboQEData[target.name]~= nil then
				if myHero.pos:DistanceTo(target.pos) <= 2000 and IsValid(target) and target.health < comboQEData[target.name] then
					DrawText("Kill", 24, target.pos2D.x, target.pos2D.y-50,DrawColor(255, 255, 0, 0))
					DrawText("Kill", 10, target.posMM.x - 15, target.posMM.y - 15,DrawColor(255, 255, 0, 0))	
				elseif  myHero.pos:DistanceTo(target.pos) <= 2000 and IsValid(target) then
					DrawText(math.floor(((target.health-comboQEData[target.name])/target.maxHealth)*100).."%", 24, target.pos2D.x, target.pos2D.y-50,DrawColor(255, 255, 255, 255))
				end				
			end	
		end	
	end	
end

local function CastQ(aim, unit)
	if Ready(_Q) then	
		local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 55, Range = 900, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
		QPrediction:GetPrediction(aim, unit)
		if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
			_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end				
	end
end

local function CastW(aim, unit)
	if Ready(_W) and castSpell.state == 0 then
	
		if Menu.Pred.Change:Value() == 1 then
			local pred = GetGamsteronPrediction(aim, WData, unit)
			if pred.Hitchance >= Menu.Pred.PredW:Value()+1 then
				Control.CastSpell(HK_W, pred.CastPosition)

			end
			
		elseif Menu.Pred.Change:Value() == 2 then
			local pred = _G.PremiumPrediction:GetPrediction(unit, aim, WspellData)
			if pred.CastPos and ConvertToHitChance(Menu.Pred.PredW:Value(), pred.HitChance) then					
				Control.CastSpell(HK_W, pred.CastPos)

			end	
			
		else
			local WPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 290, Range = 900, Speed = 2500, Collision = false})
			WPrediction:GetPrediction(aim, unit)
			if WPrediction:CanHit(Menu.Pred.PredW:Value() + 1) then
				Control.CastSpell(HK_W, WPrediction.CastPosition)

			end				
		end
	end	
end

function Q()
local target = GetTarget2(2400)
if target == nil then return end
    if Ready(_Q) then

		if myHero.pos:DistanceTo(target.pos) <= 750 and (not Menu.Combo.SaveQ:Value() and (Wshadow ~= nil or not Ready(_W)) or target.health/target.maxHealth <= 0.1) then
			CastQ(target, myHero)
		--	print("y")
		end
		if myHero.pos:DistanceTo(target.pos) <= 900 and Menu.Combo.QKey:Value() then
			QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 900, Speed = 1700, Collision =false })
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
			--	print("t")
				return
			end				
		end
		
		-- if myHero.pos:DistanceTo(target.pos) <= 850 and ((Wshadow ~= nil) or (Rshadow ~= nil)) then
			-- _G.Control.CastSpell(HK_Q, target.pos)			
		-- end
		--print((myHero:GetSpellData(_R).cd - myHero:GetSpellData(_R).currentCd))
		if myHero.pos:DistanceTo(target.pos) <= 850 and (Wshadow ~= nil) and (Rshadow ~= nil or myHero:GetSpellData(_R).level==0 or  myHero:GetSpellData(_R).currentCd>4) and (GetDistance(Wshadow, target.pos)<=850 or GetDistance(Rshadow, target.pos)<=850)  then --and(GetDistance(Wshadow, target.pos)<=850 or not Menu.Combo.SaveQ:Value())) and (Rshadow ~= nil or(not Menu.Combo.SaveQ:Value()) or myHero.pos:DistanceTo(target.pos) >= 625  or not Ready(_R)) then
			QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 1500, Speed = 1700, Collision =false })
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
			--	print("r")
				return
			end	
			
		end
		if myHero.pos:DistanceTo(target.pos) >= 850 and (Wshadow ~= nil and GetDistance(Wshadow, target.pos)<=900) and Menu.Combo.QKey:Value() then --and(GetDistance(Wshadow, target.pos)<=850 or not Menu.Combo.SaveQ:Value())) and (Rshadow ~= nil or(not Menu.Combo.SaveQ:Value()) or myHero.pos:DistanceTo(target.pos) >= 625  or not Ready(_R)) then
		local speed=1700*(myHero.pos:DistanceTo(target.pos)/Wshadow:DistanceTo(target.pos))
		QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 2500, Speed = speed, Collision =false })
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
				--print("e")
				return
			end	
			
		end
		if myHero.pos:DistanceTo(target.pos) >= 850 and (Rshadow ~= nil and GetDistance(Rshadow, target.pos)<=900) and Menu.Combo.QKey:Value() then --and(GetDistance(Wshadow, target.pos)<=850 or not Menu.Combo.SaveQ:Value())) and (Rshadow ~= nil or(not Menu.Combo.SaveQ:Value()) or myHero.pos:DistanceTo(target.pos) >= 625  or not Ready(_R)) then
		local speed=1700*(myHero.pos:DistanceTo(target.pos)/Rshadow:DistanceTo(target.pos))
		QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 2500, Speed = speed, Collision =false })
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
			--	print("e")
				return
			end	
			
		end
		
		
		if myHero.pos:DistanceTo(target.pos) > 900 and not Menu.Combo.SaveQ:Value() then	
			
			if Wshadow ~= nil and GetDistance(Wshadow, target.pos) <= 850 then
				local speed=1700*(myHero.pos:DistanceTo(target.pos)/Wshadow:DistanceTo(target.pos))
				QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 2500, Speed = speed, Collision =false })
				QPrediction:GetPrediction(target, myHero)
				if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
			--	print("q")
				return
			end	
			
		
			end
			
			if Rshadow ~= nil and GetDistance(Rshadow, target.pos) <= 850 then
				local speed=1700*(myHero.pos:DistanceTo(target.pos)/Rshadow:DistanceTo(target.pos))
				QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 2500, Speed = speed, Collision =false })
				QPrediction:GetPrediction(target, myHero)
				if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
			--	print("w")
				return
				end
			end
		end	
    end
end
function hW()
local target = GetTarget2(2000)
if target == nil then return end
    if Ready(_W) then

		if myHero:GetSpellData(_W).name ~= "ZedW2" then
			if Ready(_Q) and not Ready(_E) then
				if myHero.pos:DistanceTo(target.pos) <= 1800 then
					if myHero.pos:DistanceTo(target.pos) <= 900 then
						CastW(target, myHero)
						DelayAction(function()
							_G.Control.CastSpell(HK_Q, target.pos)
						end,0.2)	
						return
					else
						Control.CastSpell(HK_W, target.pos)
						WTime = GameTimer()

						return
					end	
				end
			else
				if Ready(_Q) and Ready(_E) then
					if myHero.pos:DistanceTo(target.pos) < 900 then
						Control.CastSpell(HK_W, target.pos:Extended(myHero.pos,-150) )
						WTime = GameTimer()
						return
					end	
				end	
			end
		end
		if  Ready(_Q) and ((not Ready(_W)) or myHero:GetSpellData(_W).name == "ZedW2") and WTime + 0.3 < GameTimer() then
			QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 1500, Speed = 1700, Collision =false })
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
				return
			end				
		end
		
    end
end

function W()
local target = GetTarget2(2000)
if target == nil then return end    
    if Ready(_W) then

		if myHero:GetSpellData(_W).name ~= "ZedW2" then
			if Ready(_Q) and not Ready(_E) then
				if myHero.pos:DistanceTo(target.pos) <= 1800 then
					if myHero.pos:DistanceTo(target.pos) <= 900 then
						CastW(target, myHero)
						return
					else
						Control.CastSpell(HK_W, target.pos)
						return
					end	
				end
			else
				if Ready(_Q) and Ready(_E) then
					if myHero.pos:DistanceTo(target.pos) < 900 then
						CastW(target, myHero)
						return
					end	
				end	
			end
		end
    end
end

function E()
	local target = GetTarget2(1000)
	if target and Ready(_E) and myHero.pos:DistanceTo(target.pos) <= 2000 and IsValid(target) then
	
		if GetDistance(target.pos, myHero.pos) < 290 then
			Control.CastSpell(HK_E)
		end	
			
		if Wshadow then
			if GetDistance(Wshadow, target.pos) < 290 then
				Control.CastSpell(HK_E)
			end
		end
		
		if Rshadow then
			if GetDistance(Rshadow, target.pos) < 290 then
				Control.CastSpell(HK_E)
			end
		end
	end
end

function AutoE()
	local target = GetTarget2(1000)
	if target and Ready(_E) and myHero.pos:DistanceTo(target.pos) <= 2000 and IsValid(target) then
	
		if GetDistance(target.pos, myHero.pos) < 290 then
			Control.CastSpell(HK_E)
		end	
			
		if Wshadow then
			if GetDistance(Wshadow, target.pos) < 290 then
				Control.CastSpell(HK_E)
			end
		end
		
		if Rshadow then
			if GetDistance(Rshadow, target.pos) < 290 then
				Control.CastSpell(HK_E)
			end
		end
	end
	
end

function Ult()
local target = GetTarget2(2500)
if target == nil then return end	
	if IsValid(target) then
 		local IGdmg 	= GetDamage(Ignite) or 0
  --  return CalculatePhysicalDamage(target, TotalDmg), CalculatePhysicalDamage(target, QEDmg)
		--print("rdmg"..Rdmg)
		local TotalDmg 	= comboDamageData[target.name]
		local currentEnergyNeeded = GetEnergy()

		if Menu.Combo.Ult.IGN:Value() and myHero.pos:DistanceTo(target.pos) <= 600 and TotalDmg> target.health and  TotalDmg-IGdmg <= target.health then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and GameCanUseSpell(SUMMONER_1) == 0 then
				Control.CastSpell(HK_SUMMONER_1, target)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and GameCanUseSpell(SUMMONER_2) == 0 then
				Control.CastSpell(HK_SUMMONER_2, target)
			end	
		end	
		
		if Menu.Combo.Ult.UseR:Value() and Menu.Combo.Ult.UseRBack:Value() and myHero:GetSpellData(_R).name == "ZedR2" then	
			if myHero.health/myHero.maxHealth <= Menu.Combo.Ult.Hp:Value() / 100 then
				Control.CastSpell(HK_R)
			end	
		end		
		
		if Menu.Combo.Ult.UseR:Value() and Ready(_R) and myHero:GetSpellData(_R).name ~= "ZedR2" then					
			if myHero.pos:DistanceTo(target.pos) <= 625 then
			
				if Menu.Combo.Ult.UseRTower:Value() then
					if target.health < TotalDmg and target.health < TotalDmg and myHero.mana > currentEnergyNeeded then
						UltKillable = true
						Rshadow = myHero.pos
						DelayAction(function()
							Control.CastSpell(HK_R, target)
							TableInsert(Rtarget, target) 
							RTime = GameTimer()
							UltKillable = false
						end,0.2)
						return
					end
				else
					for i, ally in ipairs(GetAllyHeroes()) do
						if target.health < TotalDmg and myHero.mana > currentEnergyNeeded then
							if not IsUnderTurret(target) or (IsUnderTurret(target) and ally.pos:DistanceTo(target.pos) < 900 and IsUnderTurret(ally)) then
								UltKillable = true
								Rshadow = myHero.pos
								DelayAction(function()
									Control.CastSpell(HK_R, target)
									TableInsert(Rtarget, target)
									RTime = GameTimer()
									UltKillable = false
								end,0.2)
								return
							end	
						end	
					end	
				end				
			else
				if Wshadow ~= nil then
					if Ready(_W) and myHero:GetSpellData(_W).toggleState == 2 and target.health < TotalDmg and myHero.mana > currentEnergyNeeded and GetDistance(Wshadow, target.pos) <= 625 then
						-- if Menu.Combo.Ult.UseRTower:Value() then
							-- UltKillable = true
							-- Wshadow = myHero.pos
							-- Control.CastSpell(HK_W)
							-- DelayAction(function()
								-- UltKillable = false
							-- end,0.2)	
						-- else
							-- for i, ally in ipairs(GetAllyHeroes()) do
								-- if not IsUnderTurret(target) or (IsUnderTurret(target) and ally.pos:DistanceTo(target.pos) < 800 and IsUnderTurret(ally)) then
									-- UltKillable = true
									-- Wshadow = myHero.pos
									-- Control.CastSpell(HK_W)
									-- DelayAction(function()
										-- UltKillable = false
									-- end,0.2)
								-- end	
							-- end	
						-- end
					end
				else
					if myHero:GetSpellData(_W).toggleState == 0 then
						if Ready(_W) and target.health < TotalDmg and myHero.mana > currentEnergyNeeded and Menu.Combo.Ult.UseW1:Value() then
							
							if myHero.pos:DistanceTo(target.pos) <= 1250 then
								if Menu.Combo.Ult.UseRTower:Value() then
									UltKillable = true
									Control.CastSpell(HK_W, target.pos)
									DelayAction(function()
										UltKillable = false
									end,0.2)
								else
									for i, ally in ipairs(GetAllyHeroes()) do
										if not IsUnderTurret(target) or (IsUnderTurret(target) and ally.pos:DistanceTo(target.pos) < 800 and IsUnderTurret(ally)) then
											UltKillable = true
											Control.CastSpell(HK_W, target.pos)
											DelayAction(function()
												UltKillable = false
											end,0.2)
										end
									end	
								end	
							end
						end
					else
						if Ready(_W) and myHero:GetSpellData(_W).toggleState == 2 and target.health < TotalDmg and myHero.mana > currentEnergyNeeded then
							Wshadow = myHero.pos
							Control.CastSpell(HK_W)
						end
					end	
				end	
			end
		end	
	end	
end

function AutoBack()
	for i, target in ipairs(Rtarget) do
		
		if Menu.Combo.Ult.UseR2:Value() and HasBuff(myHero, "ZedR2") and Rshadow ~= nil and target then
			if GetEnemyCount(600, myHero.pos) > 1 or IsUnderTurret(myHero) then
				if (GetDistance(target.pos, myHero.pos) < GetDistance(target.pos, Rshadow)) and GetEnemyCount(400, Rshadow) == 0 then
					DelayAction(function()
						Control.CastSpell(HK_R)
					end,2)	
				end
				
				if Wshadow ~= nil and myHero:GetSpellData(_W).toggleState == 2 and GetEnemyCount(400, Wshadow) == 0 then
					Control.CastSpell(HK_W)
				end	
			end	
		end
	end	
end

function QEKill()
	local target = GetTarget2(1000)
		if target and myHero.pos:DistanceTo(target.pos) < 900 and IsValid(target) then

			local currentEnergyNeeded = GetEnergy()
			
			if Ready(_W) and myHero:GetSpellData(_W).name ~= "ZedW2" and target.health < comboQEData[target.name] and myHero.mana > currentEnergyNeeded then
				QEKillable = true
				Control.CastSpell(HK_W, target.pos)
			end
			if myHero:GetSpellData(_W).toggleState == 2 and target.health < comboQEData[target.name]and myHero.mana > currentEnergyNeeded then
			E()			
			
				QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 900, Speed = 1700, Collision =false })
				QPrediction:GetPrediction(target, myHero)
				if Ready(_Q) and QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
					_G.Control.CastSpell(HK_Q, QPrediction.CastPosition)
					return
				end				
			end	
			
		end
		QEKillable = false

end	
