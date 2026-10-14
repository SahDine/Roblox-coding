--[[
	Format
	Number and time formatting helpers shared by the server and the client.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = (string.gsub(text, "0+$", ""))
		text = (string.gsub(text, "%.$", ""))
	end
	return text
end

-- 1234 -> "1.23K", 1500000 -> "1.5M"
function Format.Number(value: number): string
	if value ~= value or value == math.huge or value == -math.huge then
		return "0"
	end

	local sign = if value < 0 then "-" else ""
	value = math.abs(value)

	if value < 1000 then
		if value == math.floor(value) then
			return sign .. tostring(math.floor(value))
		end
		return sign .. trimZeros(string.format("%.1f", math.floor(value * 10) / 10))
	end

	local index = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (index * 3)

	local text
	if scaled >= 100 then
		text = tostring(math.floor(scaled))
	elseif scaled >= 10 then
		text = trimZeros(string.format("%.1f", math.floor(scaled * 10) / 10))
	else
		text = trimZeros(string.format("%.2f", math.floor(scaled * 100) / 100))
	end

	return sign .. text .. SUFFIXES[index + 1]
end

function Format.Money(value: number): string
	return "$" .. Format.Number(value)
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return Format
