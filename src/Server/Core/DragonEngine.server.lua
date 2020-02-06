--[[
	Dragon Engine Server

	Handles the server sided aspects for the framework, including services.
--]]

---------------------
-- Roblox Services --
---------------------
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")

--------------
-- REQUIRES --
--------------
local DragonEngine=require(ReplicatedStorage.DragonEngine.EngineCore)
local ENGINE_LOGO=require(ReplicatedStorage.DragonEngine.Logo)
local Boilerplate=require(ReplicatedStorage.DragonEngine.Boilerplate)

-------------
-- DEFINES --
-------------
DragonEngine.Services={} --Contains all services, both running and stopped

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------
-- DEFINES --
-------------
Instance.new('Folder',ReplicatedStorage.DragonEngine).Name="Network"
local Service_Endpoints=Instance.new('Folder',ReplicatedStorage.DragonEngine.Network) --A folder containing the remote functions/events for services with client APIs.
Service_Endpoints.Name="Service_Endpoints"
local Service_Events=Instance.new('Folder',ServerScriptService.DragonEngine) --A folder containing the server sided events for services.
Service_Events.Name="Service_Events"

local Service_Loaded_ServerEvent=Instance.new('BindableEvent') --Bindable event for signalling server services when a service is loaded.
DragonEngine.ServiceLoaded=Service_Loaded_ServerEvent.Event
local Service_Unloaded_ServerEvent=Instance.new('BindableEvent') --Bindable event for signalling server services when a service is unloaded.
DragonEngine.ServiceUnloaded=Service_Unloaded_ServerEvent.Event

local Service_Loaded_ClientEvent=Instance.new('RemoteEvent',ReplicatedStorage.DragonEngine.Network) --Remote event for signalling the engine clients that a service was loaded.
Service_Loaded_ClientEvent.Name="ServiceLoaded"
local Service_Unloaded_ClientEvent=Instance.new('RemoteEvent',ReplicatedStorage.DragonEngine.Network) --Remote event for signalling the engine clients that a service was unloaded.
Service_Unloaded_ClientEvent.Name="ServiceUnloaded"

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Boilerplate
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local function IsModuleIgnored(Module)
	for _,ModuleName in pairs(DragonEngine.Config.IgnoredModules) do
		if ModuleName==Module.Name then
			return true
		end
	end

	return false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name: GetService
