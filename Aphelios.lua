function GetDistanceSqr(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

function GetDistance(Pos1, Pos2)
	return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function GetEnemyHeroes()
	local EnemyHeroes = {}
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isEnemy then
			table.insert(EnemyHeroes, Hero)
		end
	end
	return EnemyHeroes
end

function GetEnemyCount(range, pos)
	local count = 0
	for i, hero in ipairs(GetEnemyHeroes()) do
	local Range = range * range
		if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

function GetTarget(range)
	if _G.SDK then
		return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
	end
end

function GotBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return buff.count
		end
	end
	return 0
end

function IsReady(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
	if _G.SDK then
		if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			return "Combo"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			return "Harass"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
			return "LaneClear"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
			return "LastHit"
		elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
			return "Flee"
		end
	end
end

function SetMovement(bool)	
	if _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
	end
end

function SetAttack(bool)
	if _G.SDK then
		_G.SDK.Orbwalker:SetAttack(bool)
	end
end

function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end


function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
    	if range then
    		if GetDistance(unit.pos) <= range then
        		return true;
        	end
        else
        	return true
        end
    end
    return false;
end
class "Manager"

function Manager:__init()
	if myHero.charName == "Aphelios" then

		require "GGPrediction"
		require "2DGeometry"

		DelayAction(function() self:LoadAphelios() end, 1.05)
	end
end

function Manager:LoadAphelios()
	Aphelios:Spells()
	Aphelios:Menu()
	Callback.Add("Tick", function() Aphelios:Tick() end)
		Callback.Add("Draw", function() Aphelios:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Aphelios:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Aphelios:OnPostAttackTick(...) end)
	end
end

class "Aphelios"

local EnemyLoaded = false
local MainHand = "None"
local OffHand = "None"
local FlameQR = Game:Timer()
local SniperQR = Game:Timer()
local SlowQR = Game:Timer()
local BounceQR = Game:Timer()
local HealQR = Game:Timer()
local MainAtTime = MainHand
local CanRoot = false
local CanRange = false

function Aphelios:Menu()
	self.Menu = MenuElement({type = MENU, id = "Aphelios2", name = "Aphelios (Isbjorn's edit)"})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q's in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Switch Weapons", value = false})
	self.Menu.ComboMode:MenuElement({id = "UseR2", name = "R Semi Manual Key", value = false,key=string.byte("S"),toggle=false})
	self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseRCount", name = "Use R hix X enemies", value = 2, min = 1, max = 5})
	self.Menu.ComboMode:MenuElement({id = "CrescendumSlider", name = "adjustible Crescendum attackspeed offset", value = 0.2, min = -1, max = 1,step=0.01,tooltip="higher value= more delay b/t aas, try different values depending on if script is standing still too early, or not autoing early enough"})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q's in Harass", value = true})

	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = true})
end


function Aphelios:Spells()
	QSniperSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 60, Range = 1450, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	QFlameSpell = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.4, Angle = 40, Range = 850, Speed = 1850, Collision = false}
	RAllSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.6, Radius = 400, Range = 1300, Speed = 1000, Collision = false}
	lastQ = 0
	lastR = 0
	self.AttackTarget = nil
