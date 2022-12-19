require 'GamsteronPrediction'
require 'GGPrediction'
local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local TableInsert       = _G.table.insert


local orbwalker         = _G.SDK.Orbwalker
local TargetSelector    = _G.SDK.TargetSelector

local lastQ = 0
local lastW = 0
local lastE = 0
local lastR = 0
local lastMove = 0
local lastAttack = 0

local Enemys =   {}
local Allys  =   {}

local function HasBuff(name ,unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name == name then
            return true, buff.duration, buff.count
        end
    end
    return false
end

local function GetDistanceSquared(vec1, vec2)
    local dx = vec1.x - vec2.x
    local dy = (vec1.z or vec1.y) - (vec2.z or vec2.y)
    return dx * dx + dy * dy
end


local function IsValid(unit)
    if (unit 
        and unit.valid 
        and unit.isTargetable 
        and unit.alive 
        and unit.visible 
    --    and unit.networkID 
    --    and unit.health > 0
    --    and not unit.dead
    ) then
        return true;
    end
    return false;
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 
    and myHero:GetSpellData(spell).level > 0 
    and myHero:GetSpellData(spell).mana <= myHero.mana 
    and Game.CanUseSpell(spell) == 0
end

local function OnAllyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isAlly then
            cb(obj)
        end
    end
end

local function OnEnemyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isEnemy then
            cb(obj)
        end
    end
end

class "Ryze"
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team



local function getEnemyHeroes()
    local EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy and not Hero.dead then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
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

function Ryze:__init()
	collcast=0
    self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 55, Range = 1000, Speed = 1700, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.W = {Range = 630}
    self.E = {Range = 615}

    self:LoadMenu()

    OnAllyHeroLoad(function(hero)
        TableInsert(Allys, hero);
    end)

    OnEnemyHeroLoad(function(hero)
        TableInsert(Enemys, hero);
    end)

    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)


    orbwalker:OnPreAttack(
        function(args)
            if args.Process then
                if lastAttack + self.tyMenu.Human.AA:Value() > GetTickCount() then
                    args.Process = false
                    print("block aa")
                else
                    args.Process = true
                    self.AttackTarget = args.Target
                    lastAttack = GetTickCount()
                end
            end
        end
    )

    orbwalker:OnPreMovement(
        function(args)
            if args.Process then
                if (lastMove + self.tyMenu.Human.Move:Value() > GetTickCount()) or (ExtLibEvade and ExtLibEvade.Evading == true) then
                    args.Process = false
                else
                    args.Process = true
                    lastMove = GetTickCount()
                end
            end
        end 
    )

end

function Ryze:LoadMenu()
    self.tyMenu = MenuElement({type = MENU, id = "14Ryze", name = "14 Ryze"})

    self.tyMenu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.tyMenu.Combo:MenuElement({id = "UseQ", name = "[Q]", value = true})
	self.tyMenu.Combo:MenuElement({id = "UseQnowait", name = "[Q]no wait", value = true, toggle=true,key=string.byte("S")})
    self.tyMenu.Combo:MenuElement({id = "UseW", name = "[W] ", value = true})
    self.tyMenu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})

    self.tyMenu:MenuElement({type = MENU, id = "Setting", name = "Setting"})
    self.tyMenu.Setting:MenuElement({id = "AAlevel", name = "Disable AA >= Level If Q/W/E ready", value = 6, min = 1, max = 19, step = 1})
	self.tyMenu.Setting:MenuElement({id = "AAlevel2", name = "Disable AA", value = 6, min = 1, max = 19, step = 1})
    self.tyMenu.Setting:MenuElement({id = "AAQ", name = "Disable AA if Q ready", value = true})

    self.tyMenu:MenuElement({type = MENU, id = "Human", name = "Humanizer"})
        self.tyMenu.Human:MenuElement({id = "Move", name = "Only allow 1 movement in X Tick ", value = 180, min = 1, max = 500, step = 1})
        self.tyMenu.Human:MenuElement({id = "AA", name = "Only allow 1 AA in X Tick", value = 180, min = 1, max = 500, step = 1})

    self.tyMenu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
    self.tyMenu.Drawing:MenuElement({id = "Q", name = "Draw [Q] Range", value = true})
    self.tyMenu.Drawing:MenuElement({id = "W", name = "Draw [W] Range", value = true})
    self.tyMenu.Drawing:MenuElement({id = "E", name = "Draw [E] Range", value = true})

