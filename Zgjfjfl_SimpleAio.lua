
local Heroes ={"Ornn", "JarvanIV", "Poppy", "Shyvana", "Trundle", "Rakan", "Belveth", "Nasus", "Singed", "Udyr", "Galio", "Yorick", "Ivern", "Bard", "Taliyah", "Lissandra", "Sejuani", "KSante"}

if not table.contains(Heroes, myHero.charName) then return end

require "GGPrediction"
require "2DGeometry"
require "MapPositionGOS"
_G.dodge=0
local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion

local orbwalker         = _G.SDK.Orbwalker
local HealthPrediction         = _G.SDK.HealthPrediction


local function isSpellReady(spell)
    return  myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function isValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true
    end
    return false
end

local function getDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

local function getDistance(Pos1, Pos2)
    return math.sqrt(getDistanceSqr(Pos1, Pos2))
end

local function getEnemyHeroes()
    local EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local Hero = GameHero(i)
        if Hero.isEnemy and not Hero.dead then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyMinionsWithinDistanceOfLocation(location, distance)
    local EnemyMinions = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.isEnemy and not minion.dead and minion.pos:DistanceTo(location) < distance then
            table.insert(EnemyMinions, minion)
        end
    end
    return EnemyMinions
end

local function getAOEMinion(maxRange, abilityRadius) 
    local bestCount = 0
    local bestPosition = nil
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        local count = 0
        if minion and not minion.dead and minion.isEnemy and myHero.pos:DistanceTo(minion.pos) < maxRange then 
            local count = #getEnemyMinionsWithinDistanceOfLocation(minion.pos, abilityRadius)
            if count > bestCount then
                bestCount = count
                bestPosition = minion.pos
            end
        end
    end
    return bestPosition, bestCount
end

local function castSpell(spellData, hotkey, target)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_NORMAL) then
        if myHero.pos:DistanceTo(pred.CastPosition) <= spellData.Range + 15 then
            Control.CastSpell(hotkey, pred.CastPosition)	
        end
    end
end

local function castSpellHigh(spellData, hotkey, target)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        Control.CastSpell(hotkey, pred.CastPosition)	
    end
end

local function doesMyChampionHaveBuff(buffName)
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

local function HaveBuff(unit,buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

function getBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

local function getEnemyHeroesWithinDistanceOfUnit(location, distance)
    local EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy and not Hero.dead and Hero.pos:DistanceTo(location) < distance then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyHeroesWithinDistance(distance)
    return getEnemyHeroesWithinDistanceOfUnit(myHero.pos, distance)
end

local function getEnemyCount(range, unit)
	local count = 0
	for i, hero in ipairs(getEnemyHeroes()) do
	local Range = range * range
		if unit ~= hero and getDistanceSqr(unit, hero.pos) < Range and isValid(hero) then
		count = count + 1
		end
	end
	return count
end

local function getMinionCount(range, unit)
	local count = 0
	for i = 1,GameMinionCount() do
	local hero = GameMinion(i)
	local Range = range * range
		if hero.team ~= TEAM_ALLY and hero.dead == false and getDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

local function isImmobile(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false
end

local function isInvulnerable(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.type == 18 and buff.count > 0 then
			return true
            	end
	end
	return false
end

local vectorCast = {}
local mouseReturnPos = mousePos
local mouseCurrentPos = mousePos
local nextVectorCast = 0
function CastVectorSpell(key, pos1, pos2)
	if nextVectorCast > Game.Timer() then return end
	nextVectorCast = Game.Timer() + 1.5
	orbwalker:SetMovement(false)
	orbwalker:SetAttack(false)
	vectorCast[#vectorCast + 1] = function () 
		mouseReturnPos = mousePos
		mouseCurrentPos = pos1
		Control.SetCursorPos(pos1)
	end
	vectorCast[#vectorCast + 1] = function () 
		Control.KeyDown(key)
	end
	vectorCast[#vectorCast + 1] = function () 
		local deltaMousePos =  mousePos-mouseCurrentPos
		mouseReturnPos = mouseReturnPos + deltaMousePos
		Control.SetCursorPos(pos2)
		mouseCurrentPos = pos2
	end
	vectorCast[#vectorCast + 1] = function ()
		Control.KeyUp(key)
	end
	vectorCast[#vectorCast + 1] = function ()	
		local deltaMousePos =  mousePos -mouseCurrentPos
		mouseReturnPos = mouseReturnPos + deltaMousePos
		Control.SetCursorPos(mouseReturnPos)
	end
	vectorCast[#vectorCast + 1] = function () 
		orbwalker:SetMovement(true)
		orbwalker:SetAttack(true)
	end		
end
------------------------------------

class "Ornn"
        
function Ornn:__init()	     
    print("Zgjfjfl-Ornn Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 750, Speed = 1800, Collision = false}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 175, Range = 500, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 180, Range = 800, Speed = 1600, Collision = false}

  end

function Ornn:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgOrnn", name = "Zgjfjfl Ornn"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EQ", name = "[E] to Q", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "EWall", name = "[E] to Wall", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min = 0, max = 300, value = 300})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})

end

function Ornn:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
   
end

function Ornn:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then
	
	local qcastpos = myHero.pos + (target.pos - myHero.pos):Normalized() * self.qSpell.Range
        local ecastpos = myHero.pos + (target.pos - myHero.pos):Normalized() * self.eSpell.Range
        local objpos = target.pos:Extended(myHero.pos, -self.Menu.Combo.ED:Value())
        local lineE = LineSegment(target.pos, objpos)

        if not MapPosition:intersectsWall(lineE) then
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
	       if isSpellReady(_E) and self.Menu.Combo.EQ:Value() then
                    DelayAction(function()
                        Control.CastSpell(HK_E, qcastpos)
                    end, 1.4
                    )
	       end
            end
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            castSpellHigh(self.wSpell, HK_W, target)
        end

        if MapPosition:inWall(ecastpos) and MapPosition:intersectsWall(lineE) and self.Menu.Combo.EWall:Value() and isSpellReady(_E) then
            Control.CastSpell(HK_E, ecastpos)
        end
    end
end	

function Ornn:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.W:Value() and isSpellReady(_W) then
            bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_W, bestPosition)
            end
        end
    end
end

function Ornn:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range);
    if target then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end
        if self.Menu.Harass.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            castSpellHigh(self.wSpell, HK_W, target)
        end
    end
end

function Ornn:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------
class "JarvanIV"
        
function JarvanIV:__init()	     
    print("Zgjfjfl-JarvanIV Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 90, Range = 785, Speed = math.huge, Collision = false}
    self.wSpell = { Range = 600 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 200, Range = 860, Speed = math.huge, Collision = false}
  end

function JarvanIV:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgJarvanIV", name = "Zgjfjfl JarvanIV"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "EQ", name = "[EQ]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})



end

function JarvanIV:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
   
end

function JarvanIV:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then

        local pred = GGPrediction:SpellPrediction(self.eSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -100)
            if self.Menu.Combo.E:Value() and isSpellReady(_E) then
                Control.CastSpell(HK_E, castPos)
	            if isSpellReady(_Q) and self.Menu.Combo.Q:Value() then
                    DelayAction(function()
                        Control.CastSpell(HK_Q, castPos)
                    end, 0.1
                    )
				end
			end
        end	
		        
		if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and not isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
            Control.CastSpell(HK_W)
        end
		
    end
end	

function JarvanIV:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
            end
        end
    end
end

function JarvanIV:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

    end
end

function JarvanIV:Flee()
    if self.Menu.Flee.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.eSpell.Range
            Control.CastSpell(HK_E, pos)
            DelayAction(function()
                Control.CastSpell(HK_Q, pos)
            end, 0.1
            )
    end
end

function JarvanIV:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------

class "Poppy"
        
function Poppy:__init()	     
    print("Zgjfjfl-Poppy Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 430, Speed = math.huge, Collision = false}
    self.eSpell = { Range = 475 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 450, Speed = 2500, Collision = false}
    self.r2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 1200, Speed = 2500, Collision = false}
  end

function Poppy:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgPoppy", name = "Zgjfjfl Poppy"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min =0, max = 400, value = 400})
        self.Menu.Combo:MenuElement({id = "RF", name = "[R] Fast", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RFHP", name = "[R] Fastcast on target HP %", value = 30, min=0, max = 100 })
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Slowcast Semi-Manual Key", key = string.byte("T")})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "W", name = "W Setting "})
        self.Menu.W:MenuElement({type = MENU, id = "WB", name = "Auto W If Enemy dash on ME"})
            DelayAction(function()
                for i, Hero in pairs(getEnemyHeroes()) do
                    self.Menu.W.WB:MenuElement({id = Hero.charName, name =Hero.charName, value = false})		
                end		
            end,0.2)
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Poppy:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if isSpellReady(_W) then
        self:AutoW()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end
    if self.Menu.Combo.RMflee:Value() then
        self:RSemiManualflee()
    end

end

function Poppy:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then
	
        local endPos = target.pos:Extended(myHero.pos, -self.Menu.Combo.ED:Value())
        if MapPosition:inWall(endPos) and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
            Control.CastSpell(HK_E, target)
        end
				        
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end
		
        if self.Menu.Combo.RF:Value() and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and target.health/target.maxHealth <= self.Menu.Combo.RFHP:Value()/100 then
                Control.KeyDown(HK_R)
                if Control.IsKeyDown(HK_R) then
                    Control.SetCursorPos(target)
                    DelayAction(function() Control.SetCursorPos(mousePos) end, 0.1)
                    DelayAction(function() Control.KeyUp(HK_R) end, 0.1)

                end
        end
    end
end	

function Poppy:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
            end
        end
    end
end

function Poppy:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range);
    if target then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

    end
end

function Poppy:AutoW()

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then
    local blockobj = self.Menu.W.WB[target.charName] and self.Menu.W.WB[target.charName]:Value()
        if blockobj and target.pathing.isDashing then
        local vct = Vector(target.pathing.endPos.x, target.pathing.endPos.y, target.pathing.endPos.z)
            if vct:DistanceTo(myHero.pos) < 400 then
                Control.CastSpell(HK_W)
            end
        end
    end
end

function Poppy:RSemiManual()
    local target = _G.SDK.TargetSelector:GetTarget(self.r2Spell.Range)
    if target then
        if isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.r2Spell.Range then
                Control.KeyDown(HK_R)
                if Control.IsKeyDown(HK_R) then
                    Control.SetCursorPos(target)
                    DelayAction(function() Control.SetCursorPos(mousePos) end, 1)
                    DelayAction(function() Control.KeyUp(HK_R) end, 1)
                end
        end
    end
end


function Poppy:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.r2Spell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Shyvana"
        
function Shyvana:__init()	     
    print("Zgjfjfl-Shyvana Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 925, Speed = 1600, Collision = false}
    self.e2Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.333, Radius = 345, Range = 925, Speed = 1575, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 160, Range = 850, Speed = 700, Collision = false}
end

function Shyvana:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgShyvana", name = "Zgjfjfl Shyvana"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RHP", name = "[R] Use on target HP %", value = 50, min=0, max = 100 })
        self.Menu.Combo:MenuElement({id = "RC", name = "[R] Use X enemies in range", value = 1, min = 1, max = 5})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Flee:MenuElement({id = "R", name = "[R] to mouse", toggle = true, value = true})

	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Shyvana:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

end

function Shyvana:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Combo.W:Value() and isSpellReady(_W) then
            Control.CastSpell(HK_W)
        end
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) then
            castSpellHigh(self.eSpell, HK_E, target)
        end
        if myHero.pos:DistanceTo(target.pos) <= myHero.range+25 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
            Control.CastSpell(HK_Q)
        end

        local DragonForm = doesMyChampionHaveBuff("ShyvanaTransform")
        if DragonForm then
            if myHero.pos:DistanceTo(target.pos) < self.e2Spell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) then
                castSpellHigh(self.e2Spell, HK_E, target)
            end
        end

        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and self.Menu.Combo.R:Value() and isSpellReady(_R) and (target.health/target.maxHealth <= self.Menu.Combo.RHP:Value() / 100) then
        local numEnemies = getEnemyHeroesWithinDistance(self.rSpell.Range)
            if #numEnemies >= self.Menu.Combo.RC:Value() then
                castSpellHigh(self.rSpell, HK_R, target)
            end
        end
    end
