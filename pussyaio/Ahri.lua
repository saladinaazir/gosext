local function GotBuff(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff.count
    end
  end
  return 0
end
local LocalGameHeroCount 	= Game.HeroCount
local LocalGameHero 		= Game.Hero
local _Q			= _Q
local _W			= _W
local _E			= _E
local _R		        = _R
local READY 		        = READY
local LocalTableInsert          = table.insert
local LocalTableSort            = table.sort
local LocalTableRemove          = table.remove;
local tonumber		        = tonumber
local ipairs		        = ipairs
local pairs		        = pairs

local GetEnemyHeroes = function()
        local result = {}
	for i = 1, LocalGameHeroCount() do
		local Hero = LocalGameHero(i)
		if Hero.isEnemy then
			LocalTableInsert(result, Hero)
		end
	end
	return result
end



local forcedTarget
local lastSpellCast = Game.Timer()
local qPointsUpdatedAt = Game.Timer()
local qLastChecked = 1
enemyPaths = {}

local function GetEnemyHeroes()
    local _EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local unit = GameHero(i)
        if unit.isEnemy then
            table.insert(_EnemyHeroes, unit)
        end
    end
    return _EnemyHeroes
end

local function GetTargetMS(target)
	local ms = target.pathing.isDashing and target.pathing.dashSpeed or target.ms
	return ms
end

local function GetPathNodes(unit)
	local nodes = {}
	table.insert(nodes, unit.pos)
	if unit.pathing.hasMovePath then
		for i = unit.pathing.pathIndex, unit.pathing.pathCount do
			path = unit:GetPath(i)
			table.insert(nodes, path)
		end
	end		
	return nodes
end

local function PredictUnitPosition(unit, delay)
	local predictedPosition = unit.pos
	local timeRemaining = delay
	local pathNodes = GetPathNodes(unit)
	for i = 1, #pathNodes -1 do
		local nodeDistance = GetDistance(pathNodes[i], pathNodes[i +1])
		local nodeTraversalTime = nodeDistance / GetTargetMS(unit)
			
		if timeRemaining > nodeTraversalTime then
			timeRemaining =  timeRemaining - nodeTraversalTime
			predictedPosition = pathNodes[i + 1]
		else
			local directionVector = (pathNodes[i+1] - pathNodes[i]):Normalized()
			predictedPosition = pathNodes[i] + directionVector *  GetTargetMS(unit) * timeRemaining
			break;
		end
	end
	return predictedPosition
end

local function VectorPointProjectionOnLineSegment(v1, v2, v)
	assert(v1 and v2 and v, "VectorPointProjectionOnLineSegment: wrong argument types (3 <Vector> expected)")
	local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
	local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
	local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
	local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
	local isOnSegment = rS == rL
	local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
	return pointSegment, pointLine, isOnSegment
end

local function GetLineTargetCount(source, Pos, delay, speed, width)
	local Count = 0
	for i = 1, GameMinionCount() do
		local minion = GameMinion(i)
		if minion and minion.team == TEAM_ENEMY and myHero.pos:DistanceTo(minion.pos) <= 1050 and IsValid(minion) then
			
			local predictedPos = PredictUnitPosition(minion, delay+ GetDistance(source, minion.pos) / speed)
			local proj1, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(source, Pos, predictedPos)
			if proj1 and isOnSegment and (GetDistanceSqr(predictedPos, proj1) <= (minion.boundingRadius + width) * (minion.boundingRadius + width)) then
				Count = Count + 1
			end
		end
	end
	return Count
end

local function CheckEnemyCollision(location, radius, delay, maxDistance)
	if not maxDistance then
		maxDistance = 1100
	end
	for i, hero in ipairs(GetEnemyHeroes()) do
		if IsValid(hero) and GetDistance(hero.pos, location) < maxDistance then
			local predictedPosition = PredictUnitPosition(hero, delay)
			if GetDistance(location, predictedPosition) < radius + hero.boundingRadius then
				return true, hero
			end
		end
	end
	
	return false
end

local function CheckMinionIntercection(location, radius, delay, maxDistance)
	if not maxDistance then
		maxDistance = 1200
	end
	for i = 1, GameMinionCount() do
		local minion = GameMinion(i)
		if minion.isEnemy and minion.isTargetable and minion.alive and GetDistance(minion.pos, location) < maxDistance then
			local predictedPosition = PredictUnitPosition(minion, delay)
			if GetDistance(location, predictedPosition) <= radius + minion.boundingRadius then
				return true
			end
		end
	end
	
	return false
end

local function CalculateNode(missile, nodePos)
	local result = {}
	result["pos"] = nodePos
	result["delay"] = 0.251 + GetDistance(missile.pos, nodePos) / Q2.Speed
	
	local isCollision = false
	local hitEnemy 
	if not isCollision then
		isCollision, hitEnemy = CheckEnemyCollision(nodePos, 35, result["delay"])
	end
	
	result["playerHit"] = hitEnemy
	result["collision"] = isCollision
	return result
end





local function IsImmobileTarget(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false	
end

local function GetMinionCount(range, pos)
    local pos = pos.pos
	local count = 0
	for i = 1,GameMinionCount() do
	local hero = GameMinion(i)
	local Range = range * range
		if hero.team ~= TEAM_ALLY and hero.dead == false and GetDistanceSqr(pos, hero.pos) < Range then
		count = count + 1
		end
	end
	return count
end

local function IsUltPosUnderTurret(Pos)
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        local range = (turret.boundingRadius + 750 + myHero.boundingRadius / 2)
        if turret.isEnemy and not turret.dead then
            if turret.pos:DistanceTo(Pos) < range then
                return true
            end
        end
    end
    return false
end

local function IsUnderTurret(unit)
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
        if turret.isEnemy and not turret.dead then
            if turret.pos:DistanceTo(unit.pos) < range then
                return true
            end
        end
    end
    return false
end

function LoadScript() 	 
	
	Menu = MenuElement({type = MENU, id = "PussyAIO".. myHero.charName, name = myHero.charName})
	Menu:MenuElement({name = " ", drop = {"Version 0.12"}})
	
	--ComboMenu
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.Combo:MenuElement({id = "UseQbeforeE", name = "[Q] can be used before E when r not up", value = true,key=string.byte("S"), toggle=true})
	Menu.Combo:MenuElement({id = "efkey", name = "eflashkey", value = false,key=string.byte("A"), toggle=false})
	Menu.Combo:MenuElement({id = "fkey", name = "LoL hotkey for your flash",key=string.byte("O")})
	Menu.Combo:MenuElement({id = "UseW", name = "[W]", value = true})
	Menu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})
	Menu.Combo:MenuElement({id = "UseR", name = "[R]", value = true})	
	Menu.Combo:MenuElement({type = MENU, name = "e White List",  id = "WhiteList"})
        for i, Enemy in pairs(GetEnemyHeroes()) do
        	Menu.Combo.WhiteList:MenuElement({name = Enemy.charName,  id = Enemy.charName, value = true})
        end

	--HarassMenu
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.Harass:MenuElement({id = "UseW", name = "[W]", value = true})
	Menu.Harass:MenuElement({id = "UseE", name = "[E]", value = true})	
	Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
	
	--LaneClear Menu
	Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
	Menu.Clear:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.Clear:MenuElement({id = "Qmin", name = "[Q] If Hit X Minion ", value = 2, min = 1, max = 6, step = 1, identifier = "Minion/s"})
	Menu.Clear:MenuElement({id = "UseW", name = "[W]", value = true})	
	Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to LaneClear", value = 40, min = 0, max = 100, identifier = "%"})
	
	--JungleClear
	Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
	Menu.JClear:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.JClear:MenuElement({id = "UseW", name = "[W]", value = true})	
	Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
		
	--AutoSpell on CC
	Menu:MenuElement({type = MENU, id = "CC", name = "AutoSpells on CC"})
	Menu.CC:MenuElement({id = "UseQ", name = "Q", value = true})
	Menu.CC:MenuElement({id = "UseE", name = "E", value = true})
	
	--Prediction
	Menu:MenuElement({type = MENU, id = "Pred", name = "Prediction"})
	Menu.Pred:MenuElement({name = " ", drop = {"After change Pred.Typ reload 2x F6"}})
	Menu.Pred:MenuElement({id = "Change", name = "Change Prediction Typ", value = 3, drop = {"Gamsteron Prediction", "Premium Prediction", "GGPrediction"}})	
	Menu.Pred:MenuElement({id = "PredQ", name = "Hitchance[Q]", value = 1, drop = {"Normal", "High", "Immobile"}})	
	Menu.Pred:MenuElement({id = "PredE", name = "Hitchance[E]", value = 1, drop = {"Normal", "High", "Immobile"}})	
	
	--Drawing
	Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
	Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw[Q]", value = false})
	Menu.Drawing:MenuElement({id = "DrawW", name = "Draw[W]", value = false})
	Menu.Drawing:MenuElement({id = "DrawE", name = "Draw[E]", value = false})
	Menu.Drawing:MenuElement({id = "DrawR", name = "Draw[R]", value = false})		
	
	QData =
	{
	Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 880, Speed = 1300, Collision = false
	}
	
	QspellData = {speed = 1550, range = 880, delay = 0.25, radius = 100, collision = {nil}, type = "linear"}		

	EData =
	{
	Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1600, Collision = true, CollisionTypes = {_G.COLLISION_MINION}
	}
	
	EspellData = {speed = 1600, range = 975, delay = 0.25, radius = 60, collision = {"minion"}, type = "linear"}		

  	                                          
	Callback.Add("Tick", function() Tick() end)
	local flashData = myHero:GetSpellData(SUMMONER_1).name:find("Flash") and SUMMONER_1 or myHero:GetSpellData(SUMMONER_2).name:find("Flash") and SUMMONER_2 or nil
	
	Callback.Add("Draw", function()
		if myHero.dead then return end
		
		
		
		    

    if Menu.Combo.UseQbeforeE:Value() then
        Draw.Text("Q: On ",20,myHero.pos:To2D(),Draw.Color(255 ,0,255,0))
    else
        Draw.Text("Q: Off ",20,myHero.pos:To2D(),Draw.Color(255 ,255,0,0))

    end

		if Menu.Drawing.DrawQ:Value() and Ready(_Q) then
		DrawCircle(myHero, 900, 1, DrawColor(225, 225, 0, 10))
		end
		if Menu.Drawing.DrawW:Value() and Ready(_W) then
		DrawCircle(myHero, 700, 1, DrawColor(225, 225, 0, 10))
		end
		if Menu.Drawing.DrawE:Value() and Ready(_E) then
		DrawCircle(myHero, 975, 1, DrawColor(225, 225, 0, 10))
		end
		if Menu.Drawing.DrawR:Value() and Ready(_R) then
		DrawCircle(myHero, 450, 1, DrawColor(225, 225, 0, 10))
		end		
	end)		
