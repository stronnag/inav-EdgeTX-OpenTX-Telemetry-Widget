-- Lua Telemetry Flight Status for INAV/Taranis
-- Author: https://github.com/teckel12
-- Docs: https://github.com/iNavFlight/LuaTelemetry

local zone, options = ...
local VERSION = "2.0.1"
local FILE_PATH = "/SCRIPTS/TELEMETRY/iNav/"
local SMLCD = LCD_W < 212
local HORUS = LCD_W >= 480 or LCD_H >= 480
local tmp, view, lang, playLog
local env = "bt" -- compile on platform
local inav = {}

local ext = "" -- compile on platform

local v, r, m, i, e, osname = getVersion()
-- Nirvana NV14 doesn't have have these global constants, so we set them
if string.sub(r, 0, 4) == "nv14" or string.sub(r, 0, 4) == "NV14" then
	EVT_SYS_FIRST = 1 --1542
	EVT_ROT_LEFT = 2 --57088
	EVT_ROT_RIGHT = 3 --56832
	EVT_ENTER_BREAK = 4 --514
	EVT_EXIT_BREAK = 5 --516
end

--[[ if string.sub(r, -4) == "simu" then
   env = "btd"
   end
]]

local config = loadScript(FILE_PATH .. "config" .. ext, env)(SMLCD)
collectgarbage()

local modes, units, labels, dir = loadScript(FILE_PATH .. "modes" .. ext, env)(HORUS)
collectgarbage()

local data, getTelemetryId, getTelemetryUnit, PREV, NEXT, MENU, text, line, rect, fill, frmt = loadScript(FILE_PATH .. "data" .. ext, env)(r, m, i, HORUS)
collectgarbage()

data.etx = (osname ~= nil)

loadScript(FILE_PATH .. "load" .. ext, env)(config, data, FILE_PATH)
collectgarbage()

--[[ Simulator language testing
data.lang = "ro"
data.voice = "ro"
]]

if data.lang ~= "en" or data.voice ~= "en" then
	lang = loadScript(FILE_PATH .. "lang" .. ext, env)(modes, labels, data, FILE_PATH, env)
	collectgarbage()
end

loadScript(FILE_PATH .. "reset" .. ext, env)(data)
collectgarbage()

local crsf, distCalc = loadScript(FILE_PATH .. "other" .. ext, env)(config, data, units, getTelemetryId, getTelemetryUnit, FILE_PATH, env, SMLCD)
collectgarbage()

local title, gpsDegMin, hdopGraph, icons, rect = loadScript(FILE_PATH .. "func_" .. (HORUS and "h" or "t") .. ext, env)(config, data, modes, dir, SMLCD, FILE_PATH, text, line, rect, fill, frmt, options)
collectgarbage()

local function playAudio(f, a)
	if config[4].v == 2 or (config[4].v == 1 and a ~= nil) then
		playFile(FILE_PATH .. data.voice .. "/" .. f .. ".wav")
	end
end

local function calcBearing(gps1, gps2)
	--[[ Spherical-Earth math: More accurate if the Earth was a sphere, but obviously it's not
	local x = (math.cos(o1) * math.sin(o2)) - (math.sin(o1) * math.cos(o2) * math.cos(a2 - a1))
	local y = math.sin(a2 - a1) * math.cos(o2)
	return math.deg(math.atan2(y, x))
	]]
	-- Flat-Earth math
	local x = (gps2.lon - gps1.lon) * math.cos(math.rad(gps1.lat))
	return math.deg(1.5708 - math.atan2(gps2.lat - gps1.lat, x))
end

local function calcDir(r1, r2, r3, x, y, r)
	local x1 = math.sin(r1) * r + x
	local y1 = y - (math.cos(r1) * r)
	local x2 = math.sin(r2) * r + x
	local y2 = y - (math.cos(r2) * r)
	local x3 = math.sin(r3) * r + x
	local y3 = y - (math.cos(r3) * r)
	return x1, y1, x2, y2, x3, y3
end

local function endLog()
	playLog = nil
	collectgarbage()
	loadScript(FILE_PATH .. "reset" .. ext, env)(data)
end

function inav.update(opt)
   options = opt
end

