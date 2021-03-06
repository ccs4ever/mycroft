-- Pretty-printing functions
function debugPrint(msg)
	if(verbose) then print(pretty("debug: "..serialize(msg))) end
end

function serialize(args, luaMode) -- serialize in Mycroft syntax
	local ret, sep
	if(type(args)~="table") then
		ret=string.gsub(tostring(args), string.char(127), ",")
		ret=string.gsub(ret, string.char(128), "(")
		ret=string.gsub(ret, string.char(129), ")")
		ret=string.gsub(ret, string.char(130), "<")
		ret=string.gsub(ret, string.char(131), ">")
		ret=string.gsub(ret, string.char(132), "!")
		ret=string.gsub(ret, "([^ ]+)", function(q) 
			if ("\\Y\\E\\S"==q) then return "YES" 
			elseif("\\N\\O"==q) then return "NO" 
			elseif("\\N\\C"==q) then return "NC" 
			else return q end 
		end)
		return ret
	end
	if(args.truth~=nil and args.confidence~=nil) then
		if(luaMode) then
			return "{truth="..args.truth..", confidence="..args.confidence.."}"
		end
		if(1==args.confidence) then
			if(1==args.truth) then
				return "YES"
			elseif (0==args.truth) then
				return "NO"
			else
				return "<"..tostring(args.truth).."|"
			end
		elseif(1==args.truth) then
			return "|"..args.confidence..">"
		elseif(0==args.truth and 0==args.confidence) then
			return "NC"
		else 
			return "<"..tostring(args.truth)..","..tostring(args.confidence)..">" 
		end
	elseif(nil~=args.name and nil~=args.arity) then
		return prettyPredID(args)
	end
	if(luaMode) then
		ret="{"
	else
		ret="("
	end
	sep=""
	local lastK=0
	for k,v in ipairs(args) do
		ret=ret..sep
		if(type(v)=="table") then
			ret=ret..serialize(v,luaMode)
		elseif(type(v)=="string") then
			if(string.find(v, "[^A-Za-z0-9]")==nil and not luaMode) then
				ret=ret..v
			else
				ret=ret.."\""..serialize(v,luaMode).."\""
			end
		else
			ret=ret..tostring(v)
		end
		sep=","
		lastK=k
	end
	for k,v in pairs(args) do
		if(type(k)~="number") then
			ret=ret..sep..tostring(k).."="
			if(type(v)=="table") then
				ret=ret..serialize(v, luaMode)
			elseif(type(v)=="string") then
				ret=ret.."\""..serialize(v, luaMode).."\""
			else
				ret=ret..tostring(v)
			end
			sep=","
		elseif(k>lastK) then
			ret=ret..sep..tostring(k).."="..serialize(v, luaMode)
		end
	end
	if(luaMode) then return ret.."}" end
	return ret..")"
end

function prettyPredID(p) -- serialize a predicate name, prolog-style
	debugPrint("Constructing pred id: "..serialize(p.name).."/"..serialize(p.arity))
	return p.name.."/"..p.arity
end

-- pretty-printing routines for predicate definition
function printWorld(world) -- print all preds
	print(pretty(strWorld(world)))
end

function strWorld(world) -- return the code for all predicates as a string
	local k, v
	ret=""
	debugPrint({"world:", world})
	if(world~=nil) then 
		for k,v in pairs(world.aliases) do
			ret=ret..strDef(world, k)
			debugPrint({k, v, ret})
		end
		for k,v in pairs(world) do
			if(k~="MYCERR" and k~="MYCERR_STR" and k~="aliases" and k~="symbols") then
				ret=ret..strDef(world, k)
			end
		end
	end
	return "# State of the world\n"..ret
end

-- XXX: str*Lua does not work yet
function strWorldLua(world) -- return the code for all predicates as a string
	local k, v
	ret=""
	debugPrint({"world:", world})
	if(world~=nil) then 
		for k,v in pairs(world.aliases) do
			ret=ret..strDefLua(world, k)
			debugPrint({k, v, ret})
		end
		for k,v in pairs(world) do
			if(k~="MYCERR" and k~="MYCERR_STR" and k~="aliases" and k~="symbols") then
				ret=ret..strDefLua(world, k)
			end
		end
	end
	return "# State of the world\n"..ret
end

function strDefLua(world, k) -- return the definition of the predicate k as a string
	local ret, argCount, args, hash, val, i, v, sep, pfx
	ret=""
	if(world.aliases[k]) then
		v=world[world.aliases[k]]
		if (nil==v) then ret=ret.."function "..k.."() return "..world.aliases[k].."() end\n" end
	else
		v=world[k]
	end
	if(nil==v) then return ret end
	det="function "
	pfx=det.." "..string.gsub(tostring(k), "/%d*$", "")
	if(nil~=v.facts) then
		for hash,val in pairs(v.facts) do
			ret=ret..pfx..serialize(hash).." return "..serialize(val).." end\n"
		end
	end
	if(nil~=v.def) then
		argCount=0
		args={}
		if(v.arity<26) then
			for i=1,v.arity do
				args[i]=string.char(64+i)
			end
		else
			for i=1,v.arity do
				args[i]="Arg"..tostring(i)
			end
		end
		if(nil~=v.def.children) then
			if(nil~=v.def.children[1]) then
				ret=ret..pfx..serialize(args).." return "
				if(nil~=v.def.children[2])  then
					ret=ret.."performPLBoolean("
					ret=ret..v.def.children[1].name..serialize(translateArgList(args, v.def.correspondences[1]), true)
					ret=ret..","
					ret=ret..v.def.children[2].name
					ret=ret..serialize(translateArgList(args, v.def.correspondences[2]), true)
					ret=ret..",\""..v.def.op.."\")"
				else
					ret=ret..v.def.children[1].name
					ret=ret..serialize(translateArgList(args, v.def.correspondences[1]), true)
				end
				ret=ret.." end \n"
			end
		end
	end
	return ret
