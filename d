-- LocalScript inside StarterGui (or executed)
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

local isFlingThingsAndPeople = (game.PlaceId == 10113110292) or (ReplicatedStorage:FindFirstChild("CharacterEvents") ~= nil)

-- ==========================================
-- STATE VARIABLES & ENGINES
-- ==========================================
local isCopying = false
local copyAllActive = false
local targetsToCopy = {}
local lastTargetName = "" 
local lastTargetDisplayName = "" 
local barOpen = false
local silenceResponses = false

local aimbotEnabled = false
local aimbotLockActive = false
local aimbotTargetPlayer = nil
local aimbotHeartbeat = nil
local aimbotButtonFrame = nil
local inputBeganConnection = nil
local inputEndedConnection = nil

local activeConnections = {}
local function trackConnection(conn)
	table.insert(activeConnections, conn)
	return conn
end

local infiniteJumpEnabled = false
local jumpConnection = nil
local antiGrabEnabled = false
local autoStruggleCoroutine = nil
local sittingOnTarget = false
local sitHeartbeat = nil
local sitJumpHook = nil
local isSpinning = false
local spinHeartbeat = nil
local isOrbiting = false
local orbitHeartbeat = nil
local orbitAngle = 0
local clickTeleportActive = false
local clickConnection = nil
local stopButtonFrame = nil
local flyHeartbeat = nil
local flySpeed = 50
local isFlying = false
local noclipEnabled = false
local noclipConnection = nil
local isManualAfk = false
local manualAfkLoopThread = nil
local isAutoAfk = false
local lastInputTime = os.clock()
local INACTIVITY_THRESHOLD = 20 
local autoAfkLoopThread = nil

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local IsPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled

-- ==========================================
-- INITIALIZE INFINITE YIELD-STYLE GUI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IY_Style_CommandBar"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local CleanupTrigger = Instance.new("BindableEvent")
CleanupTrigger.Name = "CleanupTrigger"
CleanupTrigger.Parent = ScreenGui

local function disableAimbotEngine()
	aimbotEnabled = false; aimbotLockActive = false; aimbotTargetPlayer = nil
	if aimbotHeartbeat then aimbotHeartbeat:Disconnect() aimbotHeartbeat = nil end
	if inputBeganConnection then inputBeganConnection:Disconnect() inputBeganConnection = nil end
	if inputEndedConnection then inputEndedConnection:Disconnect() inputEndedConnection = nil end
	if aimbotButtonFrame then aimbotButtonFrame:Destroy() aimbotButtonFrame = nil end
end

CleanupTrigger.Event:Connect(function()
	antiGrabEnabled = false; infiniteJumpEnabled = false; isCopying = false; sittingOnTarget = false
	isSpinning = false; isOrbiting = false; clickTeleportActive = false; isFlying = false; noclipEnabled = false
	isManualAfk = false; isAutoAfk = false; disableAimbotEngine()
	pcall(function() ContextActionService:UnbindAction("ToggleCommandBarAction") end)
	if manualAfkLoopThread then task.cancel(manualAfkLoopThread) end
	if autoAfkLoopThread then task.cancel(autoAfkLoopThread) end
	if autoStruggleCoroutine then autoStruggleCoroutine:Disconnect() end
	if jumpConnection then jumpConnection:Disconnect() end
	if sitHeartbeat then sitHeartbeat:Disconnect() end
	if sitJumpHook then sitJumpHook:Disconnect() end
	if spinHeartbeat then spinHeartbeat:Disconnect() end
	if orbitHeartbeat then orbitHeartbeat:Disconnect() end
	if clickConnection then clickConnection:Disconnect() end
	if stopButtonFrame then stopButtonFrame:Destroy() end
	if flyHeartbeat then flyHeartbeat:Disconnect() end
	if noclipConnection then noclipConnection:Disconnect() end
	for _, conn in ipairs(activeConnections) do if conn then conn:Disconnect() end end
end)

local ExistingGui = PlayerGui:FindFirstChild("IY_Style_CommandBar")
if ExistingGui then
	local existingCleanup = ExistingGui:FindFirstChild("CleanupTrigger")
	if existingCleanup then pcall(function() existingCleanup:Fire() end) end
	ExistingGui:Destroy()
	task.wait(0.1)
end

local CmdBar = Instance.new("Frame")
CmdBar.Name = "CmdBar"; CmdBar.Size = UDim2.new(0, 320, 0, 32); CmdBar.Position = UDim2.new(0.5, -160, 1, 5)
CmdBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25); CmdBar.BackgroundTransparency = 0.2; CmdBar.BorderSizePixel = 0; CmdBar.Parent = ScreenGui