end
local function CheckCol(source, startPos, minion, endPos, delay, speed, range, radius)
	if source.networkID == minion.networkID then 
		return false
	end
	
	if _G.SDK and _G.SDK.Orbwalker and startPos and minion and minion.pos and minion.type ~= myHero.type and _G.SDK.HealthPrediction:GetPrediction(minion, delay + GetDistance(startPos, minion.pos) / speed - Game.Latency()/1000) < 0 then
		return false
	end
	
	local waypoints = GetPathNodes(minion)
	local MPos, CastPosition = #waypoints == 1 and Vector(minion.pos) or PredictUnitPosition(minion, delay)
	
	if startPos and MPos and GetDistanceSqr(startPos, MPos) <= (range)^2 and GetDistanceSqr(startPos, minion.pos) <= (range + 100)^2 then
		local buffer = (#waypoints > 1) and 8 or 0 
		
		if minion.type == myHero.type then
			buffer = buffer + minion.boundingRadius
		end
		
		if #waypoints > 1 then
			local proj1, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(startPos, endPos, Vector(MPos))
			if proj1 and isOnSegment and (GetDistanceSqr(MPos, proj1) <= (minion.boundingRadius + radius + buffer) ^ 2) then				
				return true		
			end
		end
		
		local proj2, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(startPos, endPos, Vector(minion.pos))
		if proj2 and isOnSegment and (GetDistanceSqr(minion.pos, proj2) <= (minion.boundingRadius + radius + buffer) ^ 2) then
			return true
		end
	end
end

local function CheckMinionCollisionGG(source, endPos, delay, radius, speed, range, start)
	local startPos = myHero.pos
	if start then
		startPos = start
	end
		
	for i, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(range)) do
		if CheckCol(source, startPos, minion, endPos, delay, speed ,range,  radius) then
			return true
		end
	end
	for i, minion in ipairs(_G.SDK.ObjectManager:GetMonsters(range)) do
		if CheckCol(source, startPos, minion, endPos, delay, speed ,range,  radius) then
			return true
		end
	end
	for i, minion in ipairs(_G.SDK.ObjectManager:GetOtherEnemyMinions(range)) do
		if minion.team ~= myHero.team and CheckCol(source, startPos, minion, endPos, delay, speed ,range,  radius) then
			return true
		end
	end
	
	return false
