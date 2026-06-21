-- LocalScript inside StarterGui (or executed)
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer

-- Setup State Variables
local isCopying = false
local copyAllActive = false
local targetsToCopy = {} -- Format: { ["Username"] = true }

-- Helper function to find a player by a partial name match
local function findPlayerByPartialName(searchString)
	searchString = string.lower(searchString)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			if string.find(string.lower(player.Name), searchString, 1, true) or string.find(string.lower(player.DisplayName), searchString, 1, true) then
				return player
			end
		end
	end
	return nil
end

-- ==========================================
-- CHAT ROUTING AND DUPLICATION PIPELINE
-- ==========================================
local function duplicateMessage(message)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local generalChannel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if generalChannel then 
			generalChannel:SendAsync(message) 
		end
	else
		local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		local sayMessage = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
		if sayMessage then 
			sayMessage:FireServer(message, "All") 
		end
	end
end

-- ==========================================
-- COMMAND INTERACTION HANDLERS
-- ==========================================
local function handleChatCommands(message)
	-- Strip trailing spaces to prevent syntax match fails
	message = string.gsub(message, "%s+$", "")

	-- Command 1: Exact check for "all" configuration
	if message == "/copychat all" or message == "/chatcopy all" then
		copyAllActive = true
		isCopying = true
		
		table.clear(targetsToCopy)
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				targetsToCopy[player.Name] = true
			end
		end
		
		print("[ChatCopy] Now copying EVERYONE in the server.")
		return true
	end

	-- Command 2: Dynamic single-user extraction layout
	local copyArg = string.match(message, "^/copychat%s+(.+)$") or string.match(message, "^/chatcopy%s+(.+)$")
	if copyArg then
		copyAllActive = false 
		local target = findPlayerByPartialName(copyArg)
		if target then
			targetsToCopy[target.Name] = true
			isCopying = true
			print("[ChatCopy] Now copying: " .. target.DisplayName .. " (@" .. target.Name .. ")")
		else
			warn("[ChatCopy] Player not found matching: " .. copyArg)
		end
		return true
	end
	
	-- Command 3: Execution reset rule
	if message == "/stopcopying" then
		isCopying = false
		copyAllActive = false
		table.clear(targetsToCopy)
		print("[ChatCopy] Stopped copying all players.")
		return true
	end
	return false
end

-- Hook into incoming messages from other players
local function watchOtherPlayers(player)
	if player == LocalPlayer then return end
	
	if
