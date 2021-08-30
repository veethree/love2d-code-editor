local code_editor = {}
code_editor_meta = {__index = code_editor}

--Local methods
-- Converts color from 0-255 range to 0-1
local function color(r, g, b, a)
	a = a or 255
	return {r / 255, g / 255, b / 255, a / 255}
end

local function getCharBytes(string, char)
	char = char or 1
	local b = string.byte(string, char)
	local bytes = 1
	if b > 0 and b <= 127 then
      bytes = 1
   elseif b >= 194 and b <= 223 then
      bytes = 2
   elseif b >= 224 and b <= 239 then
      bytes = 3
   elseif b >= 240 and b <= 244 then
      bytes = 4
   end
	return bytes
end

local function len(str)
	local pos = 1
	local len = 0
	while pos <= #str do
		len = len + 1
		pos = pos + getCharBytes(str, pos)
	end
	return len
end

local function sub(str, s, e)
	s = s or 1
	e = e or len(str)

	if s < 1 then s = 1 end
	if e < 1 then e = len(str) + e + 1 end
	if e > len(str) then e = len(str) end

	if s > e then return "" end

	local sByte = 0
	local eByte = 1

	local pos = 1
	local i = 0
	while pos <= #str do
		i = i + 1
		if i == s then
			sByte = pos
		end
		pos = pos + getCharBytes(str, pos)
		if i == e then
			eByte = pos - 1
			break
		end
	end

	return string.sub(str, sByte, eByte)
end

local function has_key(tab, key)
	local r = false
	for k, v in pairs(tab) do
		if k == key then
			r = true
			break
		end
	end
	return r
end

--LÖVE SETUP
local lg = love.graphics
local fs = love.filesystem
local lk = love.keyboard
lk.setKeyRepeat(true)

function code_editor.new(x, y, width, height)
    local ce = {
        x = x,
        y = y,
        width = width,
        height = height,
        lines = {""},
		file = "None",
		scroll = {
			x = 1,
			y = 1
		},
        cursor = {
            x = 1,
            y = 1,
			draw_x = 1,
			draw_y = 1
        },
        config = {
            font = lg.newFont(16),
			text_color_base = {1, 1, 1, 1},
			cursor_color = {0, 0.7, 0, 1},
			background_color = color(26, 28, 36),
			info_color = color(232, 118, 118),
			line_number_color = color(191, 191, 191),
			x_margin = 3,
			y_margin = 12,
			tab = "    ",
			syntax = {
				number = color(230, 76, 76),
				value = color(180, 77, 240),
				keyword = color(51, 177, 255),
				string = color(245, 205, 105),
				symbol = color(129, 219, 90),
				comment = color(120, 120, 120),
				ident = color(239, 242, 136)
			}
        }    
    }

	ce.font_height = ce.config.font:getAscent() - ce.config.font:getDescent()
	ce.font_width = ce.config.font:getWidth("a")
	ce.config.x_margin = ce.config.x_margin + ce.config.font:getWidth("1234")
	ce.visible_lines = math.floor(ce.height / ce.font_height)
	ce.max_line_width = math.floor((ce.width - (ce.config.x_margin * 2)) / ce.font_width)
	print(ce.max_line_width)

    return setmetatable(ce, code_editor_meta)
end

function code_editor:set_font(font)
    self.config.font = font
	self.font_height = self.config.font:getAscent() - self.config.font:getDescent()
	self.font_width = self.config.font:getWidth("W")
	self.visible_lines = math.floor((self.height - (self.config.y_margin * 2) - self.font_height) / self.font_height) - 1
	self.max_line_width = math.floor((self.width - (self.config.x_margin * 2)) / self.font_width)
end

function code_editor:get_line(line)
	line = line or self.cursor.y
	return self.lines[line]
end

function code_editor:set_line(text, line)
	line = line or self.cursor.y
	self.lines[line] = text
end

-- Inserts 't' wherever the cursor is in  a line
function code_editor:insert(t)
	local line_start, line_end = self:split_line()
	if self.cursor.x == 1 then
		line_start = ""
	end

	self:set_line(line_start..t..line_end)
end