end	

function Shyvana:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Clear.W:Value() and isSpellReady(_W) then
            Control.CastSpell(HK_W)
        end
        if myHero.pos:DistanceTo(target.pos) <= myHero.range+25 and self.Menu.Clear.Q:Value() and isSpellReady(_Q) then
            Control.CastSpell(HK_Q)
        end
        if self.Menu.Clear.E:Value() and isSpellReady(_E) then
            bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_E, bestPosition)
            end
        end
    end
end

function Shyvana:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range);
    if target then

        local DragonForm = doesMyChampionHaveBuff("ShyvanaTransform")
        if DragonForm then
            if myHero.pos:DistanceTo(target.pos) < self.e2Spell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) then
                castSpellHigh(self.e2Spell, HK_E, target)
            end
        end
            
        if self.Menu.Harass.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
            castSpellHigh(self.eSpell, HK_E, target)
        end

    end
end
function Shyvana:Flee()
    if self.Menu.Flee.W:Value() and isSpellReady(_W) then
        Control.CastSpell(HK_W)
    end
    if self.Menu.Flee.R:Value() and isSpellReady(_R) then
        Control.CastSpell(HK_R, mousePos)
    end
end

function Shyvana:Draw()
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R)then
            Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Trundle"
        
function Trundle:__init()	     
    print("Zgjfjfl-Trundle Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 775, Range = 750, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1000, Speed = math.huge, Collision = false}
    self.rSpell = { Range = 650 }
end

function Trundle:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgTrundle", name = "Zgjfjfl Trundle"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value = 60, min=0, max = 100 })
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Trundle:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

end

function Trundle:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Combo.W:Value() and isSpellReady(_W) then
            Control.CastSpell(HK_W, target)

        end
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
            Control.CastSpell(HK_Q)
        end
        if self.Menu.Combo.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) > 300 then
	local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) + 100)
            Control.CastSpell(HK_E, castPos)
        end

        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and self.Menu.Combo.R:Value() and isSpellReady(_R) and (myHero.health/myHero.maxHealth <= self.Menu.Combo.RHP:Value() / 100) then
                Control.CastSpell(HK_R, target)
            end

    end
end	

function Trundle:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Clear.W:Value() and isSpellReady(_W) then
            Control.CastSpell(HK_W, myHero)
        end
        if myHero.pos:DistanceTo(target.pos) <= 300 and self.Menu.Clear.Q:Value() and isSpellReady(_Q) then
            Control.CastSpell(HK_Q)
        end
    end

end

function Trundle:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(500);
    if target then

        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= myHero.range then
            Control.CastSpell(HK_Q)
        end

    end
end
function Trundle:Flee()   
    if self.Menu.Flee.W:Value() and isSpellReady(_W) then
        Control.CastSpell(HK_W, mousePos)
    end
    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range);
    if target then
    local pred = GGPrediction:SpellPrediction(self.eSpell)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), 75)
        if self.Menu.Flee.E:Value() and isSpellReady(_E) then
            Control.CastSpell(HK_E, castPos)
        end
    end
    end

end

function Trundle:Draw()   
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Rakan"
        
function Rakan:__init()	     
    print("Zgjfjfl-Rakan Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 900, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 250, Range = 600, Speed = 1700, Collision = false}
    self.eSpell = {Range = 700}
end

function Rakan:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgRakan", name = "Zgjfjfl Rakan"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Flee:MenuElement({id = "E", name = "[E] to Ally", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function Rakan:onTickEvent()
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and not hero.dead and hero.isAlly and not hero.isMe and hero.charName == "Xayah" then
            self.eSpell.Rang = 1000
        end
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

end

function Rakan:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1500);
    if target then
        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and isSpellReady(_W) then
            for i = 1, GameHeroCount() do
                local hero = GameHero(i)
                if hero and not hero.dead and hero.isAlly and not hero.isMe then
                    if myHero.pos:DistanceTo(hero.pos) <= self.eSpell.Range then
                        if getEnemyCount(self.wSpell.Range, myHero.pos) == 0 and getEnemyCount(self.wSpell.Range, hero.pos) >= 1 then
                            Control.CastSpell(HK_E, hero)
                        end
                    end
                end
            end
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             castSpellHigh(self.wSpell, HK_W, target)
        end
    end
end	

function Rakan:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(myHero.rang);
    if target then

        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
    end