end

local function UpdateTargetPaths()
	for i, enemy in ipairs(GetEnemyHeroes()) do
		if enemy.isEnemy then
			if not enemyPaths[enemy.charName] then
				enemyPaths[enemy.charName] = {}
			end
			
			if enemy.pathing and enemy.pathing.hasMovePath and enemyPaths[enemy.charName] and GetDistance(enemy.pathing.endPos, Vector(enemyPaths[enemy.charName].endPos)) > 56 then				
				enemyPaths[enemy.charName]["time"] = Game.Timer()
				enemyPaths[enemy.charName]["endPos"] = enemy.pathing.endPos					
			end
		end
	end
end

function Tick()
if MyHeroNotReady() then return end
	if Menu.Combo.efkey:Value() then
	UpdateTargetPaths()
				--	_G.SDK.Orbwalker:Orbwalk()
					target=GetHeroTarget(1370)
					if target==nil or not Ready(_E) then return end
					-- if castflash and castflash+0.2>Game.Timer() then
								-- if _G.SDK.Cursor.Step == 0 then
									-- _G.SDK.Cursor:Add(string.byte("O"), myHero.pos:Extended(Vector(mousePos), 600))
									-- castflash=nil
									-- return
								-- end
					-- end
					if (myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and Ready(SUMMONER_1)) or (myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and Ready(SUMMONER_2))  then
						local EPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.2, Radius = 60, Range = 1300, Speed = 1650, Collision = false})
						EPrediction:GetPrediction(target, myHero)
						--if EPrediction:CanHit(1)  then myHero.pos:Extended(Vector(mousePos), 600) CheckMinionCollisionGG(source, endPos, delay, radius, speed, range, start)
						local flashpos= (myHero.pos:DistanceTo(mousePos)<400 and mousePos) or myHero.pos:Extended(Vector(mousePos), 400)
						if EPrediction:CanHit() and not CheckMinionCollisionGG(myHero, EPrediction.CastPosition, 0.25, 60, 1550, 1000,flashpos) then
							Control.CastSpell(HK_E, EPrediction.CastPosition)
							local castflash=Game.Timer()
								 DelayAction(function() 
								
									if castflash and castflash+0.23>Game.Timer() then
											if _G.SDK.Cursor.Step == 0 then
												_G.SDK.Cursor:Add(Menu.Combo.fkey:Key(), flashpos)
												print("0.15")
												castflash=nil
												return
											end
									end
								
								end, 0.15)
																DelayAction(function() 
								
								--_G.SDK.Cursor:Add(string.byte("O"), myHero.pos:Extended(Vector(mousePos), 600)) 
									if castflash and castflash+0.23>Game.Timer() then
											if _G.SDK.Cursor.Step == 0 then
												_G.SDK.Cursor:Add(Menu.Combo.fkey:Key(), flashpos)
												print("0.17")
												castflash=nil
												return
											end
									end
								
								end, 0.17)


						end
						--end
					else
						local EPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
						EPrediction:GetPrediction(target, myHero)
							if EPrediction:CanHit(1) then
								Control.CastSpell(HK_E, EPrediction.CastPosition)
							end
					end


	end