function inav.background()
	local gpsTemp
	data.rssi, data.rssiLow, data.rssiCrit = getRSSI()
	if data.rssi > 0 then
		data.telem = true
		data.rssiMin = math.min(data.rssiMin, data.rssi)
		data.satellites = getValue(data.sat_id)
		if data.showFuel then
			data.fuel = getValue(data.fuel_id)
		end
		if data.crsf then
			crsf(data)
		else
			data.heading = getValue(data.hdg_id)
			if data.fpv_id > -1 then data.fpv = getValue(data.fpv_id) * 0.1 end
			if data.pitchRoll then
				data.pitch = getValue(data.pitch_id)
				data.roll = getValue(data.roll_id)
			else
				data.accx = getValue(data.accx_id)
				data.accy = getValue(data.accy_id)
				data.accz = getValue(data.accz_id)
			end
			data.mode = getValue(data.mode_id)
			data.rxBatt = getValue(data.rxBatt_id)
			data.gpsAlt = data.satellites > 1000 and getValue(data.gpsAlt_id) or 0
			data.distance = getValue(data.dist_id)
			data.distanceMax = getValue(data.distMax_id)
		end
		data.vspeed = getValue(data.vspeed_id)
		data.altitude = getValue(data.alt_id)
		if data.alt_id == -1 and data.gpsAltBase and data.gpsFix and data.satellites > 3000 then
			data.altitude = data.gpsAlt - data.gpsAltBase
		end
		data.speed = getValue(data.speed_id)
		if data.showCurr then
			data.current = getValue(data.curr_id)
			data.currentMax = getValue(data.currMax_id)
		end
		data.altitudeMax = getValue(data.altMax_id)
		data.speedMax = getValue(data.speedMax_id)
		data.batt = getValue(data.batt_id)
		data.battMin = getValue(data.battMin_id)
		gpsTemp = getValue(data.gpsLatLon_id)
		if data.a4_id > -1 then
			data.cell = getValue(data.a4_id)
			data.cellMin = getValue(data.a4Min_id)
		end
	else
		data.telem = false
	end
	data.txBatt = getValue(data.txBatt_id)
	data.throttle = getValue(data.thr_id)

	-- Log playback
	if data.doLogs then
		-- Checking if it's really armed
		if data.rssi > 0 and bit32.band(data.mode % 10, 4) == 4 then
			-- Armed, kill playback
			endLog()
		else
			-- Not armed, continue playback
			if playLog == nil then
				loadScript(FILE_PATH .. "reset" .. ext, env)(data)
				data.doLogs = true -- Resist removing this, the reset above sets doLogs to false, so this is needed
				playLog = loadScript(FILE_PATH .. "log" .. ext, env)(env, FILE_PATH)
			end
			gpsTemp = playLog(data, config, distCalc, config[34].l[config[34].v], NEXT, PREV)
			if not data.doLogs then
				endLog()
			end
		end
	end

	if data.rssi > 0 then
		-- Dist doesn't have a known unit so the transmitter doesn't auto-convert
		if data.dist_unit == 10  and not data.crsf then
			data.distance = math.floor(data.distance * 3.28084 + 0.5)
			data.distanceMax = data.distanceMax * 3.28084
		end
		if data.a4_id == -1 then
			if data.batt / data.cells > config[29].v or data.batt / data.cells < 2.2 then
				data.cells = math.floor(data.batt / config[29].v) + 1
			end
			data.cell = data.batt / data.cells
			data.cellMin = data.battMin / data.cells
		end
		data.rssiLast = data.rssi
		data.gpsFix = false
		if type(gpsTemp) == "table" and gpsTemp.lat ~= nil and gpsTemp.lon ~= nil then
			data.gpsLatLon = gpsTemp
			if data.satellites > 1000 and gpsTemp.lat ~= 0 and gpsTemp.lon ~= 0 then
				data.gpsFix = true
				data.lastLock = gpsTemp
				if data.gpsHome ~= false and distCalc ~= nil then
					distCalc(data)
				end
			end
		end
		if data.distance > 0 then
			data.distanceLast = data.distance
		end
	end

	local armedPrev = data.armed
	local headFreePrev = data.headFree
	local headingHoldPrev = data.headingHold
	local altHoldPrev = data.altHold
	local homeReset = false
	local modeIdPrev = data.modeId
	local preArmMode = false
	data.modeId = 1 -- No telemetry
	if data.telem then
		data.armed = false
		data.headFree = false
		data.headingHold = false
		data.altHold = false
		local modeA = data.mode * 0.0001
		local modeB = data.mode * 0.001 % 10
		local modeC = data.mode * 0.01 % 10
		local modeD = data.mode * 0.1 % 10
		local modeE = data.mode % 10
		if bit32.band(modeD, 2) == 2 then
			data.modeId = 2 -- Horizon
		elseif bit32.band(modeD, 1) == 1 then
			data.modeId = 3 -- Angle
		else
			data.modeId = 4 -- Acro
		end
		data.headFree = bit32.band(modeB, 4) == 4
		data.headingHold = bit32.band(modeC, 1) == 1
		if bit32.band(modeE, 4) == 4 then
			data.armed = true
			data.altHold = (bit32.band(modeC, 2) == 2 or bit32.band(modeC, 4) == 4)
			homeReset = data.satellites >= 4000
			data.modeId = bit32.band(modeC, 4) == 4 and 7 or data.modeId -- Pos hold
		else
			preArmMode = data.modeId
			data.modeId = (bit32.band(modeE, 2) == 2 or modeE == 0) and (data.throttle > -920 and 12 or 5) or 6 -- Not OK to arm(5) / Throttle warning(12) / Ready to fly(6)
		end
		if bit32.band(modeA, 4) == 4 then
			data.modeId = 11 -- Failsafe
		elseif bit32.band(modeB, 1) == 1 then
			data.modeId = 10 -- RTH
		elseif bit32.band(modeD, 4) == 4 then
			data.modeId = 9 -- Manual
		elseif bit32.band(modeB, 2) == 2 then
			data.modeId = 8 -- Waypoint
		elseif bit32.band(modeB, 8) == 8 then
			data.modeId = 13 -- Cruise
		end
	end

	-- Voice alerts
	local vibrate = false
	local beep = false
	if data.armed and not armedPrev then -- Engines armed
		data.timerStart = getTime()

		data.gpsHome = false
		data.battPercentPlayed = 100
		data.battLow = false
		data.showMax = false
		data.showDir = config[32].v == 1
		data.configStatus = 0
		data.configSelect = 0
		if not data.gpsAltBase and data.gpsFix then
			data.gpsAltBase = data.gpsAlt
		end
		playAudio("engarm", 1)
	elseif not data.armed and armedPrev then -- Engines disarmed
		if data.distanceLast <= data.distRef then
			data.headingRef = -1
			data.showMax = false
			data.showDir = true
			data.gpsAltBase = false
		end
		playAudio("engdrm", 1)
	end
	if data.gpsFix ~= data.gpsFixPrev and modeIdPrev ~= 12 and data.modeId ~= 12 then -- GPS status change
		playAudio("gps", not data.gpsFix and 1 or nil)
		playAudio(data.gpsFix and "good" or "lost", not data.gpsFix and 1 or nil)
	end
	if modeIdPrev ~= data.modeId then -- New flight mode
		if data.armed and modes[data.modeId].w ~= nil then
			playAudio(modes[data.modeId].w, modes[data.modeId].f > 0 and 1 or nil)
		elseif not data.armed and data.modeId == 6 and (modeIdPrev == 5 or modeIdPrev == 12) then
			playAudio(modes[data.modeId].w)
		end
	elseif preArmMode ~= false and data.preArmModePrev ~= preArmMode then
		playAudio(modes[preArmMode].w)
	end
	data.hdop = math.floor(data.satellites * 0.01) % 10
	if data.headingHold ~= headingHoldPrev then -- Heading hold status change
		playAudio("hedhld")
		playAudio(data.headingHold and "active" or "off")
	end
	if data.headFree ~= headFreePrev then -- Head free status change
		playAudio(data.headFree and "hfact" or "hfoff", 1)
	end
	if data.armed then
		data.distanceLast = data.distance
		if config[13].v == 1 then
			data.timer = (getTime() - data.timerStart) * 0.01 -- Armed so update timer
		elseif config[13].v > 1 then
			data.timer = model.getTimer(config[13].v - 2)["value"]
		end
		if data.altHold ~= altHoldPrev then -- Alt hold status change
			playAudio("althld")
			playAudio(data.altHold and "active" or "off")
		end
		if homeReset and not data.homeResetPrev then -- Home reset
			playAudio("homrst")
			data.gpsHome = false
			data.headingRef = data.heading
		end
		if data.altitude + 0.5 >= config[6].v and config[12].v > 0 then -- Altitude alert
			if getTime() > data.altNextPlay then
				if config[4].v > 0 then
					playNumber(data.altitude + 0.5, data.alt_unit)
				end
				data.altNextPlay = getTime() + 1000
			else
				beep = true
			end
		elseif config[7].v > 1 then -- Vario voice
			local steps = {[0] = 1, 2, 5, 10, 15, 20, 25, 30, 40, 50}
			if math.abs(data.altitude - data.altLastAlt) + 0.5 >= steps[config[24].v] then
				if math.abs(data.altitude + 0.5 - data.altLastAlt) / steps[config[24].v] > 1.5 then
					tmp = math.floor((data.altitude + 0.5) / steps[config[24].v]) * steps[config[24].v]
				else
					tmp = math.floor(data.altitude / steps[config[24].v] + 0.5) * steps[config[24].v]
				end
				if tmp > 0 and getTime() > data.altNextPlay then
					playNumber(tmp, data.alt_unit)
					data.altLastAlt = tmp
					data.altNextPlay = getTime() + 500
				end
			end
		end
		if data.showCurr and config[23].v == 0 and data.battPercentPlayed > data.fuel and config[11].v == 2 and config[4].v == 2 and getTime() > data.battNextPlay then -- Fuel notifications
			if data.fuel >= config[17].v and data.fuel <= config[18].v and data.fuel > config[17].v then -- Fuel low
				playAudio("batlow")
				playNumber(data.fuel, 13)
				data.battPercentPlayed = data.fuel
				data.battNextPlay = getTime() + 500
			elseif data.fuel % 10 == 0 and data.fuel < 100 and data.fuel > config[18].v then -- Fuel 10% notification
				playAudio("battry")
				playNumber(data.fuel, 13)
				data.battPercentPlayed = data.fuel
				data.battNextPlay = getTime() + 500
			end
		end
		if ((data.showCurr and config[23].v == 0 and data.fuel <= config[17].v) or data.cell < config[3].v) and config[11].v > 0 then -- Voltage/fuel critial
			if getTime() > data.battNextPlay then
				playAudio("batcrt", 1)
				if data.showCurr and config[23].v == 0 and data.fuel <= config[17].v and data.battPercentPlayed > data.fuel and config[4].v > 0 then
					playNumber(data.fuel, 13)
					data.battPercentPlayed = data.fuel
				end
				data.battNextPlay = getTime() + 1000
			else
				vibrate = true
				beep = true
			end
			data.battLow = true
		elseif data.cell < config[2].v and config[11].v == 2 and not data.battLow then -- Voltage notification
			playAudio("batlow")
			data.battLow = true
		end
		if (data.headFree and config[9].v == 1) or modes[data.modeId].f ~= 0 then
			if data.modeId ~= 10 or (data.modeId == 10 and config[8].v == 1) then
				beep = true
				vibrate = true
			end
		elseif data.rssi < data.rssiLow and config[10].v == 1 then
			if data.rssi < data.rssiCrit then
				vibrate = true
			end
			beep = true
		end
		if data.hdop < 11 - config[21].v * 2 then
			beep = true
		end
		if vibrate and (config[5].v == 1 or config[5].v == 3) and not data.doLogs then
			playHaptic(25, 3000)
		end
		if beep and config[5].v >= 2 then
			playTone(2000, 100, 3000, PLAY_NOW)
		end
		-- Altitude hold center feedback
		if config[26].v == 1 and config[5].v > 0 then
			if data.altHold then
				if data.thrCntr == -2000 then
					data.thrCntr = data.throttle
					data.trCnSt = true
				end
				if math.abs(data.throttle - data.thrCntr) < 50 then
					if not data.trCnSt then
						playHaptic(15, 0)
						data.trCnSt = true
					end
				elseif data.trCnSt then
					playTone(data.throttle > data.thrCntr and 600 or 400, 75, 0, PLAY_NOW + PLAY_BACKGROUND)
					data.trCnSt = false
				end
			else
				data.thrCntr = -2000
				data.trCnSt = false
			end
		end
	else
		data.battLow = false
		data.battPercentPlayed = 100
		-- Initalize variables on flight reset (uses timer3)
		tmp = model.getTimer(2)
		if tmp.value == 0 then
			loadScript(FILE_PATH .. "load" .. ext, env)(config, data, FILE_PATH)
			loadScript(FILE_PATH .. "reset" .. ext, env)(data)
			tmp.value = 3600
			model.setTimer(2, tmp)
		end
	end
	data.gpsFixPrev = data.gpsFix
	data.homeResetPrev = homeReset
	data.preArmModePrev = preArmMode

	if data.armed and data.gpsFix and data.gpsHome == false then
		data.gpsHome = data.gpsLatLon
	end

	-- Altitude graph
	if data.armed and config[28].v > 0 and getTime() >= data.altLst + (config[28].v * 100) then
		data.alt[data.altCur] = data.altitude
		data.altCur = data.altCur == 60 and 1 or data.altCur + 1
		data.altLst = getTime()
		-- I don't like this min/max routine at all, there's got to be a better way
		data.altMin = 0
		data.altMax = data.alt_unit == 10 and 50 or 30
		local min, max = math.min, math.max
		for i = 1, 60 do
			data.altMin = min(data.altMin, data.alt[i])
			data.altMax = max(data.altMax, data.alt[i])
		end
		data.altMax = math.ceil(data.altMax * (data.alt_unit == 10 and 0.1 or 0.2)) * (data.alt_unit == 10 and 10 or 5)
	end
	data.bkgd = true