end
function Rakan:Flee()   
    if self.Menu.Flee.W:Value() and isSpellReady(_W) then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.wSpell.Range
            Control.CastSpell(HK_W, pos)
    end

    if self.Menu.Flee.E:Value() and isSpellReady(_E) then
        for i = 1, GameHeroCount() do
            local hero = GameHero(i)
            if hero and not hero.dead and hero.isAlly and not hero.isMe then
            local distance1 = hero.pos:DistanceTo(myHero.pos)
            local distance2 = mousePos:DistanceTo(hero.pos)
                 if  distance2< mousePos:DistanceTo(myHero.pos) and distance1 <= self.eSpell.Range then
                    Control.CastSpell(HK_E, hero)
                 end
            end
        end
    end
end

function Rakan:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Belveth"
        
function Belveth:__init()	     
    print("Zgjfjfl-Belveth Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 50, Range = 450, Speed = myHero:GetSpellData(_E).speed, Collision =false}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 100, Range = 660, Speed = math.huge, Collision = false}
    self.eSpell = {Range = 500}
end

function Belveth:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgBelveth", name = "Zgjfjfl Belveth"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EHP", name = "[E] Use when self HP %", value = 30, min=0, max = 100 })
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function Belveth:onTickEvent()
    local castingE = doesMyChampionHaveBuff("BelvethE")
    if castingE and getEnemyCount(self.eSpell.Range, myHero.pos) == 0 and getMinionCount(self.eSpell.Range, myHero.pos) == 0 then
        Control.CastSpell(HK_E)
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:KillSteal()

end

function Belveth:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then
    local castingE = doesMyChampionHaveBuff("BelvethE")
        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and not castingE then
             castSpellHigh(self.qSpell, HK_Q, target)
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and not castingE then
             castSpellHigh(self.wSpell, HK_W, target)
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and getEnemyCount(self.eSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < self.Menu.Combo.EHP:Value()/100 then
             Control.CastSpell(HK_E)
        end

    end
end	

function Belveth:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then

        if myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range and self.Menu.Harass.W:Value() and isSpellReady(_W) then
             castSpellHigh(self.wSpell, HK_W, target)
        end
    end
end

function Belveth:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.W:Value() and isSpellReady(_W) then
            bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_W, bestPosition)
            end
        end
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
             Control.CastSpell(HK_Q, target)
        end
    end
end

function Belveth:Flee()   
    if self.Menu.Flee.Q:Value() and isSpellReady(_Q) then
        Control.CastSpell(HK_Q, mousePos)
    end
end

function Belveth:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range);
    if target then

  	if isSpellReady(_E) and self.Menu.KS.E:Value() then
			if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
		             Control.CastSpell(HK_E)
			end	
	    end
    end
end

function Belveth:geteDmg(target)
    local missingHP = (1 - (target.health / target.maxHealth))	
    local elvl = myHero:GetSpellData(_Q).level
    local ebaseDmg  = 2 * elvl + 6
    local eadDmg = myHero.totalDamage * 0.06
    local exttimes = math.floor(((myHero.attackSpeed / 0.85 - 1) / 0.333) + 0.5)
    local eDmg = (ebaseDmg + eadDmg) * (1 + missingHP * 3) * (6 + exttimes)
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg) 
end

function Belveth:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
-------------------------------
class "Nasus"
        
function Nasus:__init()	     
    print("Zgjfjfl-Nasus Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.wSpell = { Range = 700 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 650, Speed = math.huge, Collision =false}
end

function Nasus:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgNasus", name = "Zgjfjfl Nasus"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value=30, min=10, max=100})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "EH", name = "E hits x minions", value = 3, min = 1, max = 6})

    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
        self.Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Nasus:onTickEvent()

    local numEnemies = getEnemyHeroesWithinDistance(700)
    if #numEnemies >= 1 and myHero.health/myHero.maxHealth <= self.Menu.Combo.RHP:Value()/100 and self.Menu.Combo.R:Value() and isSpellReady(_R) then
        Control.CastSpell(HK_R)
   end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    self:KillSteal()

end

function Nasus:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             Control.CastSpell(HK_Q)
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             Control.CastSpell(HK_W, target)
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
             castSpellHigh(self.eSpell, HK_E, target)
        end

    end
end	

function Nasus:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000);
    if target then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Harass.Q:Value() and isSpellReady(_Q) then
             Control.CastSpell(HK_Q)
        end

        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) then
             castSpellHigh(self.eSpell, HK_E, target)
        end
    end
end

function Nasus:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.E:Value() and isSpellReady(_E) then
            bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
            if bestCount >= self.Menu.Clear.EH:Value() then 
                Control.CastSpell(HK_E, bestPosition)
            end
        end
    if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) < 300 and self:getqDmg(target) >= target.health then
        Control.CastSpell(HK_Q)
        Control.Attack(target)
    end
    end
end

function Nasus:LastHit()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
    
      if self.Menu.LastHit.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) < 300 and self:getqDmg(target) >= target.health then
        Control.CastSpell(HK_Q)
        Control.Attack(target)
    end
    end
end

function Nasus:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target then

        if isSpellReady(_E) and self.Menu.KS.E:Value() and self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
            Control.CastSpell(HK_E, target)
        end

        if isSpellReady(_Q) and self.Menu.KS.Q:Value() and self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < 300 then
            Control.CastSpell(HK_Q)
            Control.Attack(target)
        end	
    end
end 

function Nasus:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 20 * qlvl + 10
    local qDmg = qbaseDmg + getBuffData(myHero, "NasusQStacks").stacks + myHero.totalDamage
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function Nasus:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg = 40 * elvl + 15
    local eapDmg = 0.6 * myHero.ap
    local eDmg = ebaseDmg + eapDmg
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end



function Nasus:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------

class "Singed"
        
function Singed:__init()	     
    print("Zgjfjfl-Singed Loaded") 
    self:LoadMenu()
	
    Callback.Add("Tick", function() self:onTickEvent() end)
end

function Singed:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgSinged", name = "Zgjfjfl Singed"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})

end

function Singed:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

end

function Singed:Combo()

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target then
        
        local wcastpos = myHero.pos:Extended(target.pos, -400)
        if self.Menu.Combo.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) < 300 then
        orbwalker:SetAttack(false)
            Control.CastSpell(HK_W, wcastpos)
            DelayAction(function() Control.SetCursorPos(target) end, 0.25)
            DelayAction(function() Control.SetCursorPos(mousePos) end, 0.5)
            Control.CastSpell(HK_E)
            DelayAction(function() orbwalker:SetAttack(true) end, 1)
        end
        if self.Menu.Combo.W:Value() and isSpellReady(_W) and not isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) < 1000 then
            Control.CastSpell(HK_W, target)
        end


    end
end
------------------------------
class "Udyr"
        
function Udyr:__init()	     
    print("Zgjfjfl-Udyr Loaded") 
    self:LoadMenu()

    Callback.Add("Tick", function() self:onTickEvent() end)

  end

function Udyr:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgUdyr", name = "Zgjfjfl Udyr"})

    self.Menu:MenuElement({type = MENU, id = "Style", name = "Playstyle Set"})
        self.Menu.Style:MenuElement({id = "MainR", name = "Main R Playstyle", value = true})
        self.Menu.Style:MenuElement({id = "MainQ", name = "Main Q Playstyle", value = false})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Whp", name = "[W] use when X% hp ", value = 50, min = 0, max = 100})
        self.Menu.Combo:MenuElement({id = "W2hp", name = "use AwakenedW when self X% hp ", value = 30, min = 0, max = 100})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "Whp", name = "[W] use when self X% hp", value = 30, min = 0, max = 100})
        self.Menu.Clear:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

end

function Udyr:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
        self:JungleClear()
    end

   end