-- @Description : Returns the requested service.
--                Similiar to game:GetService().
-- @Params : string "ServiceName" - The name of the service to retrieve
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:GetService(ServiceName)
	assert(DragonEngine.Services[ServiceName]~=nil,"[Dragon Engine Server] GetService() : Service '"..ServiceName.."' was not loaded or does not exist.")
	return DragonEngine.Services[ServiceName]
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : LoadService
-- @Description : Loads the specified service module into the engine. Returns false if the service fails to load.
-- @Params : Instance <ModuleScript> "ServiceModule" - The service module to load into the engine
-- @Returns : Boolean "ServiceLoaded" - Will be TRUE if the service is loaded successfully, will be FALSE if the service failed to load.
--            string "ErrorMessage" - The error message if loading the service failed. Is nil if loading succeeded.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:LoadService(ServiceModule)

	----------------
	-- Assertions --
	----------------
	assert(ServiceModule~=nil,"[Dragon Engine Server] LoadService() : ModuleScript expected for 'ServiceModule', got nil instead.")
	assert(typeof(ServiceModule)=="Instance","[Dragon Engine Server] LoadService() : ModuleScript expected for 'ServiceModule', got "..typeof(ServiceModule).." instead.")
	assert(ServiceModule:IsA("ModuleScript"),"[Dragon Engine Server] LoadService() : ModuleScript expected for 'ServiceModule', got "..ServiceModule.ClassName.." instead.")
	assert(self.Services[ServiceModule.Name]==nil,"[Dragon Engine Server] LoadService() : A service with the name '"..ServiceModule.Name.."' is already loaded!")

	-------------
	-- DEFINES --
	-------------
	local ServiceName=ServiceModule.Name
	local Service; --Table holding the service

	-------------------------
	-- Loading the service --
	------------------------
	self:DebugLog("Loading service '"..ServiceModule.Name.."'...")
	local Success,Error=pcall(function() --If the module fails to load/errors, we want to keep the engine going
		Service=require(ServiceModule)
	end)
	if not Success then --Service module failed to load
		self:Log("Failed to load service '"..ServiceName.."' : "..Error,"Warning")
		return false,Error
	else --Service module was loaded

		----------------------------------
		-- Generating service endpoints --
		----------------------------------
		local EndpointFolder=Instance.new('Folder',Service_Endpoints) --Container for remote functions/events so clients can access the service client API.
		EndpointFolder.Name=ServiceName
		Service._EndpointFolder=EndpointFolder

		if Service.Client~=nil then --The service has client APIs
			for FunctionName,Function in pairs(Service.Client) do
				if type(Function)=="function" then
					local RemoteFunction=Instance.new('RemoteFunction',EndpointFolder);RemoteFunction.Name=FunctionName

					RemoteFunction.OnServerInvoke=function(...)
						return Function(Service.Client,...) --Service.Client is passed since `self` needs to be manually defined
					end
					self:DebugLog("Registered endpoint '"..ServiceName.."."..FunctionName.."'")
				end
			end
		end

		---------------------------------------------
		-- Adding service to DragonEngine.Services --
		---------------------------------------------
		local EventsFolder=Instance.new('Folder',Service_Events);EventsFolder.Name=ServiceName --Container for server sided events for this service

		Service.Name=ServiceName
		Service.Status="Uninitialized"
		Service.Initialized=false
		Service._ServerEventsFolder=EventsFolder

		setmetatable(Service,{__index=DragonEngine}) --Exposing Dragon Engine to the service
		self.Services[ServiceName]=Service
		Service_Loaded_ClientEvent:FireAllClients(ServiceName)

		self:DebugLog("Service '"..ServiceName.."' loaded.")
		return true
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : LoadServicesIn
-- @Description : Loads all services in the given container.
-- @Params : Instance "Container" - The container holding all of the service modules.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:LoadServicesIn(Container)
	for _,ServiceModule in pairs(Boilerplate.RecurseFind(Container,"ModuleScript")) do
		if not IsModuleIgnored(ServiceModule) then
			DragonEngine:LoadService(ServiceModule)
		end
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : UnloadService
-- @Description : Unloads the specified service from the engine and destroys any endpoints/events it created.
--                This function will attempt to Stop() the service before unloading it, to clean state.
-- @Params : string "ServiceName" - The name of the service to unload.
-- @Returns : Boolean "ServiceUnloaded" - Will be TRUE if the service is unloaded successfully, will be FALSE if the service failed to unload.
--            string "ErrorMessage" - The error message if unloading the service failed. Is nil if unloading succeeded.

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:UnloadService(ServiceName)

	----------------
	-- Assertions --
	----------------
	assert(ServiceName~=nil,"[Dragon Engine Server] UnloadService() : string expected for 'ServiceName', got nil instead.")
	assert(typeof(ServiceName)=="string","[Dragon Engine Server] UnloadService() : string expected for 'ServiceName', got "..typeof(ServiceName).." instead.")
	assert(self.Services[ServiceName]~=nil,"[Dragon Engine Server] UnloadService() : No service with the name '"..ServiceName.."' is loaded!")

	-------------
	-- DEFINES --
	-------------
	local Service=self.Services[ServiceName]

	--------------------------
	-- Stopping the service --
	--------------------------
	if Service.Status=="Running" then
		self:StopService(ServiceName)
	end

	---------------------------
	-- Unloading the service --
	---------------------------
	self:Log("Unloading service '"..ServiceName.."'...")
	if typeof(Service.Unload)=="function" then --The service has an unload function, run it to allow the service to clean state.
		local Success,Error=pcall(function()
			Service:Unload()
		end)
		if not Success then --Unloading the service failed.
			self:Log("Service '"..ServiceName.."' unload function failed, a memory leak is possible. : "..Error,"Warning")
			return false,Error
		end
	else --The service had no unload function. Warn about potential memory leaks.
		self:Log("Service '"..ServiceName.."' had no unload function, a memory leak is possible.","Warning")
	end

	if Service._EndpointFolder~=nil then Service._EndpointFolder:Destroy() end --Destroy service endpoints
	Service._ServerEventsFolder:Destroy() --Destroy service server events
	self.Services[ServiceName]=nil
	Service_Unloaded_ClientEvent:FireAllClients(ServiceName)

	self:Log("Service '"..ServiceName.."' unloaded.")
	return true
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : InitializeService
-- @Description : Initializes the specified service.
-- @Params : string "ServiceName" - The name of the service to initialize
-- @Returns : bool "Success" - Whether or not the service was successfully initialized.
--            string "Error" - The error message if the initialization failed. Is nil if initialization succeeded.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:InitializeService(ServiceName)

	----------------
	-- Assertions --
	----------------
	assert(ServiceName~=nil,"[Dragon Engine Server] InitializeService() : string expected for 'ServiceName', got nil instead.")
	assert(typeof(ServiceName)=="string","[Dragon Engine Server] InitializeService() : string expected for 'ServiceName', got "..typeof(ServiceName).." instead.")
	assert(self.Services[ServiceName]~=nil,"[Dragon Engine Server] InitializeService() : No service with the name '"..ServiceName.."' is loaded!")
	assert(self.Services[ServiceName].Initialized==false,"[Dragon Engine Server] InitializeService() : Service '"..ServiceName.."' is already initialized!")

	-------------
	-- DEFINES --
	-------------
	local Service=self.Services[ServiceName]

	------------------------------
	-- Initializing the service --
	------------------------------
	self:DebugLog("Initializing service '"..ServiceName.."'...")
	if type(Service.Init)=="function" then --An init() function exists, run it.
		local Success,Error=pcall(function()
			Service:Init()
		end)
		if not Success then
			DragonEngine:Log("Failed to initialize service '"..ServiceName.."' : "..Error,"Warning")
			return false,Error
		end
		Service.Status="Stopped"
		Service.Initialized=true
	else --Init function doesn't exist
		self:DebugLog("Service '"..ServiceName.."' could not be initilized, no init function was found!","Warning")
	end

	self:DebugLog("Service '"..ServiceName.."' initialized.")

	return true
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : StartService
-- @Description : Starts the specified service.
-- @Params : bool "Success" - Whether or not the service was successfully started.
--           string "Error" - The error message if starting the service failed. Is nil if the start succeeded.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:StartService(ServiceName)
	----------------
	-- Assertions --
	----------------
	assert(ServiceName~=nil,"[Dragon Engine Server] StartService() : string expected for 'ServiceName', got nil instead.")
	assert(typeof(ServiceName)=="string","[Dragon Engine Server] StartService() : string expected for 'ServiceName', got "..typeof(ServiceName).." instead.")
	assert(self.Services[ServiceName]~=nil,"[Dragon Engine Server] StartService() : No service with the name '"..ServiceName.."' is loaded!")
	assert(self.Services[ServiceName].Status~="Running","[Dragon Engine Server] StartService() : The service '"..ServiceName.."' is already running!")
	assert(self.Services[ServiceName].Initialized==true,"[Dragon Engine Server] StartService() : The service '"..ServiceName.."' was not initialized!")

	-------------
	-- DEFINES --
	-------------
	local Service=self.Services[ServiceName]

	------------------------------
	-- Initializing the service --
	------------------------------
	self:DebugLog("Starting service '"..ServiceName.."'...")
	if type(Service.Start)=="function" then --An init() function exists, run it.
		local Success,Error=pcall(function()
			coroutine.wrap(Service.Start)(Service)
		end)
		if not Success then
			DragonEngine:Log("Failed to start service '"..ServiceName.."' : "..Error,"Warning")
			return false,Error
		end
	else --Start function doesn't exist
		self:DebugLog("Service '"..ServiceName.."' could not be started, no start function was found!","Warning")
	end
	Service.Status="Running"
	self:DebugLog("Service '"..ServiceName.."' started.")

	return true
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : StopService
-- @Description : Stops the specified service.
-- @Params : bool "Success" - Whether or not the service was successfully stopped.
--           string "Error" - The error message if stopping the service failed. Is nil if the start succeeded.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:StopService(ServiceName)
	----------------
	-- Assertions --
	----------------
	assert(ServiceName~=nil,"[Dragon Engine Server] StopService() : string expected for 'ServiceName', got nil instead.")
	assert(typeof(ServiceName)=="string","[Dragon Engine Server] StopService() : string expected for 'ServiceName', got "..typeof(ServiceName).." instead.")
	assert(self.Services[ServiceName]~=nil,"[Dragon Engine Server] StopService() : No service with the name '"..ServiceName.."' is loaded!")
	assert(self.Services[ServiceName].Status=="Running","[Dragon Engine Server] StopService() : The service '"..ServiceName.."' is already stopped!")

	-------------
	-- DEFINES --
	-------------
	local Service=self.Services[ServiceName]

	------------------------------
	-- Stopping the service --
	------------------------------
	self:DebugLog("Stopping service '"..ServiceName.."'...")
	if type(Service.Stop)=="function" then --A stop() function exists, run it.
		local Success,Error=pcall(function()
			Service:Stop()
		end)
		if not Success then
			DragonEngine:Log("Failed to stop service '"..ServiceName.."' : "..Error,"Warning")
			return false,Error
		end
		Service.Status="Stopped"
	else --Stop function doesn't exist
		self:DebugLog("Service '"..ServiceName.."' could not be stopped, no stop function was found!","Warning")
	end
	
	self:DebugLog("Service '"..ServiceName.."' stopped.")

	return true