local Mode = GetMode()
	if Mode == "Combo" then
		Combo()
	elseif Mode == "Harass" then
		Harass()
	elseif Mode == "Clear" then
		Clear()
		JungleClear()
	end	
	CC()
end

function GetHeroTarget(range)
    local EnemyHeroes = _G.SDK.ObjectManager:GetEnemyHeroes(range, false)
    local target = _G.SDK.TargetSelector:GetTarget(EnemyHeroes)

    return target
end


function Combo()
local target = GetHeroTarget(1500)
if target == nil then return end                                                                   
	if IsValid(target) then    
	local Rcast = false	
	local Ecast = false		
		if Ready(_R) then	
			local buff = GotBuff(myHero, "AhriTumble")
			if myHero.pos:DistanceTo(target.pos) < 1000 and Menu.Combo.UseR:Value() and Ready(_R) and buff == 0 then
				if myHero.pos:DistanceTo(target.pos) < 550 then
					local castPos = target.pos:Extended(mousePos, 550)
					if not IsUltPosUnderTurret(castPos) then
						Rcast = Control.CastSpell(HK_R, castPos)
					end	
				else 
					if not IsUnderTurret(target) then
						Rcast = Control.CastSpell(HK_R, target.pos)	
					end	
				end	
			end	
			
			if not Ecast and myHero.pos:DistanceTo(target.pos) < 1000 and Menu.Combo.UseR:Value() and Ready(_R) and buff == 2 then
				if myHero.pos:DistanceTo(target.pos) < 550 then
					local castPos = target.pos:Extended(mousePos, 550)
					if not IsUltPosUnderTurret(castPos) then
						Rcast = Control.CastSpell(HK_R, castPos)
					end	
				else 
					if not IsUnderTurret(target) then
						Rcast = Control.CastSpell(HK_R, target.pos)	
					end	
				end	
			end

			if not Ecast and myHero.pos:DistanceTo(target.pos) < 1000 and Menu.Combo.UseR:Value() and Ready(_R) and buff == 1 then
				if myHero.pos:DistanceTo(target.pos) < 550 then
					local castPos = Vector(target) - (Vector(myHero) - Vector(target)):Perpendicular():Normalized() * 350
					if not IsUltPosUnderTurret(castPos) then
						Rcast = Control.CastSpell(HK_R, castPos)
					end
				else 
					if not IsUnderTurret(target) then
						Rcast = Control.CastSpell(HK_R, target.pos)	
					end	
				end					
			end			
			
			if myHero.pos:DistanceTo(target.pos) <= 975 and Menu.Combo.UseE:Value() and Ready(_E) then
				if Menu.Pred.Change:Value() == 1 then
					local pred = GetGamsteronPrediction(target, EData, myHero)
					if pred.Hitchance >= Menu.Pred.PredE:Value()+1 then
						Control.CastSpell(HK_E, pred.CastPosition)
					end
				elseif Menu.Pred.Change:Value() == 2 then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, EspellData)
					if pred.CastPos and ConvertToHitChance(Menu.Pred.PredE:Value(), pred.HitChance) then
						Control.CastSpell(HK_E, pred.CastPos)
					end
				else
					local EPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
					EPrediction:GetPrediction(target, myHero)
					if EPrediction:CanHit(Menu.Pred.PredE:Value() + 1) then
						Control.CastSpell(HK_E, EPrediction.CastPosition)
					end				
				end
			end			
			
			if (Ecast or Menu.Combo.UseQbeforeE:Value()) and myHero.pos:DistanceTo(target.pos) <= 880 and Menu.Combo.UseQ:Value() and Ready(_Q) then
				if Menu.Pred.Change:Value() == 1 then
					local pred = GetGamsteronPrediction(target, QData, myHero)
					if pred.Hitchance >= Menu.Pred.PredQ:Value()+1 then
						Control.CastSpell(HK_Q, pred.CastPosition)
					end
				elseif Menu.Pred.Change:Value() == 2 then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QspellData)
					if pred.CastPos and ConvertToHitChance(Menu.Pred.PredQ:Value(), pred.HitChance) then
						Control.CastSpell(HK_Q, pred.CastPos)
					end
				else
					local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 880, Speed = 1300, Collision = false})
					QPrediction:GetPrediction(target, myHero)
					if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
						Control.CastSpell(HK_Q, QPrediction.CastPosition)
					end				
				end
			end

			if myHero.pos:DistanceTo(target.pos) <= 700 and Menu.Combo.UseW:Value() and Ready(_W) then
				Control.CastSpell(HK_W)
			end
		
		else
		
			if myHero.pos:DistanceTo(target.pos) <= 975 and Menu.Combo.UseE:Value() and Ready(_E) and Menu.Combo.WhiteList[target.charName]:Value() then
				if Menu.Pred.Change:Value() == 1 then
					local pred = GetGamsteronPrediction(target, EData, myHero)
					if pred.Hitchance >= Menu.Pred.PredE:Value()+1 then
						Control.CastSpell(HK_E, pred.CastPosition)
					end
				elseif Menu.Pred.Change:Value() == 2 then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, EspellData)
					if pred.CastPos and ConvertToHitChance(Menu.Pred.PredE:Value(), pred.HitChance) then
						Control.CastSpell(HK_E, pred.CastPos)
					end
				else
					local EPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
					EPrediction:GetPrediction(target, myHero)
					if EPrediction:CanHit(Menu.Pred.PredE:Value() + 1) then
						Control.CastSpell(HK_E, EPrediction.CastPosition)
					end				
				end
			end			
			
			if myHero.pos:DistanceTo(target.pos) <= 880 and Menu.Combo.UseQ:Value() and Ready(_Q) and (not Ready(_E) or Menu.Combo.UseQbeforeE:Value())  then
				if Menu.Pred.Change:Value() == 1 then
					local pred = GetGamsteronPrediction(target, QData, myHero)
					if pred.Hitchance >= Menu.Pred.PredQ:Value()+1 then
						Control.CastSpell(HK_Q, pred.CastPosition)
					end
				elseif Menu.Pred.Change:Value() == 2 then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QspellData)
					if pred.CastPos and ConvertToHitChance(Menu.Pred.PredQ:Value(), pred.HitChance) then
						Control.CastSpell(HK_Q, pred.CastPos)
					end
				else
					local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 880, Speed = 1300, Collision = false})
					QPrediction:GetPrediction(target, myHero)
					if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
						Control.CastSpell(HK_Q, QPrediction.CastPosition)
					end				
				end
			end

			if myHero.pos:DistanceTo(target.pos) <= 700 and Menu.Combo.UseW:Value() and Ready(_W) then
				Control.CastSpell(HK_W)
			end		
		end	
	end