end

function strDef(world, k) -- return the definition of the predicate k as a string
	local ret, argCount, args, hash, val, i, v, sep, pfx
	ret=""
	if(world.aliases[k]) then
		v=world[world.aliases[k]]
		if (nil==v) then ret=ret.."nondet "..k.."() :- "..world.aliases[k]..".\n" end
	else
		v=world[k]
	end
	if(nil==v) then return ret end
	det=v.det
	if(nil==v.det or v.det) then det="det" else det="nondet" end
	pfx=det.." "..string.gsub(tostring(k), "/%d*$", "")
	if(nil~=v.facts) then
		for hash,val in pairs(v.facts) do
			ret=ret..pfx..serialize(hash).." :- "..serialize(val)..".\n"
		end
	end
	if(nil~=v.def) then
		argCount=0
		args={}
		if(v.arity<26) then
			for i=1,v.arity do
				args[i]=string.char(64+i)
			end
		else
			for i=1,v.arity do
				args[i]="Arg"..tostring(i)
			end
		end
		if(nil~=v.def.children) then
			if(nil~=v.def.children[1]) then
				ret=ret..pfx..serialize(args).." :- "
				ret=ret..v.def.children[1].name
				ret=ret..serialize(translateArgList(args, v.def.correspondences[1]))
				if(nil~=v.def.children[2])  then
					sep=", "
					if(v.def.op=="or") then
						sep="; "
					end
					ret=ret..sep..v.def.children[2].name
					ret=ret..serialize(translateArgList(args, v.def.correspondences[2]))
				end
				ret=ret..".\n"
			end
		end
	end
	return ret
end
-- ANSI color code handling
colors={black=0, red=1, green=2, yellow=3, blue=4, magenta=5, cyan=6, white=7, none=0}
function colorCode(bg, fg, bold) 
	if(bg==nil) then 
		return string.char(27).."[0m" 
	end 
	local b="0"
	if(bold~=nil) then b="1" end
	return string.char(27).."["..b..";"..tostring(30+colors[fg])..";"..tostring(40+colors[bg]).."m" 
end
function pretty(msg) -- perform syntax highlighting if we are in ansi mode
	if(ansi) then
		msg=string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(msg, 
			"(;)", function (c)
				return colorCode("black", "magenta", 1)..c..colorCode("black", "white")
			end), "([.,])", function (c)
				return colorCode("black", "magenta", 1)..c..colorCode("black", "white")
			end),"([a-z_]%w+ *%b())", function (c)
				return colorCode("black", "cyan", 1)..c..colorCode("black", "white")
			end), "([()])", function (c)
				return colorCode("black", "magenta", 1)..c..colorCode("black", "white")
			end), "([ \t\n]*)(%w+)", function(b, c)
				if("YES"==c or "NO"==c or "NC"==c) then
					return b..colorCode("black", "yellow", 1)..c..colorCode("black", "white")
				elseif("debug"==c or "error"==c) then
					return b..colorCode("black", "red", 1)..c..colorCode("black", "white")
				elseif(string.find(c, "^%u%w*$")~=nil) then
					return b..colorCode("black", "cyan")..c..colorCode("black", "white")
				else 
					return b..c
				end
			end), "(40m)(%w+)", function(b, c)
				if("YES"==c or "NO"==c or "NC"==c) then
					return b..colorCode("black", "yellow", 1)..c..colorCode("black", "white")
				elseif("debug"==c or "error"==c) then
					return b..colorCode("black", "red", 1)..c..colorCode("black", "white")
				elseif(string.find(c, "^%u%w*$")~=nil) then
					return b..colorCode("black", "cyan")..c..colorCode("black", "white")
				else 
					return b..c
				end
			end), "([?:]%-)", function (c) 
				return colorCode("black", "green", 1)..c..colorCode("black", "white") 
			end), "([<|][0-9., ]+[|>])", function(c) 
				return colorCode("black", "yellow", 1)..c..colorCode("black", "white") 
			end), "%b\"\"", function(c)
				return colorCode("black", "red")..string.gsub(c, string.char(27).."%[".."[^m]+m", "")..colorCode("black", "white")
			end), "(#[^\n]*)", function(c)
				return colorCode("black", "blue", 1)..string.gsub(c, string.char(27).."%[".."[^m]+m", "")..colorCode("black", "white")
			end)
		msg=colorCode("black", "white")..msg..colorCode("black", "white", 1)
	end
	return msg
end

