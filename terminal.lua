-- This is a VT100 terminal output writer for Pandoc.
-- Inwoke with: pandoc -t terminal.lua

-- Copyright (c) 2018 — 2020 Orange
-- Homepage: https://github.com/Orange-OpenSource/pandoc-terminal-writer
-- This module is released under the MIT License (MIT).
-- Please see LICENCE.txt for details.
-- Author: Camille Oudot
-- Author: Benoît Bailleux

-- Table to store footnotes, so they can be appended at the end of the output.
local notes = {}

-- Globally declared:
STYLE_BOLD   = "1" -- Bold
STYLE_DIM    = "2" -- Dimmed
STYLE_ITALIC = "3" -- Italic
STYLE_UNDERL = "4" -- Underlined
STYLE_STRIKE = "9" -- Striked through
-- STYLE_TITLE  = "1;7;33" -- Bold, Inverted, Yellow
STYLE_TITLE  = "1;33" -- Bold, NOT Inverted, Yellow
STYLE_TABLE_HEAD = "1;33" -- Bold, Yellow
SCREEN_WIDTH = 128
terminal_col_nb = SCREEN_WIDTH

-- Pipes an inp(ut) to a cmd
local function pipe(cmd, inp)
	local tmp = os.tmpname()
	local tmph = io.open(tmp, "w")
	tmph:write(inp)
	tmph:close()
	local outh = io.popen(cmd .. " " .. tmp .. " 2>/dev/null","r")
	local result = outh:read("*all")
	outh:close()
	os.remove(tmp)
	return result
end

-- Tells if a given command is available on the system
local function command_exists(cmd)
	local h = io.popen("which " .. cmd)
	local result = h:read("*all")
	h:close()
	return not (result == "")
end

-- Look for a syntax highlighter command on the current system
if command_exists("pygmentize") then
	highlight = function(s, fmt)
		local hl = pipe("pygmentize -l " .. fmt ..  " -f console", s)
		return hl == "" and s or hl
	end
elseif command_exists("highlight") then
	highlight = function(s, fmt)
		local hl = pipe("highlight -O ansi -S " .. fmt, s)
		return hl == "" and s or hl
	end
else
	highlight = function(s, fmt)
		return s
	end
end

-- Look for the width of the current terminal window
if os.getenv('COLUMNS') then
	-- User defined
	terminal_col_nb = tonumber(os.getenv('COLUMNS'))
elseif command_exists("stty") then
	local h = io.popen("stty size") -- Result is like: "42 80" (height width)
	local w = h:read("*all")
	terminal_col_nb = tonumber(string.match(w, "%d+%s(%d+)"))
	h:close()
elseif command_exists("tput") then
	local h = io.popen("tput cols")
	terminal_col_nb = tonumber(h:read("*all"))
	h:close()
end

--------- Helpers for wrapping long formatted text lines ----------------------