end

function Harass()
local target = GetHeroTarget(1000)
if target == nil then return end
	if IsValid(target) and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if myHero.pos:DistanceTo(target.pos) <= 975 and Menu.Harass.UseE:Value() and Ready(_E) then
			if Menu.Pred.Change:Value() == 1 then
				local pred = GetGamsteronPrediction(target, EData, myHero)
				if pred.Hitchance >= Menu.Pred.PredE:Value()+1 then
					Control.CastSpell(HK_E, pred.CastPosition)
				end
			elseif Menu.Pred.Change:Value() == 2 then
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, EspellData)
				if pred.CastPos and ConvertToHitChance(Menu.Pred.PredE:Value(), pred.HitChance) then
					Control.CastSpell(HK_E, pred.CastPos)
				end
			else
				local EPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
				EPrediction:GetPrediction(target, myHero)
				if EPrediction:CanHit(Menu.Pred.PredE:Value() + 1) then
					Control.CastSpell(HK_E, EPrediction.CastPosition)
				end				
			end
		end		
		
		if myHero.pos:DistanceTo(target.pos) <= 880 then	
			if Menu.Harass.UseQ:Value() and Ready(_Q) then
				if Menu.Pred.Change:Value() == 1 then
					local pred = GetGamsteronPrediction(target, QData, myHero)
					if pred.Hitchance >= Menu.Pred.PredQ:Value()+1 then
						Control.CastSpell(HK_Q, pred.CastPosition)
					end
				elseif Menu.Pred.Change:Value() == 2 then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QspellData)
					if pred.CastPos and ConvertToHitChance(Menu.Pred.PredQ:Value(), pred.HitChance) then
						Control.CastSpell(HK_Q, pred.CastPos)
					end
				else
					local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 880, Speed = 1300, Collision = false})
					QPrediction:GetPrediction(target, myHero)
					if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
						Control.CastSpell(HK_Q, QPrediction.CastPosition)
					end				
				end
			end
		end

		if myHero.pos:DistanceTo(target.pos) <= 700 then	
			if Menu.Harass.UseW:Value() and Ready(_W) then
				Control.CastSpell(HK_W)
			end
		end
	end