local CmdCorner = Instance.new("UICorner"); CmdCorner.CornerRadius = UDim.new(0, 4); CmdCorner.Parent = CmdBar
local CmdStroke = Instance.new("UIStroke"); CmdStroke.Thickness = 1; CmdStroke.Color = Color3.fromRGB(60, 60, 60); CmdStroke.Parent = CmdBar

local TextBox = Instance.new("TextBox")
TextBox.Name = "TextBox"; TextBox.Size = UDim2.new(1, -10, 1, 0); TextBox.Position = UDim2.new(0, 5, 0, 0)
TextBox.BackgroundTransparency = 1; TextBox.Text = ""; TextBox.PlaceholderText = "Command Bar (No Prefix)"
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255); TextBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
TextBox.TextSize = 16; TextBox.Font = Enum.Font.SourceSans; TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = false; TextBox.Parent = CmdBar

local PredictionLabel = Instance.new("TextLabel")
PredictionLabel.Name = "PredictionLabel"; PredictionLabel.Size = UDim2.new(1, -10, 1, 0); PredictionLabel.Position = UDim2.new(0, 5, 0, 0)
PredictionLabel.BackgroundTransparency = 1; PredictionLabel.Text = ""; PredictionLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
PredictionLabel.TextSize = 16; PredictionLabel.Font = Enum.Font.SourceSans; PredictionLabel.TextXAlignment = Enum.TextXAlignment.Left
PredictionLabel.ZIndex = 0; PredictionLabel.Parent = CmdBar

-- ==========================================
-- UNIVERSAL NOTIFICATION UTILITIES
-- ==========================================
local function displayLocalSystemMessage(text, colorHex)
	colorHex = colorHex or "#EBEBEB"
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local textChannels = TextChatService:FindFirstChild("TextChannels")
		local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
		if generalChannel then
			generalChannel:DisplaySystemMessage(string.format("<font color='%s'><b>%s</b></font>", colorHex, text))
			return
		end
	end
	pcall(function()
		local r, g, b = string.match(colorHex, "#(%x%x)(%x%x)(%x%x)")
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = text,
			Color = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)),
			Font = Enum.Font.SourceSansBold, TextSize = 16
		})
	end)
end

local function notifyIY(text, isError)
	local prefix = isError and "[Error]: " or "[CMD]: "
	displayLocalSystemMessage(prefix .. text, isError and "#FF5555" or "#EBEBEB")
end

local function localChatLog(senderName, messageText)
	displayLocalSystemMessage(string.format("[%s]: %s", senderName, messageText), "#AAFF7F")
end

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

local function sendPublicChatMessage(message)
	if silenceResponses then return end
	local textChannels = TextChatService:FindFirstChild("TextChannels")
	local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
	if generalChannel then 
		generalChannel:SendAsync(message) 
	else
		local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		local sayMessage = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
		if sayMessage then sayMessage:FireServer(message, "All") else Players:Chat(message) end
	end
end

-- ==========================================
-- COMMAND PROCESSING ENGINE
-- ==========================================
local validCommands = {"fov", "afk", "back", "fly", "unfly", "noclip", "clip", "enable aimbot", "disable aimbot", "dontrespond", "respond", "teleportclick", "spin", "unspin", "orbit", "unorbit", "headsit", "tpto", "chatcopy", "copychat", "stopcopying", "uncopychat", "enable infjump", "disable infjump", "enable antigrab", "disable antigrab", "cmds", "commands"}

