-- LocalScript inside StarterGui (or executed)
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Safe PlayerGui fetching
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

-- Flexible game detection
local isFlingThingsAndPeople = (game.PlaceId == 10113110292) or (ReplicatedStorage:FindFirstChild("CharacterEvents") ~= nil)

-- ==========================================
-- AIMBOT ENGINE VARIABLES & INTERFACES
-- ==========================================
local aimbotEnabled = false
local aimbotLockActive = false
local aimbotTargetPlayer = nil
local aimbotHeartbeat = nil
local aimbotButtonFrame = nil
local selfGrabHookConnection = nil
local selfGrabTouchConnection = nil
local inputBeganConnection = nil
local inputEndedConnection = nil
local tButton = nil

local function disableAimbotEngine()
	aimbotEnabled = false
	aimbotLockActive = false
	aimbotTargetPlayer = nil
	if aimbotHeartbeat then aimbotHeartbeat:Disconnect() aimbotHeartbeat = nil end
	if selfGrabHookConnection then selfGrabHookConnection:Disconnect() selfGrabHookConnection = nil end
	if selfGrabTouchConnection then selfGrabTouchConnection:Disconnect() selfGrabTouchConnection = nil end
	if inputBeganConnection then inputBeganConnection:Disconnect() inputBeganConnection = nil end
	if inputEndedConnection then inputEndedConnection:Disconnect() inputEndedConnection = nil end
	if aimbotButtonFrame then aimbotButtonFrame:Destroy() aimbotButtonFrame = nil end
end

local function getClosestPlayer()
	local closest, dist = nil, math.huge
	local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not myHrp then return nil end
	
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local d = (p.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude
			if d < dist then
				dist = d
				closest = p
			end
		end
	end
	return closest
end

-- ==========================================
-- RE-EXECUTION CLEANUP HOOK
-- ==========================================
local ExistingGui = PlayerGui:FindFirstChild("IY_Style_CommandBar")
if ExistingGui then
	local existingCleanup = ExistingGui:FindFirstChild("CleanupTrigger")
	if existingCleanup then pcall(function() existingCleanup:Fire() end) end
	ExistingGui:Destroy()
	task.wait(0.1)
end

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

CleanupTrigger.Event:Connect(function()
	antiGrabEnabled = false
	infiniteJumpEnabled = false
	isCopying = false
	sittingOnTarget = false
	isSpinning = false
	isOrbiting = false
	clickTeleportActive = false
	isFlying = false
	noclipEnabled = false
	isManualAfk = false
	isAutoAfk = false
	disableAimbotEngine()
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

local CmdBar = Instance.new("Frame")
CmdBar.Name = "CmdBar"
CmdBar.Size = UDim2.new(0, 320, 0, 32)
CmdBar.Position = UDim2.new(0.5, -160, 1, 5)
CmdBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
CmdBar.BackgroundTransparency = 0.2
CmdBar.BorderSizePixel = 0
CmdBar.Parent = ScreenGui

local CmdCorner = Instance.new("UICorner")
CmdCorner.CornerRadius = UDim.new(0, 4)
CmdCorner.Parent = CmdBar

local CmdStroke = Instance.new("UIStroke")
CmdStroke.Thickness = 1
CmdStroke.Color = Color3.fromRGB(60, 60, 60)
CmdStroke.Parent = CmdBar

local TextBox = Instance.new("TextBox")
TextBox.Name = "TextBox"
TextBox.Size = UDim2.new(1, -10, 1, 0)
TextBox.Position = UDim2.new(0, 5, 0, 0)
TextBox.BackgroundTransparency = 1
TextBox.Text = ""
TextBox.PlaceholderText = "Command Bar (No Prefix)"
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
TextBox.TextSize = 16
TextBox.Font = Enum.Font.SourceSans
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = false
TextBox.Parent = CmdBar

local PredictionLabel = Instance.new("TextLabel")
PredictionLabel.Name = "PredictionLabel"
PredictionLabel.Size = UDim2.new(1, -10, 1, 0)
PredictionLabel.Position = UDim2.new(0, 5, 0, 0)
PredictionLabel.BackgroundTransparency = 1
PredictionLabel.Text = ""
PredictionLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
PredictionLabel.TextSize = 16
PredictionLabel.Font = Enum.Font.SourceSans
PredictionLabel.TextXAlignment = Enum.TextXAlignment.Left
PredictionLabel.ZIndex = 0
PredictionLabel.Parent = CmdBar

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
		local color3 = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = text,
			Color = color3,
			Font = Enum.Font.SourceSansBold,
			TextSize = 16
		})
	end)
