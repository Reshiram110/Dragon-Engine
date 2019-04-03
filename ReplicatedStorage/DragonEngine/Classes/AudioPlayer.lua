--[[
	Audio Player

	Acts as a 'music player', allowing the easy deployment of audio on the client and server.

	Programmed by @Reshiram110
]]

local AudioPlayer={}

---------------------
-- Roblox Services -- 
---------------------
local HttpService=game:GetService("HttpService")
local TweenService=game:GetService("TweenService")

-------------
-- DEFINES --
-------------
local CLASS_DEBUG=true --Determines whether or not debug output will be displayed.

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- DEBUG CLASS METHODS
----------------------------------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : SpitPlaylist
-- @Description : Spits the playlist table to the output in JSON format.
-- @Example : AudioPlayer.Debug:SpitPlaylist
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:SpitPlaylist()
	for Index=1,#self.Playlist do
		if self.PlaylistPosition~=Index then
			print(Index.." :   "..HttpService:JSONEncode(self.Playlist[Index]))
		else
			print(Index.." : ->"..HttpService:JSONEncode(self.Playlist[Index]))
		end
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CLASS METHODS
----------------------------------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : new
-- @Description : Creates and returns a new instance of the audioplayer class.
-- @Returns : table "NewAudioPlayer" - The new instance of the audio player.
-- @Example : local MyAudioPlayer=AudioPlayer.new()
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer.new()
	local NewAudioPlayer={

		--[[ Properties ]]--
		Name="AudioPlayer",
		
		Playlist={}, --Contains all of the information about the different sounds
		PlaylistPosition=0, --The current position in the playlist.

		CurrentAudio={ --Information about the current song
			Name="",
			ID="rbxassetid://0", 
			--AudioOptions={} --Contains properties and other options for the audio.
		},

		AutoPlay=false, --Determines whether or not the audioplayer will autoplay when moving to a new index in the playlist.
		Looped=false, --Determines whether or not the audioplayer will loop through the playlist.

		Sound=Instance.new('Sound',game.Workspace),

		_Destroyed=false, --Used to prevent further usage after this object is destroyed.
		
		--[[ Events ]]--
		_Events={
			AudioAdded=Instance.new('BindableEvent'), --Fired when an audio is added to the playlist.
			AudioRemoved=Instance.new('BindableEvent'), --Fired when an audio is removed from the playlist.
		}
		
	}
	NewAudioPlayer.AudioAdded=NewAudioPlayer._Events.AudioAdded.Event
	NewAudioPlayer.AudioRemoved=NewAudioPlayer._Events.AudioRemoved.Event
	setmetatable(NewAudioPlayer,{__index=AudioPlayer})

	return NewAudioPlayer
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : Destroy
-- @Description : Destroys the audio player.
-- @Example : AudioPlayer:Destroy()
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:Destroy()
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] Destroy() : Cannot destroy an already destroyed audioplayer.")

	self._Destroyed=true

	--[[ Clean up instances ]]--
	self.Sound:Destroy()
	for _,BindableEvent in pairs(self._Events) do
		BindableEvent:Destroy()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : AddAudioAtIndex
