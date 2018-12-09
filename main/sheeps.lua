local Sheeps = {}

Sheeps.units = {}
Sheeps.count = 0
Sheeps.score = 0
Sheeps.name = "Player1"

local MAX_SPEED = 30.0
local MAX_ACCEL = 25.0

local MIN_DIST = 15.0
local MIN_DIST_S = MIN_DIST * MIN_DIST
local MAX_VISION = 100.0 * 100.0

function Sheeps.restart()
	Sheeps.units = {}
	Sheeps.count = 0
	Sheeps.score = 0
end

function Sheeps.add(sheep_id)
	table.insert(Sheeps.units, sheep_id)
	Sheeps.count = Sheeps.count + 1

	if Sheeps.count == 1 then
		msg.post(sheep_id, "black")
	end
end

function Sheeps.remove(sheep_id)
	for ind, sid in pairs(Sheeps.units) do
		if sid == sheep_id then
			table.remove(Sheeps.units, ind)
			return
		end
	end
end

function Sheeps.update(dt)
	for _, sid in pairs(Sheeps.units) do
		Sheeps.proccess(sid)
	end
end

function Sheeps.findNearest(to_pos)
	local min = -1
	local sheepId = nil
	for _, sid in pairs(Sheeps.units) do
		local spos = go.get_position(sid)
		local dist = vmath.length_sqr(to_pos - spos)
		if min < 0 or dist < min then
			min = dist
			sheepId = sid
		end
	end

	return sheepId
end

function Sheeps.checkCollision(to_pos, min_dist_sqr)
	for _, sid in pairs(Sheeps.units) do
		local spos = go.get_position(sid)
		local dist = vmath.length_sqr(to_pos - spos)
		if dist < min_dist_sqr then
			return true
		end
	end

	return false
end

function Sheeps.resetFlag()
	for _, sid in pairs(Sheeps.units) do
		msg.post(sid, "flagreset")
	end
end

function Sheeps.moveFlag(flag_pos)
	for _, sid in pairs(Sheeps.units) do

		local sheepPos = go.get_position(sid)
		local sheepDir = vmath.normalize(sheepPos - flag_pos)
		local sheepDist = vmath.length(sheepPos - flag_pos)
		local collision = false

		for _, cid in pairs(Sheeps.units) do
			if cid ~= sid then

				local collisionPos = go.get_position(cid)
				local collisionVect = collisionPos - flag_pos
				local proj = vmath.dot(collisionVect, sheepDir)

				if proj < sheepDist then
					local projPos = flag_pos + sheepDir * proj
					local dist = vmath.length_sqr(projPos - collisionPos)
					if dist < 100 then
						collision = true
						break
					end
				end
			end
		end

		if collision then
			msg.post(sid, "flagreset")
		else
			msg.post(sid, "flag", { pos = flag_pos })
		end
	end
end

--[[
function Sheeps.moveFlag(flag_pos)
	local min = -1
	local sheepId = nil
	for _, sid in pairs(Sheeps.units) do
		msg.post(sid, "flagreset")
		
		local spos = go.get_position(sid)
		local dist = vmath.length_sqr(flag_pos - spos)
		if min < 0 or dist < min then
			min = dist
			sheepId = sid
		end
	end

	if sheepId == nil then
		return
	end
	
	local sheepPos = go.get_position(sheepId)

	for _, sid in pairs(Sheeps.units) do
		local spos = go.get_position(sid)
		local dist = vmath.length_sqr(sheepPos - spos)
		if dist < (25 * 25) then
			msg.post(sid, "flag", { pos = flag_pos })
		end
	end
end
]]

function Sheeps.inVision(one_pos, two_pos)
	return vmath.length_sqr(one_pos - two_pos) < MAX_VISION
end

function Sheeps.inTooClose(one_pos, two_pos)
	return vmath.length_sqr(one_pos - two_pos) < MIN_DIST_S
end

function Sheeps.limitVectorLength(vec, limit)
	local length = vmath.length(vec)
	if length > limit then
		--vec.x = (vec.x / length) * limit
		--vec.y = (vec.y / length) * limit
		return vec * (limit / length)
	end

	return vec
end

function Sheeps.proccess(sheep_id)
	-- aligment / cohesion / separation
	local velMatching = vmath.vector3()
	local posCentering = vmath.vector3()
	local velCollision = vmath.vector3()

	local countVision = 0
	local countCentering = 0
	local countCollision = 0

	local sheedUrl = msg.url("stage", sheep_id, "script")
	local sheepPos = go.get_position(sheep_id)
	local sheepVel = go.get(sheedUrl, "velocity")

	for _, sid in pairs(Sheeps.units) do
		if sid ~= sheep_id then
			local spos = go.get_position(sid)
			local svel = go.get(msg.url("stage", sid, "script"), "velocity")

			if Sheeps.inVision(sheepPos, spos) then
				countVision = countVision + 1
				
				-- velocity matching
				--velMatching = velMatching + svel
				velMatching.x = velMatching.x + svel.x
				velMatching.y = velMatching.y + svel.y

				if Sheeps.inTooClose(sheepPos, spos) then
					-- collision avoidance
					countCollision = countCollision + 1

					local dir = sheepPos - spos
					local length = vmath.length(dir)
					if length > 0 then
						velCollision = velCollision + dir * (MIN_DIST - length)
					else
						velCollision.x = velCollision.x + math.random() * MIN_DIST
						velCollision.y = velCollision.y + math.random() * MIN_DIST
					end
				else
					-- position centering
					countCentering = countCentering + 1
					--posCentering = posCentering + spos
					posCentering.x = posCentering.x + spos.x
					posCentering.y = posCentering.y + spos.y
				end
			end
		end
	end
	
	local accelAligment = vmath.vector3()
	local accelCentering = vmath.vector3()
	local accelCollision = vmath.vector3()
	
	if countVision > 0 then
		-- velocity matching acceleration
		velMatching = velMatching * (1.0 / countVision)
		accelAligment = Sheeps.limitVectorLength(velMatching - sheepVel, MAX_ACCEL)

		-- centering acceleration
		if countCentering > 0 then
			posCentering = posCentering * (1.0 / countCentering)
			local velCentering = vmath.normalize(posCentering - sheepPos) * MAX_SPEED
			accelCentering = Sheeps.limitVectorLength(velCentering - sheepVel, MAX_ACCEL)
		end

		-- collision avoidance acceleration
		if countCollision > 0 then
			velCollision = vmath.normalize(velCollision) * MAX_SPEED
			accelCollision = Sheeps.limitVectorLength(velCollision - sheepVel, MAX_ACCEL)
		end
	end

	local accel = accelAligment * 0.5 + accelCentering * 1.0 + accelCollision * 1.5
	go.set(sheedUrl, "accel", accel)
end

return Sheeps
