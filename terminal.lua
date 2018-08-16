-- This is a VT100 terminal output writer for Pandoc.
-- Inwoke with: pandoc -t terminal.lua


-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
	return "\n\n"
end

-- prints a table recursively
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

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
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

-- Set Display Attibute using a VT100 escape sequence
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
	return vt100_sda("    [Image (" .. tit .. ")](" .. src .. ")", "1")
end

function Code(s, attr)
	return vt100_sda(s, "1;32")
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
	local ret = vt100_sda("  ╭───┬ code: ─┄", "2") .. "\n"

	for l in s:gmatch("([^\n]*)\n?") do
		lines[#lines + 1] = l
	end

	if lines[#lines] == "" then
		lines[#lines] = nil
	end

	for n, l in pairs(lines) do
		ret = ret .. vt100_sda("  │" .. string.format("%3d",n) .. "│ ", "2") .. vt100_sda(l, "1;32") .. "\n"
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

function Table(caption, aligns, widths, headers, rows)
	return ""
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