end


----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : RegisterServiceClientEvent
-- @Description : Registers a client event for the service calling. MUST BE CALLED FROM INSIDE A SERVICE MODULE.
-- @Params : string "Name" - The name to assign to the client event.
-- @Returns : Instance <RemoteEvent> "RemoteEvent" - The service client event.
-- @TODO : Create endpoint folder for service if it doesn't exist.
--         This occurs when the service has no endpoint functions, but has client events.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:RegisterServiceClientEvent(Name)

	----------------
	-- Assertions --
	----------------
	assert(Name~=nil,"[Dragon Engine Server] RegisterServiceClientEvent() : string expected for 'Name', got nil instead.")
	assert(typeof(Name)=="string","[Dragon Engine Server] RegisterServiceClientEvent() : string expected for 'ame', got "..typeof(Name).." instead.")

	local RemoteEvent=Instance.new('RemoteEvent')
	RemoteEvent.Name=Name
	RemoteEvent.Parent=self._EndpointFolder

	self:DebugLog("Registered client event '"..Name.."' for service '"..self.Name.."'")

	return RemoteEvent
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : RegisterServiceServerEvent
-- @Description : Registers a server event for the service calling. MUST BE CALLED FROM INSIDE A SERVICE MODULE.
-- @Params : string "Name" - The name to assign to the server event.
-- @Retruns : Instance <BindableEvent> "BindableEvent" - The service server event.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function DragonEngine:RegisterServiceServerEvent(Name)

	----------------
	-- Assertions --
	----------------
	assert(Name~=nil,"[Dragon Engine Server] RegisterServiceServerEvent() : string expected for 'Name', got nil instead.")
	assert(typeof(Name)=="string","[Dragon Engine Server] RegisterServiceServerEvent() : string expected for 'ame', got "..typeof(Name).." instead.")

	local BindableEvent=Instance.new('BindableEvent')
	BindableEvent.Name=Name
	BindableEvent.Parent=self._ServerEventsFolder
	self[Name]=BindableEvent.Event

	self:DebugLog("Registered server event '"..Name.."' for service '"..self.Name.."'")

	return BindableEvent
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ENGINE INIT
----------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------
-- Set up environment --
------------------------