end
shouldreset=false
lastcrcheck=0
nextguessedtime=0
function Aphelios:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	if EnemyLoaded == false then
		local CountEnemy = 0
		for i, enemy in pairs(GetEnemyHeroes()) do
			CountEnemy = CountEnemy + 1
		end
		if CountEnemy < 1 then
			GetEnemyHeroes()
		else
			EnemyLoaded = true
			PrintChat("Enemy Loaded")
		end
	end
	AArange1 = 550 + myHero.boundingRadius * 2
	AArange2 = 650 + myHero.boundingRadius * 2

	if _G.SDK.BuffManager:HasBuff(myHero, "ApheliosSeverumQ") then
		SetAttack(false)
	else
		SetAttack(true)
	end

	target = GetTarget(2300)

	
	candotech=false
	highestprio2=0
	bestmarkedtarget=nil
	for i, enemy in pairs(GetEnemyHeroes()) do
		if enemy and enemy.distance<_G.SDK.Data:GetAutoAttackRange(myHero) then
			candotech=true
		elseif enemy.distance<1800 and  _G.SDK.TargetSelector:GetPriority(enemy)>highestprio2 and enemy.toScreen.onScreen and Mode() == "Combo" and lastcalibrumattack+0.7<Game.Timer() and _G.SDK.BuffManager:HasBuff(enemy, "aphelioscalibrumbonusrangedebuff") and not _G.SDK.BuffManager:HasBuff(myHero, "ApheliosSeverumQ") then	
			bestmarkedtarget=enemy
			highestprio2=_G.SDK.TargetSelector:GetPriority(enemy)
		end
	end
	if candotech==false and bestmarkedtarget then
		print("proccing calibrum")
		_G.SDK.Orbwalker:__OnAutoAttackReset()
		_G.SDK.Orbwalker:Attack(bestmarkedtarget)
		lastcalibrumattack=Game.Timer()
		return
	end
	
	if myHero.activeSpell.name=="ApheliosCrescendumAttack"  then
		local target = _G.SDK.Orbwalker:GetTarget((_G.SDK.Data:GetAutoAttackRange(myHero)))
		if target and Game.Timer()>lastcrcheck then
			lastcrcheck=myHero.activeSpell.castEndTime
			nextguessedtime=(myHero.activeSpell.castEndTime+(target.distance/5000)+(target.distance/(600+((myHero.attackSpeed-1)*750))))+self.Menu.ComboMode.CrescendumSlider:Value()
			DelayAction(function() 
				--if lastcalibrumattack+1<Game.Timer() then
					_G.SDK.Orbwalker:__OnAutoAttackReset()
					print("Crescendum AA up?"..Game.Timer())
				--end
			end, nextguessedtime-Game.Timer())
		end
	end
	-- if MainHand == "White" and Game.Timer()>nextguessedtime then
		-- for i = 1, Game.MissileCount() do
			-- local missile = Game.Missile(i)
			-- if missile and missile.name == "ApheliosCrescendumAttackMisIn" and missile.distance<200 then
				-- DelayAction(function() 
					-- _G.SDK.Orbwalker:__OnAutoAttackReset()
					-- print(Game.Timer()) 
				-- end, (missile.distance/(600+((myHero.attackSpeed-1)*750))))
			-- end
		-- end
	-- end
	OffHand = self:GetOffHand()
	MainHand = self:GetGun()
	if self.Menu.ComboMode.UseR2:Value() and target then
	self:UseRAll(target,false)
	end
	self:GetTargetBuffs()
	if IsReady(_Q)==false then
		if MainHand == "Snare" then
			SlowQR = Game:Timer() + myHero:GetSpellData(0).currentCd
		elseif MainHand == "Sniper" then
			SniperQR = Game:Timer() + myHero:GetSpellData(0).currentCd		
		elseif MainHand == "Red" then
				HealQR = Game:Timer() + myHero:GetSpellData(0).currentCd
		elseif MainHand == "White" then
			BounceQR = Game:Timer() + myHero:GetSpellData(0).currentCd	
		elseif MainHand == "AOE" then
			FlameQR = Game:Timer() + myHero:GetSpellData(0).currentCd
		end
	end
 	if Mode() == "Combo" then
		self:Combo()
	end
	if Mode() == "Harass" then
		self:Harass()
	end
end

function Aphelios:GetColor(gun)
	if gun=="Sniper" then
		return 0xFF25b38b
	elseif gun=="Snare" then
		return 0xFF712bb3 
	elseif gun=="Red" then	
		return 0xFFbd1c24 
	elseif gun=="White" then	
		return 0xFFf7f5fa 
	elseif gun=="AOE" then	
		return 0xFF2332d9 
	end
 end
 

