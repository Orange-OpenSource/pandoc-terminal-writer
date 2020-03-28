# Pandoc Terminal Writer showcase

## Titles

### Foo

#### Bar

#### Baz

### Fizz

### Buzz

## Text formating

Text in **bold**, _italic_, ~~strikeout~~, `code`, **_bold italic_**, <span style="font-variant:small-caps;">Small Caps</span> 

## Links

Link [with a title](http://foo.bar)

Link without title: <http://foo.bar>

## Block formating

### Bullet list

- foo
- bar:
  - baz
  - qux
- fizz
- buzz

### Ordered lists

1. foo
2. bar:
    1. baz
    2. qux
3. fizz
4. buzz

### Citations

> Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Sed non risus.

### Code without syntax highlighting

```
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
```

### Code with syntax highlighting

You need either the `pygmentize` or the `highlight` command available on your system

```lua
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
```

### Horizontal lines

between 

---

two paragraphs

## Tables


| Foo     | right aligned | left aligned | centered    |
|---------|--------------:|:-------------|:-----------:|
| bar     |           128 | 123          |      x      |
| **baz** |           256 | 456          |      y      |
| ~~qux~~ |           512 | 789          |      z      |
| `fizz`  |          1024 | 000          |      t      |