----------------------
-- Loading Settings --
----------------------
--[[ Load default settings ]]--
local DefSettingsSuccess,DefSettingsError=pcall(function()
	DragonEngine.Config=require(ReplicatedStorage.DragonEngine.Settings.EngineSettings)
	DragonEngine.Config.Paths=require(ReplicatedStorage.DragonEngine.Settings.ServerPaths)
end)
assert(DefSettingsSuccess==true, DefSettingsSuccess==true or "[Dragon Engine Server] An error occured while loading settings : "..DefSettingsError)

--[[ Load user settings ]]--
if ReplicatedStorage:FindFirstChild("DragonEngine_UserSettings")~=nil then
	local SettingsFolder=ReplicatedStorage.DragonEngine_UserSettings

	local LoadSuccess,Error=pcall(function()
		if SettingsFolder:FindFirstChild("EngineSettings")~=nil then
			local EngineSettings=require(SettingsFolder.EngineSettings)

			for SettingName,SettingValue in pairs(EngineSettings) do
				if DragonEngine.Config[SettingName]~=nil then --Setting exists, override with developer value.
					DragonEngine.Config[SettingName]=SettingValue
				else --Setting does not exist.
					error("Attempt to override non-existant setting!")
				end
			end
		end

		if SettingsFolder:FindFirstChild("ServerPaths")~=nil then
			local ServerPaths=require(SettingsFolder.ServerPaths)

			for PathName,PathValues in pairs(ServerPaths) do
				for _,PathValue in pairs(PathValues) do
					table.insert(DragonEngine.Config.Paths[PathName],PathValue)
				end
			end
		end
	end)

	assert(LoadSuccess==true,LoadSuccess==true or "[Dragon Engine Server] An error occured while loading developer-specified settings : "..Error)
