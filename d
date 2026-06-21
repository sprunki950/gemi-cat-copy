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
		-- Modern Roblox TextChat Engine
		local generalChannel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if generalChannel then 
			generalChannel:SendAsync(message) 
		end
	else
		-- Legacy Roblox Chat Engine
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
	-- Command 1: /copychat all
	if string.match(message, "^/copychat%s+all") or string.match(message, "^/chatcopy%s+all") then
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

	-- Command 2: /copychat [name] or /chatcopy [name]
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
	
	-- Command 3: /stopcopying
	if string.match(message, "^/stopcopying") then
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
	
	-- If /copychat all is active, auto-include players who join late
	if copyAllActive then
		targetsToCopy[player.Name] = true
	end
	
	player.Chatted:Connect(function(message)
		if isCopying and targetsToCopy[player.Name] then
			duplicateMessage(message)
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do watchOtherPlayers(p) end
Players.PlayerAdded:Connect(watchOtherPlayers)

-- Universal outgoing local hook to execute commands internally
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.SendingMessage:Connect(function(textChatMessage)
		handleChatCommands(textChatMessage.Text)
		-- Removed the status change so the message sends to the chat layout normally
	end)
else
	local chatBar = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Chat", 5)
	if chatBar then
		LocalPlayer.Chatted:Connect(handleChatCommands)
	else
		task.spawn(function()
			while task.wait(0.5) do
				local success = pcall(function()
					LocalPlayer.Chatted:Connect(handleChatCommands)
				end)
				if success then break end
			end
		end)
	end
end

-- Clean up tracking array when players leave the game
Players.PlayerRemoving:Connect(function(player)
	if targetsToCopy[player.Name] then
		targetsToCopy[player.Name] = nil
	end
end)
