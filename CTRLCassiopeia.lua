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
	return _G.SDK.TargetSelector:GetTarget(range)
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

local function HasPoison(unit)
	for i = 0, unit.buffCount do
	local buff = unit:GetBuff(i)
		if buff.type == 24 and Game.Timer() < buff.expireTime - 0.141  then
			return true
		end
	end
	return false
end

local function MinionsNear(pos,range)
	local pos = pos.pos
	local N = 0
		for i = 1, GameMinionCount() do
		local Minion = GameMinion(i)
		local Range = range * range
		if Minion.team == TEAM_ENEMY and Minion.pos:DistanceTo(pos) < Range then
			N = N + 1
		end
	end
	return N
end

function LoadScript()
	Menu = MenuElement({type = MENU, id = "PussyAIO".. myHero.charName, name = myHero.charName})
	Menu:MenuElement({name = " ", drop = {"Version 0.13"}})	
		Menu:MenuElement({name = " ", drop = {"General Settings"}})	
		
		--Combo   
		Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})		
		Menu.combo:MenuElement({id = "Q", name = "Use Q", value = false, toggle=false, key=string.byte("S")})
		Menu.combo:MenuElement({id = "W", name = "Use W", value = false, toggle=false, key=string.byte("A")})
		Menu.combo:MenuElement({id = "E", name = "Use E", value = true})
		Menu.combo:MenuElement({id = "SR", name = "Manual R ", key = string.byte("A")})
		Menu.combo:MenuElement({id = "R", name = "Use R ", value = true})
		Menu.combo:MenuElement({id = "R2", name = "Use R Stun/Slow if killable", value = true})
		Menu.combo:MenuElement({id = "Count", name = "Min facing Amount to hit R", value = 2, min = 1, max = 5, step = 1})
		Menu.combo:MenuElement({id = "P", name = "Use Panic R and Ghost", value = true})
		Menu.combo:MenuElement({id = "HP", name = "Min HP % to Panic R", value = 30, min = 0, max = 100, step = 1})
		Menu.combo:MenuElement({name = " ", drop = {"-------------------------------------------"}})
		Menu.combo:MenuElement({name = " ", drop = {"-------------------------------------------"}})
		Menu.combo:MenuElement({name = " ", drop = {"Block AutoAttack Settings"}})
		Menu.combo:MenuElement({name = " ", drop = {"Turn off AutoAttack in LoL Options/Game/"}})
		Menu.combo:MenuElement({id = "Block", name = "Block AA in Combo for E", value = true})
		Menu.combo:MenuElement({id = "Cd", name = "Block AA if Cooldown E lower than", value = 0.55, min = 0, max = 0.8, step = 0.01, identifier = "sec"})

		--Harass
		Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
		Menu.harass:MenuElement({id = "Q", name = "UseQ", value = true})
		Menu.harass:MenuElement({id = "E", name = "UseE only poisend", value = true})

		--Clear
		Menu:MenuElement({type = MENU, id = "clear", name = "Clear"})
		Menu.clear:MenuElement({id = "Q", name = "Use Q", value = true})
		Menu.clear:MenuElement({id = "W", name = "Use W", value = true})
		Menu.clear:MenuElement({id = "Count", name = "Min Minions to hit W", value = 3, min = 1, max = 5, step = 1})
		Menu.clear:MenuElement({id = "E", name = "Auto E Toggle Key", key = 84, toggle = true, value = true})
		Menu.clear:MenuElement({id = "E2", name = "Auto E off in Combo Mode", value = true})

		--JungleClear
		Menu:MenuElement({type = MENU, id = "jclear", name = "JungleClear"})
		Menu.jclear:MenuElement({id = "Q", name = "Use Q", value = true})
		Menu.jclear:MenuElement({id = "W", name = "Use W", value = true})
		Menu.jclear:MenuElement({id = "E", name = "Use E[poisend or Lasthit]", value = true})

		--KillSteal
		Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
		Menu.ks:MenuElement({id = "Q", name = "UseQ", value = true})
		Menu.ks:MenuElement({id = "W", name = "UseW", value = true})
		Menu.ks:MenuElement({id = "E", name = "UseE", value = true})

		--Prediction
		Menu:MenuElement({type = MENU, id = "Pred", name = "Prediction"})
		Menu.Pred:MenuElement({name = " ", drop = {"After change Pred.Typ reload 2x F6"}})
		Menu.Pred:MenuElement({id = "Change", name = "Change Prediction Typ", value = 3, drop = {"Gamsteron Prediction", "Premium Prediction", "GGPrediction"}})
		Menu.Pred:MenuElement({id = "PredQ", name = "Hitchance[Q]", value = 1, drop = {"Normal", "High", "Immobile"}})

		--RSetting
		Menu:MenuElement({type = MENU, id = "RS", name = "R Range Setting"})
		Menu.RS:MenuElement({id = "Rrange", name = "Max CastR Range", value = 700, min = 100, max = 825, identifier = "range"})

		--Mana
		Menu:MenuElement({type = MENU, id = "mana", name = "Mana Settings"})
		Menu.mana:MenuElement({name = " ", drop = {"Harass [%]"}})
		Menu.mana:MenuElement({id = "Q", name = "Q Mana", value = 10, min = 0, max = 100, step = 1})
		Menu.mana:MenuElement({id = "W", name = "W Mana", value = 10, min = 0, max = 100, step = 1})
		Menu.mana:MenuElement({id = "E", name = "E Mana", value = 5, min = 0, max = 100, step = 1})
		Menu.mana:MenuElement({id = "R", name = "R Mana", value = 5, min = 0, max = 100, step = 1})
		Menu.mana:MenuElement({name = " ", drop = {"Lane/JungleClear [%]"}})
		Menu.mana:MenuElement({id = "QW", name = "Q Mana", value = 10, min = 0, max = 100, step = 1})
		Menu.mana:MenuElement({id = "WW", name = "W Mana", value = 10, min = 0, max = 100, step = 1})
		Menu.mana:MenuElement({id = "EW", name = "E Mana", value = 10, min = 0, max = 100, step = 1})

		Menu:MenuElement({name = " ", drop = {"Advanced Settings"}})

		--Drawings
		Menu:MenuElement({type = MENU, id = "drawings", name = "Drawings"})
		Menu.drawings:MenuElement({id = "ON", name = "Enable Drawings", value = true})
		Menu.drawings:MenuElement({type = MENU, id = "XY", name = "Text Pos Settings"})
		Menu.drawings.XY:MenuElement({id = "Text", name = "Draw AAE", value = true})
		Menu.drawings.XY:MenuElement({id = "x", name = "Pos: [X]", value = 700, min = 0, max = 1500, step = 10})
		Menu.drawings.XY:MenuElement({id = "y", name = "Pos: [Y]", value = 0, min = 0, max = 860, step = 10})
		Menu.drawings:MenuElement({type = MENU, id = "Q", name = "Q"})
		Menu.drawings.Q:MenuElement({id = "ON", name = "Enabled", value = false})
		Menu.drawings.Q:MenuElement({id = "Width", name = "Width", value = 1, min = 1, max = 5, step = 1})
		Menu.drawings.Q:MenuElement({id = "Color", name = "Color", color = DrawColor(255, 255, 255, 255)})
		Menu.drawings:MenuElement({type = MENU, id = "W", name = "W"})
		Menu.drawings.W:MenuElement({id = "ON", name = "Enabled", value = false})
		Menu.drawings.W:MenuElement({id = "Width", name = "Width", value = 1, min = 1, max = 5, step = 1})
		Menu.drawings.W:MenuElement({id = "Color", name = "Color", color = DrawColor(255, 255, 255, 255)})
		Menu.drawings:MenuElement({type = MENU, id = "E", name = "E"})
		Menu.drawings.E:MenuElement({id = "ON", name = "Enabled", value = false})
		Menu.drawings.E:MenuElement({id = "Width", name = "Width", value = 1, min = 1, max = 5, step = 1})
		Menu.drawings.E:MenuElement({id = "Color", name = "Color", color = DrawColor(255, 255, 255, 255)})
		Menu.drawings:MenuElement({type = MENU, id = "R", name = "R"})
		Menu.drawings.R:MenuElement({id = "ON", name = "Enabled", value = false})
		Menu.drawings.R:MenuElement({id = "Width", name = "Width", value = 1, min = 1, max = 5, step = 1})
		Menu.drawings.R:MenuElement({id = "Color", name = "Color", color = DrawColor(255, 255, 255, 255)})

	QData =
	{
	Type = _G.SPELLTYPE_CIRCLE, Delay = 0.75+ping, Radius = 80, Range = 850, Speed = MathHuge, Collision = false
	}

	spellData = {speed = MathHuge, range = 850, delay = 0.75+ping, radius = 80, collision = {nil}, type = "circular"}

	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) StopAutoAttack(...) end)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:OnPreAttack(function(...) StopAutoAttack(...) end)
	end

	Callback.Add("Tick", function() Tick() end)

	Callback.Add("Draw", function()
		if myHero.dead == false and Menu.drawings.ON:Value() then
			mhp=myHero.pos:To2D()
			if Menu.clear.E:Value() then				
				Draw.Text("AA-E",15,mhp.x,mhp.y-30,Draw.Color(255 ,0,255,0))
			else
				Draw.Text("E",15,mhp.x,mhp.y-30,Draw.Color(255 ,255,0,0))

			end
			if Menu.drawings.Q.ON:Value() then
				DrawCircle(myHero.pos, 850, Menu.drawings.Q.Width:Value(), Menu.drawings.Q.Color:Value())
			end
			if Menu.drawings.W.ON:Value() then
				DrawCircle(myHero.pos, 340, Menu.drawings.W.Width:Value(), Menu.drawings.W.Color:Value())
				DrawCircle(myHero.pos, 960, Menu.drawings.W.Width:Value(), Menu.drawings.W.Color:Value())
			end
			if Menu.drawings.E.ON:Value() then
				DrawCircle(myHero.pos, 750, Menu.drawings.E.Width:Value(), Menu.drawings.E.Color:Value())
			end
			if Menu.drawings.R.ON:Value() then
				DrawCircle(myHero.pos, Menu.RS.Rrange:Value(), Menu.drawings.E.Width:Value(), Menu.drawings.E.Color:Value())
			end
		end
	end)