end	

function Clear()
	for i = 1, GameMinionCount() do
    local minion = GameMinion(i)
		if myHero.pos:DistanceTo(minion.pos) <= 1000 and minion.team == TEAM_ENEMY and IsValid(minion) and myHero.mana/myHero.maxMana >= Menu.Clear.Mana:Value() / 100 then
			
			if myHero.pos:DistanceTo(minion.pos) <= 880 and Menu.Clear.UseQ:Value() and Ready(_Q) then
				local count = GetMinionCount(150, minion)
				if count >= Menu.Clear.Qmin:Value() then
					Control.CastSpell(HK_Q, minion.pos)
				end
			end
			
			if myHero.pos:DistanceTo(minion.pos) <= 700 and Menu.Clear.UseW:Value() and Ready(_W) then
				Control.CastSpell(HK_W)
			end			
		end
	end
end

function JungleClear()
	for i = 1, GameMinionCount() do
    local minion = GameMinion(i)
		if myHero.pos:DistanceTo(minion.pos) <= 1000 and minion.team == TEAM_JUNGLE and IsValid(minion) and myHero.mana/myHero.maxMana >= Menu.JClear.Mana:Value() / 100 then
			
			if myHero.pos:DistanceTo(minion.pos) <= 880 and Menu.JClear.UseQ:Value() and Ready(_Q) then
				Control.CastSpell(HK_Q, minion.pos)
			end
			
			if myHero.pos:DistanceTo(minion.pos) <= 700 and Menu.JClear.UseW:Value() and Ready(_W) then
				Control.CastSpell(HK_W)
			end			
		end
	end