end

function inav.run(event)
	--[[ Show FPS
	data.start = getTime()
	]]
	-- Insure background() has run before rendering screen
	if not data.bkgd then
		inav.background()
	end
	data.bkgd = false

	-- Startup message
	if data.startup == 1 then
		data.startupTime = getTime()
		data.startup = 2
	elseif data.startup == 2 and getTime() - data.startupTime >= 200 then
		data.startup = 0
		--data.msg = false
	end

	-- Clear screen
	if HORUS then
	   -- Display error if Horus widget isn't full screen
		if data.nfs ~= nil then
			data.nfs()
			return 0
		end
		-- On Horus use sticks to control the menu
		event = data.clear(event)
	else
		lcd.clear()
	end

	-- Display system error
	--[[
	if data.msg then
		text((LCD_W - string.len(data.msg) * (HORUS and 13 or 5.2)) * 0.5, HORUS and 130 or 27, data.msg, HORUS and MIDSIZE or 0)
		return 0
	end
	]]

	-- Config menu or views
	if data.configStatus > 0 then
		if data.v ~= 9 then
			view = nil
			collectgarbage()
			view = loadScript(FILE_PATH .. "menu" .. ext, env)()
			data.v = 9
		end
		tmp = config[30].v
		view(data, config, units, lang, event, gpsDegMin, getTelemetryId, getTelemetryUnit, SMLCD, PREV, NEXT, HORUS, text, rect, fill, frmt, env)
		if HORUS then
		   data.menu(tmp)
		end
		-- Exit menu or select log for playback, save config settings
		if data.configSelect == 0 and (event == EVT_EXIT_BREAK or (event == EVT_ENTER_BREAK and data.configStatus == 34 and config[34].x > -1 and not data.armed)) then
			view = nil
			collectgarbage()
			loadScript(FILE_PATH .. "save" .. ext, env)(config, data, frmt, FILE_PATH)
		end
	else
		-- User input
		if not data.armed and (event == PREV or event == NEXT) then
			-- Toggle showing max/min values
			data.showMax = not data.showMax
		end
		if event == NEXT or event == PREV then
			-- Toggle launch/compass-based orientation
			data.showDir = not data.showDir
		elseif event == EVT_ENTER_BREAK and not HORUS then
			-- Cycle through views
			config[25].v = config[25].v >= (config[28].v == 0 and 2 or 3) and 0 or config[25].v + 1
		elseif event == MENU then
			-- Config menu
			data.configStatus = data.configLast
		elseif event == EVT_EXIT_BREAK and data.doLogs then
			-- Exit playback
			endLog()
		end

		-- Views
		if data.v ~= config[25].v then
			view = nil
			collectgarbage()
			view = loadScript(FILE_PATH .. (HORUS and (data.nv and "nirvana" or "horus") or (config[25].v == 0 and "view" or (config[25].v == 1 and "pilot" or (config[25].v == 2 and "radar" or "alt")))) .. ext, env)()
			data.v = config[25].v
		end
		view(data, config, modes, dir, units, labels, gpsDegMin, hdopGraph, icons, calcBearing, calcDir, VERSION, SMLCD, FILE_PATH, text, line, rect, fill, frmt)
	end
	collectgarbage()

	-- Paint title
	title()
	return 0
end

return inav