end

local function IsFacing(unit)
	local V = Vector((unit.pos - myHero.pos))
	local D = Vector(unit.dir)
	local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
	if math.abs(Angle) < 80 then
		return true
	end
	return false
end

local function IsFacing2(unit)
	local V = Vector((unit.pos - myHero.pos))
	local D = Vector(myHero.dir)
	local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
	if math.abs(Angle) < 80 then
		return true
	end
	return false
end


local QRange = 875
local MaxWRange = 700
local ERange = 700
local RRange = 825

local Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.65, Range = 850, Radius = 135, Speed = math.huge, Collision = false}


function GetCircleIntersectionPoints(p1, p2, center, radius)
	local sect = {[0] = {0, 0, 0}, [1] = {0, 0, 0}}
	local dp = {x = 0, y = 0, z = 0}
    local a, b, c
    local bb4ac
    local mu1
    local mu2
	
     dp.x   = p2.x - p1.x
     dp.z   = p2.z - p1.z

     a = dp.x * dp.x + dp.z * dp.z
     b = 2 * (dp.x * (p1.x - center.x) + dp.z * (p1.z - center.z))
     c = center.x* center.x + center.z * center.z
     c = c + p1.x * p1.x + p1.z * p1.z
     c = c - 2 * (center.x * p1.x + center.z * p1.z)
     c = c - radius * radius
     bb4ac  = b * b - 4 * a * c
     if(math.abs(a) < 0 or bb4ac < 0) then
         return sect
     end
	
     mu1 = (-b + math.sqrt(bb4ac)) / (2 * a)
     mu2 = (-b - math.sqrt(bb4ac)) / (2 * a)
	 
     sect[0] = {p1.x + mu1 * (p2.x - p1.x), 0, p1.z + mu1 * (p2.z - p1.z)}
     sect[1] = {p1.x + mu2 * (p2.x - p1.x), 0, p1.z + mu2 * (p2.z - p1.z)}
     
     return sect;