end

function CC()
local target = GetHeroTarget(1000)
if target == nil then return end
local Immobile = IsImmobileTarget(target)	
	if Immobile and IsValid(target) then	
		if myHero.pos:DistanceTo(target.pos) <= 975 and Menu.CC.UseE:Value() and Ready(_E) then
			if Menu.Pred.Change:Value() == 1 then
				local pred = GetGamsteronPrediction(target, EData, myHero)
				if pred.Hitchance >= Menu.Pred.PredE:Value()+1 then
					Control.CastSpell(HK_E, pred.CastPosition)
				end
			elseif Menu.Pred.Change:Value() == 2 then
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, EspellData)
				if pred.CastPos and ConvertToHitChance(Menu.Pred.PredE:Value(), pred.HitChance) then
					Control.CastSpell(HK_E, pred.CastPos)
				end
			else
				local EPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
				EPrediction:GetPrediction(target, myHero)
				if EPrediction:CanHit(Menu.Pred.PredE:Value() + 1) then
					Control.CastSpell(HK_E, EPrediction.CastPosition)
				end				
			end
		end
		
		if myHero.pos:DistanceTo(target.pos) <= 880 and Menu.CC.UseQ:Value() and Ready(_Q) then
			if Menu.Pred.Change:Value() == 1 then
				local pred = GetGamsteronPrediction(target, QData, myHero)
				if pred.Hitchance >= Menu.Pred.PredQ:Value()+1 then
					Control.CastSpell(HK_Q, pred.CastPosition)
				end
			elseif Menu.Pred.Change:Value() == 2 then
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QspellData)
				if pred.CastPos and ConvertToHitChance(Menu.Pred.PredQ:Value(), pred.HitChance) then
					Control.CastSpell(HK_Q, pred.CastPos)
				end
			else
				local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 880, Speed = 1300, Collision = false})
				QPrediction:GetPrediction(target, myHero)
				if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
				end				
			end
		end	
	end
end