-- @Description : Adds an audio with the given name and ID at the specified playlist index to the playlist.
-- @Params : int "IndexNumber" - Then index of the song to add to the playlist.
--           string "AudioName" - The name to assign to the audio being added.
--           string "ID" - The rbxasset id of the audio being added.
-- @Example : AudioPlayer:AddAudio("LobbyMusic","18300397")
--            AudioPlayer:AddAudio("LobbyMusic","rbxassetid://183003997")
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:AddAudioAtIndex(IndexNumber,AudioName,ID)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] AddAudioAtIndex() : Cannot add audio to destroyed audioplayer.")
	assert(IndexNumber~=nil,"[Audio Player '"..self.Name.."'] AddAudioAtIndex() : IndexNumber expected, got nil.")
	assert(typeof(IndexNumber)=="number","[Audio Player '"..self.Name.."'] AddAudioAtIndex() : number expected for IndexNumber, got "..typeof(IndexNumber).." instead.")
	if IndexNumber~=1 then
		assert(self.Playlist[IndexNumber-1]~=nil,"[Audio Player '"..self.Name.."'] AddAudioAtIndex() : Index out of bounds.")
	end
	assert(ID~=nil,"[Audio Player '"..self.Name.."'] AddAudioAtIndex() : Audio ID expected, got nil.")
	assert(typeof(ID)=="string","[Audio Player '"..self.Name.."'] AddAudioAtIndex(): String expected for ID, got "..typeof(ID).." instead.")

	----------------------
	-- Adding the audio --
	----------------------
	if string.find(ID,"rbxassetid://")==nil then
		ID="rbxassetid://"..ID
	end
	table.insert(self.Playlist,IndexNumber,{
		Name=(AudioName or "NewAudio"),
		ID=ID,
	})

	if CLASS_DEBUG then
		print("")
		print("[Audio Player '"..self.Name.."'] Audio added.")
		print("Added audio : "..HttpService:JSONEncode(self.Playlist[#self.Playlist]))
		print("New audio list :")
		self:SpitPlaylist()
		print("")
	end

	------------------------------------------------
	-- Update current audio and playlist position --
	------------------------------------------------
	if IndexNumber<=self.PlaylistPosition then --Adjust playlist position to point to current audio.
		self.PlaylistPosition=self.PlaylistPosition+1
	end
	if self.PlaylistPosition==0 then --First audio added.
		self:JumpToIndex(1)
	end
	
	self._Events.AudioAdded:Fire(AudioName,#self.Playlist)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : AddAudio
-- @Description : Adds an audio with the given name and ID to the end of the playlist.
-- @Params : string "AudioName" - The name to assign to the audio being added.
--           string "ID" - The rbxasset id of the audio being added.
-- @Example : AudioPlayer:AddAudio("LobbyMusic","18300397")
--            AudioPlayer:AddAudio("LobbyMusic","rbxassetid://183003997")
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:AddAudio(AudioName,ID)
	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] AddAudioAtIndex() : Cannot add audio to destroyed audioplayer.")
	assert(ID~=nil,"[Audio Player '"..self.Name.."'] AddAudioAtIndex() : Audio ID expected, got nil.")
	assert(typeof(ID)=="string","[Audio Player '"..self.Name.."'] AddAudioAtIndex(): String expected for ID, got "..typeof(ID).." instead.")

	------------------------
	-- Adding the audio --
	------------------------
	self:AddAudioAtIndex(#self.Playlist+1,AudioName,ID)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : RemoveAudioAtIndex
-- @Description : Removes an audio at the specified playlist index from the playlist.
-- @Params : int "IndexNumber" - Then index of the song to remove from the playlist.
-- @Example : AudioPlayer:RemoveAudioAtIndex(2)
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:RemoveAudioAtIndex(IndexNumber)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] RemoveAudioAtIndex() : Cannot remove audio from destroyed audioplayer.")
	assert(IndexNumber~=nil,"[Audio Player '"..self.Name.."'] RemoveAudioAtIndex() : IndexNumber expected, got nil.")
	assert(typeof(IndexNumber)=="number","[Audio Player '"..self.Name.."'] number expected for IndexNumber, got "..typeof(IndexNumber).." instead.")
	assert(self.Playlist[IndexNumber]~=nil,"[Audio Player '"..self.Name.."'] RemoveAudioAtIndex() : Index out of bounds.")

	-------------
	-- DEFINES --
	-------------
	local AudioName=self.Playlist[IndexNumber].Name

	------------------------
	-- Removing the audio --
	------------------------
	if CLASS_DEBUG then
		print("")
		print("[Audio Player '"..self.Name.."'] Audio removed.")
		print("Removed audio : "..HttpService:JSONEncode(self.Playlist[IndexNumber]))
	end

	table.remove(self.Playlist,IndexNumber)
	
	------------------------------------------------
	-- Update current audio and playlist position --
	------------------------------------------------
	if IndexNumber<self.PlaylistPosition then --Adjust playlist position to point to current audio.
		self.PlaylistPosition=self.PlaylistPosition-1
	elseif IndexNumber==self.PlaylistPosition then --Current audio was removed.
		if self.PlaylistPosition>#self.Playlist then --Destroyed audio was last in playlist.
			self:JumpToIndex(#self.Playlist)
		elseif #self.Playlist==0 then --Destroyed audio was the only audio in the playlist.
			self.CurrentSong={Name="",ID="rbxassetid://0"}
			self.PlaylistPosition=0
		else
			self:JumpToIndex(self.PlaylistPosition)
		end
	end

	if CLASS_DEBUG then
		print("New audio list :")
		self:SpitPlaylist()
		print("")
	end

	self._Events.AudioRemoved:Fire(AudioName,IndexNumber)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : RemoveAudio
-- @Description : Removes an audio with the given name from the playlist.
-- @Params : string "AudioName" - The name of the audio to be removed from the playlist.
-- @Example : AudioPlayer:RemoveAudio("LobbyMusic")
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:RemoveAudio(AudioName)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] RemoveAudio() : Cannot remove audio from destroyed audioplayer.")
	assert(AudioName~=nil,"[Audio Player '"..self.Name.."'] RemoveAudio() : Name expected, got nil.")
	assert(typeof(AudioName)=="string","[Audio Player '"..self.Name.."'] RemoveAudio() : string expected for Name, got "..typeof(AudioName).." instead.")

	-------------
	-- DEFINES --
	-------------
	local AudioIndex=self:GetAudioPlaylistPosition(AudioName)

	------------------------
	-- Removing the audio --
	------------------------
	assert(AudioIndex~=nil,"[Audio Player '"..self.Name.."'] RemoveAudio() : Could not remove audio '"..AudioName.."', audio was not found.")
	self:RemoveAudioAtIndex(AudioIndex)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : RemoveAllAudio
-- @Description : Removes all audio from the playlist.
-- @Example : AudioPlayer:RemoveAllAudio()
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:RemoveAllAudio()

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] RemoveAudio() : Cannot remove audio from destroyed audioplayer.")

	------------------------
	-- Removing all audio --
	------------------------
	for Count=1,#self.Playlist do
		self:RemoveAudioAtIndex(1)
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : Play
-- @Description : Plays the audio that is at the current playlist position.
-- @Params : OPTIONAL table "AudioSettings" - A dictionary table containing the properties to apply to the audio.
--                                            Can also include a tween.
-- @Example : AudioPlayer:Play({
--                Volume=0,
--                Tween={
--                    TweenInfo.new(5,Enum.EasingStyle.Linear),
--                    {Volume=1}
--                }
--            })
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:Play(AudioSettings)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] Play() : Cannot play an audio of a destroyed audio player.")
	if AudioSettings~=nil then
		assert(typeof(AudioSettings)=="table","[Audio Player '"..self.Name.."'] Play() : table expected for AudioSettings, got "..typeof(AudioSettings).." instead.")
	end

	-----------------------
	-- Playing the audio --
	-----------------------
	self:Stop()

	--[[ Apply audio properties if specified ]]--
	if AudioSettings~=nil then
		for PropertyName,PropertyValue in pairs(AudioSettings) do
			if PropertyName~="Tween" then
				self.Sound[PropertyName]=PropertyValue
			end
		end

		--[[ Running tween if specified ]]--
		if AudioSettings.Tween~=nil then
			local AudioTween=TweenService:Create(
				self.Sound,
				unpack(AudioSettings.Tween)
			)

			AudioTween:Play()
		end
	end

	self.Sound.SoundId=self.CurrentAudio.ID
	self.Sound:Play()
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : PlayAudioAtIndex
-- @Description : Plays an audio in the audio playlist at the specified index, with the given options.
-- @Params : int "IndexNumber" - The index of the song to play.
--           OPTIONAL table "AudioSettings" - A dictionary table containing the properties to apply to the audio.
--                                            Can also include a tween.
-- @Example : AudioPlayer:PlayAudioAtIndex(2,{
--                Volume=0,
--                Tween={
--                    TweenInfo.new(5,Enum.EasingStyle.Linear),
--                    {Volume=1}
--                }
--            })
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:PlayAudioAtIndex(IndexNumber,AudioSettings)
	
	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] PlayAudioAtIndex() : Cannot play an audio of a destroyed audio player.")
	assert(IndexNumber~=nil,"[Audio Player '"..self.Name.."'] PlayAudioAtIndex() : IndexNumber expected, got nil.")
	assert(typeof(IndexNumber)=="number","[Audio Player '"..self.Name.."'] PlayAudioAtIndex() : number expcted for IndexNumber, got "..typeof(IndexNumber).." instead.")
	assert(self.Playlist[IndexNumber]~=nil,"[Audio Player '"..self.Name.."'] PlayAudioAtIndex() : Index out of bounds.")
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] PlayAudioAtIndex() : Cannot play an audio of a destroyed audio player.")
	if AudioSettings~=nil then
		assert(typeof(AudioSettings)=="table","[Audio Player '"..self.Name.."'] PlayAudioAtIndex() : table expected for AudioSettings, got "..typeof(AudioSettings).." instead.")
	end

	-----------------------
	-- Playing the audio --
	-----------------------
	self:JumpToIndex(IndexNumber)
	self:Play(AudioSettings)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : PlayAudio
