package main

import "core:math"
import rl "vendor:raylib"

// --------------------------------------------------------------------------------------------
//         LIGHTS: https://gist.github.com/laytan/b0eed93e0a03f84d5e4aa97794c8395b
// --------------------------------------------------------------------------------------------
MAX_LIGHTS :: 4;

Light :: struct
{
	type:           LightType,
	range:          f32,
	position:       [3]f32,
	target:         [3]f32,
	color:          rl.Color,
	attenuation:    f32,
	rangeLoc:       i32,
	typeLoc:        i32,
	positionLoc:    i32,
	targetLoc:      i32,
	colorLoc:       i32,
	attenuationLoc: i32
};

LightType :: enum i32
{
	Directional,
	Point
};

lightsCount: i32;

CreateLight :: proc(type: LightType, position, target: [3]f32, color: rl.Color, shader: rl.Shader, range: f32) -> (light: Light)
{
	if lightsCount < MAX_LIGHTS
    {
		light.range = range;
		light.type = type;
		light.position = position;
		light.target = target;
		light.color = color;

		light.rangeLoc = i32(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].range", lightsCount)));
		light.typeLoc = i32(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].type", lightsCount)));
		light.positionLoc = i32(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].position", lightsCount)));
		light.targetLoc = i32(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].target", lightsCount)));
		light.colorLoc = i32(rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].color", lightsCount)));

		UpdateLightValues(shader, light);

		lightsCount += 1;
	}

	return;
}

UpdateLightValues :: proc(shader: rl.Shader, light: Light)
{
	light := light;

	rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.rangeLoc), &light.range, .FLOAT);
	rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.typeLoc), &light.type, .INT);

	rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.positionLoc), &light.position, .VEC3);

	rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.targetLoc), &light.target, .VEC3);

	color := [4]f32{ f32(light.color.r)/255, f32(light.color.g)/255, f32(light.color.b)/255, f32(light.color.a)/255 };
	rl.SetShaderValue(shader, rl.ShaderLocationIndex(light.colorLoc), &color, .VEC4);
}

// --------------------------------------------------------------------------------------------
//                                      GAME
// --------------------------------------------------------------------------------------------
SCREEN_WIDTH :: 1600;
SCREEN_HEIGHT :: 900;
ROWS :: 30;
COLS :: 40;
MAX_ENEMIES :: 500;
MAX_PROJECTILES :: 500;

TileID :: enum
{
    TILE_TREE_01,
    TILE_TREE_02,
    TILE_GROUND_01
};

Tile :: struct
{
    tilePath: cstring,
    model: rl.Model
};

Tiles: [ROWS][COLS]TileID;

Weapon :: struct
{
    level: i32,
    speed: f32,
    size: f32,
    damage: i32,
    attackSpeed: f32,
    attackTime: f32,
    projectileCount: i32
};

Tower :: struct
{
    hp : i32,
    maxHP : i32,
    position: rl.Vector3,
    range : f32,
    level: i32,
    weapons: [2]Weapon
};

Projectile :: struct
{
    weaponIdx: i32,
    position: rl.Vector3,
    direction: rl.Vector3,
    damage: i32,
    speed: f32,
    size: f32
};

Enemy :: struct
{
    level: i32,
    hp: i32,
    position: rl.Vector3,
    damage: i32,
    size: f32,
    speed: f32,
    gold: i32
};
DEFAULT_ENEMY: Enemy:
{
    level = 1,
    hp = 280,
    position = {-6, 1.5, 0},
    damage = 20,
    size = 0.2,
    speed = 0.3,
    gold = 20
};

GameState :: struct
{
    tower : Tower,
    gameTime: f32,
    gold: i32,
    spawnTimer: f32,
    enemyCount: i32,
    enemies: [MAX_ENEMIES]Enemy,
    projectileCount: i32,
    projectiles: [MAX_PROJECTILES]Projectile
};
DEFAULT_STATE: GameState:
{
    tower = {
        hp = 100,
        maxHP = 100,
        position = {0, 0.2, 0},
        range = 4,
        level = 1,
        weapons = {
            {level = 1, speed = 10, attackSpeed = 1.4, damage = 100, projectileCount = 1, size = 0.5}, // Arrow
            {level = 1, speed = 10, attackSpeed = 0.8, damage = 200, projectileCount = 1, size = 0.5}  // Cannon ball
        }
    },
    gameTime = 0,
};