end

function GetExtendedSpellPrediction(target, spellData)
	local isExtended = false
	local extendedSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range-15 + spellData.Radius, Radius = spellData.Radius, Speed = spellData.Speed, Collision = spellData.Collision}
	local spellPred = GGPrediction:SpellPrediction(extendedSpellData)
	local predVec = Vector(0, 0, 0)
	spellPred:GetPrediction(target, myHero)
	--Get the extended predicted position, and the cast range of the spell
	if(spellPred.CastPosition) then
		predVec = Vector(spellPred.CastPosition.x, myHero.pos.y, spellPred.CastPosition.z)
		if(myHero.pos:DistanceTo(predVec) < spellData.Range-35) then
			return spellPred, isExtended
		end
	end
	local defaultRangeVec = (predVec - myHero.pos):Normalized() * spellData.Range + myHero.pos
	--DrawCircle(testVec, 150, 3)
	--Find the difference between these two points as a vector to create a line, and then find a perpendicular bisecting line at the extended cast position using this line
	local vec = (predVec - defaultRangeVec):Normalized() * 100 + myHero.pos
	local vecNormal = (predVec - defaultRangeVec):Normalized()
	local perp = Vector(vecNormal.z, 0, -vecNormal.x) * spellData.Radius + predVec
	local negPerp = Vector(-vecNormal.z, 0, vecNormal.x) * spellData.Radius + predVec

	--Find the points of intersection from our bisecting line to the radius of our spell at its cast range. 
	-- We can use this data to find a more precise circle, and make sure that our prediction will hit that.
	-- If our prediction hits the precise circle, that means our spell will hit if its extended
	-- This is really difficult to explain but much easier to visualize with diagrams
	local intersections = GetCircleIntersectionPoints(perp, negPerp, defaultRangeVec, spellData.Radius)
	
	--We only need one of the intersection points to form our precise circle
	local intVec = Vector(intersections[0][1], myHero.pos.y, intersections[0][3])
	local halfVec = Vector((intersections[0][1] + intersections[1][1]) /2, myHero.pos.y, (intersections[0][3] + intersections[1][3])/2)
	
	local preciseCircRadius = intVec:DistanceTo(predVec)
	local preciseSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range + spellData.Radius, Radius = preciseCircRadius, Speed = spellData.Speed, Collision = spellData.Collision}
	local preciseSpellPred = GGPrediction:SpellPrediction(preciseSpellData)
	isExtended = true
	preciseSpellPred:GetPrediction(target, myHero)

	return preciseSpellPred, isExtended