end

function Ryze:Draw()
    if myHero.dead then
        return
    end
	if not self.tyMenu.Combo.UseQnowait:Value() then
        Draw.Text("W prio: On ",30,myHero.pos:To2D(),Draw.Color(255 ,0,255,0))
    else
        Draw.Text("w prio: Off ",30,myHero.pos:To2D(),Draw.Color(255 ,255,0,0))

    end
    if self.tyMenu.Drawing.Q:Value() and Ready(_Q) then
        Draw.Circle(myHero.pos, self.Q.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end

    if self.tyMenu.Drawing.W:Value() and Ready(_W) then
        Draw.Circle(myHero.pos, self.W.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end


    if self.tyMenu.Drawing.E:Value() and Ready(_E) then
        Draw.Circle(myHero.pos, self.E.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end
end

function Ryze:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end

    if orbwalker.Modes[0] then --combo
        self:Combo()
		
    elseif orbwalker.Modes[1] then --harass
        -- self:Harass()
	elseif orbwalker.Modes[3] then --harass
		orbwalker:SetAttack(true)
	elseif orbwalker.Modes[4] then --harass
        orbwalker:SetAttack(true)
    end



end

function GetHeroTarget(range)
    local EnemyHeroes = _G.SDK.ObjectManager:GetEnemyHeroes(range, false)
    local target = _G.SDK.TargetSelector:GetTarget(EnemyHeroes)

    return target
end


function Ryze:ComboCollision()
local target = GetHeroTarget(1300)
if target == nil then return end
	if IsValid(target) and (not Ready(_W) or self.tyMenu.Combo.UseQnowait:Value()) then 	
			local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1000, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
			QPrediction:GetPrediction(target, myHero)
			if not QPrediction:CanHit(1+ 1) then
				for i = 1, GameMinionCount() do
					local minion = GameMinion(i)
					
					if myHero.pos:DistanceTo(minion.pos) <= 1000 and minion.team == TEAM_ENEMY and IsValid(minion) then
						
						if myHero.pos:DistanceTo(minion.pos) <= 615 and target.pos:DistanceTo(minion.pos) <= 200 and Ready(_E) and Ready(_Q) and self.tyMenu.Combo.UseQnowait:Value() then
							Control.CastSpell(HK_E, minion)
							collcast=GetTickCount()
						end			
						
						if myHero.pos:DistanceTo(minion.pos) <= 1000 and Ready(_Q) and target.pos:DistanceTo(minion.pos) <= 325  then
							if HasBuff("RyzeE",minion) and HasBuff("RyzeE",target) then
								Control.CastSpell(HK_Q, minion.pos)
							end
						end
					end
				end
				for i, Enemy in pairs(getEnemyHeroes()) do
					
					
					if myHero.pos:DistanceTo(Enemy.pos) <= 1000  and IsValid(Enemy) and Enemy~=target then
						
						if myHero.pos:DistanceTo(Enemy.pos) <= 615 and target.pos:DistanceTo(Enemy.pos) <= 350 and Ready(_E)  then
							Control.CastSpell(HK_E, Enemy)
						
						end			
						
						if myHero.pos:DistanceTo(Enemy.pos) <= 1000 and Ready(_Q) and target.pos:DistanceTo(Enemy.pos) <= 350  and Enemy~=target  then
							if HasBuff("RyzeE",Enemy) and HasBuff("RyzeE",target) then
							self:CastQ(Enemy,false)
							
						end
					end
				end				
				
				end
				
			end			
	end	
end	
	




function Ryze:Combo()
    self:DisableAAcheck()

    target = GetHeroTarget(self.Q.Range)
--Ready(_W) and (Ready(_E) or myHero.pos:DistanceTo(target.pos)>self.W.Range+50)) 
    if target and IsValid(target) and self.tyMenu.Combo.UseQ:Value() and (self.tyMenu.Combo.UseQnowait:Value() or (myHero:GetSpellData(_W).currentCd >1)) then
		if self.tyMenu.Combo.UseQnowait:Value() and Ready(_W) and (lastE +500) > GetTickCount() and  myHero.pos:DistanceTo(target.pos)>500 and myHero.pos:DistanceTo(target.pos)<=690 then
		--print( myHero.pos:DistanceTo(target.pos))
			self:CastQ(target,true)
		else
			--print( myHero.pos:DistanceTo(target.pos))
			self:CastQ(target,false)
		end
    end
		
    target =  GetHeroTarget(self.W.Range)
    if target and IsValid(target) and self.tyMenu.Combo.UseW:Value() then
        if Ready(_W) and ((self.tyMenu.Combo.UseQnowait:Value() and not Ready(_E) and not Ready(_Q) and (collcast+900<GetTickCount())) or (self.tyMenu.Combo.UseQnowait:Value()==false and (HasBuff("RyzeE",target) or lastE+300>GetTickCount())))  and lastW +260 < GetTickCount() and myHero.mana >= (self:GetSpellMana("Q") + self:GetSpellMana("W"))  then
            local casted = Control.CastSpell(HK_W, target)
            if casted then
                lastW = GetTickCount()
                -- print("W "..GetTickCount())
            end
        end
    end

    
    target =  GetHeroTarget(self.E.Range)
    if target and IsValid(target) and self.tyMenu.Combo.UseE:Value() then
        if (self.tyMenu.Combo.UseQnowait:Value()==false or not Ready(_Q))  and Ready(_E) and lastE +260 < GetTickCount() and myHero.mana >= (self:GetSpellMana("Q") + self:GetSpellMana("E"))  then
            local casted = Control.CastSpell(HK_E, target)
            if casted then
                lastE = GetTickCount()
                -- print("E "..GetTickCount())
            end
        end
    end



	
   self:ComboCollision()
end

function Ryze:CastQ(target,wmidair)
    if Ready(_Q) then -- and lastQ +200 < GetTickCount() then --idk what this is for, reenable if issues
        -- local Pred = GetGamsteronPrediction(target, self.Q, myHero)	
        -- if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
	local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1000, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit() then
            if Ready(_W)==false and HasBuff("ryzewroot",target) then
				--print("ryzew")
                local casted = Control.CastSpell(HK_Q, target)
                if casted then
                    lastQ = GetTickCount()
                    -- print("Q targeted "..GetTickCount())
                end
            else
					if wmidair==true then
						print"wmidair"
					--DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("0.03") end end, 0.06)
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("1") end end, 0.02)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("2") end end, 0.04)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("3") end end, 0.06)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("4") end end, 0.08)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("5") end end, 0.10)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("6") end end, 0.12)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("7") end end, 0.14)
					DelayAction(function() if Ready(_W) then Control.CastSpell(HK_W, target) print("8") end end, 0.16)
					--Control.CastSpell(HK_W, target) --yeah this way is a bit of a meme i admit
					else
						Control.CastSpell(HK_Q, QPrediction.CastPosition)
					end
					

                    lastQ = GetTickCount()

                    -- print("Q "..GetTickCount())
					
               
            end

        end
    end