function Aphelios:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		if myHero.activeSpell.valid then
			local attacktargetpos = myHero.activeSpell.placementPos
			local vectargetpos = Vector(attacktargetpos.x,attacktargetpos.y,attacktargetpos.z)
			Draw.Circle(vectargetpos, 225, 1, Draw.Color(255, 0, 191, 255))
		end
		mhp=myHero.pos:To2D()
		if IsReady(_Q) then
			Draw.Text(MainHand, 30,mhp.x-50,mhp.y-180, Draw.Color(Aphelios:GetColor(MainHand)))
		else
			Draw.Text(MainHand..math.ceil(myHero:GetSpellData(0).currentCd), 30,mhp.x-50,mhp.y-180, Draw.Color(Aphelios:GetColor(MainHand)))	
		end
		Draw.Text(OffHand, 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
		if OffHand == "Snare" then
			if SlowQR<Game.Timer() then
				Draw.Text(OffHand, 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			else
				Draw.Text(OffHand..math.ceil(SlowQR-Game.Timer()), 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			end
		elseif OffHand == "Sniper" then
			if SniperQR<Game.Timer() then
				Draw.Text(OffHand, 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			else
				Draw.Text(OffHand..math.ceil(SniperQR-Game.Timer()), 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			end
		elseif OffHand == "Red" then
			if HealQR<Game.Timer() then
				Draw.Text(OffHand, 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			else
				Draw.Text(OffHand..math.ceil(HealQR-Game.Timer()), 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			end	
		elseif OffHand == "White" then
			if BounceQR<Game.Timer() then
				Draw.Text(OffHand, 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			else
				Draw.Text(OffHand..math.ceil(BounceQR-Game.Timer()), 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			end	
		elseif OffHand == "AOE" then
			if FlameQR<Game.Timer() then
				Draw.Text(OffHand, 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			else
				Draw.Text(OffHand..math.ceil(FlameQR-Game.Timer()), 30,mhp.x+50,mhp.y-180,  Draw.Color(Aphelios:GetColor(OffHand)))
			end
		end		

		-- if OffHand == "Snare" then
			-- if SlowQR>Game.Timer() and SlowQR<Game.Timer()+2 then
			-- Draw.Text(OffHand.." Up Soon", 30,mhp.x-50,mhp.y-210, Draw.Color(Aphelios:GetColor(OffHand)))
			-- end
		-- elseif OffHand == "Sniper" then
			-- if SniperQR>Game.Timer() and SniperQR<Game.Timer()+2 then
			-- Draw.Text(OffHand.." Up Soon", 30,mhp.x-50,mhp.y-210, Draw.Color(Aphelios:GetColor(OffHand)))			
			-- end
		-- elseif OffHand == "Red" then
			-- if HealQR>Game.Timer() and HealQR<Game.Timer()+2 then
			-- Draw.Text(OffHand.." Up Soon", 30,mhp.x-50,mhp.y-210, Draw.Color(Aphelios:GetColor(OffHand)))			
			-- end		
		-- elseif OffHand == "White" then
				-- print(BounceQR)
			-- if BounceQR>Game.Timer() and BounceQR<Game.Timer()+2 then
			-- Draw.Text(OffHand.." Up Soon", 30,mhp.x-50,mhp.y-210, Draw.Color(Aphelios:GetColor(OffHand)))			
			-- end		
		-- elseif OffHand == "AOE" then
			-- if FlameQR>Game.Timer() and FlameQR<Game.Timer()+2 then
			-- Draw.Text(OffHand.." Up Soon", 30,mhp.x-50,mhp.y-210, Draw.Color(Aphelios:GetColor(OffHand)))			
			-- end	
		-- end
	end
	return 0
end
lastpretech=0
function Aphelios:OnPreAttack(args)
	--("Attackedpre")
	Attacked = 0
if	lastcalibrumattack+0.4<Game.Timer() then
	 _G.SDK.Orbwalker.ForceTarget=nil
end
	if  _G.SDK.BuffManager:HasBuff(args.Target, "aphelioscalibrumbonusrangedebuff") and _G.SDK.Orbwalker.ForceTarget==nil and  MainHand ~= "White" and args.Target.distance<_G.SDK.Data:GetAutoAttackRange(myHero) then --lastpretech+1<Game.Timer() and
		local highestprio=0
		for i, enemy in pairs(GetEnemyHeroes()) do
			if enemy and enemy.distance<AArange2 and _G.SDK.TargetSelector:GetPriority(enemy)>highestprio and  _G.SDK.BuffManager:HasBuff(enemy, "aphelioscalibrumbonusrangedebuff")==false then
				print("doingpretech")
				doingpretech=true
				highestprio=_G.SDK.TargetSelector:GetPriority(enemy)
				args.Target=enemy
			--	print(args.Target.health)			
				self.AttackTarget = args.Target
				lastpretech=Game.Timer()
			end
		end
	end
	self.AttackTarget=args.Target
end
lastcalibrumattack=0
function Aphelios:OnPostAttackTick(args)
	_G.SDK.Orbwalker.ForceTarget=nil
	if Attacked == 0 then
		Attacked = 1
		Casted = 0
		--PrintChat("Attacked")
	end
	local besttarget=nil
	local highestprio3=0
	for i, enemy in pairs(GetEnemyHeroes()) do
			--print(myHero.range)
			local extraRange = enemy.boundingRadius
			if enemy~=self.AttackTarget and enemy.distance<1800 and _G.SDK.TargetSelector:GetPriority(enemy)> highestprio3 and enemy.toScreen.onScreen and Mode() == "Combo" and  MainHand ~= "White" and _G.SDK.BuffManager:HasBuff(enemy, "aphelioscalibrumbonusrangedebuff") and not _G.SDK.BuffManager:HasBuff(myHero, "ApheliosSeverumQ") then
				besttarget=enemy
				highestprio3=_G.SDK.TargetSelector:GetPriority(enemy)
			end		
	end
	if besttarget~=nil then
		print("doingtech")
		_G.SDK.Orbwalker:__OnAutoAttackReset()
		_G.SDK.Orbwalker.ForceTarget = besttarget
		lastcalibrumattack=Game.Timer()
		return
	end
	_G.SDK.Orbwalker.ForceTarget=nil
	if target then
	end
end

function Aphelios:GetOffHand()
	if _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffCalibrum") then
		return "Sniper" 
	elseif _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffGravitum") then
		return "Snare" 
	elseif _G.SDK.BuffManager:HasBuff(myHero,  "ApheliosOffHandBuffSeverum") then
		return "Red" 
	elseif _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffCrescendum") then
		return "White" 
	elseif _G.SDK.BuffManager:HasBuff(myHero,  "ApheliosOffHandBuffInfernum") then
		return "AOE" 
	end
end

function Aphelios:GetGun()
	if myHero:GetSpellData(_Q).name == "ApheliosCalibrumQ" then
		return "Sniper" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosGravitumQ" then
		return "Snare" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosSeverumQ" then
		return "Red" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosCrescendumQ" then
		return "White" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosInfernumQ" then
		return "AOE" 
	end
end

function Aphelios:UseQSniper(unit)
if lastQ + 500 < GetTickCount() then
	local pred = GGPrediction:SpellPrediction(QSniperSpell)
   	pred:GetPrediction(unit, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_Q, pred.CastPosition)
		lastQ = GetTickCount()	
	end
end
end

function Aphelios:UseRAll(unit, AOE)
if lastR + 700 < GetTickCount() then
	local pred = GGPrediction:SpellPrediction(RAllSpell)
   	pred:GetPrediction(unit, myHero)
	if AOE then
		local RAOE = pred:GetAOEPrediction(myHero)
		local hitchance = 2
		local minenemies = 2
		local bestaoe = nil
		local bestcount = 0
		local bestdistance = 1000
		for i = 1, #RAOE do
			local aoe = RAOE[i]
			if aoe.HitChance >= hitchance and aoe.Count >= minenemies then
				if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
					bestdistance = aoe.Distance
					bestcount = aoe.Count
					bestaoe = aoe
				end
			end
		end
		if bestaoe then
				if MainHand == "Red" and myHero.health >= myHero.maxHealth*0.5 and IsReady(_W) then
					Control.CastSpell(HK_W)
				end
			Control.CastSpell(HK_R, bestaoe.CastPosition)
			lastR = GetTickCount()
		end
	elseif _G.SDK.TargetSelector.Selected==nil then
		local RAOE = pred:GetAOEPrediction(myHero)
		local hitchance = 2
		local minenemies = 1
		local bestaoe = nil
		local bestcount = 0
		local bestdistance = 1000
		for i = 1, #RAOE do
			local aoe = RAOE[i]
			if aoe.HitChance >= hitchance and aoe.Count >= minenemies then
				if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
					bestdistance = aoe.Distance
					bestcount = aoe.Count
					bestaoe = aoe
				end
			end
		end
		if bestaoe then
				if MainHand == "Red" and myHero.health >= myHero.maxHealth*0.5 and IsReady(_W) then
					Control.CastSpell(HK_W)
				end
			Control.CastSpell(HK_W)
			Control.CastSpell(HK_R, bestaoe.CastPosition)
			lastR = GetTickCount()
		end
	else
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				if MainHand == "Red" and myHero.health >= myHero.maxHealth*0.5 and IsReady(_W) then
					Control.CastSpell(HK_W)
				end
			Control.CastSpell(HK_W)
			Control.CastSpell(HK_R, pred.CastPosition)
			lastR = GetTickCount()
		end
	end
end	
end


function Aphelios:UseQFlame(unit)
if lastQ + 500 < GetTickCount() then
	local pred = GGPrediction:SpellPrediction(QFlameSpell)
   	pred:GetPrediction(unit, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_Q, pred.CastPosition)
		lastQ = GetTickCount()
	end
end	
end

function Aphelios:UseQBounce(unit)
if lastQ + 350 < GetTickCount() then
	local pos = myHero.pos + (unit.pos - myHero.pos):Normalized() * 475
		Control.CastSpell(HK_Q, pos)
lastQ = GetTickCount()
end
end

function Aphelios:GetTargetBuffs()
	if target then
		CanRoot = _G.SDK.BuffManager:HasBuff(target, "ApheliosGravitumDebuff")
		CanRange = _G.SDK.BuffManager:HasBuff(target, "aphelioscalibrumbonusrangedebuff")
	end
end
function Aphelios:GetTargetBuffs2(enemy)
	if enemy then
		CanRoot = _G.SDK.BuffManager:HasBuff(target, "ApheliosGravitumDebuff")
		CanRange = _G.SDK.BuffManager:HasBuff(target, "aphelioscalibrumbonusrangedebuff")
	end
end


function Aphelios:Combo()
	if target == nil then return end
	if target and myHero.levelData.lvl > 1 then
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ SNIPER SNIPER SNIPER SNIPER @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
			if MainHand == "Sniper" and self.Menu.ComboMode.UseQ:Value() then
				if not IsReady(_Q) then
					SniperQR = Game:Timer() + myHero:GetSpellData(0).currentCd
				end
				if OffHand == "Snare" then
					if IsReady(_Q) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if SlowQR < Game:Timer() and CanRoot and myHero.mana > 60 then
					--		Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
					-- if target has Q buff, switch to W
				end
				if OffHand == "AOE" then
					if IsReady(_Q) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						--PrintChat("W REady")
						if GetDistance(target.pos) <= AArange1 then
						--	Control.CastSpell(HK_W)
						end 
						if FlameQR < Game:Timer() and GetDistance(target.pos) <= 800  and myHero.mana > 60 then
						--	Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "White" then
					if IsReady(_Q) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if GetDistance(target.pos) < 350 then
							Control.CastSpell(HK_W)
						end
						if BounceQR < Game:Timer() and GetDistance(target.pos) <= 950 and myHero.mana > 60 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Red" then
					if IsReady(_Q) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if GetDistance(target.pos) <= 300 or myHero.health < myHero.maxHealth*0.3 then
					--		Control.CastSpell(HK_W)
						end
						if HealQR < Game:Timer() and GetDistance(target.pos) <= AArange1 and myHero.mana > 60 then
					--		Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
			end

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ SLOW SLOW SLOW SLOW @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


			if MainHand == "Snare" and self.Menu.ComboMode.UseQ:Value() then
				local shouldroot=true
				for i, enemy in pairs(GetEnemyHeroes()) do
					if GetDistance(enemy.pos) < 800 and _G.SDK.BuffManager:HasBuff(enemy, "ApheliosGravitumDebuff")==false then
					shouldroot=false
					end
				end	
				if OffHand == "Sniper" then
					if IsReady(_Q) and CanRoot and shouldroot then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if GetDistance(target.pos) < AArange2 then
				--			Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "AOE" then
					if IsReady(_Q) and CanRoot and shouldroot then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if FlameQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 800 then
					--		Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "White" then
				--	print(CanRoot)
					if IsReady(_Q) and CanRoot and shouldroot then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if not IsReady(_Q) and GetDistance(target.pos) < 350 then
					--		Control.CastSpell(HK_W)
						end 
						if BounceQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 400 and not IsReady(_Q) then
					--		Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Red" then
					if IsReady(_Q) and CanRoot and shouldroot then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if not IsReady(_Q) and myHero.health < myHero.maxHealth/2 then
					--		Control.CastSpell(HK_W)
						end
						if HealQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 and not IsReady(_Q) then
					--		Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
			end


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ BLUE @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

			if MainHand == "AOE" and self.Menu.ComboMode.UseQ:Value() then
				if OffHand == "Snare" then
					if IsReady(_Q) and ValidTarget(target, 800) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if not IsReady(_Q) and GetDistance(target.pos) <= AArange1 then
						--	Control.CastSpell(HK_W)
						end
						if SlowQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= AArange1 then
						--	Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Sniper" then
					if IsReady(_Q) and ValidTarget(target, 800) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if GetDistance(target.pos) > AArange1 then
						--	Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "White" then
					if IsReady(_Q) and ValidTarget(target, 800) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if not IsReady(_Q) and GetDistance(target.pos) < AArange1 then
						--	Control.CastSpell(HK_W)
						end
						if BounceQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= AArange1 then
						--	Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Red" then
					if IsReady(_Q) and ValidTarget(target, 800) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if HealQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= AArange1 then
					--		Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
			end


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ WHITE @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

			if MainHand == "White" and self.Menu.ComboMode.UseQ:Value() then
				if OffHand == "Snare" then
					if IsReady(_Q) and ValidTarget(target, 250) then
				--		Control.CastSpell(HK_Q, target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if IsReady(_Q) then
							if GetDistance(target.pos) > 475 then
						--		Control.CastSpell(HK_W)
							end
						else
							if GetDistance(target.pos) > 400 then
						--		Control.CastSpell(HK_W)
							end
						end
						if SlowQR < Game:Timer() and myHero.mana > 60 and CanRoot then
						--	Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "AOE" then
					if IsReady(_Q) and ValidTarget(target, 250) then
					--	Control.CastSpell(HK_Q, target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if FlameQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 800 then
						--	Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Sniper" then
					if IsReady(_Q) and ValidTarget(target, 950) then
						if GetDistance(target.pos) > 475 then
						--	self:UseQBounce(target)
						elseif GetDistance(target.pos) < 475 then
						--	Control.CastSpell(HK_Q, target)
						end
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if IsReady(_Q) then
							if GetDistance(target.pos) > 950 then
							--	Control.CastSpell(HK_W)
							end
						else
							if GetDistance(target.pos) > AArange1 then
							--	Control.CastSpell(HK_W)
							end
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Red" then
					if IsReady(_Q) and ValidTarget(target, 475) then
					--	Control.CastSpell(HK_Q, target)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if HealQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= AArange1 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
			end


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ RED @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


			if MainHand == "Red" and self.Menu.ComboMode.UseQ:Value() then
				--PrintChat("Heal")
				if OffHand == "Snare" then
					-- if IsReady(_Q) and ValidTarget(target, AArange1) then
						-- Control.CastSpell(HK_Q)
					-- end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if not IsReady(_Q) and myHero.health > myHero.maxHealth*0.7 then
						--	Control.CastSpell(HK_W)
						end
						if SlowQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
						--	Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "AOE" then
					-- if IsReady(_Q) and ValidTarget(target, AArange1) then
						-- Control.CastSpell(HK_Q)
					-- end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if not IsReady(_Q) and GetDistance(target.pos) < AArange1 and myHero.health > myHero.maxHealth*0.2 then
						--	Control.CastSpell(HK_W)
						end 
						if FlameQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 800 then
						--	Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "White" then
					if IsReady(_Q) and ValidTarget(target, AArange1) then
				--		Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if GetDistance(target.pos) < 475 and myHero.health > myHero.maxHealth*0.3 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Sniper" then
					-- if IsReady(_Q) and ValidTarget(target, AArange1) then
						-- Control.CastSpell(HK_Q)
					-- end
					if IsReady(_E) then

					end
					if IsReady(_W) and self.Menu.ComboMode.UseW:Value() then
						if GetDistance(target.pos) > AArange1 and myHero.health > myHero.maxHealth*0.3 then
						--	Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
			end
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ RSET RSET RSET RSET @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
			if IsReady(_R) and ValidTarget(target, 1300) and self.Menu.ComboMode.UseR:Value()then
				if MainHand ~= "Red" then
					if GetEnemyCount(300, target.pos) >= self.Menu.ComboMode.UseRCount:Value() then
						self:UseRAll(target, true)
					-- elseif target.health/target.maxHealth <= self.Menu.ComboMode.UseRHp:Value()/100 then
						-- self:UseRAll(target, false)
					end
				elseif MainHand == "Red" and myHero.health <= myHero.maxHealth*0.3 then
					self:UseRAll(target, false)
				end
				if OffHand == "Red" and myHero.health <= myHero.maxHealth*0.3 and IsReady(_W) then
					Control.CastSpell(HK_W)
				end
			end
	end
end

function Aphelios:Harass()
	if target == nil then return end
	if target and self.Menu.HarassMode.UseQ:Value() and myHero.levelData.lvl > 1 then
		if MainHand == "Sniper" then
			if IsReady(_Q) and ValidTarget(target, 1450) then
				self:UseQSniper(target)
			end
		end
		if MainHand == "Red" then
			if IsReady(_Q) and ValidTarget(target, AArange1) then
				Control.CastSpell(HK_Q)
			end
		end
		if MainHand == "AOE" then
			if IsReady(_Q) and ValidTarget(target, 800) then
				self:UseQFlame(target)
			end
		end
		if MainHand == "White" then
			if IsReady(_Q) and ValidTarget(target, 950) then
				self:UseQBounce(target)
			end
		end
	end
end

function OnLoad()
	Manager()
end