end

local function notifyIY(text, isError)
	local prefix = isError and "[Error]: " or "[CMD]: "
	local hexColor = isError and "#FF5555" or "#EBEBEB"
	displayLocalSystemMessage(prefix .. text, hexColor)
end

local function localChatLog(senderName, messageText)
	displayLocalSystemMessage(string.format("[%s]: %s", senderName, messageText), "#AAFF7F")
end

local function displayCommandsList()
	local commandsText = [[--- Available Commands ---
• fov [1-120] - Adjust your Field of View
• afk / back - Toggles manual automated AFK state
• fly / unfly - Toggles responsive physics-based flight
• noclip / clip - Toggle stepping directly through solid frames
• enable aimbot - Attaches target locker (PC: Hold Right Click | Mobile: Screen Toggle Button)
• disable aimbot - Whitelists look mechanics and terminates trackers
• dontrespond / respond - Public confirmation outputs switch
• teleportclick - Shift positions directly to click targets
• spin / unspin - Initiates axial model loops
• orbit [player] / unorbit - Revolves directly around active player profiles
• headsit [player] - Teleports onto player heads in sit state
• tpto [player / random] - Offsets position closely behind targets
• chatcopy [player / all] - Chains public text mirror routines
• stopcopying / uncopychat - Drops current active copying lists
• cmds / commands - Displays this panel]]
	displayLocalSystemMessage(commandsText, "#FFD700")
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

-- ==========================================
-- PIPELINE HOOKS
-- ==========================================
local function sendPublicChatMessage(message)
	if silenceResponses then return end
	local textChannels = TextChatService:FindFirstChild("TextChannels")
	local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
	
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService or generalChannel then
		if generalChannel then 
			generalChannel:SendAsync(message) 
		else
			pcall(function()
				local textChannelsFolder = TextChatService:WaitForChild("TextChannels", 2)
				local channel = textChannelsFolder and textChannelsFolder:FindFirstChildOfClass("TextChannel")
				if channel then channel:SendAsync(message) end
			end)
		end
	else
		local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
		local sayMessage = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
		if sayMessage then 
			sayMessage:FireServer(message, "All") 
		else
			game:GetService("Players"):Chat(message)
		end
	end
end

local function enableAntiGrabMechanic()
	if not isFlingThingsAndPeople then return end
	if antiGrabEnabled then return end
	antiGrabEnabled = true
	pcall(function()
		local CharacterEvents = ReplicatedStorage:WaitForChild("CharacterEvents", 2)
		local Struggle = CharacterEvents and CharacterEvents:WaitForChild("Struggle", 2)
		local GameCorrectionEvents = ReplicatedStorage:WaitForChild("GameCorrectionEvents", 2)
		local StopAllVelocity = GameCorrectionEvents and GameCorrectionEvents:WaitForChild("StopAllVelocity", 2)
		
		if Struggle and StopAllVelocity then
			autoStruggleCoroutine = RunService.Heartbeat:Connect(function()
				if not antiGrabEnabled then return end
				local character = LocalPlayer.Character
				if character and character:FindFirstChild("Head") then
					local head = character.Head
					if head:FindFirstChild("PartOwner") then
						Struggle:FireServer()
						StopAllVelocity:FireServer()
						for _, part in pairs(character:GetChildren()) do
							if part:IsA("BasePart") then part.Anchored = true end
						end
						local isHeldVal = LocalPlayer:FindFirstChild("IsHeld")
						while isHeldVal and isHeldVal.Value and antiGrabEnabled do task.wait() end
						for _, part in pairs(character:GetChildren()) do
							if part:IsA("BasePart") then part.Anchored = false end
						end
					end
				end
			end)
		end
	end)
end

local function disableAntiGrabMechanic()
	if not antiGrabEnabled then return end
	antiGrabEnabled = false
	if autoStruggleCoroutine then autoStruggleCoroutine:Disconnect() end
	pcall(function()
		local character = LocalPlayer.Character
		if character then
			for _, part in pairs(character:GetChildren()) do
				if part:IsA("BasePart") then part.Anchored = false end
			end
		end
	end)
end