end
local W = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Range = 750, Radius = 50, Speed = 3000, Collision = false}
local gameTick = 0
function Tick()
	if MyHeroNotReady() then return end
	local target = GetTarget(950)
	if Menu.combo.Q:Value() then
	_G.SDK.Orbwalker:Orbwalk()
		if target and Ready(_Q) and gameTick < GameTimer() then 
			local QPrediction,isExtended = GetExtendedSpellPrediction(target, Q)
			if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
				local castPos = QPrediction.CastPosition
				if(isExtended) then
					if myHero.pos:DistanceTo(castPos)<850+100 then
						if IsFacing2(target)==false and myHero.pos:DistanceTo(castPos)<850+50 then
							castPos = myHero.pos:Extended(castPos, 850)								
						elseif IsFacing2(target) then
							castPos = myHero.pos:Extended(castPos, 805)
						else 
							return
						end
						print(myHero.pos:DistanceTo(castPos))
						Control.CastSpell(HK_Q, castPos)
						gameTick = GameTimer() + 0.2
					end
				else
						if IsFacing2(target) and myHero.pos:DistanceTo(castPos)<850+50 then
							print("awayasd")
							local castPos =Vector(castPos):Extended(myHero.pos,25)
							Control.CastSpell(HK_Q, castPos)
							gameTick = GameTimer() + 0.2
						elseif IsFacing2(target)==false then
								print("towardsasd")
							local castPos =Vector(castPos):Extended(myHero.pos,-25)
							Control.CastSpell(HK_Q, castPos)
							gameTick = GameTimer() + 0.2
						else 
							print("notextendedbutfucked")
							return
						end							
				end
			end
		end
	end
	
	if Menu.combo.W:Value() and target  then
		local Dist = myHero.pos:DistanceTo(target.pos)
		local WPrediction = GGPrediction:SpellPrediction(W)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(2) then
			Dist= myHero.pos:DistanceTo(WPrediction.CastPosition)
		end
	
		if Dist < 725 and Ready(_W) then
			if IsFacing2(target) then
				--print("away")
				local castPos =Vector(WPrediction.CastPosition):Extended(myHero.pos,50)
				--DrawCircle(castPos, 50, 1, DrawColor(255, 225, 255, 10))
				Control.CastSpell(HK_W, castPos)
			else
				--	print("towards")
				local castPos =Vector(WPrediction.CastPosition):Extended(myHero.pos,-50)
				--DrawCircle(castPos, 50, 1, DrawColor(255, 225, 255, 10))
				Control.CastSpell(HK_W, castPos)
			end
		
		elseif Dist < QRange and Ready(_W)==false and myHero:GetSpellData(_W).cd - myHero:GetSpellData(_W).currentCd>0.3 and myHero:GetSpellData(_Q).currentCd==0 then 
			if target and Ready(_Q) and gameTick < GameTimer() then 
				local QPrediction,isExtended = GetExtendedSpellPrediction(target, Q)
				if QPrediction.CastPosition and QPrediction:CanHit(HITCHANCE_HIGH) then
					local castPos = QPrediction.CastPosition
					if(isExtended) then
						if myHero.pos:DistanceTo(castPos)<850+100 then
							if IsFacing2(target)==false and myHero.pos:DistanceTo(castPos)<850+50 then
								castPos = myHero.pos:Extended(castPos, 850)
								
							elseif IsFacing2(target) then
								castPos = myHero.pos:Extended(castPos, 805)

							else 
								return
							end
							print(myHero.pos:DistanceTo(castPos))
							Control.CastSpell(HK_Q, castPos)
							gameTick = GameTimer() + 0.2
						end
					else
						if IsFacing2(target) and myHero.pos:DistanceTo(castPos)<850+50 then
						--	print("away")
							local castPos =Vector(castPos):Extended(myHero.pos,50)
							Control.CastSpell(HK_Q, castPos)
						elseif IsFacing2(target)==false then
						--		print("towards")
							local castPos =Vector(castPos):Extended(myHero.pos,-50)
							Control.CastSpell(HK_Q, castPos)
						else 
							return
						end						
						gameTick = GameTimer() + 0.2
					end
				end
			end
		end
	end


	local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
		if Menu.combo.R2:Value() then
			KillR()
		end
	elseif Mode == "LastHit" or  Mode == "Clear" then
		Lasthit()
	elseif Mode == "Harass" then
		Harass()
	elseif Mode == "Clear" then
		Clear()
		JClear()
	end

	if Menu.clear.E:Value() then
		if Menu.clear.E2:Value() then
			if Mode ~= "Combo" then
			--	AutoE()
			end
		else
			AutoE()
		end
	end

	if Menu.combo.SR:Value() then
		SemiR()
	end

	KsQ()
	KsW()
	KsE()