-- @Description : Plays an audio in the audio playlist with the given name, with the given options.
-- @Params : string "AudioName" - The name of the song to play.
--           OPTIONAL table "AudioSettings" - A dictionary table containing the properties to apply to the audio.
--                                            Can also include a tween.
-- @Example : AudioPlayer:PlayAudio("LobbyMusic",{
--                Volume=0,
--                Tween={
--                    TweenInfo.new(5,Enum.EasingStyle.Linear),
--                    {Volume=1}
--                }
--            })
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:PlayAudio(AudioName,AudioSettings)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] PlayAudio() : Cannot play an audio of a destroyed audio player.")
	if AudioSettings~=nil then
		assert(typeof(AudioSettings)=="table","[Audio Player '"..self.Name.."'] PlayAudioAtIndex() : table expected for AudioSettings, got "..typeof(AudioSettings).." instead.")
	end

	-------------
	-- DEFINES --
	-------------
	local AudioIndex=self:GetAudioPlaylistPosition(AudioName)

	-----------------------
	-- Playing the audio --
	-----------------------
	assert(AudioIndex~=nil,"[Audio Player '"..self.Name.."'] PlayAudio() : Could not find an audio with the name '"..AudioName.."'.")
	self:JumpToIndex(AudioIndex)
	self:Play(AudioSettings)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : Stop