function Udyr:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(800)
    if target then
    local hasAwakenedQ = doesMyChampionHaveBuff("udyrqrecastready")
    local hasAwakenedW = doesMyChampionHaveBuff("udyrwrecastready")
    local hasAwakenedE = doesMyChampionHaveBuff("udyrerecastready")
    local hasAwakenedR = doesMyChampionHaveBuff("udyrrrecastready")
    local R1 = getBuffData(myHero, "UdyrRActivation")
    local haspassiveAA = doesMyChampionHaveBuff("UdyrPAttackReady")

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and not hasAwakenedE and not hasAwakenedR then
            Control.CastSpell(HK_E)
        end

        if self.Menu.Style.MainR:Value() then
            if self.Menu.Combo.R:Value() and isSpellReady(_R) and (not isSpellReady(_E) or hasAwakenedE or hasAwakenedR) and R1.duration < 1.5 and myHero.pos:DistanceTo(target.pos) < 450 then
                Control.CastSpell(HK_R)
            end
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and (not isSpellReady(_E) or hasAwakenedE) and (not isSpellReady(_R) or not hasAwakenedR) and not hasAwakenedQ and myHero.pos:DistanceTo(target.pos) < 300 then
                Control.CastSpell(HK_Q)
            end
        end

        if self.Menu.Style.MainQ:Value() then
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and (not isSpellReady(_E) or hasAwakenedE or (hasAwakenedQ and not haspassiveAA)) and myHero.pos:DistanceTo(target.pos) < 300 then
                Control.CastSpell(HK_Q)
            end
            if self.Menu.Combo.R:Value() and isSpellReady(_R) and (not isSpellReady(_E) or hasAwakenedE) and (not isSpellReady(_Q) or not hasAwakenedQ) and not hasAwakenedR and myHero.pos:DistanceTo(target.pos) < 450 then
                Control.CastSpell(HK_R)
            end
        end

        if myHero.health/myHero.maxHealth <= self.Menu.Combo.Whp:Value()/100 and self.Menu.Combo.W:Value() and isSpellReady(_W) and getEnemyCount(600, myHero.pos) >= 1 then
            Control.CastSpell(HK_W)
        end
        if myHero.health/myHero.maxHealth <= self.Menu.Combo.W2hp:Value()/100 and self.Menu.Combo.W:Value() and isSpellReady(_W) and hasAwakenedW and getEnemyCount(600, myHero.pos) >= 1 then
            Control.CastSpell(HK_W)
        end
    end
end	

function Udyr:JungleClear()
    local c = getMinionCount(450, myHero.pos)
    local hasAwakenedQ = doesMyChampionHaveBuff("udyrqrecastready")
    local hasAwakenedR = doesMyChampionHaveBuff("udyrrrecastready")
    local haspassiveAA = doesMyChampionHaveBuff("UdyrPAttackReady")
    local R1 = getBuffData(myHero, "UdyrRActivation")
    local target = HealthPrediction:GetJungleTarget()
    if target and not haspassiveAA then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and c == 1 then
            Control.CastSpell(HK_Q)
                if hasAwakenedQ then
                    Control.CastSpell(HK_Q)
                end
        elseif not hasAwakenedR and isSpellReady(_R) and not isSpellReady(_Q) then
                Control.CastSpell(HK_R)
        end
        if self.Menu.Clear.R:Value() and isSpellReady(_R) and c > 1 then
            Control.CastSpell(HK_R)
                if hasAwakenedR and R1.duration < 0.5 then
                    Control.CastSpell(HK_R)
                end
        elseif not hasAwakenedQ and isSpellReady(_Q) and not isSpellReady(_R) then
                Control.CastSpell(HK_Q)
        end
        if myHero.health/myHero.maxHealth <= self.Menu.Clear.Whp:Value()/100 and self.Menu.Clear.W:Value() and isSpellReady(_W) then
            Control.CastSpell(HK_W)
        end
    end
end

------------------------------
class "Galio"
        
function Galio:__init()	     
    print("Zgjfjfl-Galio Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 825, Speed = 1400, Collision =false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 650, Speed = 2300, Collision = false}
    self.wSpell = {Range = 480}
    self.lastWTick = GetTickCount()
end

function Galio:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgGalio", name = "Zgjfjfl Galio"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
        self.Menu.Auto:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "WHP", name = "Auto W self HP%&enemies inwrange", value = 30, min=0, max = 100 })
        self.Menu.Auto:MenuElement({type = MENU, id = "WB", name = "Auto W If Enemy dash on ME"})
            DelayAction(function()
                for i, Hero in pairs(getEnemyHeroes()) do
                    self.Menu.Auto.WB:MenuElement({id = Hero.charName, name =Hero.charName, value = false})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Galio:onTickEvent()
     if Control.IsKeyDown(HK_W) then
          orbwalker:SetAttack(false)
     else
          orbwalker:SetAttack(true)
     end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:AutoW()
    self:KillSteal()

end

function Galio:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target then
        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end

        local pred = GGPrediction:SpellPrediction(self.eSpell)
        pred:GetPrediction(target, myHero)
            if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local lineE = LineSegment(myHero.pos, pred.CastPosition)
                if not MapPosition:intersectsWall(lineE) then
                    if self.Menu.Combo.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
                         castSpellHigh(self.eSpell, HK_E, target)
                    end
                end
            end

        if self.Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             self:CastW()
        end
    end
end	

function Galio:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then

        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
    end
end

function Galio:AutoW()

        if self.Menu.Auto.W:Value() and getEnemyCount(self.wSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < self.Menu.Auto.WHP:Value()/100 then
             self:CastW()
        end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target then
        local obj = self.Menu.Auto.WB[target.charName] and self.Menu.Auto.WB[target.charName]:Value()
        if obj and target.pathing.isDashing then
        local vct = Vector(target.pathing.endPos.x, target.pathing.endPos.y, target.pathing.endPos.z)
            if vct:DistanceTo(myHero.pos) < self.wSpell.Range then
                self:CastW()
            end
        end
    end
end

function Galio:CastW()
    if isSpellReady(_W) and self.lastWTick + 300 < GetTickCount() then
        Control.KeyDown(HK_W)
        self.lastWTick = GetTickCount()
        DelayAction(function() Control.KeyUp(HK_W) end, 2)
    end
end

function Galio:Flee()   
    if self.Menu.Flee.E:Value() and isSpellReady(_E) then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.eSpell.Range
            Control.CastSpell(HK_E, pos)
    end
end

function Galio:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then

  	if isSpellReady(_Q) and self.Menu.KS.Q:Value() then
			if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
		             castSpellHigh(self.qSpell, HK_Q, target)
			end	
	    end
    end
end

function Galio:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 35 * qlvl + 35
    local qapDmg = myHero.ap * 0.75
    local qDmg = qbaseDmg + qapDmg
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg) 
end


function Galio:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
    end
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(225, 225, 0, 10))
    end

end
------------------------------
class "Yorick"
        
function Yorick:__init()	     
    print("Zgjfjfl-Yorick Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 200, Range = 600, Speed = math.huge, Collision =false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.33, Radius = 80, Range = 1100, Speed = 1800, Collision = false}
    self.rSpell = {Range = 600}
    self.lastQTick = GetTickCount()
end

function Yorick:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgYorick", name = "Zgjfjfl Yorick"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true, key=string.byte("S")})
        self.Menu.Combo:MenuElement({id = "R1", name = "[R1] ", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "Q2", name = "[Q2] activate Mist Walker", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
	
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
        self.Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
        self.Menu.Auto:MenuElement({id = "W", name = "AutoW on Immobile Target", value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Yorick:onTickEvent()
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:KillSteal()
    self:AutoW()
end

 function castSpellExtended(spellData, hotkey, target, extendAmount)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		if myHero.pos:DistanceTo(pred.CastPosition)<210 then 
			local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos),(myHero.pos:DistanceTo(pred.CastPosition)-70)) 
			Control.CastSpell(hotkey,castPos)	
		
		else
			local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), extendAmount) 	
			Control.CastSpell(hotkey, castPos)	
		end
    end
end

function Yorick:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1100);
    if target then
        if myHero.pos:DistanceTo(target.pos) <= 300 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             Control.CastSpell(HK_Q)
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             castSpellHigh(self.wSpell, HK_W, target)
        end


        if self.Menu.Combo.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
             castSpellExtended(self.eSpell, HK_E, target,200)
        end
		


        local R2ready = myHero:GetSpellData(_R).mana == 0
        if self.Menu.Combo.R1:Value() and isSpellReady(_R) and not R2ready and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range then
             Control.CastSpell(HK_R, target)
        end

    end
end	

function Yorick:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target then

        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) then
             castSpellHigh(self.eSpell, HK_E, target)
        end
    end
end