end

local function ReadyForE()
    return myHero:GetSpellData(_E).currentCd <= Menu.combo.Cd:Value() and myHero:GetSpellData(_E).level > 0 and myHero:GetSpellData(_E).mana <= myHero.mana
end

function EdmgCreep()
	local level = myHero.levelData.lvl
	local base = (48 + 4 * level) + (0.1 * myHero.ap)
	return base
end

function PEdmgCreep()
	local level = myHero:GetSpellData(_E).level
	local bonus = (({20, 40, 60, 80, 100})[level] + 0.60 * myHero.ap)
	local PEdamage = EdmgCreep() + bonus
	return PEdamage
end

function StopAutoAttack(args)
	local Mode = GetMode()
	if Menu.combo.Block:Value() and Mode == "Combo" and ReadyForE() then
		args.Process = false
		return
	end
	if Menu.clear.E:Value()==false and Menu.combo.Block:Value() and Mode == "Combo"  then
		args.Process = false
		return
	end		
	
	if (Mode == "LastHit" or Mode == "Clear") and Ready(_E) then
		local hp = _G.SDK.HealthPrediction:GetPrediction(args.Target, 0.125 + (args.Target.distance/2500)+0.05)	
		if hp<EdmgCreep() or HasPoison(args.Target) and PEdmgCreep()>hp  then
			args.Process = false
			Control.CastSpell(HK_E,args.Target)
			print("args"..Game.Timer())
			return
		end
	end
end



local function GetAngle(v1, v2)
	local vec1 = v1:Len()
	local vec2 = v2:Len()
	local Angle = math.abs(math.deg(math.acos((v1*v2)/(vec1*vec2))))
	if Angle < 40 then
		return true
	end
	return false
end

local function GetAngle2(v1, v2)
	local vec1 = v1:Len()
	local vec2 = v2:Len()
	local Angle = math.abs(math.deg(math.acos((v1*v2)/(vec1*vec2))))
	return Angle
end

local function FindFurthestTargetFromMe(targets,avgCastPos)
	local biggestangle = 0
	for i, target in pairs(targets) do
		local A = Vector(myHero.pos - target.pos)
		local B = Vector(myHero.pos - avgCastPos)
		local angle= GetAngle2(A,B)
		if(angle >= biggestangle) then
			furthestTarget = target
			biggestangle = angle
		end
	end
	
	return i
end


local function CalculateBoundingBoxAvg(targets)
	local highestX, lowestX, highestZ, lowestZ = 0, math.huge, 0, math.huge
	local avg = {x = 0, y = 0, z = 0}
	for k, v in pairs(targets) do
		local vPos = v.pos		
		if(vPos.x >= highestX) then
			highestX = v.pos.x
		end
		
		if(vPos.z >= highestZ) then
			highestZ = v.pos.z
		end
		
		if(vPos.x < lowestX) then
			lowestX = v.pos.x
		end
		
		if(vPos.z < lowestZ) then
			lowestZ = v.pos.z
		end
	end
	
	local vec1 = Vector(highestX, myHero.pos.y, highestZ)
	local vec2 = Vector(highestX, myHero.pos.y, lowestZ)
	local vec3 = Vector(lowestX, myHero.pos.y, highestZ)
	local vec4 = Vector(lowestX, myHero.pos.y, lowestZ)
	
	avg = (vec1 + vec2 + vec3 + vec4) /4
	
	return avg
end

local function locate( table, value )
    for i = 1, #table do
        if table[i] == value then print( value ..' found' ) return true end
    end
    print(' not found' ) return false
end


