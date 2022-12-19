local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local orbwalker         = _G.SDK.Orbwalker
local TargetSelector    = _G.SDK.TargetSelector
local TableInsert       = _G.table.insert
local objectManager     =  _G.SDK.ObjectManager
local DamageLib         = _G.SDK.Damage

local lastQ = 0
local lastE = 0
local lastR = 0


local lastMove = 0
local lastAttack = 0

local Enemys =   {}
local Allys  =   {}


local function HasBuff(unit , name)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name == name then
            return true, buff.duration, buff.count
        end
    end
    return false
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

class "Garen"

local function isInvulnerable(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.type == 18 and buff.count > 0 then
			return true
            	end
	end
	return false
end


function Garen:__init()
    self.E = {Range = 325}
    self.R = {Range = 400}

    self:LoadMenu()

    OnAllyHeroLoad(function(hero)
        TableInsert(Allys, hero);
    end)

    OnEnemyHeroLoad(function(hero)
        TableInsert(Enemys, hero);
    end)


    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)

    orbwalker:OnPostAttackTick(function() self:OnPostAttackTick() end)

    orbwalker:OnPreAttack(
        function(args)
            if args.Process then
                if lastAttack + self.tyMenu.Human.AA:Value() > GetTickCount() then
                    args.Process = false
                else
                    args.Process = true
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

function Garen:LoadMenu()

    self.tyMenu = MenuElement({type = MENU, id = "14Garen", name = "[14AIO] Garen"})

    self.tyMenu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.tyMenu.Combo:MenuElement({id = "Q", name = "[Q]", value = true})
        self.tyMenu.Combo:MenuElement({id = "E", name = "[E]", value = true})
        self.tyMenu.Combo:MenuElement({id = "Echeck", name = "only [E] when Q CD", value = true})
        self.tyMenu.Combo:MenuElement({id = "R", name = "[R]", value = true , toggle=true, key=string.byte("S")})
        self.tyMenu.Combo:MenuElement({type = MENU, id = "Rtarget", name = "R KS Target"})
            OnEnemyHeroLoad(function(hero) self.tyMenu.Combo.Rtarget:MenuElement({id = hero.charName, name = hero.charName, value = false}) end)

    
    self.tyMenu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
        self.tyMenu.Auto:MenuElement({id = "Qslow", name = "Auto Q if slowed", value = true})
        self.tyMenu.Auto:MenuElement({id = "QslowCombo", name = "^Only Q in Combo mode", value = true})
    
    self.tyMenu:MenuElement({type = MENU, id = "Human", name = "Humanizer"})
        self.tyMenu.Human:MenuElement({id = "Move", name = "Only allow 1 movement in X Tick ", value = 180, min = 1, max = 500, step = 1})
        self.tyMenu.Human:MenuElement({id = "AA", name = "Only allow 1 AA in X Tick", value = 180, min = 1, max = 500, step = 1})


    self.tyMenu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
        self.tyMenu.Drawing:MenuElement({id = "E", name = "Draw [E] Range", value = true})
        self.tyMenu.Drawing:MenuElement({id = "R", name = "Draw [R] Range", value = true})

end

function Garen:OnPostAttackTick()
    if orbwalker.Modes[0] and self.tyMenu.Combo.Q:Value() then
        if Ready(_Q) and lastQ + 300 < GetTickCount() then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end
    end
end

function Garen:Tick()
    if HasBuff(myHero, "GarenE") then
        orbwalker:SetAttack(false)
    else
        orbwalker:SetAttack(true)
    end

    if myHero.dead or Game.IsChatOpen() or
    (ExtLibEvade and ExtLibEvade.Evading == true) then return end
    if orbwalker.Modes[0] then --combo
        self:Combo()
    end

    self:Auto()

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



  function Garen:IsHeroImmortal(target, isAttack)
		local hp
		
		hp = 100 * (target.health / target.maxHealth)
		self.UndyingBuffs["kindredrnodeathbuff"] = hp < 10
		self.UndyingBuffs["ChronoShift"] = hp < 15
		self.UndyingBuffs["chronorevive"] = hp < 15
		self.UndyingBuffs["UndyingRage"] = hp < 15
		self.UndyingBuffs["JaxCounterStrike"] = isAttack
		self.UndyingBuffs["ShenWBuff"] = isAttack
		for buffName, isActive in pairs(self.UndyingBuffs) do
			if isActive and Buff:HasBuff(target, buffName) then
				return true
			end
		end
		-- anivia passive, olaf R, ... if unit.isImmortal and not Buff:HasBuff(unit, 'willrevive') and not Buff:HasBuff(unit, 'zacrebirthready') then return true end
		return false
	end

function Garen:Combo()
	local target = TargetSelector:GetTarget(1000)		

		if target and HasBuffType(target, 4) then
	 print("nor")
	end
	 
	 
    local target = TargetSelector:GetTarget(self.E.Range)
    if target and self.tyMenu.Combo.E:Value() and not HasBuff(myHero, "GarenE") and not HasBuff(myHero, "GarenQ") and Ready(_E) and lastE + 300 < GetTickCount()  then
        if self.tyMenu.Combo.Echeck:Value() and Ready(_Q) then return end
        Control.CastSpell(HK_E)
        lastE = GetTickCount()
    end

    local target = TargetSelector:GetTarget(self.R.Range)
    if target and self.tyMenu.Combo.R:Value() and Ready(_R) and lastR + 300 < GetTickCount() and not cantkill(target,true,true,false) then
        if target.health < self:GetRDmg(target) and not HasBuffType(target, 4) then
            Control.CastSpell(HK_R, target)
            lastR = GetTickCount()
        end
    end
end

function Garen:Auto()
    if Ready(_Q) and lastQ + 300 < GetTickCount() then
        if self.tyMenu.Auto.Qslow:Value() then
            if (self.tyMenu.Auto.QslowCombo:Value() and orbwalker.Modes[0] ) or (not self.tyMenu.Auto.QslowCombo:Value()) then
                if HasBuffType(myHero, 10) then
                    Control.CastSpell(HK_Q)
                    lastQ = GetTickCount()    
                end
            end
        end
    end
end

function Garen:GetRDmg(target)
    local baseDmg = ({150, 300, 450})[myHero:GetSpellData(_R).level]
    local percentage = ({0.25, 0.3, 0.35})[myHero:GetSpellData(_R).level]

    local value = baseDmg + (target.maxHealth - target.health) * percentage 
    return DamageLib:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_TRUE ,  value )
end

function Garen:Draw()
    if myHero.dead then return end


    if self.tyMenu.Drawing.E:Value() and Ready(_E) then
        Draw.Circle(myHero.pos, self.E.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end
	
	if self.tyMenu.Combo.R:Value() then
        Draw.Text("R: On ",20,myHero.pos:To2D(),Draw.Color(255 ,0,255,0))
    else
        Draw.Text("R: Off ",20,myHero.pos:To2D(),Draw.Color(255 ,255,0,0))

    end

    if self.tyMenu.Drawing.R:Value() and  Ready(_R) then
        Draw.Circle(myHero.pos, self.R.Range,Draw.Color(80 ,0xFF,0xFF,0xFF))
    end

end

Garen()