end

function Ryze:DisableAAcheck()
    if myHero.levelData.lvl >= self.tyMenu.Setting.AAlevel:Value() or (myHero.levelData.lvl >=self.tyMenu.Setting.AAlevel2:Value()) then
        if Ready(_Q) or Ready(_W) or Ready(_E) or (myHero.levelData.lvl >=self.tyMenu.Setting.AAlevel2:Value()) or self.tyMenu.Combo.UseQnowait:Value()==false then
            orbwalker:SetAttack(false)
		else
			orbwalker:SetAttack(true)
        end
    end

    if self.tyMenu.Setting.AAQ:Value() and Ready(_Q) then
        orbwalker:SetAttack(false)
    end
end

function Ryze:GetSpellMana(spell)
    if spell == "Q" then
        return 40
    end
    if spell == "W" then
        return ({40,55,70,85,100})[myHero:GetSpellData(1).level]
    end
    if spell == "E" then
        return ({40,55,70,85,100})[myHero:GetSpellData(2).level]
    end

end

function Ryze:GetTarget(list, range)
    local targetList = {}

    for i = 1, #list do
        local hero = list[i]
        if GetDistanceSquared(hero.pos, myHero.pos) < range * range then
            targetList[#targetList + 1] = hero
        end
    end

    return TargetSelector:GetTarget(targetList)
end

Ryze()