-- This is a VT100 terminal output writer for Pandoc.
-- Inwoke with: pandoc -t terminal.lua

-- Copyright (c) 2018 Orange
-- Homepage: https://github.com/Orange-OpenSource/pandoc-terminal-writer
-- This module is released under the MIT License (MIT).
-- Please see LICENCE.txt for details.
-- Author: Camille Oudot

-- Table to store footnotes, so they can be appended at the end of the output.
local notes = {}

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

-- Prints a table recursively
function tprint (tbl, indent)
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then
			print(formatting)
			tprint(v, indent+1)
		else
			print(formatting .. v)
		end
	end
end

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
	return vt100_sda(s, "3")
end

function Strong(s)
	return vt100_sda(s, "1")
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
	return vt100_sda(s, "9")
end

function Link(s, src, tit, attr)
	if s == src then
		return vt100_sda(s, "4")
	else
		return vt100_sda(s, "4") .. " (" .. vt100_sda(src, "2") .. ")"
	end
end

function Image(s, src, tit, attr)
	return vt100_sda("[Image (" .. tit .. ")](" .. src .. ")", "1")
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
	return vt100_sda(string.rep("██", lev - 1) .. "▓▒░ " .. s, "1;33")
end

function BlockQuote(s)
	local ret = "  ▛\n"
	for l in s:gmatch("[^\r\n]+") do
		ret = ret .. "  ▌ " .. l .. "\n"
	end
	return ret .. "  ▙"
end

function HorizontalRule()
	return " _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _\n"
end

function CodeBlock(s, attr)
	local lines = {}
	local ret
	ret = vt100_sda("  ╭───┬────────┄", "2") .. "\n"

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
		ret = ret .. vt100_sda("  │" .. string.format("%3d",n) .. "│ ", "2") .. l .. "\n"
	end
	return ret .. vt100_sda("  ╰───┴───────────┄", "2")
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
		ret[_] = indent(item, "  " .. vt100_sda("•", "2") .. " ", "    ")
	end
	return table.concat(ret, "\n")
end

function OrderedList(items)
	local ret = {}
	for _, item in pairs(items) do
		ret[_] = indent(item, vt100_sda(string.format("%2d.", _), "2") .. " ", "    ")
	end
	return table.concat(ret, "\n")
end

-- Revisit association list STackValue instance.
function DefinitionList(items)
	return ""
end

function CaptionedImage(src, tit, caption, attr)
	return BlockQuote(vt100_sda("[Image (" .. tit .. ")](" .. src .. ")", "1") .. "\n" .. caption)
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

-- Position text in a wider string (stuffed with blanks)
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

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
	local buffer = {}
	local align = {["AlignDefault"] = 0, ["AlignLeft"] = 0, ["AlignRight"] = 1, ["AlignCenter"] = 2}
	local function add(s)
		table.insert(buffer, s)
	end
	-- Find maximum width for each column:
	local col_width = {}
	local cell_width = 0
	for i, header in pairs(headers) do
		table.insert(col_width, i, _utf8Len(_getText(header)))
		for _, row in pairs(rows) do
			cell_width = _utf8Len(_getText(row[i]))
			if cell_width > col_width[i] then
				col_width[i] = cell_width
			end
		end
	end

	local top_border = '┌'
	local row_border = '├'
	local bottom_border = '└'
	local last = table.getn(col_width)
	local tmpl = ''
	for i, w in pairs(col_width) do
		tmpl = tmpl .. string.rep('─', w) .. (i < last and 'm' or '')
	end
	top_border = top_border .. string.gsub(tmpl, 'm', '┬') .. '┐'
	row_border = row_border .. string.gsub(tmpl, 'm', '┼') .. '┤'
	bottom_border = bottom_border .. string.gsub(tmpl, 'm', '┴') .. '┘'
	
	if caption ~= "" then
		add(Strong(caption))
	end
	local header_row = {}
	local empty_header = true
	for i, h in pairs(headers) do
		table.insert(header_row, Strong(_position(h, col_width[i], 2)))
		empty_header = empty_header and h == ""
	end
	add(top_border)
	if empty_header then
		head = ""
	else
		local content = ''
		for _, h in pairs(header_row) do
			content = content .. '│' .. h
		end
		add(content .. '│')
		add(row_border)
	end
	for i, row in pairs(rows) do
		local content = ''
		for i, c in pairs(row) do
			if (col_width[i]) then
				content = content .. '│' .. _position(c, col_width[i], align[aligns[i]])
			end
		end
		add(content .. '│')
		if i < table.getn(rows) then
			add(row_border)
		end
	end
	add(bottom_border)
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

