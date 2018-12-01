local Sheeps = {}

Sheeps.units = {}

local MAX_SPEED = 30.0
local MAX_ACCEL = 5.0

local MIN_DIST = 15.0
local MIN_DIST_S = MIN_DIST * MIN_DIST
local MAX_VISION = 50.0 * 50.0

function Sheeps.add(sheep_id)
	table.insert(Sheeps.units, sheep_id)
end

function Sheeps.update()
	for _, sid in pairs(Sheeps.units) do
		Sheeps.proccess(sid)
	end
end

function Sheeps.moveFlag(flag_pos)

	local min = -1
	local sheep = 0
	for _, sid in pairs(Sheeps.units) do
		--msg.post(sid, "flag", { pos = flag_pos })
		
		local spos = go.get_position(sid)
		local dist = vmath.length_sqr(flag_pos - spos)
		if min < 0 or dist < min then
			min = dist
			sheep = sid
		end
	end

	if sheep ~= 0 then
		msg.post(sheep, "flag", { pos = flag_pos })
	end
end

function Sheeps.inVision(one_pos, two_pos)
	return vmath.length_sqr(one_pos - two_pos) < MAX_VISION
end

function Sheeps.inTooClose(one_pos, two_pos)
	return vmath.length_sqr(one_pos - two_pos) < MIN_DIST_S
end

function Sheeps.limitVectorLength(vec, limit)
	local length = vmath.length(vec)
	if length > limit then
		vec.x = (vec.x / length) * limit
		vec.y = (vec.y / length) * limit
	end

	return vec
end

function Sheeps.proccess(sheep_id)
	-- aligment / cohesion / separation
	local velMatching = vmath.vector3()
	local posCentering = vmath.vector3()
	local velCollision = vmath.vector3()

	local countVision = 0
	local countCollision = 0

	local sheepPos = go.get_position(sheep_id)
	local sheepVel = go.get(msg.url("main", sheep_id, "script"), "velocity")

	for _, sid in pairs(Sheeps.units) do
		if sid ~= sheep_id then
			local spos = go.get_position(sid)
			local svel = go.get(msg.url("main", sid, "script"), "velocity")

			if Sheeps.inVision(sheepPos, spos) then
				countVision = countVision + 1
				
				-- velocity matching
				velMatching = velMatching + svel
				-- position centering
				posCentering = posCentering + spos

				-- collision avoidance
				if Sheeps.inTooClose(sheepPos, spos) then
					countCollision = countCollision + 1

					local dir = sheepPos - spos
					local length = vmath.length(dir)
					velCollision = velCollision + dir * (MIN_DIST - length)
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
		posCentering = posCentering * (1.0 / countVision)
		local velCentering = vmath.normalize(posCentering - sheepPos) * MAX_SPEED
		accelCentering = Sheeps.limitVectorLength(velCentering - sheepVel, MAX_ACCEL)

		-- collision avoidance acceleration
		if countCollision > 0 then
			velCollision = vmath.normalize(velCollision) * MAX_SPEED
			accelCollision = Sheeps.limitVectorLength(velCollision - sheepVel, MAX_ACCEL)
		end
	end

	local accel = accelAligment * 1.0 + accelCentering * 1.0 + accelCollision * 3.0
	msg.post(sheep_id, "acceleration", { accel = accel })
end

return Sheeps