end

if DragonEngine.Config["ShowLogoInOutput"] then print(ENGINE_LOGO) end --Displaying the logo in the output logs.
if DragonEngine.Config["Debug"] then warn("[Dragon Engine Server] Debug enabled. Logging will be verbose.") end

-------------------
-- Loading Enums --
-------------------
for EnumName,EnumVal in pairs(DragonEngine.Config.Enums) do
	DragonEngine:DefineEnum(EnumName,EnumVal)
end

-----------------------------------
-- Loading services,classes,etc. --
-----------------------------------
local Paths=DragonEngine.Config.Paths

--[[ Utils ]]--
print("")
print("**** LOADING UTIL MODULES ****")
print("")
for _,Path in pairs(Paths.Utils) do
	DragonEngine:LoadUtilitiesIn(Path)
end
--[[ Shared classes ]]--
print("")
print("**** LOADING CLASS MODULES ****")
print("")
for _,Path in pairs(Paths.SharedClasses) do
	DragonEngine:LoadClassesIn(Path)
end
--[[ Server classes ]]--
print("")
print("**** LOADING SERVER CLASS MODULES ****")
print("")
for _,Path in pairs(Paths.ServerClasses) do
	DragonEngine:LoadClassesIn(Path)
end

--[[ Loading services into the engine and initializing them ]]--
print("")
print("**** LOADING SERVICES ****")
print("")
DragonEngine:DebugLog("Loading and initializing services...")
for _,Path in pairs(Paths.Services) do
	DragonEngine:LoadServicesIn(Path)
end
for ServiceName,_ in pairs(DragonEngine.Services) do
	DragonEngine:InitializeService(ServiceName)
end
DragonEngine:DebugLog("All services loaded and initialized!")

--[[ Running services ]]--
DragonEngine:DebugLog()
DragonEngine:DebugLog("Starting services...")
for ServiceName,Service in pairs(DragonEngine.Services) do
	if Service.Initialized then
		DragonEngine:StartService(ServiceName)
	end
end
DragonEngine:DebugLog("All services running!")

--[[ Engine loaded ]]--
local Engine_Loaded=Instance.new('BoolValue')
Engine_Loaded.Name="_Loaded"
Engine_Loaded.Value=true
Engine_Loaded.Parent=ReplicatedStorage.DragonEngine

print("")
DragonEngine:DebugLog("Engine config : ")
DragonEngine:DebugLog(DragonEngine.Utils.Table.repr(DragonEngine.Config,{pretty=true}))
print("Dragon Engine "..DragonEngine.Version.." loaded!")