function Yorick:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        local Q2ready = myHero:GetSpellData(_Q).mana == 0
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and self.lastQTick + 300 < GetTickCount() and not Q2ready and myHero.pos:DistanceTo(target.pos) <= 300 and self:getqDmg(target) >= target.health then
            Control.CastSpell(HK_Q)
            self.lastQTick = GetTickCount()
            Control.Attack(target)
        end

        if self.Menu.Clear.Q2:Value() and Q2ready then
            Control.CastSpell(HK_Q)
        end

        if self.Menu.Clear.E:Value() and isSpellReady(_E) then
            bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_E, bestPosition)
            end
        end
    end
end

function Yorick:LastHit()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        local Q2ready = myHero:GetSpellData(_Q).mana == 0
        if self.Menu.LastHit.Q:Value() and isSpellReady(_Q) and self.lastQTick + 300 < GetTickCount() and not Q2ready and myHero.pos:DistanceTo(target.pos) <= 300 and self:getqDmg(target) >= target.health then
            Control.CastSpell(HK_Q)
            self.lastQTick = GetTickCount()
            Control.Attack(target)
        end
    end
end

function Yorick:Flee()
    local target = _G.SDK.TargetSelector:GetTarget(self.wSpell.Range);
    if target then

        if self.Menu.Flee.W:Value() and isSpellReady(_W) then
            if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
                 castSpell(self.wSpell, HK_W, target)
            end
         end
    end
end

function Yorick:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target then

  	if isSpellReady(_Q) and self.Menu.KS.Q:Value() then
	    if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= 300 then
	        Control.CastSpell(HK_Q)
	        Control.Attack(target)
	    end	
	end

  	if isSpellReady(_E) and self.Menu.KS.E:Value() then
	    if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
	        castSpellHigh(self.eSpell, HK_E, target)
	    end	
	end
    end
end

function Yorick:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 25 * qlvl + 5
    local qadDmg = myHero.totalDamage * 0.4
    local qDmg = qbaseDmg + qadDmg + myHero.totalDamage
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function Yorick:geteDmg(target)
    local elvl = myHero:GetSpellData(_Q).level
    local ebaseDmg  = 35 * elvl + 35
    local eapDmg = myHero.ap * 0.7
    local eDmg = ebaseDmg + eapDmg
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function Yorick:AutoW()
    if _G.SDK.Attack:IsActive() then return end
    for i, target in pairs(getEnemyHeroes()) do
        if self.Menu.Auto.W:Value() and isSpellReady(_W) and isInvulnerable(target) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            Control.CastSpell(HK_W, target)
        end
    end
			
    local target = _G.SDK.TargetSelector:GetTarget(self.wSpell.Range)
    if target then
        if self.Menu.Auto.W:Value() and isSpellReady(_W) and isImmobile(target) then
            if myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
                castSpellHigh(self.wSpell, HK_W, target)
            end
        end
    end
end

function Yorick:Draw()

    if self.Menu.Combo.E:Value() then
        Draw.Text("E: On ",20,myHero.pos:To2D(),Draw.Color(255 ,0,255,0))
    else
        Draw.Text("E: Off ",20,myHero.pos:To2D(),Draw.Color(255 ,255,0,0))

    end



    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
    end

end
------------------------------
class "Ivern"
        
function Ivern:__init()	     
    print("Zgjfjfl-Ivern Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1100, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.eSpell = { Range = 750 }
    self.rSpell = { Range = 800 }
    self.lastQTick = GetTickCount()
    self.lastRTick = GetTickCount()
end

function Ivern:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgIvern", name = "Zgjfjfl Ivern"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto E"})
        self.Menu.Auto:MenuElement({id = "Eally", name = "[E] auto on ally,when enemies inrange", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "Eself", name = "[E] auto on self,when enemies inrange", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Ivern:onTickEvent()
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    self:AutoE()
end

function Ivern:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range);
    if target then
        local Q2ready = myHero:GetSpellData(_Q).mana == 0
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.lastQTick + 300 < GetTickCount() and not Q2ready and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
            self.lastQTick = GetTickCount()
        end
        local R2ready = myHero:GetSpellData(_R).mana == 0
        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and self.lastRTick + 300 < GetTickCount() and not R2ready and self.Menu.Combo.R:Value() and isSpellReady(_R) then
             Control.CastSpell(HK_R, target)
            self.lastRTick = GetTickCount()
        end
    end
end	

function Ivern:AutoE()
    if _G.SDK.Attack:IsActive() then return end
        for i = 1, GameHeroCount() do
        local hero = GameHero(i)
            if hero and not hero.dead and hero.isAlly and not hero.isMe then
                if myHero.pos:DistanceTo(hero.pos) <= self.eSpell.Range then
                    if getEnemyCount(500, myHero.pos) == 0 and getEnemyCount(500, hero.pos) >= 1 and self.Menu.Auto.Eally:Value() and isSpellReady(_E) then
                        Control.CastSpell(HK_E, hero)
                    end
                end
            end
            if self.Menu.Auto.Eself:Value() and isSpellReady(_E) and getEnemyCount(500, myHero.pos) >= 1 then
                Control.CastSpell(HK_E, myHero)
            end
        end
end

function Ivern:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "Bard"
        
function Bard:__init()	     
    print("Zgjfjfl-Bard Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 850, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
end

function Bard:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgBard", name = "Zgjfjfl Bard"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q] Single", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Q2", name = "[Q] Stun with minion or enemyteam", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Q3", name = "[Q] Stun with wall", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
        self.Menu.Auto:MenuElement({id = "W", name = "[W] Auto", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "Whp", name = "[W] auto on ally or self X hp%", value = 30, min = 0, max = 100, step = 5})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function Bard:onTickEvent()
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    self:AutoW()
end

function Bard:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end

        local pred = GGPrediction:SpellPrediction(self.qSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local extendPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -300)
            local lineQ = LineSegment(pred.CastPosition, extendPos)
            if MapPosition:intersectsWall(lineQ) and self.Menu.Combo.Q3:Value() and isSpellReady(_Q) then
                Control.CastSpell(HK_Q, target)
            end
        end

        local pred2 = target:GetPrediction(self.qSpell.Speed, self.qSpell.Delay)
        if pred2 == nil then return end
        local d = getDistance(myHero.pos, pred2)
        local targetPos = Vector(myHero.pos):Extended(pred2, self.qSpell.Range+300) 
        if isSpellReady(_Q) and self.Menu.Combo.Q2:Value() then 
            for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i) 
                if minion and minion.isEnemy and not minion.dead then
                local minionPos = Vector(myHero.pos):Extended(Vector(minion.pos), self.qSpell.Range+300)
                    if getDistance(targetPos, minionPos) <= 30 then
                    local d2 = getDistance(myHero.pos, minion.pos)
                        if d2 <= self.qSpell.Range and d <= self.qSpell.Range+300 and d > d2 then 
                            Control.CastSpell(HK_Q, minion)
                        elseif d2 <= self.qSpell.Range+300 and d <= self.qSpell.Range and d < d2 then
                            Control.CastSpell(HK_Q, pred2)
                        end
                    end
                end 
            end
            for i, Enemy in pairs(getEnemyHeroes()) do
                if Enemy and Enemy ~= target then 
                    local EnemyPos = Vector(myHero.pos):Extended(Vector(Enemy.pos), self.qSpell.Range+300)
                    if getDistance(targetPos, EnemyPos) <= 30 then
                    local d3 = getDistance(myHero.pos, Enemy.pos)
                        if d3 <= self.qSpell.Range and d <= self.qSpell.Range+300 and d > d3 then 
                            Control.CastSpell(HK_Q, Enemy)
                        elseif d3 <= self.qSpell.Range+300 and d <= self.qSpell.Range and d < d3 then
                            Control.CastSpell(HK_Q, pred2)
                        end
                    end
                end
            end
        end
    end
end

function Bard:AutoW()
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and not hero.dead and hero.isAlly then
            if getDistance(myHero.pos, hero.pos) <= self.wSpell.Range and self.Menu.Auto.W:Value() and hero.health/hero.maxHealth <= self.Menu.Auto.Whp:Value()/100 and isSpellReady(_W) then
                Control.CastSpell(HK_W, hero)
            end
        end
    end
end

function Bard:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end

------------------------------
class "Taliyah"
        
function Taliyah:__init()	     
    print("Zgjfjfl-Taliyah Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1000, Speed = myHero:GetSpellData(_Q).speed, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 225, Range = 900, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 200, Range = 950, Speed = 1700, Collision = false}
end

function Taliyah:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgTaliyah", name = "Zgjfjfl Taliyah"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Wpush", name = "[W] push range", value = 400, min = 100, max = 600, step = 50})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Erange", name = "[E] cast range", value = 950, min = 100, max = 950, step = 50})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