-- Returns the first letter and the remaining characters of the input string.
-- If the string begins with "Set Display Attribute" escape sequences, they are
-- kept alongside the first letter in the first returned value.
--
-- example: get_1st_letter("ABCD")
--		  returns: "A", "BCD"
--		  get_1st_letter("\27[1mA\27[0mBCD")
--		  returns: "27[1mA\27[0m", "BCD"
function get_1st_letter(s)
	local function get_1st_letter_rec(s, acc)
		if #s == 0 then
			return "", ""
		elseif #s == 1 then
			return s, ""
		else
			local m = s:match("^\27%[[0-9;]+m")

			if m == nil then
				local m = s:match("^[^\27]\27%[[0-9;]+m")
				if m == nil then
					return acc .. s:sub(1,1), s:sub(2)
				else
					return acc .. m, s:sub(#m + 1)
				end
			else
				return get_1st_letter_rec(s:sub(#m + 1), acc .. m)
			end
		end
	end
	return get_1st_letter_rec(s, "")
end

-- Inserts line breaks in 's' every 'w' _actual_ characters, meaning that the
-- escape sequences do not count as a character.
function fold(s, w)
	local col = 0
	local buf = ""
	local h

	while #s > 0 do
		h, s = get_1st_letter(s)
		if col == w then
			buf = buf .. "\n"
			col = 0
		end
		buf = buf .. h
		col = col + 1
	end
	return buf
end

-- Returns a substring of 's', starting after 'orig' and of length 'nb'
-- Escape sequences are NOT counted as characters and thus are not cut.
function subString(s, orig, nb)
	local col = 0
	local buf = ""
	local h

	while #s > 0 and col < orig do
		h, s = get_1st_letter(s)
		col = col + 1
	end

	col = 0
	while #s > 0 and col < nb do
		h, s = get_1st_letter(s)
		buf = buf .. h
		col = col + 1
	end
	return buf
end


-- Merges all consecutive "Set Display Attribute" escape sequences in the input
-- 's' string, and merges them into single ones in the returned string.
-- 
-- example: simplify_vt100("foo \27[1m\27[2;3m\27[4m bar")
--		  returns: "foo \27[1;2;3;4m bar"
function simplify_vt100(s)
	local _
	while s:match("(\27%[[0-9;]+)m\27%[") do
		s, _ = s:gsub("(\27%[[0-9;]+)m\27%[", "%1;")
	end
	return s
end

-------------------------------------------------------------------------------

-- Blocksep is used to separate block elements.
function Blocksep()
	return "\n\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom LUA template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
	local buffer = {}
	local function add(s)
		table.insert(buffer, s)
	end
	add(body)
	if #notes > 0 then
		add('<ol class="footnotes">')
		for _,note in pairs(notes) do
			add(note)
		end
		add('</ol>')
	end
	return table.concat(buffer,'\n') .. '\n'
end

-- Sets Display Attribute using a VT100 escape sequence
function vt100_sda(s, style)
	return string.format(
		"\27[%sm%s\27[0m",
		style,
		string.gsub(
			s,
			"\27%[0m",
			"\27[0m\27[" .. style .. "m"))
end

function Str(s)
	return s
end

function Space()
	return " "
end

function SoftBreak()
	return " "
end

function LineBreak()
	return "\n"
end

function Emph(s)
	return vt100_sda(s, STYLE_ITALIC)
end

function Strong(s)
	return vt100_sda(s, STYLE_BOLD)
end

function Subscript(s)
	return "_{" .. s .. "}"
end

function Superscript(s)
	return "^{" .. s .. "}"
end

function SmallCaps(s)
	return s:upper()
end

function Strikeout(s)
	return vt100_sda(s, STYLE_STRIKE)
end

function Link(s, src, tit, attr)
	if s == src then
		return vt100_sda(s, STYLE_UNDERL)
	else
		return vt100_sda(s, STYLE_UNDERL) .. " (" .. vt100_sda(src, STYLE_DIM) .. ")"
	end
end

function Image(s, src, tit, attr)
	return vt100_sda("[Image (" .. tit .. ")](" .. src .. ")", STYLE_BOLD)
end

function Code(s, attr)
	return vt100_sda(s, "32")
end

function InlineMath(s)
	return s
end

function DisplayMath(s)
	return s
end

function Note(s)
	return s
end

function Span(s, attr)
	return s
end

function RawInline(format, str)
	return str
end

function Cite(s, cs)
	return s
end

function Plain(s)
	return s
end

function Para(s)
	return s
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
	return vt100_sda(string.rep("██", lev - 1) .. "▓▒░ " .. s .. " ", STYLE_TITLE)
end

function BlockQuote(s)
	local ret = "  ▛\n"
	local bloc = ''
	for l in s:gmatch("[^\r\n]+") do
		-- Split long line if needed:
		bloc = fold(l, terminal_col_nb - 4)  -- 4 == width of left margin
		for sl in bloc:gmatch("[^\r\n]+") do
			ret = ret .. "  ▌ " .. sl .. "\n"
		end
	end
	return ret .. "  ▙"
end

function HorizontalRule()
	return " " .. string.rep('—', terminal_col_nb - 3) .. "\n"
	--return " _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _\n"
end

function CodeBlock(s, attr)
	local lines = {}
	local ret
	ret = vt100_sda("  ╭───┬────────┄", STYLE_DIM) .. "\n"

	if attr["class"] ~= "" then
		s = highlight(s, attr["class"])
	end

	for l in s:gmatch("([^\n]*)\n?") do
		lines[#lines + 1] = l
	end

	if lines[#lines] == "" then
		lines[#lines] = nil
	end

	for n, l in pairs(lines) do
		ret = ret .. vt100_sda("  │" .. string.format("%3d",n) .. "│ ", STYLE_DIM) .. l .. "\n"
	end
	return ret .. vt100_sda("  ╰───┴───────────┄", STYLE_DIM)
end

depth = 0

function indent(s, fl, ol)
	local ret = {}
	local i = 1

	for l in s:gmatch("[^\r\n]+") do
		if i == 1 then
			ret[i] = fl .. l
		else
			ret[i] = ol .. l
		end
		i = i + 1
	end
	return table.concat(ret, "\n")
end

function BulletList(items)
	local ret = {}
	for _, item in pairs(items) do
		ret[_] = indent(item, "  " .. vt100_sda("•", STYLE_DIM) .. " ", "	")
	end
	return table.concat(ret, "\n")
end

function OrderedList(items)
	local ret = {}
	for _, item in pairs(items) do
		ret[_] = indent(item, vt100_sda(string.format("%2d.", _), STYLE_DIM) .. " ", "	")
	end
	return table.concat(ret, "\n")
end

-- Revisit association list STackValue instance.
function DefinitionList(items)
	return ""
end

function CaptionedImage(src, tit, caption, attr)
	return BlockQuote(vt100_sda("[Image (" .. tit .. ")](" .. src .. ")", STYLE_BOLD) .. "\n" .. caption)
end

-- Gets the 'text only' version of a text to display (as they may have been
-- modified with escape sequences before)
local function _getText(txt)
	return string.gsub(txt, "\27%[[;%d]+m", "")
end

-- Count viewable chars in UTF-8 strings
-- See http://lua-users.org/wiki/LuaUnicode
function _utf8Len(ustring)
	local ulen = 0
	for uchar in string.gmatch(ustring, "([%z\1-\127\194-\244][\128-\191]*)") do
		ulen = ulen + 1
	end
	return ulen
end

-- Position some text within a wider string (stuffed with blanks)
-- 'way' is '0' to left justify, '1' for right and '2' for center
function _position(txt, width, way)
	if way < 0 or way > 2 then
		return txt
	end
	local l = _utf8Len(_getText(txt))
		if width > l then
		local b = (way == 0 and 0) or math.floor((width - l) / way)
		local a = width - l - b
		return string.rep(' ', b) .. txt .. string.rep(' ', a)
	else
		return txt
	end
end

function _getNthRowLine(txt, nth, height, width)
	local s = ''
	if nth == height then
		s = subString(txt, (nth - 1) * width, width + 1) -- Avoid cutting last UTF8 sequence
	else
		s = subString(txt, (nth - 1) * width, width)
	end
	return s
end

MAX_COL_WIDTH = 42
MIN_COL_WIDTH = 5
-- "caption" is a string, "aligns" is an array of strings,
-- "widths" is an array of floats, "headers" is an array of
-- strings, "rows" is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
	local buffer = {}
	local table_width_for_adjust = 0
	local max_table_width_for_adjust = terminal_col_nb
	local align = {["AlignDefault"] = 0, ["AlignLeft"] = 0, ["AlignRight"] = 1, ["AlignCenter"] = 2}
	local function add_row(s)
		table.insert(buffer, s)
	end
	-- Find maximum width for each column:
	local col_width = {}
	local row_height = {}
	for j, row in pairs(rows) do
		row_height[j] = 1
	end
	local header_height = 1
	local cell_width = 0
	local cell_height = 0
	table_width_for_adjust = #headers + 3 -- # of columns + 2 for borders + 1 for margin
	for i, header in pairs(headers) do
		table.insert(col_width, i, _utf8Len(_getText(header)))
		for j, row in pairs(rows) do
			cell_width = _utf8Len(_getText(row[i]))
			if cell_width > col_width[i] then
				col_width[i] = cell_width
			end
		end
		if (col_width[i] > MIN_COL_WIDTH) then
			-- Sum of all widths for columns that could be reduced
			table_width_for_adjust = table_width_for_adjust + col_width[i]
		else
			max_table_width_for_adjust = max_table_width_for_adjust - col_width[i]
		end
	end
	-- Reduce large cells if needed:
	local xs = table_width_for_adjust - max_table_width_for_adjust
	if xs > 0 then
		for i, w in pairs(col_width) do
			if w > MIN_COL_WIDTH then
				col_width[i] = w - math.floor(w * xs / table_width_for_adjust + 1)
			end
			cell_height = math.floor(_utf8Len(_getText(headers[i])) / col_width[i]) + 1
			if cell_height > header_height then
				header_height = cell_height
			end
			for j, row in pairs(rows) do
				text_width = _utf8Len(_getText(row[i]))
				cell_height = math.floor(text_width / col_width[i]) + 1
				if cell_height > row_height[j] then
					row_height[j] = cell_height
				end
			end
		end
	end

	local last = #col_width
	local tmpl = ''
	for i, w in pairs(col_width) do
		-- Here, 'c' stands for "crossing char" and will be replaced
		tmpl = tmpl .. string.rep('─', w) .. (i < last and 'c' or '')
	end
	local CELL_SEP = vt100_sda('│', STYLE_DIM)
	local top_border    = vt100_sda('┌' .. string.gsub(tmpl, 'c', '┬') .. '┐', STYLE_DIM)
	local row_border    = vt100_sda('├' .. string.gsub(tmpl, 'c', '┼') .. '┤', STYLE_DIM)
	local bottom_border = vt100_sda('└' .. string.gsub(tmpl, 'c', '┴') .. '┘', STYLE_DIM)
	
	if caption ~= "" then
		add_row(Strong(caption))
	end
	local header_row = {}
	local empty_header = true
	for i, h in pairs(headers) do
		-- Table headers have same color as document headers
		empty_header = empty_header and h == ""
	end
	add_row(top_border)
	local content = ''
	local s = ''
	if not empty_header then
		for k = 1, header_height do -- Break long lines
			content = ''
			s = ''
			for i, h in pairs(headers) do
				s = _getNthRowLine(h, k, header_height, col_width[i])
				s = _position(vt100_sda(s, STYLE_TABLE_HEAD), col_width[i], 2)
				content = content .. CELL_SEP .. s
			end
			add_row(content .. CELL_SEP)
		end
		add_row(row_border)
	end
	for i, row in pairs(rows) do
		content = ''
		for k = 1, row_height[i] do -- Break long lines
			content = ''
			s = ''
			for j, c in pairs(row) do
				if (col_width[j]) then
					s = _getNthRowLine(c, k, row_height[i], col_width[j])
					content = content .. CELL_SEP .. _position(s, col_width[j], align[aligns[j]])
				end
			end
			add_row(content .. CELL_SEP)
		end
		if i < #rows then
			add_row(row_border)
		end
	end
	add_row(bottom_border)
	return table.concat(buffer,'\n')
end

function RawBlock(format, str)
	return str
end

function Div(s, attr)
	return s
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
	function(_, key)
		io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
		return function() return "" end
	end
setmetatable(_G, meta)

