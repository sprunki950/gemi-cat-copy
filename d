-- LocalScript inside StarterGui (or executed)
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- Setup State Variables
local isCopying = false
local copyAllActive = false
local targetsToCopy = {} -- Format: { ["Username"] = true }

-- Helper function to safely print tracking info directly to YOUR chat box
local function localChatLog(senderName, messageText)
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = string.format("[Copying %s]: %s", senderName, messageText),
			Color = Color3.fromRGB(85, 255, 127), -- Clean visible green neon tint
			Font = Enum.Font.GothamBold,
			TextSize = 14
		})
	end)
end

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
		end
		return true
	end
	
	-- Command 3: Execution reset rule
	if message == "/stopcopying" then
		isCopying = false
		copyAllActive = false
		table.clear(targetsToCopy)
		return true
	end
	return false
end

-- Hook into incoming messages from other players
local function watchOtherPlayers(player)
	if player == LocalPlayer then return end
	
	if copyAllActive then
		targetsToCopy[player.Name] = true
	end
	
	player.Chatted:Connect(function(message)
		if isCopying and targetsToCopy[player.Name] then
			-- Send copy tracking alert directly to your local screen feed
			localChatLog(player.DisplayName, message)
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
