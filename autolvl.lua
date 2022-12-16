require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"
require "GGPrediction"

local charName = myHero.charName
local Timer = Game.Timer
local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

local function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end


local function isImmobil(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false
end


function GetDifference(a,b)
    local Sa = a^2
    local Sb = b^2
    local Sdif = (a-b)^2
    return math.sqrt(Sdif)
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end



local function CheckHPPred(unit, SpellSpeed)
     local speed = SpellSpeed
     local range = myHero.pos:DistanceTo(unit.pos)
     local time = range / speed
     if _G.SDK and _G.SDK.Orbwalker then
         return _G.SDK.HealthPrediction:GetPrediction(unit, time)
     elseif _G.PremiumOrbwalker then
         return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
end




function GetEnemyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end






function IsReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end


function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end



local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
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


local function ValidTarget(unit, range)
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




class "Activator"
local EnemyLoaded = false
local AllyLoaded = false
local EnemiesIronSpike = spikecount
local EnemiesGoreDrinker = drinkercount
local EnemiesOmen = omencount
local AlliesAround = allycount

local Timer = Game.Timer()
local ComboTimer = 0
local LocalGetTickCount         = GetTickCount
local LvLTick = 0

function Activator:__init()

	self:LoadMenu()
	self:ItemSpells()
	Callback.Add("Tick", function() self:Tick() end)
	
end

function Activator:ItemSpells()
	FrostSpellData = {speed = 1200, range = 835, delay = 0.20, radius = 50, collision = {}, type = "linear"}
	BeltSpellData = {speed = 1600, range = 1000, delay = 0.31, angle = 45, radius = 50, collision = {"minion"}, type = "conic"}
	BreakerSpellData = {speed = 4000, range = 420, delay = 0.31, radius = 10, collision = {}, type = "circular"}
end

function Activator:UseBarrier()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2)
	end
end

function Activator:UseExhaust(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function Activator:UseIgnite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end



function Activator:UseIronSpk()
    if (self.Menu.targitems.itemironspk.itemironspkcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemironspk.itemironspkcombo:Value() then
    	local ItemIronSpk = GetItemSlot(myHero, 6029)
    	if ItemIronSpk > 0 and myHero:GetSpellData(ItemIronSpk).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemIronSpk])
    	end
    end
end

function Activator:UseGoreDrinker()
    if (self.Menu.targitems.itemgoredrnk.itemgoredrnkcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemgoredrnk.itemgoredrnkcombo:Value() then
    	local ItemGoreDrinker = GetItemSlot(myHero, 6630)
    	if ItemGoreDrinker > 0 and myHero:GetSpellData(ItemGoreDrinker).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemGoreDrinker])
    	end
    end
end

function Activator:UseStrideBreaker(unit)
    if (self.Menu.targitems.itemstidebreaker.itemstidebreakercombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemstidebreaker.itemstidebreakercombo:Value() then
    	local ItemStrideBreaker = GetItemSlot(myHero, 6631)
    	if ItemStrideBreaker > 0 and myHero:GetSpellData(ItemStrideBreaker).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemStrideBreaker])
    	end
     end
end

function Activator:UseOmen()
    if (self.Menu.targitems.itemranduin.itemranduincombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemranduin.itemranduincombo:Value() then
    	local ItemOmen = GetItemSlot(myHero, 3143)
    	if ItemOmen > 0 and myHero:GetSpellData(ItemOmen).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemOmen])
    	end
    end
end

function Activator:UseChempunk()
    if (self.Menu.targitems.itemchempunk.itemchempunkcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemchempunk.itemchempunkcombo:Value() then
    	local ItemChempunk = GetItemSlot(myHero, 6664)
    	if ItemChempunk > 0 and myHero:GetSpellData(ItemChempunk).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemChempunk])
    	end
    end
end

function Activator:UseClaw(unit)
    if (self.Menu.targitems.itemprowler.itemprowlercombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemprowler.itemprowlercombo:Value() then
    	local ItemClaw = GetItemSlot(myHero, 6693)
    	if ItemClaw > 0 and myHero:GetSpellData(ItemClaw).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemClaw], unit)
    	end
    end
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