-- ==========================================
-- COMMAND PROCESSING ENGINE
-- ==========================================
local validCommands = {"fov", "afk", "back", "fly", "unfly", "noclip", "clip", "enable aimbot", "disable aimbot", "dontrespond", "respond", "teleportclick", "spin", "unspin", "orbit", "unorbit", "headsit", "tpto", "chatcopy", "copychat", "stopcopying", "uncopychat", "enable infjump", "disable infjump", "enable antigrab", "disable antigrab", "cmds", "commands"}

local function runCommand(message)
	message = string.gsub(message, "^%s+", "")
	message = string.gsub(message, "%s+$", "")
	local lowerMessage = string.lower(message)
	
	local args = string.split(message, " ")
	local baseCmd = string.lower(args[1] or "")
	local targetArg = args[2] and string.lower(args[2]) or nil

	if baseCmd == "fov" then
		local fovValue = tonumber(targetArg)
		if fovValue and fovValue >= 1 and fovValue <= 120 then
			Workspace.CurrentCamera.FieldOfView = fovValue
			sendPublicChatMessage("Changed FOV to " .. tostring(fovValue))
		else notifyIY("Usage: fov [1-120]", true) end
		return true
	end

	if baseCmd == "afk" then
		if isManualAfk then return true end
		if isAutoAfk then isAutoAfk = false if autoAfkLoopThread then task.cancel(autoAfkLoopThread) autoAfkLoopThread = nil end end
		isManualAfk = true
		sendPublicChatMessage("Goodbye, see you later!")
		if isFlingThingsAndPeople then enableAntiGrabMechanic() end
		if manualAfkLoopThread then task.cancel(manualAfkLoopThread) end
		manualAfkLoopThread = task.spawn(function()
			while isManualAfk do
				task.wait(30)
				if isManualAfk then sendPublicChatMessage("Im afk, ill be back (automated message from script)") end
			end
		end)
		return true
	end

	if baseCmd == "back" then
		if isManualAfk then
			isManualAfk = false
			if manualAfkLoopThread then task.cancel(manualAfkLoopThread) manualAfkLoopThread = nil end
			if isFlingThingsAndPeople then disableAntiGrabMechanic() end
			sendPublicChatMessage("Welcome back!")
		end
		return true
	end

	if baseCmd == "fly" then
		if isFlying then return true end
		isFlying = true
		sendPublicChatMessage("Enabled fly")
		if flyHeartbeat then flyHeartbeat:Disconnect() end
		
		flyHeartbeat = RunService.Heartbeat:Connect(function()
			if not isFlying then return end
			local character = LocalPlayer.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			
			if hrp and humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Flying)
				local lookVector = camera.CFrame.LookVector
				local rightVector = camera.CFrame.RightVector
				local flyVelocity = Vector3.new(0, 0, 0)
				
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyVelocity = flyVelocity + lookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyVelocity = flyVelocity - lookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyVelocity = flyVelocity + rightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyVelocity = flyVelocity - rightVector end
				
				if flyVelocity.Magnitude == 0 and humanoid.MoveDirection.Magnitude > 0 then
					flyVelocity = camera.CFrame:VectorToWorldSpace(Vector3.new(
						UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or (UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0),
						0,
						UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or (UserInputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0)
					))
				end
				
				if flyVelocity.Magnitude > 0 then flyVelocity = flyVelocity.Unit * flySpeed end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyVelocity = flyVelocity + Vector3.new(0, flySpeed, 0)
				elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyVelocity = flyVelocity - Vector3.new(0, flySpeed, 0) end
				
				hrp.AssemblyLinearVelocity = flyVelocity
				hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookVector)
			end
		end)
		return true
	end

	if baseCmd == "unfly" then
		if isFlying then
			isFlying = false
			if flyHeartbeat then flyHeartbeat:Disconnect() end
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
			sendPublicChatMessage("Disabled fly")
		end
		return true
	end

	if baseCmd == "noclip" then
		if noclipEnabled then return true end
		noclipEnabled = true
		sendPublicChatMessage("Enabled noclip")
		if noclipConnection then noclipConnection:Disconnect() end
		noclipConnection = RunService.Stepped:Connect(function()
			if not noclipEnabled then return end
			local character = LocalPlayer.Character
			if character then
				for _, part in pairs(character:GetChildren()) do
					if part:IsA("BasePart") then part.CanCollide = false end
				end
			end
		end)
		return true
	end

	if baseCmd == "clip" then
		if noclipEnabled then
			noclipEnabled = false
			if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
			sendPublicChatMessage("Disabled noclip")
		end
		return true
	end

	if string.sub(lowerMessage, 1, 14) == "enable aimbot" then
		disableAimbotEngine()
		local targetPlayer = getClosestPlayer()
		if not targetPlayer then notifyIY("No target players nearby.", true) return true end
		
		aimbotEnabled = true
		aimbotTargetPlayer = targetPlayer
		
		-- CLICK-AND-HOLD CONFIGURATION
		if IsPC then
			sendPublicChatMessage("Aimbot dynamic tracker active. Target: " .. targetPlayer.DisplayName .. " [Hold Right Click]")
			
			inputBeganConnection = UserInputService.InputBegan:Connect(function(input, processed)
				if processed or UserInputService:GetFocusedTextBox() then return end
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					aimbotLockActive = true
				end
			end)
			
			inputEndedConnection = UserInputService.InputEnded:Connect(function(input, processed)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					aimbotLockActive = false
				end
			end)
		else
			-- Fallback to Screen Toggle Button if Mobile
			sendPublicChatMessage("Aimbot tracking active. Target: " .. targetPlayer.DisplayName .. " [Mobile Toggle Enabled]")
			
			aimbotButtonFrame = Instance.new("Frame")
			aimbotButtonFrame.Name = "AimbotToggleContainer"
			aimbotButtonFrame.Size = UDim2.new(0, 70, 0, 35)
			
			local mobileGui = PlayerGui:FindFirstChild("TouchGui")
			local touchFrame = mobileGui and mobileGui:FindFirstChild("TouchControlFrame")
			local jumpButton = touchFrame and touchFrame:FindFirstChild("JumpButton")
			
			if jumpButton then
				aimbotButtonFrame.Position = UDim2.new(
					jumpButton.Position.X.Scale, 
					jumpButton.Position.X.Offset + (jumpButton.Size.X.Offset / 2) - 35, 
					jumpButton.Position.Y.Scale, 
					jumpButton.Position.Y.Offset - 110
				)
				aimbotButtonFrame.Parent = touchFrame
			else
				aimbotButtonFrame.Position = UDim2.new(1, -160, 1, -240)
				aimbotButtonFrame.Parent = ScreenGui
			end
			
			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 6)
			bCorner.Parent = aimbotButtonFrame
			
			tButton = Instance.new("TextButton")
			tButton.Name = "LockToggle"
			tButton.Size = UDim2.new(1, 0, 1, 0)
			tButton.BackgroundTransparency = 0.3
			tButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
			tButton.Text = "LOCK"
			tButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			tButton.Font = Enum.Font.SourceSansBold
			tButton.TextSize = 14
			tButton.Parent = aimbotButtonFrame
			
			tButton.MouseButton1Click:Connect(function()
				aimbotLockActive = not aimbotLockActive
				if tButton then
					tButton.BackgroundColor3 = aimbotLockActive and Color3.fromRGB(40, 180, 40) or Color3.fromRGB(180, 40, 40)
					tButton.Text = aimbotLockActive and "UNLOCK" or "LOCK"
				end
			end)
		end
		
		aimbotHeartbeat = RunService.RenderStepped:Connect(function()
			if not aimbotEnabled then return end
			local activeNearest = getClosestPlayer()
			if activeNearest then aimbotTargetPlayer = activeNearest end
			
			-- DYNAMIC SCREEN OBJECT/COLOR RECOGNITION SENSOR
			if aimbotLockActive then
				local grabGui = PlayerGui:FindFirstChild("GrabGui") or PlayerGui:FindFirstChild("MobileGrabGui") or PlayerGui:FindFirstChild("MainGui")
				if grabGui then
					for _, element in ipairs(grabGui:GetDescendants()) do
						if element:IsA("ImageLabel") or element:IsA("Frame") or element:IsA("TextButton") then
							if element.Visible and element.BackgroundColor3 == Color3.fromRGB(0, 162, 255) then
								aimbotLockActive = false
								if tButton then
									tButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
									tButton.Text = "LOCK"
								end
								notifyIY("Aimbot unlocked: Interface color state matched.", false)
								break
							end
						end
					end
				end
			end
			
			if not aimbotLockActive or not aimbotTargetPlayer then return end
			
			local character = aimbotTargetPlayer.Character
			local targetPart = character and (character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso"))
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			
			if targetPart and humanoid and humanoid.Health > 0 then
				camera.CFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
			else
				aimbotLockActive = false
				if tButton then
					tButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
					tButton.Text = "LOCK"
				end
			end
		end)
		return true
	end
	
	if lowerMessage == "disable aimbot" then
		if aimbotEnabled then disableAimbotEngine() sendPublicChatMessage("Disabled aimbot engine") end
		return true
	end

	if baseCmd == "dontrespond" then silenceResponses = true notifyIY("Command log muted.", false) return true end
	if baseCmd == "respond" then silenceResponses = false notifyIY("Command log unmuted.", false) sendPublicChatMessage("Enabled public responses") return true end

	if baseCmd == "teleportclick" then
		if clickTeleportActive then return true end
		clickTeleportActive = true
		sendPublicChatMessage("Enabled teleport click")
		if clickConnection then clickConnection:Disconnect() end
		if stopButtonFrame then stopButtonFrame:Destroy() end

		stopButtonFrame = Instance.new("Frame")
		stopButtonFrame.Size = UDim2.new(0, 140, 0, 35)
		stopButtonFrame.Position = UDim2.new(0.5, -70, 0.05, 0)
		stopButtonFrame.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		stopButtonFrame.BorderSizePixel = 0
		stopButtonFrame.Parent = ScreenGui

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = stopButtonFrame

		local stopButton = Instance.new("TextButton")
		stopButton.Size = UDim2.new(1, 0, 1, 0)
		stopButton.BackgroundTransparency = 1
		stopButton.Text = "Stop Teleport"
		stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		stopButton.Font = Enum.Font.SourceSansBold
		stopButton.TextSize = 14
		stopButton.Parent = stopButtonFrame

		stopButton.MouseButton1Click:Connect(function()
			clickTeleportActive = false
			if clickConnection then clickConnection:Disconnect() end
			if stopButtonFrame then stopButtonFrame:Destroy() end
			sendPublicChatMessage("Disabled teleport click")
		end)

		local mouse = LocalPlayer:GetMouse()
		clickConnection = mouse.Button1Down:Connect(function()
			if not clickTeleportActive or UserInputService:GetFocusedTextBox() then return end
			if mouse.Target and (mouse.Target:IsA("ClickDetector") or mouse.Target:FindFirstChildOfClass("ClickDetector")) then return end
			local startPos = UserInputService:GetMouseLocation()
			task.wait(0.08)
			if (startPos - UserInputService:GetMouseLocation()).Magnitude > 4 then return end
			local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp and mouse.Target then hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end
		end)
		return true
	end

	if baseCmd == "spin" then
		if isSpinning then return true end
		isSpinning = true
		sendPublicChatMessage("Enabled spin")
		local currentAngle = 0
		spinHeartbeat = RunService.Heartbeat:Connect(function(deltaTime)
			local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp and isSpinning then currentAngle = currentAngle + (360 * deltaTime) hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(currentAngle), 0) end
		end)
		return true
	end

	if baseCmd == "unspin" then if isSpinning then isSpinning = false if spinHeartbeat then spinHeartbeat:Disconnect() end sendPublicChatMessage("Disabled spin") end return true end

	if baseCmd == "orbit" then
		if not targetArg then notifyIY("Usage: orbit [player]", true) return true end
		local targetPlayer = findPlayerByPartialName(string.sub(message, string.len(args[1]) + 2))
		if not targetPlayer then notifyIY("Player not found.", true) return true end
		if orbitHeartbeat then orbitHeartbeat:Disconnect() end
		isOrbiting, orbitAngle = true, 0
		sendPublicChatMessage("Orbiting " .. targetPlayer.DisplayName)

		orbitHeartbeat = RunService.Heartbeat:Connect(function(deltaTime)
			local localHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local targetHRP = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			if isOrbiting and localHRP and targetHRP then
				orbitAngle = orbitAngle + (120 * deltaTime)
				local offset = Vector3.new(math.cos(math.rad(orbitAngle)) * 6, 1, math.sin(math.rad(orbitAngle)) * 6)
				localHRP.CFrame = CFrame.new(targetHRP.Position + offset, targetHRP.Position)
				localHRP.AssemblyLinearVelocity = Vector3.new(0,0,0)
			else isOrbiting = false if orbitHeartbeat then orbitHeartbeat:Disconnect() end sendPublicChatMessage("Stopped orbiting") end
		end)
		return true
	end

	if baseCmd == "unorbit" then if isOrbiting then isOrbiting = false if orbitHeartbeat then orbitHeartbeat:Disconnect() end sendPublicChatMessage("Disabled orbit") end return true end

	if baseCmd == "headsit" then
		if not targetArg then notifyIY("Usage: headsit [player]", true) return true end
		local targetPlayer = findPlayerByPartialName(string.sub(message, string.len(args[1]) + 2))
		if not targetPlayer then notifyIY("Player not found.", true) return true end
		if sitHeartbeat then sitHeartbeat:Disconnect() end
		if sitJumpHook then sitJumpHook:Disconnect() end
		sittingOnTarget = true
		sendPublicChatMessage("Headsitting " .. targetPlayer.DisplayName)

		sitJumpHook = UserInputService.JumpRequest:Connect(function()
			sittingOnTarget = false if sitHeartbeat then sitHeartbeat:Disconnect() end if sitJumpHook then sitJumpHook:Disconnect() end
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Sit = false hum:ChangeState(Enum.HumanoidStateType.Jumping) end
			sendPublicChatMessage("Stopped headsitting")
		end)

		sitHeartbeat = RunService.Heartbeat:Connect(function()
			local localHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local targetHRP = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if sittingOnTarget and localHRP and targetHRP and hum then
				hum.Sit = true localHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 1.5, 0) localHRP.AssemblyLinearVelocity = Vector3.new(0,0,0)
			else sittingOnTarget = false if sitHeartbeat then sitHeartbeat:Disconnect() end if sitJumpHook then sitJumpHook:Disconnect() end end
		end)
		return true
	end

	if baseCmd == "tpto" then
		if not targetArg then notifyIY("Usage: tpto [player / random]", true) return true end
		local targetPlayer = nil
		if targetArg == "random" then
			local pool = {}
			for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then table.insert(pool, p) end end
			if #pool > 0 then targetPlayer = pool[math.random(1, #pool)] else notifyIY("No players found.", true) return true end
		else
			targetPlayer = findPlayerByPartialName(string.sub(message, string.len(args[1]) + 2))
			if not targetPlayer then notifyIY("Player not found.", true) return true end
		end
		local tHrp = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if tHrp and myHrp then myHrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3) sendPublicChatMessage("Teleporting to " .. targetPlayer.DisplayName) end
		return true
	end

	if baseCmd == "chatcopy" or baseCmd == "copychat" then
		if targetArg == "all" then
			copyAllActive, isCopying = true, true table.clear(targetsToCopy)
			for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then targetsToCopy[p.Name] = true end end
			sendPublicChatMessage("Copying everyone's chat")
		elseif targetArg then
			local t = findPlayerByPartialName(string.sub(message, string.len(args[1]) + 2))
			if t then
				copyAllActive = false targetsToCopy[t.Name] = true isCopying = true
				lastTargetName, lastTargetDisplayName = t.Name, t.DisplayName
				sendPublicChatMessage("Copying " .. t.DisplayName .. "'s chat")
			else notifyIY("Player not found.", true) end
		else notifyIY("Usage: chatcopy [player / all]", true) end
		return true
	end
	
	if baseCmd == "stopcopying" or baseCmd == "uncopychat" then
		isCopying, copyAllActive = false, false table.clear(targetsToCopy)
		sendPublicChatMessage(lastTargetDisplayName ~= "" and "Stopped copying " .. lastTargetDisplayName .. "'s chat" or "Stopped copying chat")
		lastTargetName, lastTargetDisplayName = "", ""
		return true
	end

	if lowerMessage == "enable infjump" then
		if not infiniteJumpEnabled then
			infiniteJumpEnabled = true
			jumpConnection = UserInputService.JumpRequest:Connect(function()
				local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				if infiniteJumpEnabled and hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
			end)
			sendPublicChatMessage("Enabled infinite jump")
		end
		return true
	end

	if lowerMessage == "disable infjump" then if infiniteJumpEnabled then infiniteJumpEnabled = false if jumpConnection then jumpConnection:Disconnect() end sendPublicChatMessage("Disabled infinite jump") end return true end
	if lowerMessage == "enable antigrab" then enableAntiGrabMechanic() if isFlingThingsAndPeople then sendPublicChatMessage("Enabled anti-grab") end return true end
	if lowerMessage == "disable antigrab" then disableAntiGrabMechanic() sendPublicChatMessage("Disabled anti-grab") return true end
	if baseCmd == "cmds" or baseCmd == "commands" then displayCommandsList() return true end
	return false
