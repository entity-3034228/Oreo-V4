--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local vape = shared.vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then 
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert') 
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function() 
		return readfile(file) 
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true) 
		end)
		if not suc or res == '404: Not Found' then 
			error(res) 
		end
		if path:find('.lua') then 
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res 
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local BEDWARS_PLACE_IDS = {
    [6872274481] = true,  
    [8444591321] = true,
    [6872265039] = true   
}

vape.Place = 6872274481

local gameFileName = tostring(vape.Place)..'.lua'
if shared.VapeAccountType == "free" and BEDWARS_PLACE_IDS[vape.Place] then
    gameFileName = 'FREE'..tostring(vape.Place)..'.lua'
end

if isfile('newvape/games/'..gameFileName) then
	loadstring(readfile('newvape/games/'..gameFileName), 'bedwars')()
else
	if not shared.VapeDeveloper then
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/'..readfile('newvape/profiles/commit.txt')..'/games/'..gameFileName, true) 
		end)
		if suc and res ~= '404: Not Found' then
			loadstring(downloadFile('newvape/games/'..gameFileName), 'bedwars')()
		end
	end
end