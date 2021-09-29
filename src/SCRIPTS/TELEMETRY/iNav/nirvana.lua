local function view(data, config, modes, dir, units, labels, gpsDegMin, hdopGraph, icons, calcBearing, calcDir, VERSION, SMLCD, FILE_PATH, text, line, rect, fill, frmt)

	local rgb = data.RGB
	local SKY = rgb(50, 171, 230)
	local GROUND = rgb(148, 118, 58)
	--local SKY2 = 8943 --rgb(32, 92, 122)
	--local GROUND2 = 20996 --rgb(81, 65, 36)
	local MAP = rgb(50, 150, 50)
	--local DKMAP = 544 --rgb(0, 70, 0)
	local LIGHTMAP = rgb(50, 200, 50)
	--local DATA = 12942 --rgb(50, 82, 115)
	local DKGREY = rgb(98, 106, 115)
	local RIGHT_POS = 270
	local X_CNTR = 134 --(RIGHT_POS + LEFT_POS [0]) / 2 - 1
	local HEADING_DEG = 190
	local PIXEL_DEG = RIGHT_POS / HEADING_DEG --(RIGHT_POS - LEFT_POS [0]) / HEADING_DEG
	local TOP = 20
	local BOTTOM = 146
	local Y_CNTR = 83 --(TOP + BOTTOM) / 2
	local DEGV = 160
	local CENTERED = 4
	--local TINSIZE = 256
	--local VERTICAL = 16384
	local tmp, tmp2, top2, bot2, pitch, roll, roll1, upsideDown
	local bmap = lcd.drawBitmap
	local color = lcd.setColor
	local floor = math.floor
	local min = math.min
	local max = math.max
	local abs = math.abs
	local rad = math.rad
	local deg = math.deg
	local sin = math.sin
	local cos = math.cos

	function intersect(s1, e1, s2, e2)
		local d = (s1.x - e1.x) * (s2.y - e2.y) - (s1.y - e1.y) * (s2.x - e2.x)
		local a = s1.x * e1.y - s1.y * e1.x
		local b = s2.x * e2.y - s2.y * e2.x
		local x = (a * (s2.x - e2.x) - (s1.x - e1.x) * b) / d
		local y = (a * (s2.y - e2.y) - (s1.y - e1.y) * b) / d
		if x < min(s2.x, e2.x) - 1 or x > max(s2.x, e2.x) + 1 or y < min(s2.y, e2.y) - 1 or y > max(s2.y, e2.y) + 1 then
			return nil, nil
		end
		return floor(x + 0.5), floor(y + 0.5)
	end

	local function pitchLadder(r, adj)
		--[[ Caged mode
		local x = sin(roll1) * r
		local y = cos(roll1) * r
		local p = cos(rad(pitch - adj)) * DEGV
		local x1, y1, x2, y2 = X_CNTR - x, Y_CNTR + y - p, X_CNTR + x, Y_CNTR - y - p
		]]
		-- Uncaged mode
		local p = sin(rad(adj)) * DEGV
		local y = (Y_CNTR - cos(rad(pitch)) * DEGV) - sin(roll1) * p
		if y > top2 and y < bot2 then
			local x = X_CNTR - cos(roll1) * p
			local xd = sin(roll1) * r
			local yd = cos(roll1) * r
			local x1, y1, x2, y2 = x - xd, y + yd, x + xd, y - yd
			if (y1 > top2 or y2 > top2) and (y1 < bot2 or y2 < bot2) and x1 >= 0 and x2 >= 0 then
			   local rcol = (r == 20) and WHITE or LIGHTGREY
			   line(x1, y1, x2, y2, SOLID, data.set_flags(0, rcol))
			   if r == 20 and y1 > top2 and y1 < bot2 then
			      text(x1, y1 - 8, upsideDown and -adj or adj, data.set_flags(SMLSIZE + RIGHT, data.TextColor))
			   end
			end
		end
	end

	local function tics(v, p)
		tmp = floor((v + 25) * 0.1) * 10
		for i = tmp - 40, tmp, 5 do
			local tmp2 = Y_CNTR + ((v - i) * 3) - 9
			if tmp2 > 10 and tmp2 < BOTTOM - 8 then
			   line(p, tmp2 + 8, p + 2, tmp2 + 8, SOLID, data.set_flags(0, data.TextColor))
				--[[ Currently disabled due to preformance
				if config[28].v == 0 and i % 10 == 0 and (i >= 0 or p > X_CNTR) and tmp2 < BOTTOM - 23 then
					text(p + (p > X_CNTR and -1 or 4), tmp2, i, SMLSIZE + (p > X_CNTR and RIGHT or 0) + TEXT_COLOR)
				end
				]]
			end
		end
	end

	-- Setup
	bmap(icons.bg, 0, TOP)

	-- Calculate orientation
	if data.pitchRoll then
		pitch = (abs(data.roll) > 900 and -1 or 1) * (270 - data.pitch * 0.1) % 180
		roll = (270 - data.roll * 0.1) % 180
		upsideDown = abs(data.roll) > 900
	else
		pitch = 90 - deg(math.atan2(data.accx * (data.accz >= 0 and -1 or 1), math.sqrt(data.accy * data.accy + data.accz * data.accz)))
		roll = 90 - deg(math.atan2(data.accy * (data.accz >= 0 and 1 or -1), math.sqrt(data.accx * data.accx + data.accz * data.accz)))
		upsideDown = data.accz < 0
	end
	roll1 = rad(roll)
	top2 = config[33].v == 0 and TOP or TOP + 20
	bot2 = BOTTOM - 16
	local i = { {}, {} }
	local tl = { x = 1, y = TOP }
	local tr = { x = RIGHT_POS - 2, y = TOP }
	local bl = { x = 1, y = BOTTOM - 1 }
	local br = { x = RIGHT_POS - 2, y = BOTTOM - 1 }
	local skip = false

	-- Calculate horizon (uses simple "caged" mode for less math)
	local x = sin(roll1) * 200
	local y = cos(roll1) * 200
	local p = cos(rad(pitch)) * DEGV
	local h1 = { x = X_CNTR + x, y = Y_CNTR - y - p }
	local h2 = { x = X_CNTR - x, y = Y_CNTR + y - p }

	-- Find intersections between horizon and edges of attitude indicator
	local x1, y1 = intersect(h1, h2, tl, bl)
	local x2, y2 = intersect(h1, h2, tr, br)
	if x1 and x2 then
		i[1].x, i[1].y = x1, y1
		i[2].x, i[2].y = x2, y2
	else
		local x3, y3 = intersect(h1, h2, bl, br)
		local x4, y4 = intersect(h1, h2, tl, tr)
		if x3 and x4 then
			i[1].x, i[1].y = x3, y3
			i[2].x, i[2].y = x4, y4
		elseif (x1 or x2) and (x3 or x4) then
			i[1].x, i[1].y = x1 and x1 or x2, y1 and y1 or y2
			i[2].x, i[2].y = x3 and x3 or x4, y3 and y3 or y4
		else
			skip = true
		end
	end

	-- Draw ground
	local gflag = data.set_flags(0, GROUND)
	if skip then
		-- Must be going down hard!
		if (pitch - 90) * (upsideDown and -1 or 1) < 0 then
		   fill(tl.x, tl.y, br.x - tl.x + 1, br.y - tl.y + 1, gflag)
		end
	else
		local trix, triy

		-- Find right angle coordinates of triangle
		if upsideDown then
			trix = roll > 90 and max(i[1].x, i[2].x) or min(i[1].x, i[2].x)
			triy = min(i[1].y, i[2].y)
		else
			trix = roll > 90 and min(i[1].x, i[2].x) or max(i[1].x, i[2].x)
			triy = max(i[1].y, i[2].y)
		end

		-- Find rectangle(s) and fill
		if upsideDown then
			if triy > tl.y then
				fill(tl.x, tl.y, br.x - tl.x + 1, triy - tl.y, gflag)
			end
			if roll > 90 and trix < br.x then
				fill(trix, triy, br.x - trix + 1, br.y - triy + 1, gflag)
			elseif roll <= 90 and trix > tl.x then
				fill(tl.x, triy, trix - tl.x, br.y - triy + 1, gflag)
			end
		else
			if triy < br.y then
				fill(tl.x, triy + 1, br.x - tl.x + 1, br.y - triy, gflag)
			end
			if roll > 90 and trix > tl.x then
				fill(tl.x, tl.y, trix - tl.x, triy - tl.y + 1, gflag)
			elseif roll <= 90 and trix < br.x then
				fill(trix, tl.y, br.x - trix + 1, triy - tl.y + 1, gflag)
			end
		end

		-- Fill remaining triangle
		local height = i[1].y - triy
		local top = i[1].y
		if height == 0 then
			height = i[2].y - triy
			top = i[2].y
		end
		local inc = 1
		if height ~= 0 then
			local width = abs(i[1].x - trix)
			local tx1 = i[1].x
			local tx2 = trix
			if width == 0 then
				width = abs(i[2].x - trix)
				tx1 = i[2].x
				tx2 = trix
			end
			inc = abs(height) < 10 and 1 or (abs(height) < 20 and 2 or ((abs(height) < width and abs(roll - 90) < 55) and 3 or 5))
			local steps = height > 0 and inc or -inc
			local slope = width / height * inc
			local s = slope > 0 and 0 or inc - 1
			slope = abs(slope) * (tx1 < tx2 and 1 or -1)
			for y = triy, top, steps do
				if abs(steps) == 1 then
					line(tx1, y, tx2, y, SOLID, gflag)
				else
					if tx1 < tx2 then
					--if tx1 < tx2 and tx2 - tx1 + 1 > 0 then
						fill(tx1, y - s, tx2 - tx1 + 1, inc, gflag)
					else
					--elseif tx1 > tx2 and tx1 - tx2 + 1 > 0 then
						fill(tx2, y - s, tx1 - tx2 + 1, inc, gflag)
					end
				end
				tx1 = tx1 + slope
			end
		end

		-- Smooth horizon
		if not upsideDown and inc <= 3 then
			if inc > 1 then
				if inc > 2 then
					line(i[1].x, i[1].y + 2, i[2].x, i[2].y + 2, SOLID, gflag)
				end
				line(i[1].x, i[1].y + 1, i[2].x, i[2].y + 1, SOLID, gflag)
				gflag = data.set_flags(0, SKY)
				line(i[1].x, i[1].y - 1, i[2].x, i[2].y - 1, SOLID, gflag)
				if inc > 2 then
					line(i[1].x, i[1].y - 2, i[2].x, i[2].y - 2, SOLID, gflag)
				end
				if 90 - roll > 25 then
					line(i[1].x, i[1].y - 3, i[2].x, i[2].y - 3, SOLID, gflag)
				end
			end
			gflag = data.set_flags(0, LIGHTGREY)
			line(i[1].x, i[1].y, i[2].x, i[2].y, SOLID, gflag)
		end
	end

	-- Pitch ladder
	if data.telem then
		tmp = pitch - 90
		local tmp2 = max(min((tmp >= 0 and floor(tmp * 0.2) or math.ceil(tmp * 0.2)) * 5, 30), -30)
		for x = tmp2 - 20, tmp2 + 20, 5 do
			if x ~= 0 and (x % 10 == 0 or (x > -30 and x < 30)) then
				pitchLadder(x % 10 == 0 and 20 or 15, x)
			end
		end
		if not data.showMax then
		   text(X_CNTR - 60, Y_CNTR - 10, frmt("%.0f", upsideDown and -tmp or tmp) .. "\64", data.set_flags(SMLSIZE + RIGHT, data.TextColor))
		end
	end

	-- Speed & altitude tics
	if config[28].v == 0 then
		tics(data.speed, 1)
		tics(data.altitude, RIGHT_POS - 4)
		local smrf = data.set_flags(SMLSIZE + RIGHT, data.TextColor)
		text(42, Y_CNTR - 25, units[data.speed_unit], smrf)
		text(RIGHT_POS - 4, Y_CNTR - 25, "Alt " .. units[data.alt_unit], smrf)
	end

	-- Compass
	if data.showHead then
		for i = 0, 348.75, 11.25 do
			tmp = floor(((i - data.heading + (361 + HEADING_DEG * 0.5)) % 360) * PIXEL_DEG - 2.5)
			if tmp >= 9 and tmp <= RIGHT_POS - 12 then
				if i % 45 == 0 then
				   text(tmp, bot2, dir[i / 45], data.set_flags(CENTERED + SMLSIZE, data.TextColor))
				else
					line(tmp, BOTTOM - 4, tmp, BOTTOM - 1, SOLID,  data.set_flags(0, data.TextColor))
				end
			end
		end
	end

	-- Calculate the maximum distance for scaling home location and map
	local maxDist = max(min(data.distanceMax, data.distanceLast * 6), data.distRef * 10)

	-- Home direction
	if data.showHead and data.armed and data.telem and data.gpsHome ~= false then
		if data.distanceLast >= data.distRef then
			local bearing = calcBearing(data.gpsHome, data.gpsLatLon) + 540 % 360
			if config[15].v == 1 then
				-- HUD method
				local d = 1 - data.distanceLast / maxDist
				local w = HEADING_DEG / (d + 1)
				local h = floor((((upsideDown and data.heading - bearing or bearing - data.heading) + (361 + w * 0.5)) % 360) * (RIGHT_POS / w) - 0.5)
				--local p = sin(math.atan(data.altitude / data.distanceLast) - math.atan(data.altitude / max(maxDist, data.altitude * 0.25))) * (upsideDown and DEGV or -DEGV)
				--local p = sin(rad(d * max(15 + (pitch - 90) * 0.5, 0))) * (upsideDown and DEGV or -DEGV)
				local p = sin(math.atan(data.altitude / data.distanceLast * 0.5)) * (upsideDown and DEGV or -DEGV)
				local x = (X_CNTR - cos(roll1) * p) + (sin(roll1) * (h - X_CNTR)) - 9
				local y = ((Y_CNTR - cos(rad(pitch)) * DEGV) - sin(roll1) * p) - (cos(roll1) * (h - X_CNTR)) - 9
				if x >= 0 and x < RIGHT_POS - 17 then
					local s = floor(d * 2 + 0.5)
					bmap(icons.home[s], x, min(max(y, s == 2 and TOP or 15), BOTTOM - (s == 2 and 35 or 30)))
				end
				--[[
				if x >= 0 and y >= TOP and x < RIGHT_POS - 17 and y < BOTTOM - 17 then
					bmap(icons.home[floor(d * 2 + 0.5)], x, y)
				end
				]]
			else
				-- Bottom-fixed method
				local home = floor(((bearing - data.heading + (361 + HEADING_DEG * 0.5)) % 360) * PIXEL_DEG - 2.5)
				if home >= 3 and home <= RIGHT_POS - 6 then
					bmap(icons.home[1], home - 7, BOTTOM - 31)
				end
			end
		end
		-- Flight path vector
		if data.fpv_id > -1 and data.speed >= 8 then
			tmp = (data.fpv - data.heading + 360) % 360
			if tmp >= 302 or tmp <= 57 then
				local fpv = floor(((data.fpv - data.heading + (361 + HEADING_DEG * 0.5)) % 360) * PIXEL_DEG - 0.5)
				--local p = sin(rad(data.vspeed_id == -1 and pitch - 90 or math.log(1 + min(abs(0.6 * (data.vspeed_unit == 6 and data.vspeed * 0.3048 or data.vspeed)), 10)) * (data.vspeed < 0 and -5 or 5))) * DEGV
				local p = sin(data.vspeed_id == -1 and rad(pitch - 90) or (math.tan(data.vspeed / (data.speed * (data.speed_unit == 8 and 1.4667 or 0.2778))))) * DEGV
				local x = (X_CNTR - cos(roll1) * p) + (sin(roll1) * (fpv - X_CNTR)) - 9
				local y = ((Y_CNTR - cos(rad(pitch)) * DEGV) - sin(roll1) * p) - (cos(roll1) * (fpv - X_CNTR)) - 6
				if y > TOP and y < bot2 and x >= 0 then
					bmap(icons.fpv, x, y)
				end
			end
		end
	end

	-- View overlay
	bmap(icons.fg, 1, 20)
	--line(0, BOTTOM, RIGHT_POS, BOTTOM, SOLID, DKGREY)
	line(0, BOTTOM + 1, RIGHT_POS, BOTTOM + 1, SOLID, data.set_flags(0, MAP))
	local telemCol = (data.telem) and data.TextColor or RED
	-- Speed & altitude
	tmp = data.showMax and data.speedMax or data.speed
	text(41, Y_CNTR - 9, tmp >= 99.5 and floor(tmp + 0.5) or frmt("%.1f", tmp), data.set_flags(SMLSIZE + RIGHT, telemCol))
	tmp = data.showMax and data.altitudeMax or data.altitude
	text(RIGHT_POS, Y_CNTR - 9, floor(tmp + 0.5), data.set_flags(SMLSIZE + RIGHT, ((not data.telem or tmp + 0.5 >= config[6].v) and RED or data.TextColor)))
	if data.altHold then
		bmap(icons.lock, RIGHT_POS - 55, Y_CNTR - 5)
	end

	-- Heading
	if data.showHead then
	   text(X_CNTR + 20, bot2, floor(data.heading + 0.5) % 360 .. "\64", data.set_flags(SMLSIZE + RIGHT, telemCol))
	end

	-- Roll scale
	if config[33].v == 1 then
		bmap(icons.roll, 43, 20)
		if roll > 30 and roll < 150 and not upsideDown then
			local x1, y1, x2, y2, x3, y3 = calcDir(rad(roll - 90), rad(roll + 55), rad(roll - 235), X_CNTR - (cos(roll1) * 75), 79 - (sin(roll1) * 40), 7)
			local ycol = data.set_flags(0, YELLOW)
			line(x1, y1, x2, y2, SOLID, ycol)
			line(x1, y1, x3, y3, SOLID, ycol)
			line(x2, y2, x3, y3, SOLID, ycol)
		end
	end

	--[[ Variometer
	if config[7].v % 2 == 1 then
		color(CUSTOM__COLOR, DKGREY)
		fill(RIGHT_POS, TOP, 10, BOTTOM - 20, CUSTOM__COLOR)
		color(CUSTOM__COLOR, LIGHTGREY)
		line(RIGHT_POS + 10, TOP, RIGHT_POS + 10, BOTTOM - 1, SOLID, CUSTOM__COLOR)
		color(CUSTOM__COLOR, GREY)
		line(RIGHT_POS, Y_CNTR - 1, RIGHT_POS + 9, Y_CNTR - 1, SOLID, CUSTOM__COLOR)
		if data.telem then
			color(CUSTOM__COLOR, YELLOW)
			tmp = math.log(1 + min(abs(0.6 * (data.vspeed_unit == 6 and data.vspeed * 0.3048 or data.vspeed)), 10)) * (data.vspeed < 0 and -1 or 1)
			local y1 = Y_CNTR - (tmp * 0.416667 * (Y_CNTR - 21))
			local y2 = Y_CNTR - (tmp * 0.384615 * (Y_CNTR - 21))
			line(RIGHT_POS, y1 - 1, RIGHT_POS + 9, y2 - 1, SOLID, CUSTOM__COLOR)
			line(RIGHT_POS, y1, RIGHT_POS + 9, y2, SOLID, CUSTOM__COLOR)
		end
		if data.startup == 0 then
			text(RIGHT_POS + 13, TOP - 1, frmt(abs(data.vspeed) >= 9.95 and "%.0f" or "%.1f", data.vspeed) .. units[data.vspeed_unit], SMLSIZE + data.telem__Flags)
		end
	end
	]]

	-- RSSI/LQ
	tmp = (not data.telem or data.rssi < data.rssiLow) and RED or data.TextColor
	local val = data.showMax and data.rssiMin or data.rssiLast
	text(LCD_W + 1, BOTTOM - 19, val .. (data.crsf and "%" or "dB"), data.set_flags(RIGHT, tmp))
	text(LCD_W - 43, TOP, data.crsf and "  LQ" or "RSSI", data.set_flags(SMLSIZE, data.TextColor))
	if data.rl ~= val then
		local red = val >= data.rssiLow and max(floor((100 - val) / (100 - data.rssiLow) * 255), 0) or 255
		local green = val < data.rssiLow and max(floor((val - data.rssiCrit) / (data.rssiLow - data.rssiCrit) * 255), 0) or 255
		data.rc = rgb(red, green, 60)
		data.rl = val
	end
	rect(LCD_W - 32, TOP + 20, 15, 88, data.set_flags(0, data.rc))
	local h = math.floor(max(1, (min(val, 100) * 0.01) * 86))
	fill(LCD_W - 31, TOP + 107 - h, 13, h, data.set_flags(0, data.rc))

	-- Calc orientation
	tmp = data.headingRef
	if data.showDir or data.headingRef == -1 then
		tmp = 0
	end
	local r1 = rad(data.heading - tmp)
	local r2 = rad(data.heading - tmp + 145)
	local r3 = rad(data.heading - tmp - 145)

	-- Radar
	local LEFT_POS = 0
	RIGHT_POS = 319
	X_CNTR = 159 --(RIGHT_POS + LEFT_POS) * 0.5 - 1
	BOTTOM = 297 --BOTTOM + 150
	Y_CNTR = 222 --BOTTOM - 75
	if data.startup == 0 then
		-- Launch/north-based orientation
		if data.showDir or data.headingRef == -1 then
		   text(LEFT_POS + 2, Y_CNTR - 9, dir[6], data.set_flags(SMLSIZE, data.TextColor))
		   text(RIGHT_POS, Y_CNTR - 9, dir[2], data.set_flags(SMLSIZE + RIGHT, data.TextColor))
		end
		local cx, cy, d

		-- Altitude graph
		if config[28].v > 0 then
			local factor = 30 / (data.altMax - data.altMin)
			local mcol = LIGHTMAP
			for i = 1, 60 do
				cx = RIGHT_POS - 60 + i
				cy = floor(BOTTOM - (data.alt[((data.altCur - 2 + i) % 60) + 1] - data.altMin) * factor + 0.5)
				if cy < BOTTOM then
				   line(cx, cy, cx, BOTTOM - 1, SOLID, data.set_flags(0, mcol))
				end
				if (i - 1) % (60 / config[28].v) == 0 then
				   mcol = BLACK
				   line(cx, BOTTOM - 30, cx, BOTTOM - 1, DOTTED, data.set_flags(0, mcol))
				   mcol = LIGHTMAP
				end
			end
			if data.altMin < -1 then
				cy = BOTTOM - (-data.altMin * factor)
				mcol = BLACK
				line(RIGHT_POS - 58, cy, RIGHT_POS - 1, cy, DOTTED, data.set_flags(0, mcol))
				if cy < 142 then
				   text(RIGHT_POS - 59, cy - 8, "0", data.set_flags(SMLSIZE + RIGHT, data.TextColor))
				end
			end
			text(RIGHT_POS + 2, BOTTOM - 46, floor(data.altMax + 0.5) .. units[data.alt_unit], data.set_flags(SMLSIZE + RIGHT, data.TextColor))
		end

		if data.gpsHome ~= false then
			-- Craft location
			tmp2 = config[31].v == 1 and 65 or 130
			d = data.distanceLast >= data.distRef and min(max(data.distanceLast / maxDist * tmp2, 7), tmp2) or 1
			local bearing = calcBearing(data.gpsHome, data.gpsLatLon) - tmp
			local rad1 = rad(bearing)
			cx = floor(sin(rad1) * d + 0.5)
			cy = floor(cos(rad1) * d + 0.5)
			-- Home position
			local hx = X_CNTR + 2
			local hy = Y_CNTR
			if config[31].v ~= 1 then
				hx = hx - (d > 9 and cx * 0.5 or 0)
				hy = hy + (d > 9 and cy * 0.5 or 0)
			end
			if d >= 12 then
				--bmap(icons.home, hx - 4, hy - 5)
				bmap(icons.home[1], hx - 8, hy - 10)
			elseif d > 1 then
			   fill(hx - 1, hy - 1, 3, 3, SOLID, data.set_flags(0, data.TextColor))
			end
			-- Shift craft location
			cx = d == 1 and X_CNTR + 2 or cx + hx
			cy = d == 1 and Y_CNTR or hy - cy
		else
			cx = X_CNTR + 2
			cy = Y_CNTR
			d = 1
		end
		-- Orientation
		local x1, y1, x2, y2, x3, y3 = calcDir(r1, r2, r3, cx, cy, 8)
		line(x2, y2, x3, y3, SOLID, data.set_flags(0, LIGHTGREY))
		local tcol = data.set_flags(0, data.TextColor)
		line(x1, y1, x2, y2, SOLID, tcol)
		line(x1, y1, x3, y3, SOLID, tcol)
		tmp = data.distanceLast < 1000 and floor(data.distanceLast + 0.5) .. units[data.dist_unit] or (frmt("%.1f", data.distanceLast / (data.dist_unit == 9 and 1000 or 5280)) .. (data.dist_unit == 9 and "km" or "mi"))
		text(LEFT_POS + 2, BOTTOM - 16, tmp, data.set_flags(SMLSIZE, telemCol))
	end

	-- Startup message
	if data.startup == 2 then
	   local tcol = data.set_flags(MIDSIZE, BLACK)
	   text(X_CNTR - 78, 192, "Lua Telemetry", tcol)
	   text(X_CNTR - 38, 222, "v" .. VERSION, tcol)
	   tcol = data.set_flags(MIDSIZE, data.TextColor)
	   text(X_CNTR - 79, 191, "Lua Telemetry", tcol)
	   text(X_CNTR - 39, 221, "v" .. VERSION, tcol)
	end

	-- Data
	local X1 = 140 - 149
	local X2 = 234 - 144
	local X3 = 346 - 149
	TOP = BOTTOM + 60
	BOTTOM = 479

	-- Box 1 (fuel, battery)
	tmp = (not data.telem or data.cell < config[3].v or (data.showFuel and config[23].v == 0 and data.fuel <= config[17].v)) and RED or data.TextColor
	local btop = TOP - 54
	local bleft = 0
	local bwidth = 150
	local bright = 150
	if data.showFuel then
		if config[23].v > 0 or (data.crsf and data.showMax) then
		   text(bright, btop, (data.crsf and data.fuelRaw or data.fuel) .. data.fUnit[data.crsf and 1 or config[23].v], data.set_flags(MIDSIZE + RIGHT, tmp))
		else
			text(bright, btop, data.fuel .. "%", MIDSIZE + RIGHT + tmp)
			if data.fl ~= data.fuel then
				local red = data.fuel >= config[18].v and max(floor((100 - data.fuel) / (100 - config[18].v) * 255), 0) or 255
				local green = data.fuel < config[18].v and max(floor((data.fuel - config[17].v) / (config[18].v - config[17].v) * 255), 0) or 255
				data.fc = rgb(red, green, 60)
				data.fl = data.fuel
			end
			--lcd.drawGauge(bleft, btop + 26, bwidth, 15, min(data.fuel, 99), 100, CUSTOM__COLOR)
			rect(bleft, btop + 27, bwidth, 15, data.set_flags(0, data.fc))
			local w = max(1, (min(data.fuel, 100) * 0.01) * (bwidth - 2))
			fill(1, btop + 28, w, 13, data.set_flags(0, data.fc))
		end
		text(bleft, btop + ((config[23].v > 0 or (data.crsf and data.showMax)) and 23 or 9), labels[1], data.set_flags(SMLSIZE, data.TextColor))
	end

	bleft = 170
	bright = LCD_W - 1
	val = math.floor((data.showMax and data.cellMin or data.cell) * 100 + 0.5) * 0.01
	text(bright, btop, frmt(config[1].v == 0 and "%.2fV" or "%.1fV", config[1].v == 0 and val or (data.showMax and data.battMin or data.batt)), data.set_flags(MIDSIZE + RIGHT, tmp))
	text(bleft, btop + 9, labels[2], data.set_flags(SMLSIZE, data.TextColor))
	if data.bl ~= val then
		local red = val >= config[2].v and max(floor((4.2 - val) / (4.2 - config[2].v) * 255), 0) or 255
		local green = val < config[2].v and max(floor((val - config[3].v) / (config[2].v - config[3].v) * 255), 0) or 255
		data.bc = rgb(red, green, 60)
		data.bl = val
	end
	--lcd.drawGauge(bleft,  btop + 27, bwidth, 15, min(max(val - config[3].v + 0.1, 0) * (100 / (4.2 - config[3].v + 0.1)), 99), 100, CUSTOM__COLOR)
	rect(bleft, btop + 27, bwidth, 15, data.set_flags(0, data.bc))
	local w = max(1, (min(max(val - config[3].v + 0.1, 0) * (100 / (4.2 - config[3].v + 0.1)), 100) * 0.01) * (bwidth - 2))
	fill(bleft + 1, btop + 28, w, 13, data.set_flags(0, data.bc))

	-- Box 2 (altitude, distance, current)
	tmp = data.showMax and data.altitudeMax or data.altitude
	text(X1 + 9, TOP + 1, labels[4], data.set_flags(SMLSIZE,data.TextColor))
	text(X2, TOP + 12, floor(tmp + 0.5) .. units[data.alt_unit], data.set_flags(MIDSIZE + RIGHT, ((not data.telem or tmp + 0.5 >= config[6].v) and RED or data.TextColor)))
	tmp2 = data.showMax and data.distanceMax or data.distanceLast
	tmp = tmp2 < 1000 and floor(tmp2 + 0.5) .. units[data.dist_unit] or (frmt("%.1f", tmp2 / (data.dist_unit == 9 and 1000 or 5280)) .. (data.dist_unit == 9 and "km" or "mi"))
	text(X1 + 9, TOP + 44, labels[5], data.set_flags(SMLSIZE, data.TextColor))
	text(X2, TOP + 55, tmp, data.set_flags(MIDSIZE + RIGHT, telemCol))
	if data.showCurr then
		tmp = data.showMax and data.currentMax or data.current
		text(X1 + 9, TOP + 87, labels[3], SMLSIZE)
		text(X2, TOP + 98, (tmp >= 99.5 and floor(tmp + 0.5) or frmt("%.1fA", tmp)), data.set_flags(MIDSIZE + RIGHT, telemCol))
	end

	-- Box 3 (flight modes, orientation)
	tmp = (X2 + X3) * 0.5 + 4
	text(tmp, TOP, modes[data.modeId].t, data.set_flags(CENTERED,  (modes[data.modeId].f == 3 and data.WarningColor or data.TextColor)))
	if data.altHold then
		bmap(icons.lock, X1 + 63, TOP + 4)
	end
	if data.headFree then
	   text(X2 + 7, TOP + 19, "HF", data.set_flags(0, RED))
	end

	if data.showHead then
		if data.showDir or data.headingRef == -1 then
		   text(tmp, TOP + 18, dir[0], data.set_flags(CENTERED + SMLSIZE, data.TextColor))
		   text(X3 - 4, 421, dir[2], data.set_flags(SMLSIZE + RIGHT, data.TextColor))
		   text(X2 + 10, 421, dir[6], data.set_flags(SMLSIZE, data.TextColor))
		   text(tmp + 4, BOTTOM - 15, floor(data.heading + 0.5) % 360 .. "\64", data.set_flags(CENTERED + SMLSIZE, telemCol))
		end
		local x1, y1, x2, y2, x3, y3 = calcDir(r1, r2, r3, tmp, 429, 25)
		if data.headingHold then
			fill((x2 + x3) * 0.5 - 2, (y2 + y3) * 0.5 - 2, 5, 5, SOLID, data.set_flags(0, data.TextColor))
		else
			line(x2, y2, x3, y3, SOLID, data.set_flags(0, DKGREY))
		end
		local tcol = data.set_flags(0, data.TextColor)
		line(x1, y1, x2, y2, SOLID, tcol)
		line(x1, y1, x3, y3, SOLID, tcol)
	end

	-- Box 4 (GPS info, speed)
	if data.crsf then
		if data.tpwr then
		   text(RIGHT_POS, TOP, data.tpwr .. "mW", data.set_flags(RIGHT + MIDSIZE, telemCol))
		end
		text(RIGHT_POS + 1, TOP + 28, data.satellites % 100, data.set_flags(MIDSIZE + RIGHT, telemCol))
	else
		tmp = ((data.armed or data.modeId == 6) and data.hdop < 11 - config[21].v * 2) or not data.telem
		text(X3 + 48, TOP, (data.hdop == 0 and not data.gpsFix) and "-- --" or (9 - data.hdop) * 0.5 + 0.8, data.set_flags(MIDSIZE + RIGHT, (tmp and RED or data.TextColor)))
		text(X3 + 11, TOP + 24, "HDOP", data.set_flags(SMLSIZE, data.TextColor))
		text(RIGHT_POS + 1, TOP, data.satellites % 100, data.set_flags(MIDSIZE + RIGHT, telemCol))
	end
	hdopGraph(X3 + 65, TOP + (data.crsf and 51 or 23))
	tmp = RIGHT + ((not data.telem or not data.gpsFix) and RED or data.TextColor)
	if not data.crsf then
	   text(RIGHT_POS, TOP + 28, floor(data.gpsAlt + 0.5) .. (data.gpsAlt_unit == 10 and "'" or units[data.gpsAlt_unit]), data.set_flags(MIDSIZE, tmp))
	end
	local pcol = data.set_flags(SMLSIZE, tmp)
	text(RIGHT_POS, TOP + 54, config[16].v == 0 and frmt("%.6f", data.gpsLatLon.lat) or gpsDegMin(data.gpsLatLon.lat, true), pcol)
	text(RIGHT_POS, TOP + 74, config[16].v == 0 and frmt("%.6f", data.gpsLatLon.lon) or gpsDegMin(data.gpsLatLon.lon, false), pcol)
	tmp = data.showMax and data.speedMax or data.speed
	text(RIGHT_POS + 1, TOP + 98, tmp >= 99.5 and floor(tmp + 0.5) .. units[data.speed_unit] or frmt("%.1f", tmp) .. units[data.speed_unit], data.set_flags(MIDSIZE + RIGHT, telemCol))

	-- Dividers
	local dkgcol = data.set_flags(0, DKGREY)
	line(X2 + 3, TOP, X2 + 3, BOTTOM, SOLID, dkgcol)
	line(X3 + 3, TOP, X3 + 3, BOTTOM, SOLID, dkgcol)
	line(X3 + 3, TOP + 95, RIGHT_POS, TOP + 95, SOLID, dkgcol)
	if data.crsf then
		line(X3 + 3, TOP + 28, RIGHT_POS, TOP + 28, SOLID, dkgcol)
	end
	line(0, TOP - 1, LCD_W - 1, TOP - 1, SOLID, dkgcol)

	if data.showMax then
	   fill(240, TOP - 211, 80, 20, data.set_flags(0, YELLOW))
	   text(319, TOP - 211, "Min/Max", data.set_flags(RIGHT, BLACK))
	end

end

return view