function code_editor:insert_line(pos, line)
	line = line or ""
	table.insert(self.lines, pos, line)
end

function code_editor:remove_line(pos)
	table.remove(self.lines, pos)
end

-- Splits the line at the cursor
function code_editor:split_line()
	local line = self:get_line()
	local line_start = sub(line, 1, self.cursor.x-1)
	local line_end = sub(line, self.cursor.x, #line)

	return line_start, line_end
end

-- Draws line with syntax highlighting
function code_editor:draw_line(line)
	local colored_text = {}
	local l = lex(self:get_line(line))
	for i,v in ipairs(l) do
		for o,j in ipairs(v) do
			local color = self.config.text_color_base
			if has_key(self.config.syntax, j.type) then
				color = self.config.syntax[j.type]
			end
		
			colored_text[#colored_text + 1] = color
			colored_text[#colored_text + 1] = j.data
		end
	end

	line = line - self.scroll.y


	lg.setStencilTest("greater", 0)
	lg.setColor(1, 1, 1, 1)
	lg.print(colored_text, self.x + (self.config.x_margin * 2) - (self.font_width * (self.scroll.x)), self.y + self.config.y_margin + (self.font_height * (line)))

	--Line numbers
	lg.setColor(self.config.line_number_color)
	lg.print(line + self.scroll.y, self.x + self.config.x_margin, self.y + self.config.y_margin + (self.font_height * (line)))
end

-- Updates the cursor drawing position
function code_editor:update_cursor()
	self.cursor.draw_y = self.y + self.config.y_margin + (self.cursor.y - self.scroll.y) * self.font_height 
	self.cursor.draw_x = self.x + (self.config.x_margin * 2) + (self.cursor.x - 1 - self.scroll.x) * self.font_width

	--Scrolling
	--if self.cursor.x > self.max_line_width then
	self.scroll.x = self.cursor.x - self.max_line_width
	if self.scroll.x < 1 then
		self.scroll.x = 1
	end

	--end
end

-- Loads a file & replaces tabs with spaces
function code_editor:load_file(file)
	if fs.getInfo(file) then
		self.file = file
		for line in fs.lines(file) do
			-- Replacing tabs with spaces cause fuck tabs
			fixed_line = string.gsub(line, "\t", self.config.tab)
			self:insert_line(#self.lines, fixed_line)
		end
	end
end

-- Init function, Can also load a file if one is provided.
function code_editor:load(file)
	file = file or false
	if file then
		self:load_file(file)
	end
	self:update_cursor()
end

function code_editor:update(dt)

end

function code_editor:draw()
	local of = lg.getFont()
	local r, g, b, a = lg.getColor()

	local function stencil()
		lg.rectangle("fill", self.x, self.y, self.width, self.height)
	end
	lg.stencil(stencil)

	lg.setStencilTest("greater", 0)
	--BG
	lg.setColor(self.config.background_color)
	lg.rectangle("fill", self.x, self.y, self.width, self.height)

	--CURSOR
	lg.setColor(self.config.cursor_color)
	lg.rectangle("fill", self.cursor.draw_x, self.cursor.draw_y, self.font_width, self.font_height)

	--FONT
	lg.setColor(1, 1, 1, 1)
	lg.setFont(self.config.font)

	-- Code
	for i=self.scroll.y, self.scroll.y + self.visible_lines do
		if i <= #self.lines then
			self:draw_line(i)
		end
	end

	-- Info tab
	lg.setColor(self.config.info_color)
	local str_left = string.format("Total lines: %d", #self.lines)
	local str_center = string.format("'%s'", self.file)
	local str_right = string.format("[%dx%d] [%dx%d]", self.cursor.x, self.cursor.y, self.scroll.x, self.scroll.y)
	lg.printf(str_left, self.x, self.height - self.font_height, self.width, "left")
	lg.printf(str_center, self.x, self.height - self.font_height, self.width, "center")
	lg.printf(str_right, self.x, self.height - self.font_height, self.width, "right")

	lg.setStencilTest()
	lg.setColor(r, g, b, a)
	lg.setFont(of)

end 


function code_editor:keypressed(key)
	if key == "backspace" then
		local line_start, line_end = self:split_line()
		line_start = sub(line_start, 1, self.cursor.x-2)
		if self.cursor.x <= 2 then
			line_start = ""
		end

		self:set_line(line_start..line_end)

		self.cursor.x = self.cursor.x - 1
		if self.cursor.x < 1 then 
			self.cursor.x = 1
			if self.cursor.y > 1 then
				self.cursor.y = self.cursor.y - 1
				self.cursor.x = #self:get_line() + 1
				self:set_line(self:get_line()..line_end)
				self:remove_line(self.cursor.y + 1)
			end
		end

	elseif key == "return" then
		local line_start, line_end = self:split_line()
		if self.cursor.x <= 1 then
			line_start = ""
		end

		self.cursor.y = self.cursor.y + 1
		self.cursor.x = 1
		self:set_line(line_start, self.cursor.y - 1)
		self:insert_line(self.cursor.y, line_end)
	elseif key == "tab" then
		self:insert(self.config.tab)
		self.cursor.x = self.cursor.x + #self.config.tab
	elseif key == "left" then
		if self.cursor.x > 1 then
			self.cursor.x = self.cursor.x - 1
		end
		
		--snap to start
		if lk.isDown("lctrl") or lk.isDown("rctrl") then
			self.cursor.x = 1
		end
	elseif key == "right" then
		self.cursor.x = self.cursor.x + 1
		if self.cursor.x > #self:get_line() then
			self.cursor.x = #self:get_line() + 1
		end

		--snap to end
		if lk.isDown("lctrl") or lk.isDown("rctrl") then
			self.cursor.x = #self:get_line() + 1
		end
	elseif key == "up" then
		self.cursor.y = self.cursor.y - 1
		if self.cursor.y < 1 then
			self.cursor.y = 1
		end

		--Scrolling also
		if self.cursor.y < self.scroll.y then
			self.scroll.y = self.scroll.y - 1
		end

		--Fixing cursor x
		if self.cursor.x > #self:get_line() then
			self.cursor.x = #self:get_line() + 1
		end

		--Scroll
		if lk.isDown("lshift") or lk.isDown("rshift") then
			local step = math.floor(self.visible_lines / 2)
			if lk.isDown("lctrl") or lk.isDown("rctrl") then
				step = self.visible_lines
			end
			self.scroll.y = self.scroll.y - step
			self.cursor.y = self.scroll.y
			if self.cursor.y < 1 then self.cursor.y = 1 end
			if self.scroll.y < 1 then
				self.scroll.y = 1
			end
		else
			--Snap
			if lk.isDown("lctrl") or lk.isDown("rctrl") then
				self.scroll.y = 1
				self.cursor.y = 1
			end
		end
	elseif key == "down" then
		self.cursor.y = self.cursor.y + 1
		if self.cursor.y > #self.lines then
			self.cursor.y = #self.lines
		end

		--Scrolling 
		if self.cursor.y > (self.scroll.y + self.visible_lines) then
			self.scroll.y = self.scroll.y + 1
		end

		-- Fixing cursor X
		if self.cursor.x > #self:get_line() then
			self.cursor.x = #self:get_line() + 1
		end

		--Scroll
		if lk.isDown("lshift") or lk.isDown("rshift") then
			local step = math.floor(self.visible_lines / 2)
			if lk.isDown("lctrl") or lk.isDown("rctrl") then
				step = self.visible_lines
			end
			self.scroll.y = self.scroll.y + step
			self.cursor.y = self.scroll.y
			if self.cursor.y > #self.lines then self.cursor.y = #self.lines end
			if self.scroll.y > #self.lines - self.visible_lines then
				self.scroll.y = #self.lines - self.visible_lines
			end
		else
			--Snap
			if lk.isDown("lctrl") or lk.isDown("rctrl") then
				self.scroll.y = #self.lines - self.visible_lines
				self.cursor.y = #self.lines
			end
		end
	end
	self:update_cursor()
end

function code_editor:textinput(t)
	self:insert(t)

	self.cursor.x = self.cursor.x + 1
	self:update_cursor()
end

return code_editor