end

-- ==========================================
-- INACTIVITY AUTOMATION LOOP
-- ==========================================
local function registerActivity()
	lastInputTime = os.clock()
	if isAutoAfk then
		isAutoAfk = false
		if autoAfkLoopThread then task.cancel(autoAfkLoopThread) autoAfkLoopThread = nil end
		if isFlingThingsAndPeople then disableAntiGrabMechanic() end
		sendPublicChatMessage("back")
	end
end

trackConnection(UserInputService.InputBegan:Connect(function(input, processed) if processed and UserInputService:GetFocusedTextBox() then return end registerActivity() end))
trackConnection(UserInputService.TouchPan:Connect(registerActivity))
trackConnection(UserInputService.TouchTap:Connect(registerActivity))
trackConnection(UserInputService.PointerAction:Connect(registerActivity))

trackConnection(RunService.Heartbeat:Connect(function()
	if not isManualAfk and not isAutoAfk then
		if os.clock() - lastInputTime >= INACTIVITY_THRESHOLD then
			isAutoAfk = true
			sendPublicChatMessage("Im afk (automated msg from script)")
			if isFlingThingsAndPeople then enableAntiGrabMechanic() end
			if autoAfkLoopThread then task.cancel(autoAfkLoopThread) end
			autoAfkLoopThread = task.spawn(function()
				while isAutoAfk do task.wait(30) if isAutoAfk then sendPublicChatMessage("Im afk, ill be back (automated message from script)") end end
			end)
		end
	end
end))

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
		task.defer(function() if TextBox.Text == ":" then TextBox.Text = "" end end)
	else
		TextBox:ReleaseFocus() TextBox.Text = "" PredictionLabel.Text = ""
	end
