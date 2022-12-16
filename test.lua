
local Menu, Utils, Champion

local GG_Target, GG_Orbwalker, GG_Buff, GG_Damage, GG_Spell, GG_Object, GG_Attack, GG_Data, GG_Cursor, SDK_IsRecalling
local LastChatOpenTimer = 0


WndMsg = function(self, msg, wParam)
		if self.Count < 1 then
			return
		end
		if msg == 513 and wParam == 0 then
			local x1, y1, x2, y2 = cursorPos.x, cursorPos.y, self.X, self.Y
			if x1 >= x2 and x1 <= x2 + self.Width then
				if y1 >= y2 and y1 <= y2 + self.Height then
					self.MoveX = x2 - x1
					self.MoveY = y2 - y1
					self.Moving = true
					--print('started')
				end
			end
		end
		if msg == 514 and wParam == 1 and self.Moving then
			self.Moving = false
			self:Write()
			--print('stopped')
		end
end









if Champion == nil then
-- stylua: ignore start
    -- menu
	Menu = MenuElement({type = MENU, id = "etest", name = "dashtool"})
	Menu:MenuElement({id = "enabled", name = "enable dashtool", value = True, Toggle= true})
    Menu:MenuElement({id = "efake", name = "Key to use", value = false, key = string.byte("E")})
	Menu:MenuElement({id = "elol", name = "key in game", value = false, key = string.byte("L")})

	Menu:MenuElement({id = "dash", name = "dash ability", value = 2, drop = {"[Q]","[W]", "[E]", "[R]" }})
	-- stylua: ignore end
	-- locals
	
	
	local LastEFake = 0

	-- champion

	-- load

	-- wnd msg
	-- function Activator:OnWndMsg(msg, wParam)
		-- if wParam == Menu.e_fake:Key() then
			-- LastEFake = os.clock()
		-- end
	-- end

	
		Champion = {
		CanAttackCb = function()
			return GG_Spell:CanTakeAction({ q = 0.3, w = 0, e = 0.1, r = 0 })
		end,
		CanMoveCb = function()
			return GG_Spell:CanTakeAction({ q = 0.2, w = 0, e = 0.1, r = 0 })
		end,
		OnPostAttackTick = function(PostAttackTimer)
			Champion:PreTick()
			
			Champion:ELogic()
			
		end,
	}
	
	function Champion:OnLoad()
		
	
		
	end
	
	-- function Champion:OnWndMsg(msg, wParam)
		-- if wParam == Menu.efake:Key() and (os.clock() > LastEFake + 0.5) then
			-- LastEFake = os.clock()
		-- end
	-- end
	-- tick
	function Champion:OnTick()
	
		if Game.IsChatOpen() then
			LastChatOpenTimer = os.clock()
		end
		Champion:ELogic()

	end
	
	
	
	
	


	
	
function Champion:ELogic()
	local dashkey=_E
	if Menu.dash:Value()==1 then
		dashkey=_Q
	elseif Menu.dash:Value()==2 then
		dashkey=_W
	elseif Menu.dash:Value()==3 then
		dashkey=_E
	elseif Menu.dash:Value()==4	then
		dashkey=_R
	
	end
		local timer = GetTickCount()
		if self.EHelper ~= nil then
			if  _G.SDK.Cursor.Step == 0 then
				GG_Cursor:Add(self.EHelper, mousePos)
				self.LastE = timer
				self.EHelper = nil
			end
			return
		end
		if Menu.enabled:Value() then
			_G.DashtoolEnabled = true
			_G.elolkey= Menu.elol:Key()
		end
		if
			not (
				Menu.efake:Value()
				--os.clock() < LastEFake + 0.05
				and Game.CanUseSpell(dashkey) == 0
				and not Control.IsKeyDown(HK_LUS)
				and not myHero.dead
				and Menu.enabled:Value()
				and not Game.IsChatOpen()
				and Game.IsOnTop()
			)
		then
			return
		end
		if self.LastE and timer < self.LastE + 300 then
			return
		end
		if timer < LastChatOpenTimer + 1000 then
			return
		end
		if timer < LevelUpKeyTimer + 1000 then
			return
		end
		self.LastE = timer
		if GG_Cursor.Step == 0 then
			GG_Cursor:Add(Menu.elol:Key(), mousePos)
			LastEFake = os.clock()
			return
		end
		self.EHelper = Menu.elol:Key()

	end