main :: proc()
{
    rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT});
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tower Defence");
    rl.InitAudioDevice();
    rl.SetTargetFPS(240);

    gameState: GameState;
    gameState = DEFAULT_STATE;

    camera: rl.Camera;
    camera.position = { 0.0, 8.5, 4.8 };
    camera.target = { 0.0, -2.5, 0.0 };
    camera.up = { 0.0, 1.0, 0.0 };
    camera.fovy = 60.0;
    camera.projection = .PERSPECTIVE;

    shader := rl.LoadShader("assets/shaders/lighting.vs", "assets/shaders/lighting.fs");
    shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos");

    ambientLoc := rl.GetShaderLocation(shader, "ambient");
    rl.SetShaderValue(shader, ambientLoc, &cast([4]f32){ 0.1, 0.1, 0.1, 1.0 }, rl.ShaderUniformDataType.VEC4);

    lights: [MAX_LIGHTS]Light;
    lights[0] = CreateLight(.Point, { 0, 2, 0 }, { 6, 0, 0 }, rl.YELLOW, shader, 10.0);

    // ------------------------------ Load Sounds ------------------------------
    gameMusic := rl.LoadSound("assets/sounds/woodland_fantasy.ogg");
    rl.PlaySound(gameMusic);
    rl.SetSoundVolume(gameMusic, 0.4);

    // ------------------------------ Load Models ------------------------------
    tower := rl.LoadModel("assets/models/tower-round-crystals.glb");
    tower.materials[0].shader = shader;

    TileModels: [TileID]Tile = {
        .TILE_TREE_01 = {tilePath = "assets/models/tile-tree-double.glb"},
        .TILE_TREE_02 = {tilePath = "assets/models/tile-tree.glb"},
        .TILE_GROUND_01 = {tilePath = "assets/models/tile.glb"},
    };
    for &tile in TileModels
    {
        tile.model = rl.LoadModel(tile.tilePath);
        tile.model.materials[1].shader = shader;
    }

    EnemyModels: [4]rl.Model;
    EnemyModels[0] = rl.LoadModel("assets/models/enemy-ufo-a.glb");
    EnemyModels[1] = rl.LoadModel("assets/models/enemy-ufo-b.glb");
    EnemyModels[2] = rl.LoadModel("assets/models/enemy-ufo-c.glb");
    EnemyModels[3] = rl.LoadModel("assets/models/enemy-ufo-d.glb");

    ProjectileModels: [2]rl.Model;
    ProjectileModels[0] = rl.LoadModel("assets/models/weapon-ammo-arrow.glb");
    ProjectileModels[1] = rl.LoadModel("assets/models/weapon-ammo-cannonball.glb");

    // ------------------------------ Main game loop ------------------------------
    for !rl.WindowShouldClose()
    {
        // ------------------------------ Update game ------------------------------
        {
            gameState.gameTime += rl.GetFrameTime();

            lights[0].range = f32(gameState.tower.range);

            gridPosX: i32 = COLS / 2;
            gridPosY: i32 = ROWS / 2;
            towerRange := i32(gameState.tower.range);

            for row in gridPosY - towerRange..<gridPosY + towerRange
            {
                for col in gridPosY - towerRange..<gridPosX + towerRange
                {
                    dist := rl.Vector2Distance({f32(gridPosX), f32(gridPosY)}, {f32(col), f32(row)});
                    if i32(math.round(dist)) > towerRange - 2
                    {
                        continue;
                    }

                    Tiles[row][col] = .TILE_GROUND_01;
                }
            }
        }

        // cameraSpeed :: 0.5;
        // if rl.IsMouseButtonDown(.RIGHT) && rl.GetMouseDelta() != 0
        // {
        //     camera.target.xz -= rl.GetMouseDelta() * cameraSpeed * rl.GetFrameTime();
        //     camera.position.xz -= rl.GetMouseDelta() * cameraSpeed * rl.GetFrameTime();
        // }
        // camera.position += camera.target * rl.GetMouseWheelMove() * rl.GetFrameTime() * 5;
        rl.UpdateCamera(&camera, .CUSTOM);

        rl.SetShaderValue(shader, shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW], &camera.position, .VEC3);

        for i in 0..<MAX_LIGHTS
        {
            UpdateLightValues(shader, lights[i]);
        }

        // ------------------------------ Rendering ------------------------------
        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);
        rl.BeginMode3D(camera);
        rl.BeginShaderMode(shader);

        // Tower
        {
            rl.DrawModel(tower, gameState.tower.position, 1.0, rl.WHITE);
            
            // Shoot Arrow
            {
                weaponIdx: i32 = 0;
                weapon := &gameState.tower.weapons[weaponIdx];
                attackDelay := 1 / weapon.attackSpeed;
                if weapon.attackTime < attackDelay
                {
                    weapon.attackTime += rl.GetFrameTime();
                }

                if weapon.attackTime >= attackDelay
                {
                    target: Enemy = {};
                    targetIdx: i32 = -1;
                    smallestLen: f32 = 1000000;
    
                    // Find closest enemy
                    for enemyIdx: i32 = 0; enemyIdx < gameState.enemyCount; enemyIdx += 1
                    {
                        distToEnemy := rl.Vector3Length(gameState.enemies[enemyIdx].position - gameState.tower.position);
    
                        if distToEnemy < smallestLen
                        {
                            target = gameState.enemies[enemyIdx];
                            targetIdx = enemyIdx;
                            smallestLen = distToEnemy;
                        }
                    }
    
                    if targetIdx >= 0
                    {
                        dir := rl.Vector3Normalize(target.position - gameState.tower.position);
                        proj: Projectile = {
                            weaponIdx = weaponIdx,
                            damage = weapon.damage,
                            position = gameState.tower.position + dir * 0.2,
                            direction = dir,
                            speed = weapon.speed,
                            size = weapon.size
                        };

                        gameState.projectiles[gameState.projectileCount] = proj;
                        gameState.projectileCount += 1;

                        // Put weapon on CD
                        weapon.attackTime -= attackDelay;
                    }
                }
            }
        }

        // Update Projectiles
        {
            for projIdx: i32 = 0; projIdx < gameState.projectileCount; projIdx += 1
            {
                proj := &gameState.projectiles[projIdx];
                proj.position += proj.direction * proj.speed * rl.GetFrameTime();

                // rl.DrawModel(ProjectileModels[proj.weaponIdx], proj.position, proj.size, rl.WHITE);
                rotationAxis: rl.Vector3 = {0, 1, 0};
                angle := math.atan2(proj.direction.x, proj.direction.z) * rl.RAD2DEG;
                rl.DrawModelEx(ProjectileModels[proj.weaponIdx], proj.position, rotationAxis, angle, proj.size, rl.WHITE);

                // Check enemy collision
                {
                    for enemyIdx: i32 = 0; enemyIdx < gameState.enemyCount; enemyIdx += 1
                    {
                        enemy := &gameState.enemies[enemyIdx];

                        if rl.CheckCollisionSpheres(enemy.position, enemy.size / 2.0, proj.position, proj.size / 2.0)
                        {
                            enemy.hp -= proj.damage;

                            if enemy.hp <= 0
                            {
                                gameState.gold += enemy.gold;
                                // Remove enemy and copy over last enemy into slot
                                gameState.enemies[enemyIdx] = gameState.enemies[gameState.enemyCount - 1];
                                gameState.enemyCount -= 1;
                            }

                            // Remove enemy and copy over last enemy into slot
                            gameState.projectiles[projIdx] = gameState.projectiles[gameState.projectileCount - 1];
                            projIdx -= 1;
                            gameState.projectileCount -= 1;

                            break;
                        }
                    }
                }
            }
        }

        // Update Enemies
        {
            // Spawn system
            {
                spawnFrequency := 1 / (0.25 + gameState.gameTime / 100);
                gameState.spawnTimer += rl.GetFrameTime();
                enemySize := DEFAULT_ENEMY.size + DEFAULT_ENEMY.size * (gameState.gameTime / 100);
                enemySpeed := DEFAULT_ENEMY.speed + DEFAULT_ENEMY.speed * (gameState.gameTime / 200);
                gold := DEFAULT_ENEMY.gold + i32(gameState.gameTime / 20);
                hp := DEFAULT_ENEMY.hp + i32(gameState.gameTime * 0.5);

                if gameState.spawnTimer >= spawnFrequency
                {
                    gameState.enemies[gameState.enemyCount] = DEFAULT_ENEMY;

                    spawnRange := gameState.tower.range;
                    radians := f32(rl.GetRandomValue(0, 360)) * math.PI / 180.0;
                    dir: rl.Vector2 = {math.sin(radians), math.cos(radians)};
                    gameState.enemies[gameState.enemyCount].position.x = dir.x * f32(spawnRange);
                    gameState.enemies[gameState.enemyCount].position.z = dir.y * f32(spawnRange);
                    gameState.enemies[gameState.enemyCount].size = enemySize;
                    gameState.enemies[gameState.enemyCount].speed = enemySpeed;
                    gameState.enemies[gameState.enemyCount].gold = gold;
                    gameState.enemies[gameState.enemyCount].hp = hp;

                    gameState.enemyCount += 1;
                    gameState.spawnTimer -= spawnFrequency;
                }
            }

            for enemyIdx: i32 = 0; enemyIdx < gameState.enemyCount; enemyIdx += 1
            {
                enemy := &gameState.enemies[enemyIdx];
                dir := rl.Vector3Normalize(gameState.tower.position - enemy.position);

                enemy.position += dir * enemy.speed * rl.GetFrameTime();
                rl.DrawModel(EnemyModels[0], enemy.position, enemy.size, rl.WHITE);
                // rl.DrawSphereWires(enemy.position, enemy.size / 2.0, 16, 16, rl.RED);

                if rl.CheckCollisionSpheres(gameState.tower.position, 0.5, enemy.position, enemy.size / 2.0)
                {
                    gameState.tower.hp -= enemy.damage;

                    // Remove enemy and copy over last enemy into slot
                    gameState.enemies[enemyIdx] = gameState.enemies[gameState.enemyCount - 1];
                    enemyIdx -= 1;
                    gameState.enemyCount -= 1;

                    if (gameState.tower.hp <= 0)
                    {
                        gameState = DEFAULT_STATE;

                        for row in 0..<ROWS
                        {
                            for col in 0..<COLS
                            {
                                Tiles[row][col] = .TILE_TREE_01;
                            }
                        }
                    }
                }
            }
        }

        for row in 0..<ROWS
        {
            for col in 0..<COLS
            {
                tile := &TileModels[Tiles[row][col]];
                rl.DrawModel(tile.model, {-ROWS / 2 + f32(row), 0.0, -COLS / 2 + f32(col)}, 1.0, rl.WHITE);
            }
        }

        rl.EndShaderMode();
        // Draw spheres to show where the lights are
        for i in 0..<MAX_LIGHTS
        {
            rl.DrawSphereEx(lights[i].position, 0.2, 8, 8, lights[i].color);
        }

        rl.EndMode3D();

        rl.DrawFPS(SCREEN_WIDTH - 90, 10);

        // Draw HP bar
        hpBarSizeX: i32 = 400;
        hpBarSizeY: i32 = 40;
        hpPercent := f32(gameState.tower.hp) / f32(gameState.tower.maxHP);
        rl.DrawRectangle((SCREEN_WIDTH - hpBarSizeX) / 2.0, SCREEN_HEIGHT - hpBarSizeY - 10, hpBarSizeX, hpBarSizeY, rl.BLACK);
        rl.DrawRectangle((SCREEN_WIDTH - hpBarSizeX) / 2.0, SCREEN_HEIGHT - hpBarSizeY - 10, i32(f32(hpBarSizeX) * hpPercent), hpBarSizeY, rl.RED);
        
        text := rl.TextFormat("Gold: %d", gameState.gold);
        rl.DrawText(text, 10, 10, 30, rl.YELLOW);

        // UI
        {
            weapon := &gameState.tower.weapons[0];
            weaponCost: i32 = 100 + weapon.level * 6;
            if gameState.gold >= weaponCost
            {
                if rl.GuiButton({120, SCREEN_HEIGHT - 80, 90, 40}, "Arrow++")
                {
                    weapon.damage += 12;
                    weapon.attackSpeed += 0.1;
                    weapon.level += 1;
                    gameState.gold -= weaponCost;
                }
            }

            towerCost: i32 = 80 + gameState.tower.level * 16;
            if gameState.gold >= towerCost
            {
                if rl.GuiButton({120, SCREEN_HEIGHT - 120, 90, 40}, "Tower++")
                {
                    gameState.tower.maxHP += 20;
                    gameState.tower.hp += 22;
                    gameState.tower.range += 0.5;
                    gameState.tower.level += 1;

                    gameState.gold -= towerCost;
                }
            }
        }
        rl.EndDrawing();
    }

    rl.UnloadModel(tower);
    rl.CloseAudioDevice();
    rl.CloseWindow();
}