function Activator:UseFrost(unit)
	
	
	
	
	
			if (isImmobil(unit) or ( HasBuffType(unit, 11) and self.Menu.targitems.itemevfrost.itemevfrostcomboslow:Value() ) )and (self.Menu.targitems.itemevfrost.itemevfrostcombo:Value() and Mode() == "Combo") then
				local ItemFrost = GetItemSlot(myHero, 6656)
				local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 50, Range = 900, Speed = 1100, Collision =false})
				QPrediction:GetPrediction(unit, myHero)
						
				
				
					if  QPrediction:CanHit(1+1) and ItemFrost > 0 and myHero:GetSpellData(ItemFrost).currentCd == 0 and (self.Menu.targitems.itemevfrost.evfrostdelay:Value()==0 or HasBuffType(unit, 11)) then
						Control.CastSpell(ItemHotKey[ItemFrost],QPrediction.CastPosition)
					elseif QPrediction:CanHit(1+1)and ItemFrost > 0 and myHero:GetSpellData(ItemFrost).currentCd == 0 then
						DelayAction(function() Control.CastSpell(ItemHotKey[ItemFrost], QPrediction.CastPosition) end, self.Menu.targitems.itemevfrost.evfrostdelay:Value())
									
					
					end			
			end		
		
	
end

function Activator:UseFrost2(unit)
				local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 50, Range = 900, Speed = 1100, Collision =false})
				QPrediction:GetPrediction(unit, myHero)
				local ItemFrost = GetItemSlot(myHero, 6656)	
				
				
					if  QPrediction:CanHit(1+1) and ItemFrost > 0 and myHero:GetSpellData(ItemFrost).currentCd == 0 and Activator:SmoothChecks() then
						Control.CastSpell(ItemHotKey[ItemFrost],QPrediction.CastPosition)
					
									
					
					end			
	
		
	
end
		
	

function Activator:UseRocketBelt(unit)
	if (self.Menu.targitems.itemrocket.itemrocketcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemrocket.itemrocketcombo:Value() then
		local ItemRocketBelt = GetItemSlot(myHero, 3152)
			
		local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.2, Radius = 50, Range = 1200, Speed = 1400, Collision =true})
		QPrediction:GetPrediction(unit, myHero)
					
		if QPrediction:CanHit(1+1) and ItemRocketBelt > 0 and myHero:GetSpellData(ItemRocketBelt).currentCd == 0 and Activator:SmoothChecks() and GetDistance(unit.pos) >= 200 then		
			Control.CastSpell(ItemHotKey[ItemRocketBelt],QPrediction.CastPosition)
		end
	end
end

function Activator:LoadMenu()
-- main menu
	self.Menu = MenuElement({type = MENU, id = "Activator", name = "autolvl"})
	self.Menu:MenuElement({id = "summs", name = "Summoner Spells", type = MENU})
	self.Menu:MenuElement({id = "targitems", name = "Targeted Items", type = MENU})
    self.Menu:MenuElement({id = "autolvl", name = "Auto Level Spells", type = MENU})