end


if Champion ~= nil then
	function Champion:PreTick()
		self.IsCombo = GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO]
		self.IsHarass = GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS]
		self.IsLaneClear = GG_Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR]
		self.IsLastHit = GG_Orbwalker.Modes[ORBWALKER_MODE_LASTHIT]
		self.IsFlee = GG_Orbwalker.Modes[ORBWALKER_MODE_FLEE]
		self.AttackTarget = nil
		self.CanAttackTarget = false
		self.IsAttacking = GG_Orbwalker:IsAutoAttacking()
		if not self.IsAttacking and (self.IsCombo or self.IsHarass) then
			self.AttackTarget = GG_Target:GetComboTarget()
			self.CanAttack = GG_Orbwalker:CanAttack()
			if self.AttackTarget and self.CanAttack then
				self.CanAttackTarget = true
			else
				self.CanAttackTarget = false
			end
		end
		self.Timer = Game.Timer()
		self.Pos = myHero.pos
		self.BoundingRadius = myHero.boundingRadius
		self.Range = myHero.range + self.BoundingRadius
		self.ManaPercent = 100 * myHero.mana / myHero.maxMana
		self.AllyHeroes = GG_Object:GetAllyHeroes(2000)
		self.EnemyHeroes = GG_Object:GetEnemyHeroes(false, false, true)
		--Utils.CachedDistance = {}
	end
	Callback.Add("Load", function()
		GG_Target = _G.SDK.TargetSelector
		GG_Orbwalker = _G.SDK.Orbwalker
		GG_Buff = _G.SDK.BuffManager
		GG_Damage = _G.SDK.Damage
		GG_Spell = _G.SDK.Spell
		GG_Object = _G.SDK.ObjectManager
		GG_Attack = _G.SDK.Attack
		GG_Data = _G.SDK.Data
		GG_Cursor = _G.SDK.Cursor
		SDK_IsRecalling = _G.SDK.IsRecalling
		GG_Orbwalker:CanAttackEvent(Champion.CanAttackCb)
		GG_Orbwalker:CanMoveEvent(Champion.CanMoveCb)
		if Champion.OnLoad then
			Champion:OnLoad()
		end
		if Champion.OnPreAttack then
			GG_Orbwalker:OnPreAttack(Champion.OnPreAttack)
		end
		if Champion.OnAttack then
			GG_Orbwalker:OnAttack(Champion.OnAttack)
		end
		if Champion.OnPostAttack then
			GG_Orbwalker:OnPostAttack(Champion.OnPostAttack)
		end
		if Champion.OnPostAttackTick then
			GG_Orbwalker:OnPostAttackTick(Champion.OnPostAttackTick)
		end
		if Champion.OnTick then
			table.insert(_G.SDK.OnTick, function()
				--DH:drawSpellData(myHero, _W, 0, 0, 22)
				--DH:drawActiveSpell(myHero, 500, 0, 22)
				--DH:drawHeroesDistance(22)
				Champion:PreTick()
				if not SDK_IsRecalling(myHero) then
					Champion:OnTick()
				end
				
			end)
		end
		if Champion.OnDraw then
			table.insert(_G.SDK.OnDraw, function()
				Champion:OnDraw()
			end)
		end
		if Champion.OnWndMsg then
			table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
				Champion:OnWndMsg(msg, wParam)
			end)
		end
	end)
	return
end

























