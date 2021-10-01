-- Carve tracks over poor quality engravings so the engravers can try again
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
local quickfort = reqscript 'quickfort'

local quality_character = 
{
	[0] = "None", -- no quality; default (also used for constructions, tracks, etc., that don't have a quality)
	[1] = "-", -- well-crafted
	[2] = "+", -- finely-crafted
	[3] = "*", -- superior quality
	[4] = dfhack.utf2df("\u{2261}"), -- ≡ exceptional
	[5] = dfhack.utf2df("\u{263C}") -- ☼ masterful
}

function DesignateTrack(ui, cursor, size)
    local spec = ('trackN%d(%dx%d)'):format(ui.priority, size.x, size.y)
    local data = {[0]={[0]={[0]=spec}}}
    local stats = quickfort.apply_blueprint{mode='dig', data=data, pos=cursor,
                                            preserve_engravings=ui.quality}
    ui.count = stats.dig_designated.value
end

ReengraveUI = defclass(ReengraveUI, guidm.MenuOverlay)

function ReengraveUI:init()
	self:assign{
		priority = 4,
		quality = 5,
		count = 0,
		processed = false,
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
