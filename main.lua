debug = true
local utf8 = require("utf8")

require 'src/utility'
require 'src/assets'
require 'src/maps'
require 'src/player'
require 'src/ui'
require 'src/sounds'
require 'src/projectiles'
require 'src/scenes'

function love.load()
  love.window.setMode(1024, 768)
	menu_bg = love.graphics.newImage('gfx/bg/menu.jpg')
	menu_music = love.audio.newSource('music/menu.ogg', 'stream')
	font = love.graphics.newFont('Avara.ttf', 40)
	love.graphics.setFont(font)
  preloadGraphicsResources()

    -- global ingame vars
	menu = 1
	menu_items = {}
	menu_items[1] = 'Rymyämään ->'
  menu_items[2] = 'Vääntämään :F'
	menu_items[3] = 'Nukkumaan -.-'
	menuchoice = 1
  menuCooldown = 0--time until menu option can be changed
  menuWait = 0.3 --How often menu options can be changed
	loading = 0
	game = 0
	intermission = 0
  events_ticker = 50 -- interval
  cops_arrival_timer = 60 --how long till cops are called on you for loitering
	generateTileProperties()
  scene = 'no_scene'
	tile_size = 32  -- finally!! power of two
  splashSize = 0.45
  splashIncreasing = true
  splashMaxSize = 0.55
  splashMinSize = 0.35
  splashText = "Default splashtext"--Default value
  splashTable = {}
  playerScore = 0
  playerName = "Deeku"

  --option variables
  --todo: save into an options file
  master_volume = 0.3
  love.audio.setVolume( master_volume ) -- all other volume levels are up to maximum of master_volume
  music_volume = 1
  effects_volume = 1
  speech_volume = 1

  --filesystem
  for line in love.filesystem.lines("splashtexts.txt") do
    table.insert(splashTable, line)
  end
  math.randomseed( os.time() )--seed for randomization from time
  splashText = splashTable[math.random(1, #splashTable )]--number between 1 and last integer in table
  --scores
 
  if love.filesystem.exists("highscores.dat") ~= true then
    scores = love.filesystem.newFile("highscores.dat")
    data = scores:open("w")
    scores:close()
  end
  love.keyboard.setKeyRepeat(true)

  getScoreBoardEntries(4)
	--global trigger etc. vars
	gore_ticker = 0

	--tiles
	loadTileResource()

	--other image resources
	loadActorImages()
  loadItemImages()
	loadProjectileImages()

	--audio
	loadJukeboxSongs()
  loadSpecialSongs()
  loadGenericSounds()

	--player
	playerCreate()

	--actorbase
	actors = {}

	--projectilebase
	projectiles = {}
  
  --itembase
  items = {}

	--do init stuff
	gamePreload()
end

function handleActors()
	for i=1, tablelength(actors) do
		runActorLogic(i)
		checkCollisionWithPlayer(i)
	end
	destroyActors()
end

function createNewItem(of_type, coord_x, coord_y)
  -- map items: Only need a type and coordinates for now.
  new_index = tablelength(items) + 1
  items[new_index] = {}
  items[new_index]['type'] = of_type
  items[new_index]['x'] = coord_x
  items[new_index]['y'] = coord_y
  items[new_index]['visual_x'] = coord_x * tile_size
  items[new_index]['visual_y'] = coord_y * tile_size
  items[new_index]['picked_up'] = false
end

function createNewActor(of_type, state, coord_x, coord_y, weight)
	new_index = tablelength(actors) + 1
	actors[new_index] = {}
	actors[new_index]['type'] = of_type
	actors[new_index]['x'] = coord_x
	actors[new_index]['y'] = coord_y
  actors[new_index]['target_x'] = nil
  actors[new_index]['target_y'] = nil
	actors[new_index]['visual_x'] = coord_x * tile_size
	actors[new_index]['visual_y'] = coord_y * tile_size
	actors[new_index]['moving'] = 0
	actors[new_index]['weight'] = weight
	actors[new_index]['destroyed'] = false
  actors[new_index]['status'] = state
  actors[new_index]['frame'] = 1
  actors[new_index]['animation_delay'] = 15
  actors[new_index]['direction'] = 'up' --left,down,right,up

	-- variables that depend on actor type
	-- lisko or demon: spiritual enemies. No damage gained from physical attacks
	if of_type == 'lisko' or of_type == 'demon' then
		actors[new_index]['physical_factor'] = 0
		actors[new_index]['spiritual_factor'] = 1
		actors[new_index]['hp'] = 1
  elseif of_type == 'cop' then
    actors[new_index]['physical_factor'] = 1
		actors[new_index]['spiritual_factor'] = 0.0001
		actors[new_index]['hp'] = 200
  else  --undetermined. Probably generic humans
    actors[new_index]['physical_factor'] = 1
    actors[new_index]['spiritual_factor'] = 0.0001  -- you can puke humans to death, it's just ridiculously hard
    actors[new_index]['hp'] = 100
  end
  
  -- load asset
end


function setActorToBeRemoved(actor)
	--set actor to be removed, as per table safety https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating
	actors[actor]['destroyed'] = true
end

function destroyActors()
	-- iterate backwards, removing any actors set to be removed
	for i=tablelength(actors),1,-1 do
		if actors[i]['destroyed'] == true then
			table.remove(actors, i)
		end
	end
end

function runActorLogic(actor)
	--provide with index
	if actors[actor]['type'] == 'beer_guy' then
		-- move around randomly
		-- todo: recruitment
		dir = love.math.random(5)
		if dir == 1 then
			actor_move(actor, actors[actor]['x']-1, actors[actor]['y'])
		elseif dir == 2 then
			actor_move(actor, actors[actor]['x']+1, actors[actor]['y'])
		elseif dir == 3 then
			actor_move(actor, actors[actor]['x'], actors[actor]['y']-1)
		elseif dir == 4 then
			actor_move(actor, actors[actor]['x'], actors[actor]['y']+1)
		elseif dir == 5 then
			-- no move
		end
		
		-- no score is awarded for destroying fellow beer guys
		if actors[actor]['hp'] < 1 then
			-- todo: maybe do something different?
			actors[actor]['destroyed'] = true
			incrementPlayerScore(0)
		end
	end

	--lisko: sprawl around randomly!
	if actors[actor]['type'] == 'lisko' then
		if actors[actor]['status'] == 'alert' then
			-- chase player
			if player['x'] < actors[actor]['x'] then
				actor_move(actor, actors[actor]['x']-1, actors[actor]['y'])
			end
			if player['x'] > actors[actor]['x'] then
				actor_move(actor, actors[actor]['x']+1, actors[actor]['y'])
			end
			if player['y'] < actors[actor]['y'] then
				actor_move(actor, actors[actor]['x'], actors[actor]['y']-1)
			end
			if player['y'] > actors[actor]['y'] then
				actor_move(actor, actors[actor]['x'], actors[actor]['y']+1)
			end
		else
			dir = love.math.random(5)
			if dir == 1 then
				actor_move(actor, actors[actor]['x']-1, actors[actor]['y'])
			elseif dir == 2 then
				actor_move(actor, actors[actor]['x']+1, actors[actor]['y'])
			elseif dir == 3 then
				actor_move(actor, actors[actor]['x'], actors[actor]['y']-1)
			elseif dir == 4 then
				actor_move(actor, actors[actor]['x'], actors[actor]['y']+1)
			elseif dir == 5 then
				-- no move
			end
		end

		-- set chasing status if player is too near
		if player['x'] - actors[actor]['x'] < 5 and player['x'] - actors[actor]['x'] > -5 then
			if player['y'] - actors[actor]['y'] < 5 and player['y'] - actors[actor]['y'] > -5 then
				actors[actor]['status'] = 'alert'
			end
		else
			actors[actor]['status'] = 'normal'
		end
		if actors[actor]['hp'] < 1 then
			actors[actor]['destroyed'] = true
			incrementPlayerScore(1)
		end
	end
	
	if actors[actor]['type'] == 'demon' then
		-- demon glides around
		-- todo: create an actual "path" it traverses instead of teleporting around
		dir_x = love.math.random(-5, 5)
		dir_y = love.math.random(-5, 5)

		actor_move(actor, actors[actor]['x'] + dir_x, actors[actor]['y'] + dir_y)

		--actors[actor]['moving'] = actors[actor]['moving'] - 1
		if actors[actor]['hp'] < 1 then
		  actors[actor]['destroyed'] = true
		  incrementPlayerScore(5)
		end
	end

  if actors[actor]['type'] == 'cop' then
    -- cop hangs around until provoked
    -- anti-loiter cops chase players
    if actors[actor]['status'] == 'anti_loiter' then
      -- chase player
      if player['x'] < actors[actor]['x'] then
        actor_move(actor, actors[actor]['x']-1, actors[actor]['y'])
        actors[actor]['direction'] = 'left'
      end
      if player['x'] > actors[actor]['x'] then
        actor_move(actor, actors[actor]['x']+1, actors[actor]['y'])
        actors[actor]['direction'] = 'right'
      end
      if player['y'] < actors[actor]['y'] then
        actor_move(actor, actors[actor]['x'], actors[actor]['y']-1)
        actors[actor]['direction'] = 'up'
      end
      if player['y'] > actors[actor]['y'] then
        actor_move(actor, actors[actor]['x'], actors[actor]['y']+1)
        actors[actor]['direction'] = 'down'
      end
      --if hitting player, push player to that direction
      actors[actor]['moving'] = actors[actor]['moving'] - 1
    end
      
    if actors[actor]['hp'] < 1 then
      actors[actor]['destroyed'] = true
      incrementPlayerScore(100)
    end
	end
  -- for each actor, move it to it's target coordinate after it's moving counter is < 1
  if actors[actor]['moving'] < 1 then
    if actors[actor]['target_x'] ~= nil then
      actors[actor]['x'] = actors[actor]['target_x']
      actors[actor]['target_x'] = nil
    end
    if actors[actor]['target_y'] ~= nil then
      actors[actor]['y'] = actors[actor]['target_y']
      actors[actor]['target_y'] = nil
    end
  end
  actors[actor]['moving'] = actors[actor]['moving'] - 1
end

function itemGeneration()
  -- random generate map specific items if need be
  -- some beer/items perhaps?
  beers = love.math.random(5)
  for i=1, beers do
    createNewItem('beer', love.math.random(24),love.math.random(12))
  end
end

function normalActorGeneration()
	-- call this after player is about to enter new map!
	-- empty actors list and generate it again
	actors = {}
	-- a certain amount of liskos from 50 - promille factor, but minimum of 5.
	liskos = 50 - player['promilles']
  if liskos <= 0 then
    liskos = 5
  end
  
  -- demonis amount is promilles / 10, minimum is none!
	demonis = 10 - player['promilles'] / 10

	for i=1, liskos do
		createNewActor('lisko', 'normal', love.math.random(24),love.math.random(12), 25)
	end
	for i=1, demonis do
		createNewActor('demon', 'normal', love.math.random(24),love.math.random(12), 50)
	end
	
    -- small chance to spawn a beer guy on each map
    random_chance = love.math.random(100)
    if random_chance < 10 then
		createNewActor('beer_guy', 'normal', love.math.random(24),love.math.random(12), 50)
	end
end

function drawSector(matrix)
	-- draw a sector upon which körsy walketh. 20x20 tiles.
	for x=1, table.getn(matrix) do
		for y=1, table.getn(matrix[x]) do
			tile_type = map[x][y] -- get tile type
      love.graphics.draw(resource, tiles[tile_type], x * tile_size, y * tile_size)
		end
	end
end

function genericControls()
	--these controls apply everywhere
	--quit
	if love.keyboard.isDown('escape') then
		love.event.quit()
	end
end

function gamePreload()
	start_map = generateMap()
	normalActorGeneration()
  itemGeneration()
  resetPlayerScore()
end

function damageActor(actor, projectile)
  -- todo: compare projectile and actor to see what effect was on actor
end

function goreVisuals()
	-- gore: splash screen red quickly when taking damage
	-- todo: use an alpha layered blood splash image as effect?
	for i=1, gore_ticker do
		love.graphics.setColor(255, 255-(gore_ticker*20), 255-(gore_ticker*20))
	end
end

function actor_move(actor, coord_x, coord_y)
	-- mostly same as player, except for targeted actor (target with index)

	-- are we still moving?
	if actors[actor]['moving'] < 1 then

		-- are we inside bounds?
		if coord_x > 0 and coord_x <= tablelength(map) then

			for x=1, tablelength(map) do
				if coord_y > 0 and coord_y <= tablelength(map[x]) then

					-- tile in question can be moved on?
					if tile_attrs[map[coord_x][coord_y]] == nil then
						overlap = false
						-- no actor would be overlapping with move?
						for i=1, tablelength(actors) do
							if coord_x == actors[i]['x'] and coord_y == actors[i]['y'] then
								overlap = true
							end
						end
						if overlap == false then
							-- move. set it on path
							actors[actor]['moving'] = actors[actor]['weight']
							-- actors[actor]['x'] = coord_x
              actors[actor]['target_x'] = coord_x
							-- actors[actor]['y'] = coord_y
              actors[actor]['target_y'] = coord_y
						end
					end
				end

			end

		end
	end
end

function playerInteractWithActor(actor)
	-- check whether or not player can press button to interact with NPC
	-- do interaction if possible
	-- simple adjacency and direction rule
	if player['direction'] == 'up' and actors[actor]['x'] == player['x'] and actors[actor]['y'] == player['y'] - 1 then
	    return true
	elseif player['direction'] == 'down' and actors[actor]['x'] == player['x'] and actors[actor]['y'] == player['y'] + 1 then
	    return true
	elseif player['direction'] == 'left' and actors[actor]['x'] == player['x'] - 1 and actors[actor]['y'] == player['y'] then
	    return true
	elseif player['direction'] == 'right' and actors[actor]['x'] == player['x'] + 1 and actors[actor]['y'] == player['y'] then
	    return true
	-- todo: other directions
	else
		return false
	end
end

function playerInteractWithMap()
	-- check whether or not player can interact with a tile on the map
	-- Depending on tile type, do something MAYBE
	-- else play "cant do" sound in true spirit of early FPS games ("uhh" from Doom!)
	-- simple adjacency and direction rule
	-- todo: check that player does not interact out of bounds
	for i=1, tablelength(actors) do
		playerInteractWithActor(i)
	end
	if player['direction'] == 'up' then
		interact_target = start_map[player['x']][player['y']-1]
	elseif player['direction'] == 'down' then
	    interact_target = start_map[player['x']][player['y']+1]
	elseif player['direction'] == 'left' then
	    interact_target = start_map[player['x']-1][player['y']]
	elseif player['direction'] == 'right' then
	    interact_target = start_map[player['x']+1][player['y']]
	end
end

function checkCollisionWithPlayer(actor)
	-- if collision between id'd actor and player happens, do something
	if actors[actor]['x'] == player['x'] and actors[actor]['y'] == player['y'] then
		if actors[actor]['type'] == 'lisko' or actors[actor]['type'] == 'demon' then
			applyPlayerEffect('takeDamage', -15)
			setActorToBeRemoved(actor)
		elseif actors[actor]['type'] == 'cop' then
			if actors[actor]['status'] == 'anti_loiter' then
        --push player
        if actors[actor]['direction'] == 'left' then
          player_move(player['x']-1, player['y'], start_map)
        elseif actors[actor]['direction'] == 'right' then
          player_move(player['x']+1, player['y'], start_map)
        elseif actors[actor]['direction'] == 'down' then
          player_move(player['x'], player['y']+1, start_map)
        elseif actors[actor]['direction'] == 'up' then
          player_move(player['x'], player['y']-1, start_map)
        end
      end
    end
	end
end


function gameOver()
	--game over, my dude, game over! You lose. Transition to end screen and tell player to f off + write score entry
	menu_items[1] = 'Takasin baanalle :p'
	menu_items[2] = 'Mee valikkoo'
	menu_items[3] = 'PAINU VITHUU :o'
  writeEntryIntoScoreBoard(playerName, playerScore)
  getScoreBoardEntries(4)
	menu = 2
	game = 0
end

function setItemToBeRemoved(index)
	--set item to be removed, as per table safety https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating
	items[index]['picked_up'] = true
end

function removeItems()
	-- iterate backwards, removing any that were picked up
	for i=tablelength(items),1,-1 do
		if items[i]['picked_up'] == true then
			table.remove(items, i)
		end
	end
end

function handleItems()
  -- check if item collides with player (TODO possibly other actors!)
  -- apply effect depending on item type
  for i=1, tablelength(items) do
    if items[i]['x'] == player['x'] and items[i]['y'] == player['y'] then
      --beer: raise drunkenness, restore some hitpoints, raise max_hp by 1 if below threshold
      if items[i]['type'] == 'beer' then
        player['promilles'] = player['promilles'] + 15
        player['hp'] = player['hp'] + 5
        incrementPlayerScore(2)
        if player['max_hp'] < 200 then
          player['max_hp'] = player['max_hp'] + 1
        end
        playSoundEffect(sfx['beer_drink'])
      end
      setItemToBeRemoved(i)
    end
  end
  removeItems()
end

function handleWorldVars()
  --check status and update game based on global variables
  --generic and semi-random events like weather, cop arrivals
  --everything basically that's not tied to intermissions
  events_ticker = events_ticker - 1
  if events_ticker < 1 then
    if cops_arrival_timer > 0 then
      cops_arrival_timer = cops_arrival_timer - 1
    end
    events_ticker = 50
  end
  
  if cops_arrival_timer == 0 then
    --create a cop on random edge and set it to 'anti_loiter'
    createNewActor('cop', 'anti_loiter', 1, 1, 15)
    cops_arrival_timer = -100  --dont allow second cop to appear
  end
end

--main game loop
function handleGame()
	--not loading a new area
	if intermission == 0 then
		checkPlayerStatus() -- no point executing stuff if ur dead
		genericControls()
		gameJukebox()
    handleItems()
		handleActors()
		handleProjectiles()
		playerControls()
    if player['cooldown'] > 0 then
      player['cooldown'] = player['cooldown'] - 1
    end
    handleWorldVars()
	--loading a new area
else
    --determine if a scene will be generated and what type if so
    --todo: scene events happen currently at a fixed random chance 1/10
    --todo: move to separate functions
    scene_trigger = love.math.random(100)
    scene = 'no_scene'
    if scene_trigger < 10 then
      --scene triggered: resolve scene type
      --todo: always guitar man scene
      scene = 'guitar_man_intersection'
      start_map = guitarManMap()
    else
      start_map = generateMap() --todo: change map variable name
    end
    
    --normal scene
    if scene == 'no_scene' then
      itemGeneration()
      normalActorGeneration()
    else
      --other scenes
      guitarManSceneSetup()
    end
		playerArrive()
    --reset world triggers
    cops_arrival_timer = 60
    events_ticker = 50
		intermission = 0
	end
end

function drawItems()
  for i=1, tablelength(items) do
    tybe = items[i]['type']
    love.graphics.draw(resource, item_images[tybe], items[i]['visual_x'], items[i]['visual_y'])
  end
end

function drawActors()
	for i=1, tablelength(actors) do
    -- todo: active frames/animations system for actors
    tybe = actors[i]['type']
    frame = actors[i]['frame']
		love.graphics.draw(dynamics_resource, actors_images[tybe][frame], actors[i]['visual_x'], actors[i]['visual_y'])
    actors[i]['animation_delay'] = actors[i]['animation_delay'] - 1
    if actors[i]['animation_delay'] < 1 then
      actors[i]['frame'] = actors[i]['frame'] + 1
      if actors[i]['frame'] > tablelength(actors_images[tybe]) then
        actors[i]['frame'] = 1
      end
      actors[i]['animation_delay'] = 15
    end
    
		if actors[i]['visual_x'] < actors[i]['x'] * tile_size then
			actors[i]['visual_x'] = actors[i]['visual_x'] + 4
		end
		if actors[i]['visual_x'] > actors[i]['x'] * tile_size then
			actors[i]['visual_x'] = actors[i]['visual_x'] - 4
		end
		if actors[i]['visual_y'] < actors[i]['y'] * tile_size then
			actors[i]['visual_y'] = actors[i]['visual_y'] + 4
		end
		if actors[i]['visual_y'] > actors[i]['y'] * tile_size then
			actors[i]['visual_y'] = actors[i]['visual_y'] - 4
		end
	end
end

function drawGame()
	if intermission == 0 then
		drawSector(start_map)
    -- BEGIN draw player and player movement
		if player['visual_x'] < player['x'] * tile_size then
			player['visual_x'] = player['visual_x'] + 4
		end
		if player['visual_x'] > player['x'] * tile_size then
			player['visual_x'] = player['visual_x'] - 4
		end
		if player['visual_y'] < player['y'] * tile_size then
			player['visual_y'] = player['visual_y'] + 4
		end
		if player['visual_y'] > player['y'] * tile_size then
			player['visual_y'] = player['visual_y'] - 4
		end
		if player['moving'] > 1 then
      player['walk_delay'] = player['walk_delay'] - 1
    end
    -- END draw player and player movement
    
    drawItems()
		drawActors()
		drawProjectiles()
		direction = player['direction']

    if player['walk_delay'] < 1 then
      player['activeFrame'] = player['activeFrame'] + 1
      if player['activeFrame'] > tablelength(player['frames'][direction]) then
        player['activeFrame'] = 1
      end
      player['walk_delay'] = 10
      
      -- play footstep sound if tile type has sound effect loaded
      tile_type = start_map[player['x']][player['y']]
      if setContains(player['footsteps'], tile_type) then
        -- Only on every second frame change
        if player['activeFrame'] % 2 == 0 then
          random_pick = love.math.random(1, tablelength(player['footsteps'][tile_type]))
          player['footsteps'][tile_type][random_pick]:stop()
          player['footsteps'][tile_type][random_pick]:play()
        end
      end
    end
    activeFrame = player['activeFrame']
		love.graphics.draw(player['image'], player['frames'][direction][activeFrame], player['visual_x'], player['visual_y'])
	end
end

function drawEffects()
	-- visual effects, hallucinations etc. miscellanous stuff

	-- damage color "tint" - screen goes gray in accordance with damage amount
	damage_factor = 155 + player['hp']
	if player['hp'] < 25 then
		damage_factor = damage_factor - 100
	end
	love.graphics.setColor(damage_factor,damage_factor,damage_factor)

	-- hit splash
	if gore_ticker > 0 then
		goreVisuals()
		gore_ticker = gore_ticker - 1
	end
end

function love.draw()
	if menu > 0 and game == 0 then
		drawMenu()
	elseif game == 1 and menu == 0 then
		drawGame()
		drawUI()
	end
end

function love.textinput(t)
  --main menu, name
  if menu == 1 and menuchoice == 0 then
    playerName = playerName .. t
  end
end

function love.keypressed(key)
  if key == "backspace" and menu == 1 and menuchoice == 0 then
    -- get the byte offset to the last UTF-8 character in the string.
    local byteoffset = utf8.offset(playerName, -1)

    if byteoffset then
        -- remove the last UTF-8 character.
        -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
        playerName = string.sub(playerName, 1, byteoffset - 1)
    end
  end
end

function love.update(dt)
  menuCooldown = math.max ( 0, menuCooldown - dt )
	if menu > 0 and game == 0 then
		handleMenu()
	else
		handleGame()
	end
end