local NextTick = Game.Timer()
function Taliyah:onTickEvent()
    local currentTime = Game.Timer()
    if NextTick > currentTime then return end	
    if #vectorCast > 0 then
        vectorCast[1]()
        table.remove(vectorCast, 1)
        return
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
end

function Taliyah:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end

        if myHero.pos:DistanceTo(target.pos) < self.Menu.Combo.Erange:Value() and self.Menu.Combo.E:Value() and isSpellReady(_E) then
             Control.CastSpell(HK_E, target)
        end

        local pred = GGPrediction:SpellPrediction(self.wSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local endPos1 = pred.CastPosition + (myHero.pos - pred.CastPosition):Normalized() * 225
            local endPos2 = pred.CastPosition + (pred.CastPosition - myHero.pos):Normalized() * 225
            local d = myHero.pos:DistanceTo(pred.CastPosition)
            if self.Menu.Combo.W:Value() and isSpellReady(_W) then
                if d < self.wSpell.Range and d > self.Menu.Combo.Wpush:Value() then
                    CastVectorSpell(HK_W, target.pos, endPos1)
                elseif d <= self.Menu.Combo.Wpush:Value() then
                    CastVectorSpell(HK_W, target.pos, endPos2)
                end
            end
        end
    end
end

function Taliyah:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range);
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
    end
end

function Taliyah:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end

------------------------------

local EnemyHeroes = {}
local LocalGetTickCount         = GetTickCount
local LocalVector		= Vector
local LocalCallbackAdd		= Callback.Add
local LocalCallbackDel		= Callback.Del
local LocalDrawLine		= Draw.Line
local LocalDrawColor		= Draw.Color
local LocalDrawCircle		= Draw.Circle
local LocalCastSpell            = Control.CastSpell
local LocalControlMove          = Control.Move
local LocalControlIsKeyDown	= Control.IsKeyDown
local LocalControlKeyUp  	= Control.KeyUp
local LocalControlKeyDown	= Control.KeyDown
local LocalGameCanUseSpell	= Game.CanUseSpell
local LocalGameHeroCount 	= Game.HeroCount
local LocalGameHero 		= Game.Hero
local LocalGameMinionCount 	= Game.MinionCount
local LocalGameMinion 		= Game.Minion

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
local myHero = _G.myHero


class "Lissandra"
        
function Lissandra:__init()	     
    print("Zgjfjfl-Lissandra Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 150, Range = 725, Speed = 2200, Collision = false}
    self.wSpell = { Range = 450 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 125, Range = 1050, Speed = 1200, Collision = false}
    self.rSpell = { Range = 550 }
    self.lastETick = GetTickCount()
	
	self.Menu.Combo:MenuElement({type = MENU, name = "R White List1",  id = "rWhiteList1"})
        for i, Enemy in pairs(GetEnemyHeroes()) do
        	self.Menu.Combo.rWhiteList1:MenuElement({name = Enemy.charName,  id = Enemy.charName, value = true})
			print("test")
        end
	
	
end

function Lissandra:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgLissandra", name = "Zgjfjfl Lissandra"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Q2", name = "[Q] Extended", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		self.Menu.Combo:MenuElement({id = "Wenemies", name = "[W] aoe when doesn't include target", value = 3, min = 1, max = 6, step = 1})
        self.Menu.Combo:MenuElement({id = "E1", name = "[E1]", toggle = true, value = true})
		self.Menu.Combo:MenuElement({id = "R", name = "[R] on target", toggle = false, value = false, key=string.byte("S")})
	

		
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "Q2", name = "[Q] Extended", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto setting"})
        self.Menu.Auto:MenuElement({id = "Q", name = "Auto Harass With Extended Q", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "Qmana", name = "Q Mana Manager(%)", value = 50, min = 0, max = 100, step = 5})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Lissandra:onTickEvent()
    if doesMyChampionHaveBuff("LissandraRSelf") then
        orbwalker:SetMovement(false)
        orbwalker:SetAttack(false)
    else
        orbwalker:SetMovement(true)
        orbwalker:SetAttack(true)
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
	if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and isSpellReady(_R) then
     	Control.KeyDown(18)
		Control.KeyDown(HK_R)
		Control.KeyUp(HK_R)
		Control.KeyUp(18)   
		
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
	if self.Menu.Combo.R:Value() and isSpellReady(_R) then
	self:castR()
	end
    self:AutoQ()
end

local function HasBuffType(unit, type)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.type == type then
            return true
        end
    end
    return false

end


local function cantkill(unit,kill,ss,aa)
	--set kill to true if you dont want to waste on undying/revive targets
	--set ss to true if you dont want to cast on spellshield
	--set aa to true if ability applies onhit (yone q, ez q etc)

	for i = 0, unit.buffCount do
	
		local buff = unit:GetBuff(i)
		if buff.name:lower():find("kayler") and buff.count==1 then
			return true
		end
		
	
		if buff.name:lower():find("undyingrage") and (unit.health<100 or kill) and buff.count==1 then
			return true
		end
		if buff.name:lower():find("kindredrnodeathbuff") and (kill or (unit.health / unit.maxHealth)<0.11) and buff.count==1 then
			return true
		end	
		if buff.name:lower():find("chronoshift") and kill and buff.count==1 then
			return true
		end			
		
		if  buff.name:lower():find("willrevive") and kill and buff.count==1 then
			return true
		end
		
		if buff.name:lower():find("morganae") and buff.count==1  then 
			return true
		end
		
		if (buff.name:lower():find("fioraw") or buff.name:lower():find("pantheone")) and buff.count==1 then
			return true
		end
		
		if  buff.name:lower():find("jaxcounterstrike") and aa and buff.count==1  then
			return true
		end
		
		if  buff.name:lower():find("nilahw") and aa and buff.count==1  then
			return true
		end
		
		if  buff.name:lower():find("shenwbuff") and aa and buff.count==1  then
			return true
		end
		
	end
	if HasBuffType(unit, 4) and ss then
		return true
	end

	
	
	return false
end

function Lissandra:castR()
	target = _G.SDK.TargetSelector:GetTarget(565)
	if target and not cantkill(target,false,true,false) then
	Control.CastSpell(HK_R,target)
	
	end
end

function Lissandra:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target then
		if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Combo.W:Value() and isSpellReady(_W)  then
             Control.CastSpell(HK_W)
 		end
	
	
		
	
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
        if self.Menu.Combo.Q2:Value() then
            self:CastQ2(target)
        end

        local E2ready = doesMyChampionHaveBuff("LissandraE")
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.lastETick + 300 < GetTickCount() and not E2ready and self.Menu.Combo.E1:Value() and isSpellReady(_E) then
            castSpellHigh(self.eSpell, HK_E, target)
            self.lastQTick = GetTickCount()
        end
		

    end
    if getEnemyCount(self.wSpell.Range, myHero.pos) >= self.Menu.Combo.Wenemies:Value() and self.Menu.Combo.W:Value() and isSpellReady(_W) then
         Control.CastSpell(HK_W)
    end
end

function Lissandra:Harass()
	
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
        if self.Menu.Harass.Q2:Value() then
            self:CastQ2(target)
        end
    end
end

function Lissandra:AutoQ()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target then
        if self.Menu.Auto.Q:Value() and myHero.mana/myHero.maxMana >= self.Menu.Auto.Qmana:Value()/100 then
            self:CastQ2(target)
        end
    end
end

function Lissandra:CastQ2(target) 
        local pred = target:GetPrediction(self.qSpell.Speed, self.qSpell.Delay)
        if pred == nil then return end  
        if isSpellReady(_Q)  and getDistance(myHero.pos, pred) < 825 then 
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i) 
        		if minion and minion.isEnemy and not minion.dead and getDistance(myHero.pos, minion.pos) <= 725 then 
					local mincheck = Vector(myHero.pos):Extended(pred,getDistance(myHero.pos, minion.pos)) 
        			if getDistance(mincheck, minion.pos) <= 100 then 
        				Control.CastSpell(HK_Q, pred) 
        			end 
        		end 
            end 
			for i, Enemy in pairs(getEnemyHeroes()) do
        		if Enemy and not Enemy.dead and getDistance(myHero.pos, Enemy.pos) <= 725 then 
					local EnemyCheck = Vector(myHero.pos):Extended(pred,getDistance(myHero.pos, Enemy.pos))  
        			if getDistance (Enemy.pos, EnemyCheck) <= 100 then 
        				Control.CastSpell(HK_Q, pred) 
        			end 
        		end 
        	end 
        end 
