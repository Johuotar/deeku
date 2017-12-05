--[[
Functions for player character generation and action handling.
--]]

function applyPlayerEffect(effect, context_variable)
	-- apply any kind of effect based on name on player.
	if effect == "takeDamage" then
		-- todo: apply sound effect, color splash and shit
		gore_ticker = 20 -- set splash effect in motion
		alterPlayerStat("hp", context_variable)
		playerGrunt()
	end
end

function alterPlayerStat(stat_name, amount)
	-- alter a player stat by an amount. Use minus value to subtract
	player[stat_name] = player[stat_name] + amount
	-- todo: need other operations to handle?
end

function player_move(coord_x, coord_y, map)
	-- check where player is about to move, allow or disallow move based on that and resolve effects
	-- apply speed / delay factor to movement
	-- can be used for teleport

	-- are we still moving?
	if player['moving'] < 1 then

		-- are we inside bounds?
		if coord_x > 0 and coord_x <= tablelength(map) then

			for x=1, tablelength(map) do
				if coord_y > 0 and coord_y <= tablelength(map[x]) then

					-- tile in question can be moved on?
					if tile_attrs[map[coord_x][coord_y]] == nil then
						-- move. set us on path
						player['moving'] = 10
						player['x'] = coord_x
						player['y'] = coord_y
						player['activeFrame'] = 2
					end
				elseif coord_y > tablelength(map[x]) and player['arrival'] ~= 'down' then
					player['arrival'] = 'up'
					intermission = 1
				elseif coord_y < 1 and player['arrival'] ~= 'up' then
					player['arrival'] = 'down'
					intermission = 1
				end

			end
		-- arrival direction determiningin, always trigger intermission
		elseif coord_x > tablelength(map) and player['arrival'] ~= 'right' then
			player['arrival'] = 'left'
			intermission = 1
		elseif coord_x < 1 and player['arrival'] ~= 'left' then
			player['arrival'] = 'right'
			intermission = 1
		end
	end
end

function playerCreate()
	player = {}
	player['x'] = 1
	player['y'] = 16
	player['visual_x'] = 1 * tile_size
	player['visual_y'] = 16 * tile_size
	player['moving'] = 0
	player['weight'] = 10
	player['image'] = love.graphics.newImage('gfx/CharacterSheet.png')
	player['arrival'] = 'left'
	player['cooldown'] = 0
	player['direction'] = 'right'

	--stats player
	player['hp'] = 100
	player['max_hp'] = 100
	player['fatigue'] = 0
	player['promilles'] = 0
	player['equipped'] = 'puke'

	player['frames'] = {}
	--directional frames player
	player['frames']['down'] = {}
	player['frames']['down'][1] = love.graphics.newQuad(0,0,32,32, player['image']:getDimensions())
	player['frames']['down'][2] = love.graphics.newQuad(32,0,32,32, player['image']:getDimensions())
  player['frames']['down'][3] = love.graphics.newQuad(64,0,32,32, player['image']:getDimensions())
	player['frames']['up'] = {}
	player['frames']['up'][1] = love.graphics.newQuad(0,32,32,32, player['image']:getDimensions())
	player['frames']['up'][2] = love.graphics.newQuad(32,32,32,32, player['image']:getDimensions())
  player['frames']['up'][3] = love.graphics.newQuad(64,32,32,32, player['image']:getDimensions())
	player['frames']['left'] = {}
	player['frames']['left'][1] = love.graphics.newQuad(0,96,32,32, player['image']:getDimensions())
	player['frames']['left'][2] = love.graphics.newQuad(32,96,32,32, player['image']:getDimensions())
	player['frames']['right'] = {}
	player['frames']['right'][1] = love.graphics.newQuad(0,64,32,32, player['image']:getDimensions())
	player['frames']['right'][2] = love.graphics.newQuad(32,64,32,32, player['image']:getDimensions())
	player['direction'] = 'down'
	player['activeFrame'] = 1

	--generic sound effects
	player['grunts'] = {}
	player['grunts'][1] = love.audio.newSource('sfx/zombie-1.wav', 'static')
	player['grunts'][2] = love.audio.newSource('sfx/zombie-2.wav', 'static')
	player['grunts'][3] = love.audio.newSource('sfx/zombie-3.wav', 'static')

  player['attacks'] = {}
  player['attacks']['puke'] = love.audio.newSource('sfx/zombie-8.wav', 'static')
  player['attacks']['puke']:setPitch(1.5)
end

function playerArrive()
	if player['arrival'] == 'left' then
		player['x'] = 1
		player['visual_x'] = 1 * tile_size
	elseif player['arrival'] == 'right' then
		player['x'] = tablelength(start_map)
		player['visual_x'] = 32 * tile_size
	elseif player['arrival'] == 'up' then
		player['y'] = 1
		player['visual_y'] = 1 * tile_size
	elseif player['arrival'] == 'down' then
		player['y'] = tablelength(start_map[1]) --todo: fix map variable name
		player['visual_y'] = tablelength(start_map[1]) * tile_size
	end
end

function playerUseItem()
	-- launch a player item use depending on chosen item.
	if player['cooldown'] < 1 then
		if player['equipped'] == 'puke' then
			-- create a puke ball
			createNewProjectile('puke', player['x'], player['y'], player['direction'])
      playSoundEffect(player['attacks']['puke'])
      player['cooldown'] = 25
		end
	end
end

function checkPlayerStatus()
	-- check and apply whatever persistent statuses player has. Also check death.
	if player['hp'] < 1 then
		gameOver()
	end
end

function playerControls()
	-- todo: Something so you can bind keys
	if love.keyboard.isDown('down') then
		player_move(player['x'], player['y'] + 1, start_map)
		player['direction'] = 'down'
	elseif love.keyboard.isDown('up') then
		player_move(player['x'], player['y'] - 1, start_map)
		player['direction'] = 'up'
	elseif love.keyboard.isDown('left') then
		player_move(player['x'] - 1, player['y'], start_map)
		player['direction'] = 'left'
	elseif love.keyboard.isDown('right') then
		player_move(player['x'] + 1, player['y'], start_map)
		player['direction'] = 'right'
	end

	-- attack/use active item
	if love.keyboard.isDown('space') then
		-- todo: check what item is active
		playerUseItem()
	end
end