local function RLogic()
	local RTarget = nil
	local Most = 0
	local ShouldCast = false
	local InFace = {}

	for i = 1, GameHeroCount() do
		local Hero = GameHero(i)
		if IsValid(Hero) and GetDistance(Hero.pos, myHero.pos) <= Menu.RS.Rrange:Value() then
			--local LS = LineSegment(myHero.pos, Hero.pos)
			--LS:__draw()
			table.insert(InFace, Hero)
		end
	end

	local IsFace = {}
	for r = 1, #InFace do
		local FHero = InFace[r]
		if IsFacing(FHero) then
			table.insert(IsFace, FHero)
		end
	end
	--print(#IsFace)
	local targets = {}
	avgCastPos = CalculateBoundingBoxAvg(IsFace,math.huge)
	for i = 1, #IsFace do
		local enemy = IsFace[i]
		local A = Vector(myHero.pos - enemy.pos)
		local B = Vector(myHero.pos - avgCastPos)
		if GetAngle(A,B) then
			table.insert(targets, enemy)
		end
	end
	--print(#targets)
	if #targets== #IsFace and #targets>= Menu.combo.Count:Value() then
	--	print(#targets)
		return targets, avgCastPos, #targets
	elseif #targets<#IsFace then	
		--print(FindFurthestTargetFromMe(IsFace))
		table.remove(IsFace, FindFurthestTargetFromMe(IsFace,avgCastPos))
		local targets = {}
		avgCastPos = CalculateBoundingBoxAvg(IsFace,math.huge)
		for i = 1, #IsFace do
			local enemy = IsFace[i]
			local A = Vector(myHero.pos - enemy.pos)
			local B = Vector(myHero.pos - avgCastPos)
			if GetAngle(A,B) then
				table.insert(targets, enemy)
			end
		end
		if #targets==#IsFace and #targets>= Menu.combo.Count:Value() then
	--		print(#targets)
			return targets, avgCastPos, #targets
		elseif #targets<#IsFace then	
			table.remove(IsFace, FindFurthestTargetFromMe(IsFace,avgCastPos))
			local targets = {}
			avgCastPos = CalculateBoundingBoxAvg(IsFace,math.huge)
			for i = 1, #IsFace do
				local enemy = IsFace[i]
				local A = Vector(myHero.pos - enemy.pos)
				local B = Vector(myHero.pos - avgCastPos)
				if GetAngle(A,B) then
					table.insert(targets, enemy)
				end
			end
			if #targets>= Menu.combo.Count:Value() then
				return targets, avgCastPos, #targets		
			end
		end
	end	
end

function KillR()
local target = GetTarget(Menu.RS.Rrange:Value())
if target == nil then return end

	if IsValid(target) and Ready(_R) then
		local EDmg = getdmg("E", target, myHero) * 3
		local QDmg = Ready(_Q) and getdmg("Q", target, myHero) or 0
		local WDmg = Ready(_W) and getdmg("W", target, myHero) or 0
		local RDmg = getdmg("R", target, myHero)
		local FullDmg = EDmg+QDmg+WDmg+RDmg
		if FullDmg > target.health then
			Control.CastSpell(HK_R, target.pos)
		end
	end
end



function Combo()
local target = GetTarget(800)
if target == nil then return end

	if IsValid(target) then
    local Dist = myHero.pos:DistanceTo(target.pos)

		if Menu.combo.E:Value() and Ready(_E) and Dist < ERange  then
            Control.CastSpell(HK_E, target)
        end

        -- if Menu.combo.Q:Value() and Ready(_Q) and not HasPoison(target) then 
            -- if Dist < QRange then
				-- if Menu.Pred.Change:Value() == 1 then
					-- local pred = GetGamsteronPrediction(target, QData, myHero)
					-- if pred.Hitchance >= Menu.Pred.PredQ:Value()+1 then
						-- Control.CastSpell(HK_Q, pred.CastPosition)
					-- end
				-- elseif Menu.Pred.Change:Value() == 2 then
					-- local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
					-- if pred.CastPos and ConvertToHitChance(Menu.Pred.PredQ:Value(), pred.HitChance) then
						-- Control.CastSpell(HK_Q, pred.CastPos)
					-- end
				-- else
					-- CastQGGPred(target)
				-- end
            -- end
        -- end

        -- if Menu.combo.W:Value() and Ready(_W) then
            -- if Dist < MaxWRange then
                -- if not IsFacing(target) and Dist < 525 then
					-- local castPos = Vector(target.pos):Extended(Vector(myHero.pos), -200)
					-- --DrawCircle(castPos, 50, 1, DrawColor(255, 225, 255, 10))
					-- Control.CastSpell(HK_W, castPos)
				-- elseif Dist < 600 then
					-- Control.CastSpell(HK_W, target.pos)
                -- end
            -- end
        -- end

		-- if Menu.combo.P:Value() and myHero.health/myHero.maxHealth < Menu.combo.HP:Value()/100 and Ready(_R) then
			-- if myHero:GetSpellData(SUMMONER_1).name == "SummonerHaste" and Ready(SUMMONER_1) then
				-- Control.CastSpell(HK_SUMMONER_1)
			-- elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHaste" and Ready(SUMMONER_2) then
				-- Control.CastSpell(HK_SUMMONER_2)
			-- end

			-- if Dist < Menu.RS.Rrange:Value() and IsFacing(target) then
				-- Control.CastSpell(HK_R, target.pos)
			-- end
		-- end

		if Menu.combo.R:Value() and Ready(_R) then
			local RTargets, castpos, number = RLogic()
			if number and (_G.SDK.TargetSelector.Selected==nil or locate(RTargets,_G.SDK.TargetSelector.Selected)) then
				print(number)
				Control.CastSpell(HK_R, castpos)
			end
		end
	end
end

function SemiR()
local target = GetTarget(Menu.RS.Rrange:Value())
if target == nil then return end
	if IsValid(target) and Ready(_R) then
		Control.CastSpell(HK_R, target.pos)
	end
end
--  and _G.SDK.HealthPrediction:GetPrediction(minion,(math.max(myHero.attackData.endTime-Game.Timer(),0)+myHero.attackData.windUpTime+ (minion.distance/1200)+ 0.06))<=15 then
ethisminion=nil
ethisminiontime=0
function Lasthit()
	_G.SDK.Orbwalker.ForceTarget=nil
	if ethisminion and _G.SDK.Attack:IsActive()==false and Ready(_E) then
		if(ethisminion and IsValid(ethisminion))  then
			if ethisminiontime+1>Game.Timer() and ethisminiontime+myHero.attackData.windUpTime<Game.Timer() then
				Control.CastSpell(HK_E, ethisminion)
				ethisminion=nil
				print("E minion"..Game.Timer())
			elseif ethisminiontime+1<Game.Timer() then
				ethisminion=nil
			end
		else 
			ethisminion=nil
		end
	end
	local edmg = EdmgCreep()
	local pedmg =PEdmgCreep()
	local mana_ok = myHero.mana/myHero.maxMana >= Menu.mana.EW:Value() / 100
	
	if  mana_ok and Ready(_E) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(ERange) 
		for i = 1, #minions do
			local minion = minions[i]
			if(minion and IsValid(minion)) then
				if minion.distance <= ERange then	
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.125 + (minion.distance/2500)+0.05)									
					if  ((hp- edmg <= 0) or (HasPoison(minion) and (hp- pedmg <= 0))) then
						Control.CastSpell(HK_E, minion)
						return
					end

				end
			end
		end
		--if  then
			for i = 1, #minions do
				local minion = minions[i]
				if Menu.clear.E:Value() and (minion and IsValid(minion)) and ethisminion==nil then
					if minion.distance <= 650 then	
						local hp = _G.SDK.HealthPrediction:GetPrediction(minion,myHero.attackData.windUpTime+ (minion.distance/1200)+0.05)		
						if myHero.attackData.state == STATE_ATTACK and (hp > 0) and  ((hp- edmg - myHero.totalDamage <= 0) or (HasPoison(minion) and (hp- pedmg- myHero.totalDamage<= 0)))  then
							_G.SDK.Orbwalker.ForceTarget = minion
							_G.SDK.Orbwalker:Attack(minion)
							ethisminiontime=Game.Timer()
							ethisminion=minion

							print("setup minion"..Game.Timer())
							return
						end
					end
				end
			end
		--end
	end
end

function Harass()
local target = GetTarget(950)
if target == nil then return end

	if IsValid(target) then
		local EDmg = getdmg("E", target, myHero) * 2
		local Dist = myHero.pos:DistanceTo(target.pos)

		if Dist < ERange and Menu.harass.E:Value() and Ready(_E) and (HasPoison(target) or EDmg > target.health) then
            Control.CastSpell(HK_E, target)
        end

        if Dist < QRange and Menu.harass.Q:Value() and Ready(_Q) and myHero.mana/myHero.maxMana > Menu.mana.Q:Value()/100 then
			if Menu.Pred.Change:Value() == 1 then
				local pred = GetGamsteronPrediction(target, QData, myHero)
				if pred.Hitchance >= Menu.Pred.PredQ:Value()+1 then
					Control.CastSpell(HK_Q, pred.CastPosition)
				end
			elseif Menu.Pred.Change:Value() == 2 then
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and ConvertToHitChance(Menu.Pred.PredQ:Value(), pred.HitChance) then
					Control.CastSpell(HK_Q, pred.CastPos)
				end
			else
				CastQGGPred(target)
			end
        end
	end
end

function Clear()
	for i = 1, GameMinionCount() do
	local minion = GameMinion(i)
		if minion.team == TEAM_ENEMY and IsValid(minion) then
		local mana_ok = myHero.mana/myHero.maxMana >= Menu.mana.QW:Value() / 100

			if Menu.clear.Q:Value() and mana_ok and myHero.pos:DistanceTo(minion.pos) <= QRange and Ready(_Q) then
				Control.CastSpell(HK_Q, minion.pos)
			end

			if Menu.clear.W:Value() and mana_ok and Ready(_W) then
				if myHero.pos:DistanceTo(minion.pos) < MaxWRange and MinionsNear(minion,500) >= Menu.clear.Count:Value() then
					Control.CastSpell(HK_W, minion.pos)
				end
			end
		end
	end
end

function JClear()
	for i = 1, GameMinionCount() do
	local Minion = GameMinion(i)

		if Minion.team == TEAM_JUNGLE then
		local Dist = myHero.pos:DistanceTo(Minion.pos)

			if IsValid(Minion) and Dist < QRange then
				if Menu.jclear.Q:Value() and Ready(_Q) and myHero.mana/myHero.maxMana > Menu.mana.QW:Value()/100 then
					Control.CastSpell(HK_Q, Minion.pos)

				end
			end

			if IsValid(Minion) and Dist < MaxWRange then
				if Menu.jclear.W:Value() and Ready(_W) and myHero.mana/myHero.maxMana > Menu.mana.WW:Value()/100 then
					Control.CastSpell(HK_W, Minion.pos)

				end
			end

			if IsValid(Minion) and Dist < ERange then
				if Menu.jclear.E:Value() and Ready(_E) then
					if HasPoison(Minion) then
						Control.CastSpell(HK_E, Minion)
						return
					elseif EdmgCreep() > Minion.health then
						Control.CastSpell(HK_E, Minion)
						return
					else
						if HasPoison(Minion) and PEdmgCreep() > Minion.health then
							Control.CastSpell(HK_E, Minion)
						end
					end
				end
			end
		end
	end
end

function KsE()
local target = GetTarget(700)
if target == nil then return end
	if IsValid(target) then
		local EDmg = getdmg("E", target, myHero) * 2
		local PEDmg = getdmg("E", target, myHero)

		if Menu.ks.E:Value() and Ready(_E) then

			if HasPoison(target) and PEDmg > target.health then
				Control.CastSpell(HK_E, target)
			end

			if EDmg > target.health then
				Control.CastSpell(HK_E, target)
			end
		end
	end
end

function KsQ()
local target = GetTarget(900)
if target == nil then return end

	if IsValid(target) then
		if Menu.ks.Q:Value() and Ready(_Q) then
			local QDmg = getdmg("Q", target, myHero)
			if QDmg > target.health then
				if Menu.Pred.Change:Value() == 1 then
					local pred = GetGamsteronPrediction(target, QData, myHero)
					if pred.Hitchance >= Menu.Pred.PredQ:Value()+1 then
						Control.CastSpell(HK_Q, pred.CastPosition)
					end
				elseif Menu.Pred.Change:Value() == 2 then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
					if pred.CastPos and ConvertToHitChance(Menu.Pred.PredQ:Value(), pred.HitChance) then
						Control.CastSpell(HK_Q, pred.CastPos)
					end
				else
					CastQGGPred(target)
				end
			end
		end
	end
end

function KsW()
local target = GetTarget(700)
if target == nil then return end

	if IsValid(target) then
		if Menu.ks.W:Value() and Ready(_W) then
			local WDmg = getdmg("W", target, myHero)
			if WDmg > target.health then
				Control.CastSpell(HK_W, target.pos)
			end
		end
	end
end

function AutoE()
	local edmg = EdmgCreep()
	local pedmg =PEdmgCreep()
	local mana_ok = myHero.mana/myHero.maxMana >= Menu.mana.EW:Value() / 100
	if Menu.clear.E:Value() and mana_ok and Ready(_E) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(ERange) 
		for i = 1, #minions do
			local minion = minions[i]
			if(minion and IsValid(minion)) then
				if minion.distance <= ERange then	
					local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.125 + (minion.distance/2500))
					if (hp > 0) and ((hp- edmg <= 0) or (HasPoison(minion) and (hp- pedmg <= 0))) and _G.SDK.HealthPrediction:GetPrediction(minion,(math.max(myHero.attackData.endTime-Game.Timer(),0)+myHero.attackData.windUpTime+ (minion.distance/1200)+ 0.06))<=15 then
						Control.CastSpell(HK_E, minion)
						return
					end
				--	local PDmg = CalcDamage(myHero, minion, 2, PEdmgCreep())
				--	local EDmg = CalcDamage(myHero, minion, 2, EdmgCreep())
					-- if HasPoison(minion) and PDmg  > minion.health then
						-- if PEdmgCreep() > minion.health then
							-- Control.CastSpell(HK_E, minion)
						-- end
					-- end
					

				end
			end
		end
	end
end

function CastQGGPred(unit)
	local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.65, Radius = 80, Range = 900, Speed = MathHuge, Collision = false})
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(Menu.Pred.PredQ:Value()+1) then
		result = Control.CastSpell(HK_Q, QPrediction.CastPosition)
	end
end