-- @Description : Stops the currently playing audio.
-- @Params : OPTIONAL table "Tween" - A table containing the properties for a tween that will run before the
--                                    audio is stopped.
-- @Example : AudioPlayer:Stop()
--            AudioPlayer:Stop({
--                TweenInfo.new(5,Enum.EasingStyle.Linear),
--                {Volume=1}
--            })
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:Stop(Tween)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] Stop() : Cannot stop an audio of a destroyed audio player.")

	------------------------
	-- Stopping the audio --
	------------------------

	--[[ Running tween if specified ]]--
	if Tween~=nil then
		local AudioTween=TweenService:Create(
			self.Sound,
			unpack(Tween)
		)

		AudioTween:Play()
		spawn(function() --We spawn the function so the calling thread doesn't yield.
			AudioTween.Completed:wait()
			self.Sound:Stop()
		end)
	else
		self.Sound:Stop()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : Resume
-- @Description : Resumes the currently paused audio.
-- @Params : OPTIONAL table "AudioSettings" - A dictionary table containing the properties to apply to the audio.
--                                            Can also include a tween.
-- @Example : AudioPlayer:Resume({
--                Volume=0,
--                Tween={
--                    TweenInfo.new(5,Enum.EasingStyle.Linear),
--                    {Volume=1}
--                }
--            })
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:Resume(AudioSettings)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] Resume()) : Cannot resume an audio of a destroyed audio player.")
	if AudioSettings~=nil then
		assert(typeof(AudioSettings)=="table","[Audio Player '"..self.Name.."'] Resume() : table expected for AudioSettings, got "..typeof(AudioSettings).." instead.")
	end

	------------------------
	-- Resuming the audio --
	------------------------

	--[[ Apply audio properties if specified ]]--
	if AudioSettings~=nil then
		for PropertyName,PropertyValue in pairs(AudioSettings) do
			if PropertyName~="Tween" then
				self.Sound[PropertyName]=PropertyValue
			end
		end

		--[[ Running tween if specified ]]--
		if AudioSettings.Tween~=nil then
			local AudioTween=TweenService:Create(
				self.Sound,
				unpack(AudioSettings.Tween)
			)

			AudioTween:Play()
		end
	end

	self.Sound:Resume()
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : Pause
-- @Description : Pauses the currently playing audio.
-- @Params : OPTIONAL table "Tween" - A table containing the properties for a tween that will run before the
--                                    audio is paused.
-- @Example : AudioPlayer:Pause({
--                TweenInfo.new(5,Enum.EasingStyle.Linear),
--                {Volume=1}
--            })
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:Pause(Tween)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] Pause() : Cannot pause an audio of a destroyed audio player.")

	-----------------------
	-- Pausing the audio --
	-----------------------

	--[[ Running tween if specified ]]--
	if Tween~=nil then
		local AudioTween=TweenService:Create(
			self.Sound,
			unpack(Tween)
		)

		AudioTween:Play()
		spawn(function() --We spawn the function so the calling thread doesn't yield.
			AudioTween.Completed:wait()
			self.Sound:Pause()
		end)
	else
		self.Sound:Pause()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : JumpToIndex
