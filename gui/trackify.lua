--[====[

gui/trackify
===============
Replace those ugly non-masterwork engravings!
Designates an area to be replaced with carved track, except tiles that have engravings
of at least the specified quality.

]====]

--local world = df.global.world
local utils = require 'utils'
local gui = require 'gui'
local guidm = require 'gui.dwarfmode'
local dialog = require 'gui.dialogs'

local quality_character = 
{
	[0] = "None", -- no quality; default (also used for constructions, tracks, etc., that don't have a quality)
	[1] = "-", -- well-crafted
	[2] = "+", -- finely-crafted
	[3] = "*", -- superior quality
	[4] = dfhack.utf2df("\u{2261}"), -- ≡ exceptional
	[5] = dfhack.utf2df("\u{263C}") -- ☼ masterful
}


-- from dig.lua (myk002)
function get_priority_block_square_event(block_events)
    for i,v in ipairs(block_events) do
        if v:getType() == df.block_square_event_type.designation_priority then
            return v
        end
    end
    return nil
end

-- from dig.lua (myk002) with a few changes -- use (x,y,z) instead of a digctx
-- modifies any existing priority block_square_event to the specified priority.
-- if the block_square_event doesn't already exist, create it.
 function set_priority(x, y, z, priority)
    local block_events = dfhack.maps.getTileBlock(x, y, z).block_events
    local pbse = get_priority_block_square_event(block_events)
    if not pbse then
        block_events:insert('#',
                            {new=df.block_square_event_designation_priorityst})
        pbse = block_events[#block_events-1]
    end
    pbse.priority[x % 16][y % 16] = priority * 1000
end

-- todo: paint the tiles that we trackify so that it shows which ones are affected?
function Trackify(x, y, z, ui)
	set_priority(x, y, z, ui.priority)
	d, o = dfhack.maps.getTileFlags(x, y, z)
	o.carve_track_north = true
	
	-- set a flag that will make the game check for what jobs to create
	dfhack.maps.getTileBlock(x, y, z).flags.designated = true
	
	ui.count = ui.count+1
end

-- i know that this function has a lot of nested blocks, but...
function DesignateTrack(ui, cursor, size)
	-- reset the tile count.
	ui.count = 0

	for sx=0, size.x-1 do
		for sy=0, size.y-1 do
			for sz=0, size.z-1 do
				local tx = cursor.x+sx
				local ty = cursor.y+sy
				local tz = cursor.z+sz
				
				local tileblock = dfhack.maps.getTileBlock(tx, ty, tz)
				local tiletype = tileblock.tiletype[tx%16][ty%16]
				caption = df.tiletype.attrs[tiletype].caption

				-- todo: make sure we don't designate the edges of the map for digging? (is this needed?  map edge will never be a smooth stone floor?)
				-- looking at the caption skips everything that isn't a smooth stone floor (walls, etc.)
				if caption == "smooth stone floor" then
					-- if we have quality == 5 (i.e. trackify everything that isn't a MW engraving)
					-- then we only need to look at the masterworks.
					if ui.quality == 5 then
						if not (ui.masterworks[tx] and ui.masterworks[tx][ty] and ui.masterworks[tx][ty][tz]) then
							Trackify(tx,ty,tz,ui)
						end
					else
					-- otherwise, we need to look at all the qualities
						if not (ui.engravings[tx] and ui.engravings[tx][ty] and ui.engravings[tx][ty][tz] and ui.engravings[tx][ty][tz] < ui.quality) then
							Trackify(tx,ty,tz,ui)
						end
					end
				end
				
			end -- loop over z-values
		end -- loop over y-values
	end -- loop over x-values
end

ReengraveUI = defclass(ReengraveUI, guidm.MenuOverlay)

function ReengraveUI:init()
	
	-- cache the engraving qualities and masterwork tiles
	local eng = {}
	local mw = {}
	
	for _, el in ipairs(df.global.world.engravings) do
		
		-- if necessary, construct the relevant multidimensional table
		if not eng[el.pos.x] then
			eng[el.pos.x] = {}
		end
		
		if not eng[el.pos.x][el.pos.y] then
			eng[el.pos.x][el.pos.y] = {}
		end
		
		if not eng[el.pos.x][el.pos.y][el.pos.z] then
			eng[el.pos.x][el.pos.y][el.pos.z] = {}
		end
		
		-- finally, insert the values
		eng[el.pos.x][el.pos.y][el.pos.z] = el.quality
		
		if el.quality >= 5 then
			-- if necessary, construct the relevant multidimensional table
			if not mw[el.pos.x] then
				mw[el.pos.x] = {}
			end
		
			if not mw[el.pos.x][el.pos.y] then
				mw[el.pos.x][el.pos.y] = {}
			end
		
			if not mw[el.pos.x][el.pos.y][el.pos.z] then
				mw[el.pos.x][el.pos.y][el.pos.z] = {}
			end
		
			-- finally, insert the values
			mw[el.pos.x][el.pos.y][el.pos.z] = true
		end
		
	end
	
	self:assign{
		priority = 4,
		quality = 5,
		count = 0,
		processed = false,
		engravings = eng,
		masterworks = mw,
	}
	
end

-- a lot of this is taken from gui/liquids.lua
function ReengraveUI:onRenderBody(dc)
	dc:clear():seek(1,1):string("Trackify", COLOR_WHITE)

	local cursor = guidm.getCursorPos()
    local block = dfhack.maps.getTileBlock(cursor)
	
	if block then
        local x, y, z = pos2xyz(cursor)
        local tile = block.tiletype[x%16][y%16]
		local caption = df.tiletype.attrs[tile].caption
		local hidden = df.tiletype.attrs[tile].caption
		
		local d, _ = dfhack.maps.getTileFlags(x, y, z)
	

		-- todo: find something better to show this as

		if not d.hidden then
			dc:seek(1,3):string(caption, COLOR_CYAN)
		else
			dc:seek(1,3):string("hidden", COLOR_CYAN)
		end
		
		
    else
        dc:seek(1,3):string("No map data", COLOR_RED):advance(0,2)
    end
	
	dc:newline():pen(COLOR_GREY)
	
	-- todo: command line arg to set default quality?
	-- select quality
    dc:newline(1):string("Quality:  " .. quality_character[self.quality])
	dc:advance(1):string("(")
            :key('SECONDSCROLL_PAGEUP'):key('SECONDSCROLL_PAGEDOWN')
            --:string(", ")
            --:key('STRING_A048'):string("-"):key('STRING_A053')
            :string(")")
	
	-- todo: command line arg to set default priority?
	-- select priority
	dc:newline(1):string("Priority: " .. self.priority)
	dc:advance(1):string("(")
            :key('SECONDSCROLL_UP'):key('SECONDSCROLL_DOWN')
            --:string(", ")
            --:key('STRING_A049'):string("-"):key('STRING_A055')
            :string(")")

	
	if self.processed then
		dc:newline():newline(1):string("Trackified " .. self.count .. " tiles.")
	end
	
	dc:newline():newline(1):pen(COLOR_WHITE)
    dc:key('SELECT'):string(": Designate")
	dc:newline(1):key('LEAVESCREEN'):string(": Back")
	
end

-- todo: do we want to have priority and quality cyclic instead of having min/max?
-- a lot of this is taken from gui/liquids.lua
function ReengraveUI:onInput(keys)
    if keys.LEAVESCREEN then
        if guidm.getSelection() then
            guidm.clearSelection()
            return
        end
        self:dismiss()
        guidm.refreshSidebar()
	-- priority -
	elseif keys.SECONDSCROLL_UP then
		self.priority = math.max(1, self.priority-1)
	-- priority +
	elseif keys.SECONDSCROLL_DOWN then
		self.priority = math.min(7, self.priority+1)
	-- quality -
	elseif keys.SECONDSCROLL_PAGEUP then
		self.quality = math.max(1, self.quality-1)
	-- quality +
	elseif keys.SECONDSCROLL_PAGEDOWN then
		self.quality = math.min(5, self.quality+1)
	-- designate the area or accept the designated area
    elseif keys.SELECT then
        local cursor = guidm.getCursorPos()
        local sp = guidm.getSelection()
        local size = nil
		if not sp then
			guidm.setSelectionStart(cursor)
			return
		else
			guidm.clearSelection()
			cursor, size = guidm.getSelectionRange(cursor, sp)
		end
        
		DesignateTrack(self, cursor, size)
		self.processed = true
		guidm.clearSelection()
    -- move the cursor around
    elseif self:propagateMoveKeys(keys) then
        return
    end
end

function ReengraveUI:onDestroy()
	guidm.clearSelection()
end

if not string.match(dfhack.gui.getCurFocus(), '^dwarfmode/LookAround') then	
	guidm.enterSidebarMode(df.ui_sidebar_mode.LookAround)	
end
	
local ui = ReengraveUI()
ui:show()