end

function Lissandra:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "Sejuani"
        
function Sejuani:__init()	     
    print("Zgjfjfl-Sejuani Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 650, Speed = 1000, Collision = false}
    self.wSpell = { Range = 600 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 120, Range = 1300, Speed = 1600, Collision = true, CollisionTypes = {COLLISION_YASUOWALL}}
    self.eSpell = { Range = 600 }
end

function Sejuani:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgSejuani", name = "Zgjfjfl Sejuani"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Sejuani:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end
end

function Sejuani:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Combo.W:Value() and isSpellReady(_W) then
             castSpellHigh(self.wSpell, HK_W, target)
        end
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) then
             Control.CastSpell(HK_E)
        end
    end
end

function Sejuani:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.wSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Harass.W:Value() and isSpellReady(_W) then
             castSpellHigh(self.wSpell, HK_W, target)
        end
    end
end

function Sejuani:RSemiManual()
    local target = _G.SDK.TargetSelector:GetTarget(self.rSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and isSpellReady(_R) then
             castSpellHigh(self.rSpell, HK_R, target)
        end
    end
end

function Sejuani:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "KSante"
        
function KSante:__init()	     
    print("Zgjfjfl-KSante Loaded") 
	require("MapPositionGOS")
	lastW = 0
	morde=0
    self:LoadMenu()
	self.Qtimer = Game.Timer()
    Callback.Add("Tick", function() self:onTickEvent() end)
	Callback.Add("Draw", function() self:Draw() end)
    self.q1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 75, Range = 465, Speed = math.huge, Collision = false}
    self.q3Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 70, Range = 800, Speed = 1800, Collision = false}
	Callback.Add("Draw", function() self:Draw() end)
    self.wSpell = { Range = 400 }
    self.e1Spell = { Range = 250 }
    self.e2Spell = { Range = 400 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 350, Speed = 2000, Collision = false}
    self.lastWTick = GetTickCount()
end

function KSante:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgKSante", name = "Zgjfjfl KSante"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		self.Menu.Combo:MenuElement({id = "Qprio", name = "use q even if has q passive on", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		self.Menu.Combo:MenuElement({id = "Waim", name = "W aim", toggle = true, value = true})
		self.Menu.Combo:MenuElement({id = "Wkey", name = "W key (bind LoL w key to 'L', this to w or whatever)", toggle = false, value = valse, key=string.byte("E")})
        self.Menu.Combo:MenuElement({id = "E", name = "[E], will only use on allies 400 units or less from target", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key (walls only)", key = string.byte("T")})
        self.Menu.Combo:MenuElement({id = "RMflee", name = "[R] Semi-Manual Key", key = string.byte("A")})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
        self.Menu.LastHit:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})	
end

function KSante:Draw()
	    if doesMyChampionHaveBuff("KSanteQ3") then
        self.qSpell = self.q3Spell
    else
        self.qSpell = self.q1Spell
    end
    if self.Menu.Draw.Q:Value() then
            Draw.Circle(myHero.pos,self.qSpell.Range, Draw.Color(255, 225, 100, 5))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, 600, Draw.Color(255, 225, 255, 5))
    end
end
--just trust me on the qmath

function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 
    and myHero:GetSpellData(spell).level > 0 
    and myHero:GetSpellData(spell).mana <= myHero.mana 
    and Game.CanUseSpell(spell) == 0
end



function KSante:onTickEvent()
	qmath=math.max(0.45-(1/9000)*(myHero.maxHealth-(610+108*(myHero.levelData.lvl-1)*(0.7025+(0.0175*(myHero.levelData.lvl-1))))),0.25)
	self.q1Spell.Delay=qmath
	self.q3Spell.Delay=qmath
	--print(self.q1Spell.Delay)
    if doesMyChampionHaveBuff("KSanteQ3") then
        self.qSpell = self.q3Spell
    else
        self.qSpell = self.q1Spell
    end
    if HaveBuff(myHero, "KSanteW") or HaveBuff(myHero, "KSanteW_AllOut") then
        orbwalker:SetMovement(false)
        orbwalker:SetAttack(false)
    else
        orbwalker:SetMovement(true)
        orbwalker:SetAttack(true)
    end
	
	if HaveBuff(myHero, "MordekaiserR") then
		Control.KeyDown("L")
		print("1")
		morde=GetTickCount()
		lastW=GetTickCount()
	end
	
	if doesMyChampionHaveBuff(myHero, "MordekaiserR") then
		Control.KeyDown("L")
		print("2")
		lastW=GetTickCount()
	end
	
	CastingQ = myHero.activeSpell.name == myHero:GetSpellData(_Q).name
	CastingW = myHero.activeSpell.name == myHero:GetSpellData(_W).name
	CastingE = myHero.activeSpell.name == myHero:GetSpellData(_E).name
	CastingR = myHero.activeSpell.name == myHero:GetSpellData(_R).name
    if doesMyChampionHaveBuff("KSanteRTransform") then
		 QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 100, Range = 600, Speed = 1800, Collision = false})
        self.eSpell = self.e2Spell
    else
        self.eSpell = self.e1Spell
		 QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 100, Range = 600, Speed = 1000, Collision = false})
    end

	if self.Menu.Combo.Wkey:Value() then
		--if Control.IsKeyDown("L") and not (HaveBuff(myHero, "KSanteW") or HaveBuff(myHero, "KSanteW_AllOut")) and not Ready(_W) then
		if not Ready(_W) then
			Control.KeyUp("L")
			--lastW=GetTickCount()
			print("up")
		end
		if Ready(_W) and not Control.IsKeyDown("L")  and self:CastingChecks() and not _G.SDK.Attack:IsActive()  then
			Control.KeyDown("L")
			lastW=GetTickCount()
			print("down")
		end
		if Ready(_W) and _G.dodge+1.5> Game.Timer() then
			Control.KeyUp("L")
			lastW=GetTickCount()
			print("dodgeup")
		end
	elseif (HaveBuff(myHero, "KSanteW") or HaveBuff(myHero, "KSanteW_AllOut")) then
		local target =false or _G.SDK.TargetSelector:GetTarget(600)
		if target and  self.Menu.Combo.Waim:Value() and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and (getDistance(myHero.pos,target.pos)>200 or( target and not IsMyHeroFacing(target))) and _G.dodge+1.2< Game.Timer() then
			QPrediction:GetPrediction(target, myHero)      
			print("looking",Game.Timer())
			if  QPrediction:CanHit(1) and _G.SDK.Cursor.Step == 0 then
				_G.SDK.Cursor:Add("L", QPrediction.CastPosition) 
				-- Control.SetCursorPos(Pred.CastPosition)
				-- ControlKeyUp(HK_Q)
				--Control.CastSpell(HK_Q,Pred.CastPosition)
				lastQup = GetTickCount()
				self.Qchannel = false
			end
		elseif _G.dodge+1.5< Game.Timer() then
			Control.KeyUp("L")
		end
	end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end

	
	if not (HaveBuff(myHero, "KSanteW") or HaveBuff(myHero, "KSanteW_AllOut")) and  lastW+300< GetTickCount() and _G.dodge+1.5< Game.Timer() then
            local wSpell = myHero:GetSpellData(_W)
            if Control.IsKeyDown("L") and not self.Menu.Combo.Wkey:Value() then
                Control.KeyUp("L")--release stuck key
				print("w")
            end
    end

end

function KSante:CastingChecks()
	if not CastingQ or CastingW or CastingR then
		return true
	else 
		return false
	end
end