-- summs

	self.Menu.summs:MenuElement({id = "summbarrier", name = "Summoner Barrier", type = MENU})
	self.Menu.summs:MenuElement({id = "summexhaust", name = "Summoner Exhaust", type = MENU})
	self.Menu.summs:MenuElement({id = "summignite", name = "Summoner Ignite", type = MENU})

	-- targetitems
	self.Menu.targitems:MenuElement({id = "itemironspk", name = "Ironspike Whisp", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemgoredrnk", name = "Goredrinker", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemstidebreaker", name = "Stridebreaker", type = MENU})

	self.Menu.targitems:MenuElement({id = "itemranduin", name = "Randuin's Omen", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemchempunk", name = "Turbo Chempunk", type = MENU})

	self.Menu.targitems:MenuElement({id = "itemrocket", name = "Hextech Rocketbelt", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemprowler", name = "Prowler's Claw", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemevfrost", name = "Everfrost", type = MENU})

-- barrier
	self.Menu.summs.summbarrier:MenuElement({id = "summbarrieruse", name = "Use Barrier", value = true})
	self.Menu.summs.summbarrier:MenuElement({id = "summbarrierusehp", name = "If HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
-- exhaust
	self.Menu.summs.summexhaust:MenuElement({id = "summexhaustuse", name = "Use Exhaust", value = true})
	self.Menu.summs.summexhaust:MenuElement({id = "summexhaustusehp", name = "If my HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.summs.summexhaust:MenuElement({id = "summexhaustkey", name = "Use Exhaust", key = string.byte("f") })

	self.Menu.summs.summexhaust:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})

-- ignite 
	self.Menu.summs.summignite:MenuElement({id = "summigniteuse", name = "Use Ignite", value = true})
	self.Menu.summs.summignite:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
	self.Menu.summs.summignite:MenuElement({id = "ignitekey", key = string.byte("f")})

-- ironspike whisp
	self.Menu.targitems.itemironspk:MenuElement({id = "itemironspkuse", name = "Use Ironspike Whisp", value = true})
	self.Menu.targitems.itemironspk:MenuElement({id = "itemironspkusetar", name = "If more enemies then", value = 2, min = 0, max = 5, step = 1})
    self.Menu.targitems.itemironspk:MenuElement({id = "itemironspkcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemironspk:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- goredrinker
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkuse", name = "Use Goredrinker", value = true})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkusetar", name = "If more enemies then", value = 2, min = 1, max = 5, step = 1})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkusehp", name = "If HP lower then", value = 40, min = 5, max = 95, step = 5, identifier = "%"})
    self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "gorespace", name = "Enemies to hit and HP are seperate things", type = SPACE})
-- stridebreaker
	self.Menu.targitems.itemstidebreaker:MenuElement({id = "itemstidebreakeruse", name = "Use Stridebreaker", value = true})
    self.Menu.targitems.itemstidebreaker:MenuElement({id = "itemstidebreakercombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemstidebreaker:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
	
-- randuins
	self.Menu.targitems.itemranduin:MenuElement({id = "itemranduinuse", name = "Use Randuin's Omen", value = true})
	self.Menu.targitems.itemranduin:MenuElement({id = "itemranduintar", name = "If more enemies then", value = 2, min = 0, max = 5, step = 1})
    self.Menu.targitems.itemranduin:MenuElement({id = "itemranduincombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemranduin:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- chempunk
	self.Menu.targitems.itemchempunk:MenuElement({id = "itemchempunkuse", name = "Use Turbo Chempunk", value = true})
	self.Menu.targitems.itemchempunk:MenuElement({id = "itemchempunkrange", name = "If enemy closer then", value = 700, min = 200, max = 1500, step = 100})
    self.Menu.targitems.itemchempunk:MenuElement({id = "itemchempunkcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemchempunk:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = true})

-- rocketbelt
	self.Menu.targitems.itemrocket:MenuElement({id = "itemrocketuse", name = "Use Hextech Rocketbelt", value = true})
	self.Menu.targitems.itemrocket:MenuElement({id = "itemrocketuserange", name = "If enemy closer then", value = 700, min = 200, max = 1500, step = 25})
    self.Menu.targitems.itemrocket:MenuElement({id = "itemrocketcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemrocket:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- prowlers claw
	self.Menu.targitems.itemprowler:MenuElement({id = "itemprowleruse", name = "Use Prowler's Claw", value = true})
    self.Menu.targitems.itemprowler:MenuElement({id = "itemprowlercombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemprowler:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- everfrost
	self.Menu.targitems.itemevfrost:MenuElement({id = "itemevfrostuse", name = "Use Everfrost", value = true})
	self.Menu.targitems.itemevfrost:MenuElement({id = "itemevfrostkey", name = "Use Everfrostkey", value = false, key=string.byte("1")})
    self.Menu.targitems.itemevfrost:MenuElement({id = "itemevfrostcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemevfrost:MenuElement({id = "itemevfrostcomboslow", name = "Use on slows as well", value = true})
	self.Menu.targitems.itemevfrost:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
	self.Menu.targitems.itemevfrost:MenuElement({id = "evfrostdelay", name = "delay before evfrost cast", value = 0.25, min = 0, max = 1, step = 0.01})







-- auto level
    self.Menu.autolvl:MenuElement({id = "autolvluse", name = "Enable Auto Level Spells", value = true})
    self.Menu.autolvl:MenuElement({id = "autolvlorder", name = "Levelorder", value = 2, drop = {"[Q]->[W]->[E]", "[Q]->[E]->[W]", "[W]->[Q]->[E]", "[W]->[E]->[Q]", "[E]->[Q]->[W]", "[E]->[W]->[Q]"}})
    self.Menu.autolvl:MenuElement({id = "autolvllvl", name = "Start AutoLevel at [lvl]", value = 2, min = 2, max = 18})
	self.Menu.autolvl:MenuElement({id = "autolvl2", name = "skill to level at lvl 2", value = 2, drop = {"[Q]","[W]", "[E]"}})
end

function Activator:EnemyMenu()
	for i, enemy in pairs(EnemyHeroes) do
		self.Menu.summs.summexhaust.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.summs.summignite.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemironspk.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemgoredrnk.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemstidebreaker.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		
		self.Menu.targitems.itemranduin.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemchempunk.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemrocket.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemprowler.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemevfrost.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		
		
	end
end

function Activator:autolvl()
    if not self.Menu.autolvl.autolvluse:Value() then return end
    local spellPoints = myHero.levelData.lvlPts 
    local Level = myHero.levelData.lvl

    if spellPoints > 0 and self.Menu.autolvl.autolvluse:Value() and Game.IsOnTop() and Level >= self.Menu.autolvl.autolvllvl:Value() and Game.Timer()-LvLTick > 0.311 then
		if  Game.Timer()- LvLTick > 3 then
			LvLTick = Game.Timer()
		end
		
        if Game.Timer()-LvLTick > 0.311 and  Level == 6 or Level == 11 or Level == 16  then
            Control.KeyDown(HK_LUS)
            Control.KeyDown(HK_R)
            Control.KeyUp(HK_R)
            Control.KeyUp(HK_LUS)
        elseif Game.Timer()-LvLTick > 0.311 and  Level == 8 or Level == 10 or Level == 12 or Level == 13   then
            if  Game.Timer()-LvLTick > 0.311 and self.Menu.autolvl.autolvlorder:Value() == 1 or self.Menu.autolvl.autolvlorder:Value() == 6 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 3 or self.Menu.autolvl.autolvlorder:Value() == 5 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 2 or self.Menu.autolvl.autolvlorder:Value() == 4 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
		
        elseif  Level == 4 or Level == 5 or Level == 7 or Level == 9 and Game.Timer()-LvLTick > 0.311   then
            if Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 1 or self.Menu.autolvl.autolvlorder:Value() == 2 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 3 or self.Menu.autolvl.autolvlorder:Value() == 4 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 5 or self.Menu.autolvl.autolvlorder:Value() == 6 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
        elseif  Level == 14 or Level == 15 or Level == 17 or Level == 18 and Game.Timer()-LvLTick > 0.311   then
            if Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 4 or self.Menu.autolvl.autolvlorder:Value() == 6 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 2 or self.Menu.autolvl.autolvlorder:Value() == 5 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif Game.Timer()-LvLTick > 0.311 and  self.Menu.autolvl.autolvlorder:Value() == 1 or self.Menu.autolvl.autolvlorder:Value() == 3 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
            -- lvl 2 Protection
        elseif  Level == 2 and Game.Timer()-LvLTick > 0.311    then
            if self.Menu.autolvl.autolvl2:Value() == 1 and myHero:GetSpellData(_Q).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvl2:Value()== 2 and myHero:GetSpellData(_W).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
			elseif self.Menu.autolvl.autolvl2:Value() == 3 and myHero:GetSpellData(_E).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
					
            end
           
            
            -- lvl 3 Protection
        elseif Level == 3 and Game.Timer()-LvLTick > 0.311  then
            if self.Menu.autolvl.autolvlorder:Value() == 1 and myHero:GetSpellData(_E).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 1 and myHero:GetSpellData(_E).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 2 and myHero:GetSpellData(_W).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 2 and myHero:GetSpellData(_W).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
			--{"[Q]->[W]->[E]", "[Q]->[E]->[W]", "[W]->[Q]->[E]", "[W]->[E]->[Q]", "[E]->[Q]->[W]", "[E]->[W]->[Q]"}})
            if self.Menu.autolvl.autolvlorder:Value() == 3 and myHero:GetSpellData(_E).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 3 and myHero:GetSpellData(_E).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 4 and myHero:GetSpellData(_Q).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 4 and myHero:GetSpellData(_Q).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 5 and myHero:GetSpellData(_W).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 5 and myHero:GetSpellData(_W).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 6 and myHero:GetSpellData(_Q).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 6 and myHero:GetSpellData(_Q).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
        end
    end
end




function Activator:Tick()
	if Game.IsChatOpen() or myHero.dead then return end
	self:Loop()
    self:autolvl()
	CastingQ = myHero.activeSpell.name == myHero:GetSpellData(_Q).name
	CastingW = myHero.activeSpell.name == myHero:GetSpellData(_W).name
	CastingE = myHero.activeSpell.name == myHero:GetSpellData(_E).name
	CastingR = myHero.activeSpell.name == myHero:GetSpellData(_R).name
	if Mode() == "Combo" then
        ComboTimer = Game.Timer() - Timer
    else
        ComboTimer = 0
        Timer = Game.Timer()
    end
	
	if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
			self:EnemyMenu()
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
	end

	
end
	
	
function Activator:CastingChecks()
	if not CastingQ or CastingW or CastingE or CastingR then
		return true
	else
		return false
	end
end

function Activator:SmoothChecks()
    if self:CastingChecks() and myHero.attackData.state ~= 2 and _G.SDK.Cursor.Step == 0 and (ComboTimer == 0 or ComboTimer > 0.1) then
        return true
    else
        return false
    end
end


function OnLoad()
    Activator()
end

function Activator:Loop()
	local spikecount = 0 
	local drinkercount = 0
	local omencount = 0
	local allycount = 0
	local target = _G.SDK.TargetSelector:GetTarget(930)
	local ItemFrost = GetItemSlot(myHero, 6656)
		if self.Menu.targitems.itemevfrost.itemevfrostkey:Value() and ItemFrost > 0 and target then 
			Activator:UseFrost2(target)
		end
		-- enemy loop
		for i, enemy in pairs(EnemyHeroes) do
        
		-- spike count
			if ValidTarget(enemy,450) and self.Menu.targitems.itemironspk.enemiestohit[enemy.charName] and self.Menu.targitems.itemironspk.enemiestohit[enemy.charName]:Value() then
				spikecount = spikecount + 1
			end
		-- goredrinker count
			if ValidTarget(enemy, 430) and self.Menu.targitems.itemgoredrnk.enemiestohit[enemy.charName] and self.Menu.targitems.itemgoredrnk.enemiestohit[enemy.charName]:Value() then
				drinkercount = drinkercount + 1
			end
		-- randuins count
			if ValidTarget(enemy, 350 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemranduin.enemiestohit[enemy.charName] and self.Menu.targitems.itemranduin.enemiestohit[enemy.charName]:Value() then
				omencount = omencount + 1
			end
		
        -- exhaust self
            if self.Menu.summs.summexhaust.summexhaustuse:Value() and self.Menu.summs.summexhaust.summexhaustkey:Value() and ValidTarget(target, 610 + myHero.boundingRadius) and self.Menu.summs.summexhaust.enemiestohit[target.charName]:Value()  then
                self:UseExhaust(target)
                
            end
		-- barrier
			if self.Menu.summs.summbarrier.summbarrieruse:Value() and myHero.health / myHero.maxHealth <= self.Menu.summs.summbarrier.summbarrierusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped then
				if enemy.activeSpell.target == myHero.handle then
                    self:UseBarrier()
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseBarrier()
                    end
                end
			end
		
		-- ignite
			local IgnDmg = 50 + 20 * myHero.levelData.lvl
			
			if ValidTarget(target, 535 + myHero.boundingRadius) and self.Menu.summs.summignite.ignitekey:Value() then
				self:UseIgnite(target)
			end
		
		
		
		-- ironspike
			if self.Menu.targitems.itemironspk.itemironspkuse:Value() and EnemiesIronSpike == self.Menu.targitems.itemironspk.itemironspkusetar:Value() and myHero.attackData.state ~= 2 and  Activator:SmoothChecks()  and not _G.SDK.Attack:IsActive() then
				self:UseIronSpk()
			end
		-- goredrinker
			if self.Menu.targitems.itemgoredrnk.itemgoredrnkuse:Value() and EnemiesGoreDrinker == self.Menu.targitems.itemgoredrnk.itemgoredrnkusetar:Value() and not _G.SDK.Attack:IsActive() then
				self:UseGoreDrinker()
			elseif self.Menu.targitems.itemgoredrnk.itemgoredrnkuse:Value() and myHero.health / myHero.maxHealth <= self.Menu.targitems.itemgoredrnk.itemgoredrnkusehp:Value() / 100 and ValidTarget(enemy, 450) and not _G.SDK.Attack:IsActive() then
				self:UseGoreDrinker()
			end
		-- stridebreaker 
			if self.Menu.targitems.itemstidebreaker.itemstidebreakeruse:Value() and ValidTarget(enemy, 420) and self.Menu.targitems.itemstidebreaker.enemiestohit[enemy.charName] and self.Menu.targitems.itemstidebreaker.enemiestohit[enemy.charName]:Value() and self:SmoothChecks()  and not _G.SDK.Attack:IsActive() then
				self:UseStrideBreaker(enemy)
			end
		-- omen
			if self.Menu.targitems.itemranduin.itemranduinuse:Value() and EnemiesOmen == self.Menu.targitems.itemranduin.itemranduintar:Value() and not _G.SDK.Attack:IsActive() then
				self:UseOmen()
			end
		-- chempunk
			if self.Menu.targitems.itemchempunk.itemchempunkuse:Value() and IsMyHeroFacing(enemy) and ValidTarget(enemy, self.Menu.targitems.itemchempunk.itemchempunkrange:Value() + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemchempunk.enemiestohit[enemy.charName] and self.Menu.targitems.itemchempunk.enemiestohit[enemy.charName]:Value() and not _G.SDK.Attack:IsActive() then
				self:UseChempunk()
			end
		
		-- prowlers
			if self.Menu.targitems.itemprowler.itemprowleruse:Value() and ValidTarget(enemy, 450 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemprowler.enemiestohit[enemy.charName] and self.Menu.targitems.itemprowler.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseClaw(enemy)
			end
		-- rocketbelt
			if self.Menu.targitems.itemrocket.itemrocketuse:Value() and ValidTarget(enemy, self.Menu.targitems.itemrocket.itemrocketuserange:Value() + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemrocket.enemiestohit[enemy.charName] and self.Menu.targitems.itemrocket.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseRocketBelt(enemy)
			end
		-- frost
		
			if self.Menu.targitems.itemevfrost.itemevfrostuse:Value() and ValidTarget(enemy, 780 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemevfrost.enemiestohit[enemy.charName] and self.Menu.targitems.itemevfrost.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseFrost(enemy)
			end

			


		end
		EnemiesIronSpike = spikecount
		EnemiesGoreDrinker = drinkercount
		EnemiesOmen = omencount
end