local function runCommand(message)
	message = string.gsub(message, "^%s+", ""):gsub("%s+$", "")
	local lowerMessage = string.lower(message)
	local args = string.split(message, " ")
	local baseCmd = string.lower(args[1] or "")
	local targetArg = args[2] and string.lower(args[2]) or nil

	if baseCmd == "chatcopy" or baseCmd == "copychat" then
		if targetArg == "all" then
			copyAllActive = true; isCopying = true; table.clear(targetsToCopy)
			for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then targetsToCopy[p.Name] = true end end
			notifyIY("Copying everyone's chat.", false)
			sendPublicChatMessage("Copying everyone's chat")
		elseif targetArg then
			local matchedStr = string.sub(message, string.len(args[1]) + 2)
			local t = findPlayerByPartialName(matchedStr)
			if t then
				copyAllActive = false; targetsToCopy[t.Name] = true; isCopying = true
				lastTargetName, lastTargetDisplayName = t.Name, t.DisplayName
				notifyIY("Now copying chat from: " .. t.DisplayName, false)
				sendPublicChatMessage("Copying " .. t.DisplayName .. "'s chat")
			else 
				notifyIY("Player matching '" .. matchedStr .. "' not found.", true) 
			end
		else 
			notifyIY("Usage: chatcopy [player / all]", true) 
		end
		return true
	end
	
	if baseCmd == "stopcopying" or baseCmd == "uncopychat" then
		isCopying = false; copyAllActive = false; table.clear(targetsToCopy)
		notifyIY("Stopped chatcopy engines.", false)
		sendPublicChatMessage(lastTargetDisplayName ~= "" and "Stopped copying " .. lastTargetDisplayName .. "'s chat" or "Stopped copying chat")
		lastTargetName, lastTargetDisplayName = "", ""
		return true
	end

	-- Quick fallback implementations for other commands
	if baseCmd == "fov" then
		local fovValue = tonumber(targetArg)
		if fovValue and fovValue >= 1 and fovValue <= 120 then Workspace.CurrentCamera.FieldOfView = fovValue sendPublicChatMessage("Changed FOV to " .. tostring(fovValue)) end
		return true
	end
	if baseCmd == "fly" then isFlying = true; notifyIY("Fly enabled", false) return true end
	if baseCmd == "unfly" then isFlying = false; notifyIY("Fly disabled", false) return true end
	if baseCmd == "noclip" then noclipEnabled = true; notifyIY("Noclip enabled", false) return true end
	if baseCmd == "clip" then noclipEnabled = false; notifyIY("Noclip disabled", false) return true end
	if baseCmd == "cmds" or baseCmd == "commands" then displayLocalSystemMessage("Commands: fov, afk, back, fly, unfly, noclip, clip, chatcopy [user/all], stopcopying", "#FFD700") return true end
	return false
end

-- ==========================================
-- FIXED PC CHAT SENSOR COMPATIBILITY HOOK
-- ==========================================
local function hookPlayerChat(player)
	if player == LocalPlayer then return end
	
	-- Legacy / Generic Compatibility Engine
	trackConnection(player.Chatted:Connect(function(message)
		if isCopying and targetsToCopy[player.Name] then
			localChatLog(player.DisplayName, message)
			sendPublicChatMessage(message)
		end
	end))
end

-- TextChatService Direct Pipeline Hook (Ensures accurate processing in 2026 systems)
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	trackConnection(TextChatService.MessageReceived:Connect(function(textChatMessage)
		local textSource = textChatMessage.TextSource
		if not textSource then return end
		local sender = Players:GetPlayerByUserId(textSource.UserId)
		
		if sender and sender ~= LocalPlayer then
			if isCopying and targetsToCopy[sender.Name] then
				localChatLog(sender.DisplayName, textChatMessage.Text)
				sendPublicChatMessage(textChatMessage.Text)
			end
		end
	end))
end

-- Initialize listeners across active entities
for _, p in ipairs(Players:GetPlayers()) do hookPlayerChat(p) end
trackConnection(Players.PlayerAdded:Connect(function(p)
	hookPlayerChat(p)
	if copyAllActive then targetsToCopy[p.Name] = true end
end))
trackConnection(Players.PlayerRemoving:Connect(function(p) targetsToCopy[p.Name] = nil end))

-- ==========================================
-- INTERACTIVE GUI ANIMATIONS & INPUT
-- ==========================================
local function toggleCmdBar(open)
	barOpen = open
	local targetYOffset = IsMobile and -120 or -50
	local targetPos = open and UDim2.new(0.5, -160, 1, targetYOffset) or UDim2.new(0.5, -160, 1, 5)
	
	TweenService:Create(CmdBar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
	
	if open then
		TextBox:CaptureFocus()
		task.spawn(function()
			RunService.RenderStepped:Wait()
			if TextBox.Text == "m" or TextBox.Text == "M" then TextBox.Text = "" end
		end)
	else
		TextBox:ReleaseFocus(); TextBox.Text = ""; PredictionLabel.Text = ""
	end
end

local function handleBindAction(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		toggleCmdBar(not barOpen)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

pcall(function() ContextActionService:UnbindAction("ToggleCommandBarAction") end)
ContextActionService:BindAction("ToggleCommandBarAction", handleBindAction, false, Enum.KeyCode.M)

TextBox.Changed:Connect(function(prop)
	if prop == "Text" then
		local text = TextBox.Text
		if text == "" then PredictionLabel.Text = "" return end
		local match = ""
		for _, cmd in ipairs(validCommands) do if string.sub(cmd, 1, string.len(text)) == string.lower(text) then match = cmd break end end
		PredictionLabel.Text = match
	end
end)

TextBox.FocusLost:Connect(function(enterPressed) if enterPressed and TextBox.Text ~= "" then runCommand(TextBox.Text) end toggleCmdBar(false) end)

notifyIY("Engine initialization complete. Use 'chatcopy [username]' or 'chatcopy all'.", false)