function KSante:Combo()
   mins= _G.SDK.ObjectManager:GetAllyMinions(550)
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range + self.eSpell.Range)
    if target then
        if self.Menu.Combo.E:Value() and isSpellReady(_E) then
		local ekey=HK_E
		if _G.DashtoolEnabled == true then ekey= _G.elolkey end --isbjorn's test.lua

            for i = 1, GameHeroCount() do
                local hero = GameHero(i)
                if hero and not hero.dead and hero.isAlly and not hero.isMe then
                    if myHero.pos:DistanceTo(hero.pos) <= 550 then
                        if getDistance(hero.pos,target.pos) <400 then
							Control.KeyUp("M") -- target champs only key in isbjorn's activator
                            Control.CastSpell(ekey, hero)
							
                        end
                    end


                end
            end
  
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i) 
        		if minion and minion.isAlly and not minion.dead and getDistance(myHero.pos, minion.pos) <= 550 and getDistance(target.pos, minion.pos)<300 and getDistance(target.pos, minion.pos)<getDistance(myHero.pos,target.pos) and (getDistance(target.pos, myHero.pos)>550 and (not doesMyChampionHaveBuff("KSanteQ3"))) then 
					Control.CastSpell(ekey, minion)
				end
			end
		end
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and _G.SDK.Orbwalker:CanMove(myHero) and isSpellReady(_Q) and (self.Menu.Combo.Qprio:Value() or (doesMyChampionHaveBuff("KSanteQ3") or (getDistance(myHero.pos, target.pos) >= 350  or HaveBuff(target,"KSantePMark")==false))) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
        --if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Combo.W:Value() and not HaveBuff(target,"KSantePMark")  then
            --if not isSpellReady(_Q) then
                -- self:CastQ2(target)
           -- end
        --end
    end
end

function KSante:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) then
             castSpellHigh(self.qSpell, HK_Q, target)
        end
    end
end

function KSante:castW(target)
	    if (not self.Menu.Combo.Wkey:Value()) and not HaveBuff(myHero, "KSanteW") and  self.lastWTick+200 < GetTickCount()  then
            local wSpell = myHero:GetSpellData(_W)
            if Control.IsKeyDown("L") then
                Control.KeyUp(HK_W)--release stuck key
				print("releasedstuck")
            end
			
          --  return
        end


    if isSpellReady(_W) then --and self.lastWTick + 300 < GetTickCount() then
        Control.KeyDown(HK_W)
        self.lastWTick = GetTickCount() 
        if Control.IsKeyDown(HK_W) then
			wbuff=getBuffData(myHero, "KSanteW")
			if HaveBuff(myHero,"KSanteW") and wbuff.duration<0.5 then
				print("release")
				Control.SetCursorPos(target)
				Control.KeyUp(HK_W)
				DelayAction(function() Control.SetCursorPos(mousePos) end, 0.02)
				wbuff=nil
			end
           -- DelayAction(function()  end, 1)
          --  DelayAction(function() Control.SetCursorPos(mousePos) end, 1)
        end
    end
end

-- local GameHeroCount     = Game.HeroCount
-- local GameHero          = Game.Hero
-- local TableInsert       = _G.table.insert
-- local orbwalker         = _G.SDK.Orbwalker
-- local TargetSelector    = _G.SDK.TargetSelector
-- local LocalGameTimer = Game.Timer
-- local ControlKeyDown = Control.KeyDown
-- local ControlKeyUp = Control.KeyUp

local myHero = myHero

local lastQ = 0
local lastQdown = 0
local lastQup = 0
local lastW = 0
local lastE = 0
local lastR = 0
local lastIG = 0
local lastMove = 0
local lastAttack = 0


	
	
function KSante:iswon()
			
			wbuff=getBuffData(myHero, "KSanteW")
			wbuff2=getBuffData(myHero, "KSanteW_AllOut")
			if (HaveBuff(myHero,"KSanteW") and wbuff.duration<0.5) or (HaveBuff(myHero,"KSanteW_AllOut") and wbuff2.duration<0.3)  then
			print(wbuff.duration)
			return true
			end
			return false
end
function KSante:CastQ2(target)
    -- if LocalGameTimer() > (self.Qtimer + 1.5)  and Ready(_W)
    -- and lastQdown + 150 < GetTickCount() and myHero.pos:DistanceTo(target.pos)<400
    -- then
        -- ControlKeyDown(HK_W)
        -- lastQdown = GetTickCount()
        -- self.Qchannel = true
        -- self.Qtimer = LocalGameTimer()
    -- end
	
    --if LocalGameTimer() >= self.Qtimer + 0.7 and LocalGameTimer() < self.Qtimer + 2
   -- and self.Qchannel and Ready(_W)  and  lastQup + 150 < GetTickCount() then
   if self:iswon() then
   -- and self.Qchannel and Ready(_W)  and  lastQup + 150 < GetTickCount() then
	
		
		QPrediction:GetPrediction(target, myHero)

		print("looking",Game.Timer())
        if  QPrediction:CanHit(1) and _G.SDK.Cursor.Step == 0 then
			_G.SDK.Cursor:Add("L", QPrediction.CastPosition) 
            -- Control.SetCursorPos(Pred.CastPosition)
            -- ControlKeyUp(HK_Q)
            --Control.CastSpell(HK_Q,Pred.CastPosition)
            lastQup = GetTickCount()
            self.Qchannel = false
        end
    end
end

function KSante:CheckWall(from, to, distance)
	local pos1 = to + (to - from):Normalized() * 50
	local pos2 = pos1 + (to - from):Normalized() * (distance - 50)
	local point1 = { x = pos1.x, z = pos1.z }
	local point2 = { x = pos2.x, z = pos2.z }
	if MapPosition:intersectsWall(point1, point2) or (MapPosition:inWall(point1) and MapPosition:inWall(point2)) then
		return true
	end
	return false
end
function KSante:RSemiManual()
    local target = _G.SDK.TargetSelector:GetTarget(self.rSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and isSpellReady(_R) and self:CheckWall(myHero.pos, target.pos, 375) then
             Control.CastSpell(HK_R, target)
        end
    end
end
function KSante:RSemiManualflee()
    local target = _G.SDK.TargetSelector:GetTarget(self.rSpell.Range)
    if target then
        if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and isSpellReady(_R) then
             Control.CastSpell(HK_R, target)
        end
    end
end

function KSante:LaneClear()
	local range = (doesMyChampionHaveBuff("KSanteQ3") and 800) or 460
    local minionInRange = _G.SDK.ObjectManager:GetEnemyMinions(range)
    if next(minionInRange) == nil then return  end
	local baseDmg = ({50, 75, 100,125,150})[myHero:GetSpellData(_Q).level]
	local bonusDmg = (myHero.bonusArmor * 0.30) +(myHero.bonusMagicResist*0.3)+myHero.totalDamage*0.4
	local value = baseDmg + bonusDmg
	
    for i = 1, #minionInRange do
        local minion = minionInRange[i]
		

        if self.Menu.Clear.Q:Value() and Ready(_Q) and myHero.pos:DistanceTo(minion.pos) < range and  myHero.pos:DistanceTo(minion.pos) > 310 and  _G.SDK.Orbwalker:CanMove(myHero) then
			local QDmg = value
			if QDmg > _G.SDK.HealthPrediction:GetPrediction(minion, qmath) then
				Control.CastSpell(HK_Q, minion.pos)
				self.lastQTick = GetTickCount()
			end	
        end
    end
end
function KSante:LastHit()
	local range = (doesMyChampionHaveBuff("KSanteQ3") and 800) or 460
    local minionInRange = _G.SDK.ObjectManager:GetEnemyMinions(range)
    if next(minionInRange) == nil then return  end
	local baseDmg = ({50, 75, 100,125,150})[myHero:GetSpellData(_Q).level]
	local bonusDmg = (myHero.bonusArmor * 0.30) +(myHero.bonusMagicResist*0.3)+myHero.totalDamage*0.4
	local value = baseDmg + bonusDmg
	
    for i = 1, #minionInRange do
        local minion = minionInRange[i]
		

        if self.Menu.LastHit.Q:Value() and Ready(_Q) and myHero.pos:DistanceTo(minion.pos) < range and  myHero.pos:DistanceTo(minion.pos) > 310 and  _G.SDK.Orbwalker:CanMove(myHero) then
			local QDmg = value
			if QDmg > _G.SDK.HealthPrediction:GetPrediction(minion, qmath) then
				Control.CastSpell(HK_Q, minion.pos)
				self.lastQTick = GetTickCount()
			end	
        end
    end
end
------------------------------
function onLoadEvent()
    if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
    end
end


Callback.Add('Load', onLoadEvent)