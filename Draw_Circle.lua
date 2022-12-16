local Draw = Draw
local DrawText = Draw.Text
local DrawRect = Draw.Rect
local DrawCircle = Draw.Circle
local DrawLine = Draw.Line


local ColorWhite = Draw.Color(255, 255, 255, 255)
local ColorDarkGreen = Draw.Color(255, 0, 100, 0)
local ColorDarkRed = Draw.Color(255, 139, 0, 0)
local ColorDarkBlue = Draw.Color(255, 0, 0, 139)
local ColorTransparentBlack = Draw.Color(150, 0, 0, 0)

local CircleSize
local AddSize
local SubSize

local DrawMenu = MenuElement({type = MENU, id = "Draw Range Circle", name = "Draw Range Circle"})
DrawMenu:MenuElement({id = "Draw", name = "Enable Range Circle", value = false})
DrawMenu:MenuElement({id = "CircleSize", name = "Size of Range Circle", value = 100, min = 1, max = 1500, step = 25})
DrawMenu:MenuElement({id = "Reset", name = "Click to Reset Size of Range Circle", type = SPACE, onclick = function() DrawMenu.CircleSize:Value(100) end})
DrawMenu:MenuElement({id = "Add", name = "Click to + Size of Range Circle", type = SPACE, onclick = function() Add() end})
DrawMenu:MenuElement({id = "AddSize", name = "Size of + to Circle", value = 50, min = 1, max = 100, step = 1})
DrawMenu:MenuElement({id = "Sub", name = "Click to - Size of Range Circle", type = SPACE, onclick = function() Sub() end})
DrawMenu:MenuElement({id = "SubSize", name = "Size of - to Circle", value = 50, min = 1, max = 100, step = 1})
    Callback.Add("Tick", function() Tick() end)
    Callback.Add("Draw", function() Draw() end)

function Add()
    CircleSize = CircleSize + AddSize
    DrawMenu.CircleSize:Value(CircleSize)
end

function Sub()
    CircleSize = CircleSize - SubSize
    DrawMenu.CircleSize:Value(CircleSize)
end

function Tick()
    if Game.IsChatOpen() or myHero.dead then return end
    CircleSize = DrawMenu.CircleSize:Value()
    AddSize = DrawMenu.AddSize:Value()
    SubSize = DrawMenu.SubSize:Value()
end
-- smitedamagetrackerstalker 1
local function HasBuff(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count>0  and ( buff.name:lower():find("avatarbuff") or buff.name:lower():find("smite") ) then

            print(buff.name, buff.duration)
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


--DrMundoPImmunity ChronoShift2 willrevive1
lasttick=0
first=Game.Timer()
local QObject = { isValid = false, GameObject = nil, ID = nil }
local res = Game.Resolution()
local drawColor = Draw.Color(100,0xFF,0xFF,0xFF);
local function DrawLine3D(x,y,z,a,b,c,width,col)
  local p1 = Vector(x,y,z):To2D()
  local p2 = Vector(a,b,c):To2D()
  DrawLine(p1.x, p1.y, p2.x, p2.y, width, col)
end

local function DrawRectangleOutline(x, y, z, x1, y1, z1, width, col)
  local startPos = Vector(x,y,z)
  local endPos = Vector(x1,y1,z1)
  local c1 = startPos+Vector(Vector(endPos)-startPos):Perpendicular():Normalized()*width
  local c2 = startPos+Vector(Vector(endPos)-startPos):Perpendicular2():Normalized()*width
  local c3 = endPos+Vector(Vector(startPos)-endPos):Perpendicular():Normalized()*width
  local c4 = endPos+Vector(Vector(startPos)-endPos):Perpendicular2():Normalized()*width
  DrawLine3D(c1.x,c1.y,c1.z,c2.x,c2.y,c2.z,2,col)
  DrawLine3D(c2.x,c2.y,c2.z,c3.x,c3.y,c3.z,2,col)
  DrawLine3D(c3.x,c3.y,c3.z,c4.x,c4.y,c4.z,2,col)
  DrawLine3D(c1.x,c1.y,c1.z,c4.x,c4.y,c4.z,2,col)
end

function Draw()
    local CircleSize = DrawMenu.CircleSize:Value()
    if not DrawMenu.Draw:Value() then return end
    DrawCircle(myHero.pos, CircleSize, 1, ColorWhite)
	-- if not Control.IsKeyDown("M") then
		-- Control.KeyDown(string.byte("M"))
	-- end
	-- targ=_G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_PHYSICAL)
	-- --if targ then HasBuff(targ) end
	-- HasBuff(myHero)
	--myHero.levelData.lvl
	--print(myHero.maxHealth-(610+104*(myHero.levelData.lvl-1)*(0.7025+(0.0175*(myHero.levelData.lvl-1)))))
	--print(myHero:GetSpellData(_R).toggleState)
	-- for i = 1, Game.MissileCount() do
			-- local missile = Game.Missile(i)	 
			-- if missile.missileData and missile.missileData.owner == myHero.handle then
				-- if missile.missileData.name:find("FlashFrostSpell") then
					
					-- QObject.GameObject = missile
						-- if (lasttick+2<Game.Timer()) and (first+5<Game.Timer()) then
							-- print(missile.missileData)
							-- lasttick=Game.Timer()
						-- end
					-- LastSlot = _Q
				-- end
			-- end	
		-- end
	
	
-- local eSpell = myHero.activeSpell
	-- if eSpell and eSpell.valid and myHero.isChanneling then --and lasttick+3<Game.Timer() then
		-- --if (res.x*2 >= missile.pos2D.x) and (res.x*-1 <= missile.pos2D.x) and (res.y*2 >= missile.pos2D.y) and (res.y*-1 <= missile.pos2D.y) then --draw skillshots close to our screen, probably we need to exclude global ultimates
		-- --Draw.Circle(missile.pos,missile.missileData.width,drawColor);
		-- local CastPos = eSpell.startPos
		-- local PlacementPos = eSpell.placementPos
		-- local Width = 100
		-- if eSpell.width > 0 then
			-- Width = eSpell.width
		-- end
		-- if(CastPos and PlacementPos) then
			-- local VCastPos = Vector(CastPos.x, CastPos.y, CastPos.z)
			-- local VPlacementPos = Vector(PlacementPos.x, PlacementPos.y, PlacementPos.z)
			-- local CastDirection = Vector((VCastPos - VPlacementPos):Normalized())
			-- local PlacementPos2 = VCastPos - CastDirection * eSpell.range
		-- end
		
			-- DrawRectangleOutline(eSpell.startPos.x,eSpell.startPos.y,eSpell.startPos.z,eSpell.placementPos.x,eSpell.placementPos.y,eSpell.placementPos.z,eSpell.width,drawColor);
		-- --end
	-- end
-- lasttick=Game.Timer()
-- lasttick=Game.Timer()



	

	--print(cantkill(targ,true,true,true))
	--print(GotBuff(myHero,"willrevive1"))
			
	-- if targ then
	--	print(cantkill(myHero,true,true,true))
			
	--print(myHero:GetSpellData(_E).toggleState)

end


	
	
	