-- @Description : Sets the current song to the specified index in the playlist.
--                If audio is currently being played, the audio will be stopped.
--                If autoplay is true, the song at the specified index will be automatically played.
-- @Params : int "IndexNumber" - The index to jump to in the playlist.
-- @Example : AudioPlayer:JumpToIndex(2)
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:JumpToIndex(IndexNumber)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] JumpToIndex() : Cannot jump to an index of a destroyed audio player.")
	assert(IndexNumber~=nil,"[Audio Player '"..self.Name.."'] JumpToIndex() : IndexNumber expected, got nil.")
	assert(typeof(IndexNumber)=="number","[Audio Player '"..self.Name.."'] JumpToIndex() : number expcted for IndexNumber, got "..typeof(IndexNumber).." instead.")
	assert(self.Playlist[IndexNumber]~=nil,"[Audio Player '"..self.Name.."'] JumpToIndex() : Index out of bounds.")

	----------------------
	-- Jumping to index --
	----------------------
	if CLASS_DEBUG then
		print("")
		print("[Audio Player '"..self.Name.."'] Jumping to index "..IndexNumber..".")
		print("")
	end

	self:Stop()
	self.PlaylistPosition=IndexNumber
	self.CurrentAudio=self.Playlist[IndexNumber]
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @Name : GetAudioPlaylistPosition
-- @Description : Finds an audio in the playlist with the given name and returns its position in the playlist.
-- @Params : string "AudioName" - The name of the audio to find.
-- @Returns : int "Index" - The index of where the audio is in the playlist. Is nil if the requested audio is not found.
-- @Example : local SongIndex=AudioPlayer:GetAudioPlaylistPosition("LobbyMusic")
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function AudioPlayer:GetAudioPlaylistPosition(AudioName)

	----------------
	-- ASSERTIONS --
	----------------
	assert(self._Destroyed==false,"[Audio Player '"..self.Name.."'] GetAudioPlaylistPosition() : Cannot find audio in destroyed audioplayer.")
	assert(AudioName~=nil,"[Audio Player '"..self.Name.."'] GetAudioPlaylistPosition() : Name expected, got nil.")
	assert(typeof(AudioName)=="string","[Audio Player '"..self.Name.."'] GetAudioPlaylistPosition() : string expected for Name, got "..typeof(AudioName).." instead.")
	
	-----------------------
	-- Finding the audio --
	-----------------------
	for Index=1,#self.Playlist do
		if self.Playlist[Index].Name==AudioName then return Index end
	end
	warn("[Audio Player '"..self.Name.."'] GetAudioPlaylistPosition() : Could not find an audio with the name '"..AudioName.."'.")

	return nil
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CLASS INITIALIZATION
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
if CLASS_DEBUG then warn("[Audio Player] Debug mode enabled. Logging will be verbose.") end

return AudioPlayer