end

trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed) if input.KeyCode == Enum.KeyCode.Colon then toggleCmdBar(not barOpen) end end))

if IsMobile then
	local MobileBtn = Instance.new("TextButton")
	MobileBtn.Size = UDim2.new(0, 50, 0, 30)
	MobileBtn.Position = UDim2.new(0.05, 0, 0.35, 0)
	MobileBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	MobileBtn.BackgroundTransparency = 0.2
	MobileBtn.Text = "CMD"
	MobileBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
	MobileBtn.Font = Enum.Font.SourceSansBold
	MobileBtn.TextSize = 14
	MobileBtn.Parent = ScreenGui

	local BtnCorner = Instance.new("UICorner")
	BtnCorner.CornerRadius = UDim.new(0, 4)
	BtnCorner.Parent = MobileBtn

	local BtnStroke = Instance.new("UIStroke")
	BtnStroke.Thickness = 1
	BtnStroke.Color = Color3.fromRGB(80, 80, 80)
	BtnStroke.Parent = MobileBtn

	MobileBtn.MouseButton1Click:Connect(function() toggleCmdBar(not barOpen) end)
	local dragToggle, dragStart, startPos = nil, nil, nil

	MobileBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then dragToggle = true dragStart = input.Position startPos = MobileBtn.Position end end)
	MobileBtn.InputChanged:Connect(function(input) if dragToggle and input.UserInputType == Enum.UserInputType.Touch then local delta = input.Position - dragStart MobileBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
	MobileBtn.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then dragToggle = false end end)
end

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

task.spawn(function()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		trackConnection(TextChatService.SendingMessage:Connect(function(textChatMessage) runCommand(textChatMessage.Text) end))
	else
		local chatBar = nil pcall(function() chatBar = PlayerGui:WaitForChild("Chat", 4) end)
		trackConnection(LocalPlayer.Chatted:Connect(runCommand))
	end
end)

local function watchOtherPlayers(player)
	if player == LocalPlayer then return end
	if copyAllActive then targetsToCopy[player.Name] = true end
	trackConnection(player.Chatted:Connect(function(message) if isCopying and targetsToCopy[player.Name] then localChatLog(player.DisplayName, message) sendPublicChatMessage(message) end end))
end

for _, p in ipairs(Players:GetPlayers()) do watchOtherPlayers(p) end
trackConnection(Players.PlayerAdded:Connect(watchOtherPlayers))
trackConnection(Players.PlayerRemoving:Connect(function(player) if targetsToCopy[player.Name] then targetsToCopy[player.Name] = nil end end))

notifyIY("Engine initialization complete. Command bar ready.", false)
