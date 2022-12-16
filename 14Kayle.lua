require 'GamsteronPrediction'
require "DamageLib"
local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local TableInsert       = _G.table.insert

local orbwalker         = _G.SDK.Orbwalker
local TargetSelector    = _G.SDK.TargetSelector

local lastQ = 0
local lastW = 0
local lastE = 0
local lastR = 0
local lastIG = 0
local lastMove = 0
local lastAttack = 0
local lastHeal = 0
local Enemys =   {}
local Allys  =   {}

local EnemyHeroes = {}

EnemyLoaded = false 
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


local function GetDistanceSquared(vec1, vec2)
    local dx = vec1.x - vec2.x
    local dy = (vec1.z or vec1.y) - (vec2.z or vec2.y)
    return dx * dx + dy * dy
end

local function DistanceCompare(a,b)
    return GetDistanceSquared(myHero.pos,a.pos) < GetDistanceSquared(myHero.pos,b.pos)
end

local function IsValid(unit)
    if (unit 
        and unit.valid 
        and unit.isTargetable 
        and unit.alive 
        and unit.visible 
        and unit.networkID 
        and unit.health > 0
        and not unit.dead
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

local function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

local function GetEnemyMinions(range)
    local count = 0
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if IsValid(obj) and GetDistanceSquared(obj.pos, myHero.pos) < range * range and obj.isEnemy and obj.team < 300 then
            count = count + 1
        end
    end
    return count
end


local KrakenStacks = 0
class "Kayle"

function Kayle:__init()
    self.Q = {Hitchance = _G.HITCHANCE_HIGH, Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 830, Speed = 500, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.W = {Range = 900}
    self.E = {Range = 625}
    self.R = {Range = 900}


    self:LoadMenu()

    OnAllyHeroLoad(function(hero)
        TableInsert(Allys, hero);
    end)

    OnEnemyHeroLoad(function(hero)
        TableInsert(Enemys, hero);
    end)

    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)

    orbwalker:OnPostAttackTick(function(...) self:OnPostAttackTick(...) end)

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

function Kayle:LoadMenu()
    self.tyMenu = MenuElement({type = MENU, id = "14Kayle", name = "Kayle"})

    self.tyMenu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.tyMenu.Combo:MenuElement({id = "UseQ", name = "[Q]", value = true})
    self.tyMenu.Combo:MenuElement({id = "E", name = "[E]", value = true})
    self.tyMenu.Combo:MenuElement({id = "UseE", name = "[E] AA reset", value = true})

    self.tyMenu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.tyMenu.Harass:MenuElement({id = "UseQ", name = "[Q]", value = true})


    self.tyMenu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    self.tyMenu.Flee:MenuElement({id = "W", name = "Self [W]", value = true})

    self.tyMenu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
    self.tyMenu.Auto:MenuElement({id = "WHP", name = "Auto W Ally HP < X %", value = 20, min = 1, max = 101, step = 1})
    self.tyMenu.Auto:MenuElement({name = "Auto W ally ", id = "autoW", type = _G.MENU})
        OnAllyHeroLoad(function(hero) self.tyMenu.Auto.autoW:MenuElement({id = hero.charName, name = hero.charName, value = true}) end)
    self.tyMenu.Auto:MenuElement({id = "RHP", name = "Auto R Ally HP < X %", value = 10, min = 1, max = 101, step = 1})
    self.tyMenu.Auto:MenuElement({name = "Auto R ally ", id = "autoR", type = _G.MENU})
        OnAllyHeroLoad(function(hero) self.tyMenu.Auto.autoR:MenuElement({id = hero.charName, name = hero.charName, value = true}) end)
    
    self.tyMenu:MenuElement({type = MENU, id = "HitChance", name = "Hit Chance Setting"})
        self.tyMenu.HitChance:MenuElement({name ="Q HitChance" , drop = {"High", "Normal"}, callback = function(value) 
            if value == 1 then
                self.Q.Hitchance = _G.HITCHANCE_HIGH
            end
            if value == 2 then
                self.Q.Hitchance = _G.HITCHANCE_NORMAL
            end
        end})
        self.tyMenu.HitChance:MenuElement({id = "Qminion", name = "[Q] minoin to hit target", value = true})


    self.tyMenu:MenuElement({type = MENU, id = "Human", name = "Humanizer"})
        self.tyMenu.Human:MenuElement({id = "Move", name = "Only allow 1 movement in X Tick ", value = 180, min = 1, max = 500, step = 1})
        self.tyMenu.Human:MenuElement({id = "AA", name = "Only allow 1 AA in X Tick", value = 180, min = 1, max = 500, step = 1})


    self.tyMenu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
        self.tyMenu.Drawing:MenuElement({id = "Q", name = "Draw [Q] Range", value = true})
        self.tyMenu.Drawing:MenuElement({id = "W", name = "Draw [W] Range", value = true})
        self.tyMenu.Drawing:MenuElement({id = "E", name = "Draw [E] Range", value = true})
        self.tyMenu.Drawing:MenuElement({id = "R", name = "Draw [R] Range", value = true})

end

function Kayle:Draw()
    if myHero.dead then return end

    if self.tyMenu.Drawing.Q:Value() and  Ready(_Q) then
        Draw.Circle(myHero.pos, self.Q.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end

    if self.tyMenu.Drawing.W:Value() and Ready(_W) then
        Draw.Circle(myHero.pos, self.W.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end
    if self.tyMenu.Drawing.E:Value() and Ready(_E) then
        Draw.Circle(myHero.pos, self.E.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end
    if self.tyMenu.Drawing.R:Value() and Ready(_R) then
        Draw.Circle(myHero.pos, self.R.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end
end

function Kayle:OnPostAttackTick()
    -- if orbwalker.Modes[0] and self.tyMenu.Combo.UseE:Value() then
        -- if lastE + 300 < GetTickCount() and Ready(_E) then
            -- Control.CastSpell(HK_E)
            -- lastE = GetTickCount()
        -- end
    -- end
end

function Kayle:Tick()

    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
	Kraken = HasBuff(myHero, "6672buff")
	if Kraken == false then
        KrakenStacks = 0
    end
	
	    local EPostAttack = false
    if _G.SDK.Attack:IsActive() then
        WasAttacking = true

    else
        if WasAttacking == true then
            EPostAttack = true
            KrakenStacks = KrakenStacks + 1
        end
        WasAttacking = false
    end

    if myHero.activeSpell.valid and myHero.activeSpell.name == "KayleR" then
        orbwalker:SetAttack(false)
        return
    else
        orbwalker:SetAttack(true)
    end

    if orbwalker.Modes[0] then --combo
        self:Combo()
    elseif orbwalker.Modes[1] then --harass
        self:Harass()
    elseif orbwalker.Modes[5] then --flee
        self:Flee()
    end
    
    self:Auto()
		    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
end

function Kayle:CastQ(target)
    if lastQ + 300 < GetTickCount() and Ready(_Q) and orbwalker:CanMove() then
        self.Q.CollisionTypes = {_G.COLLISION_YASUOWALL}
        local Pred = GetGamsteronPrediction(target, self.Q, myHero)
        if Pred.Hitchance  >= self.Q.Hitchance then
            self.Q.CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}
            
            local Pred2 = GetGamsteronPrediction(target, self.Q, myHero)
            
            if Pred2.Hitchance >= self.Q.Hitchance then
                Control.CastSpell(HK_Q, Pred2.CastPosition)
                lastQ = GetTickCount()
            else
                if Pred2.Hitchance == 1 and self.tyMenu.HitChance.Qminion:Value() then
                    if #Pred2.CollisionObjects > 0 then
                        table.sort(Pred2.CollisionObjects, DistanceCompare)
                        if GetDistanceSquared(Pred2.CastPosition, Pred2.CollisionObjects[1].pos) < 400*400 then
                            Control.CastSpell(HK_Q, Pred2.CastPosition)
                            lastQ = GetTickCount()
                        end
                    end
                end
            end
        end
    end
end
local function CheckDmgItems(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        if myHero:GetItemData(j).itemID == itemID then return j end
    end
    return nil
end
function CalcExtraDmg(unit, typ) -- typ 1 = minion / typ 2 = Enemy
	local total = 0	
	
	local RecurveBow = CheckDmgItems(1043)													--Recurve Bow
	local BladeKing = CheckDmgItems(3153)													--Blade of the ruined King
	local WitsEnd = CheckDmgItems(3091)														--Wits End
	local Titanic = CheckDmgItems(3748)														--T.Hydra
	local Divine = CheckDmgItems(6632)														--Divine Sunderer  
	local Sheen = CheckDmgItems(3057)														--Sheen				
	local Black = CheckDmgItems(3071) 														--Black Cleaver    
	local Trinity = CheckDmgItems(3078)														--Trinity Force	
	local LvL = myHero.levelData.lvl 	

	
		total = total + CalcMagicalDamage(myHero, unit,10+myHero:GetSpellData(_E).level*5 + (0.10 * myHero.bonusDamage)+(0.20*myHero.ap) )
		local kaylestacks = GetBuffData(myHero, "kayleenragecounter")

		if (kaylestacks.count>= 4 and LvL>10) or (LvL>15) then 
		
		total = total + CalcMagicalDamage(myHero, unit,10+myHero:GetSpellData(_E).level*5 + (0.10 * myHero.bonusDamage)+(0.25*myHero.ap) )
		end
	if BladeKing then
		if typ == 1 then
			if unit.health*0.1 > 40 then
				total = total + CalcPhysicalDamage(myHero, unit, 40)
			else	
				total = total + CalcPhysicalDamage(myHero, unit, (unit.health*0.1))
			end
		else
			total = total + CalcPhysicalDamage(myHero, unit, (unit.health*0.1) + (HasBuff(myHero, "3153speed") and CalcMagicalDamage(myHero, unit, 40+6.47*LvL) or 0))
		end
	end
	
	if WitsEnd and myHero:GetSpellData(WitsEnd).currentCd == 0 then
		total = total + CalcMagicalDamage(myHero, unit, 15 + (4.44 * LvL))
	end

	if RecurveBow and myHero:GetSpellData(RecurveBow).currentCd == 0 then
		total = total + CalcPhysicalDamage(myHero, unit, 15)
	end	
	
	if Titanic and myHero:GetSpellData(Titanic).currentCd == 0 then
		total = total + CalcPhysicalDamage(myHero, unit, (myHero.maxHealth*0.01) + (5+myHero.maxHealth*0.015))
	end	

	if Sheen and myHero:GetSpellData(Sheen).currentCd == 0 then 
		total = total + CalcPhysicalDamage(myHero, unit, myHero.baseDamage)
	end	

	if Divine and myHero:GetSpellData(Divine).currentCd == 0 then  
		if typ == 1 then
			if unit.maxHealth*0.1 < 1.5*myHero.baseDamage then
				total = total + CalcPhysicalDamage(myHero, unit, 1.5*myHero.baseDamage)
			else
				if unit.maxHealth*0.1 > 2.5*myHero.baseDamage then
					total = total + CalcPhysicalDamage(myHero, unit, 2.5*myHero.baseDamage)
				else
					total = total + CalcPhysicalDamage(myHero, unit, unit.maxHealth*0.1)
				end
			end
		else
			if unit.maxHealth*0.1 < 1.5*myHero.baseDamage then
				total = total + CalcPhysicalDamage(myHero, unit, 1.5*myHero.baseDamage)
			else
				total = total + CalcPhysicalDamage(myHero, unit, unit.maxHealth*0.1)
			end
		end
	end	

	if typ == 2 and Black then 
		local Buff = GetBuffData(unit, "3071blackcleavermainbuff")
		if Buff.count == 6 then
			total = total + CalcPhysicalDamage(myHero, unit, (unit.maxHealth-unit.health)*0.05)
		end	
	end

	if Trinity and myHero:GetSpellData(Trinity).currentCd == 0 then 		
		total = total + CalcPhysicalDamage(myHero, unit, 2*myHero.baseDamage) 	
	end

	return total		
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
		if buff.name:lower():find("kindredrnodeathbuff") and (kill or (unit.health / unit.maxHealth)<0.11) and buff.count==1  then
			return true
		end	
		if buff.name:lower():find("chronoshift") and kill and buff.count==1 then
			return true
		end			
		
		if  buff.name:lower():find("willrevive") and kill and buff.count==1 then
			return true
		end
		
		 --uncomment for cc stuff
		if  buff.name:lower():find("morganae") and ss and not aa and buff.count==1 then
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
	--if HasBuffType(myHero, 26) and aa then
		--return true
	--end
	
	
	return false
end
function Kayle:Combo()
    if self.tyMenu.Combo.UseQ:Value() then
        local target = TargetSelector:GetTarget(self.Q.Range)
        if target then
            self:CastQ(target)
        end
    end
	AArange = myHero.range + myHero.boundingRadius
	tsrange=525
	if AArange>tsrange then
	tsrange=AArange
	end
    if self.tyMenu.Combo.E:Value() and Ready(_E) then
        local target = TargetSelector:GetTarget(tsrange+10)
        if target then
		local AADmg = getdmg("AA", target, myHero)
		if Kraken and KrakenStacks == 2 then
			AADmg = AADmg + 50 + (0.40*myHero.bonusDamage)
        --PrintChat(60 + (0.45*myHero.bonusDamage))
		end
		local EDmg = getdmg("E", target, myHero)
		local xtradmg =CalcExtraDmg(target, 2)
		--print(EDmg+AADmg+xtradmg)
            if (EDmg+AADmg+xtradmg)>= target.health+target.shieldAD+target.shieldAP and not cantkill(target,true,true,true) then
                Control.CastSpell(HK_E)
       
            end
        end
    end
end

function Kayle:Harass()
    if self.tyMenu.Harass.UseQ:Value() then
        local target = TargetSelector:GetTarget(self.Q.Range)
        if target then
            self:CastQ(target)
        end
    end
end

function Kayle:Flee()
    if self.tyMenu.Flee.W:Value() then
        if Ready(_W) and lastHeal + 180 < GetTickCount() then
            Control.CastSpell(HK_W, myHero.pos)
            print("flee W ")
            lastHeal = GetTickCount()
        end
    end
end

function Kayle:UltCalcs(unit,ally)
    local Rdmg = getdmg("R", ally, unit)
    local Qdmg = getdmg("Q", ally, unit)
    --local Qdmg = getdmg("Q", unit, myHero)
    local Wdmg = getdmg("W", ally, unit)
    local AAdmg = getdmg("AA", unit) 
    --PrintChat(Qdmg)
    --PrintChat(unit.activeSpell.name)
    --PrintChat(unit.activeSpellSlot)
    --PrintChat("Break------")
    --PrintChat(unit:GetSpellData(_Q).name)
    local CheckDmg = 0
    if unit.activeSpell.target == ally.handle and unit.activeSpell.isChanneling == false and unit.totalDamage and unit.critChance then
        --PrintChat(unit.activeSpell.name)
        --PrintChat(unit.totalDamage)
        --PrintChat(myHero.critChance)
        CheckDmg = unit.totalDamage + (unit.totalDamage*unit.critChance)
    else
        --PrintChat("Spell")
        if unit.activeSpell.name == unit:GetSpellData(_Q).name and Qdmg then
            --PrintChat(Qdmg)
            CheckDmg = Qdmg
        elseif unit.activeSpell.name == unit:GetSpellData(_W).name and Wdmg then
            --PrintChat("W")
            CheckDmg = Wdmg
        elseif unit.activeSpell.name == unit:GetSpellData(_E).name and Edmg then
            --PrintChat("E")
            CheckDmg = Edmg
        elseif unit.activeSpell.name == unit:GetSpellData(_R).name and Rdmg then
            --PrintChat("R")
            CheckDmg = Rdmg
        end
    end
    print(CheckDmg)
	-- print("CheckDmg")
    return CheckDmg * 1.1
    --[[

    check if spell is auto attack, if it is, get the target, if its us, check speed and sutff, add it to the list with an end time, the damage and so on.
    
    .isChanneling = spell
    not .isChanneling = AA    

    if it's a spell however
    Find spell name, check if that slot has damage .activeSpellSlot might work, would be super easy then.
    if it has damage, check if it has a target, if it does, and the target is myhero, get the speed yadayada, damage, add it to the table.
        if it doesn't have a target, get it's end spot, speed and target spot is close to myhero, and so on, add it to the table. also try .endtime
        .spellWasCast might help if it works, check when to add the spell to the list just the once.

        another function to clear the list of any spell that has expired.

        Add up all the damage of all the spells in the list, this is the total incoming damage to my hero

    ]]
end

function Kayle:Auto()
    for k, ally in pairs(Allys) do
        if Ready(_W) and lastHeal + 180 < GetTickCount() then
            if self.tyMenu.Auto.autoW[ally.charName] and self.tyMenu.Auto.autoW[ally.charName]:Value() then
                if IsValid(ally) and GetDistanceSquared(myHero.pos, ally.pos) < self.W.Range ^2 then
                    if ally.health / ally.maxHealth * 100 < self.tyMenu.Auto.WHP:Value() and self:GetEnemyAround(ally) > 0 then
                        Control.CastSpell(HK_W, ally.pos)
                        print("low Health cast W "..ally.charName)
                        lastHeal = GetTickCount()
                        return
                    end
                end
            end
        end

        if Ready(_R) and lastHeal + 180 < GetTickCount() then
            if self.tyMenu.Auto.autoR[ally.charName] and self.tyMenu.Auto.autoR[ally.charName]:Value() then
                if IsValid(ally) and GetDistanceSquared(myHero.pos, ally.pos) < self.R.Range ^2 then
					for i, enemy in pairs(EnemyHeroes) do
						
						if GetDistanceSquared(enemy.pos, ally.pos) < 700 ^ 2 then
							local IncDamage = self:UltCalcs(enemy,ally)
								if (IncDamage> ally.health and ally.health / ally.maxHealth<0.5) then
									print("inc")
									end
								if (ally.health / ally.maxHealth * 100 < self.tyMenu.Auto.RHP:Value() and self:GetEnemyAround(ally) > 0) or (IncDamage> ally.health and ally.health / ally.maxHealth<0.65)  then 
									if ally==myHero then
										Control.KeyDown(18)
										Control.KeyDown(HK_R)
										Control.KeyUp(HK_R)
										Control.KeyUp(18)
									else
										Control.CastSpell(HK_R, ally.pos)
										--print("low Health cast R "..ally.charName)
										lastHeal = GetTickCount()
										return
									end
								end
						end
					end
				end
			end
		end
    end
end

function Kayle:GetEnemyAround(ally)
    local counter = 0
    for enemyk , enemy in pairs(Enemys) do 
        if IsValid(enemy) and enemy.pos:DistanceTo(ally.pos) < 650 then
            counter = counter + 1
        end
    end
    return counter
end

Kayle()