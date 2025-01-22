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

main :: proc()
{
    rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT});
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tower Defence");
    rl.SetTargetFPS(240);

    camera: rl.Camera;
    camera.position = { 0.0, 7.0, 7.0 };
    camera.target = { 0.0, -2.0, 0.0 };
    camera.up = { 0.0, 1.0, 0.0 };
    camera.fovy = 60.0;
    camera.projection = .PERSPECTIVE;

    shader := rl.LoadShader("assets/shaders/lighting.vs", "assets/shaders/lighting.fs");
    shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos");

    ambientLoc := rl.GetShaderLocation(shader, "ambient");
    rl.SetShaderValue(shader, ambientLoc, &cast([4]f32){ 0.1, 0.1, 0.1, 1.0 }, rl.ShaderUniformDataType.VEC4);

    lights: [MAX_LIGHTS]Light;
    lights[0] = CreateLight(.Point, { 0, 2, 0 }, { 6, 0, 0 }, rl.YELLOW, shader, 10.0);

    tower := rl.LoadModel("assets/models/tower-round-crystals.glb");
    tower.materials[0].shader = shader;

    position := rl.Vector3{0.0, 0.2, 0.0};
    towerRange: f32 = 8.0;

    TileModels: [TileID]Tile = {
        .TILE_TREE_01 = {tilePath = "assets/models/tile-tree-double.glb"},
        .TILE_TREE_02 = {tilePath = "assets/models/tile-tree.glb"},
        .TILE_GROUND_01 = {tilePath = "assets/models/tile.glb"},
    };
    for &tile in &TileModels
    {
        tile.model = rl.LoadModel(tile.tilePath);
        tile.model.materials[1].shader = shader;
    }

    // ------------------------------ Main game loop ------------------------------
    for !rl.WindowShouldClose()
    {
        // Update game
        {
            lights[0].range = towerRange;

            gridPosX: i32 = COLS / 2;
            gridPosY: i32 = ROWS / 2;

            for row in gridPosY - i32(towerRange)..<gridPosY + i32(towerRange)
            {
                for col in gridPosY - i32(towerRange)..<gridPosX + i32(towerRange)
                {
                    dist := rl.Vector2Distance({f32(gridPosX), f32(gridPosY)}, {f32(col), f32(row)});
                    if i32(math.round(dist)) > i32(towerRange - 2)
                    {
                        continue;
                    }

                    Tiles[row][col] = .TILE_GROUND_01;
                }
            }
        }

        rl.UpdateCamera(&camera, .CUSTOM);

        rl.SetShaderValue(shader, shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW], &camera.position, .VEC3);

        for i in 0..<MAX_LIGHTS
        {
            UpdateLightValues(shader, lights[i]);
        }

        cameraSpeed :: 0.5;
        if rl.IsMouseButtonDown(.RIGHT) && rl.GetMouseDelta() != 0
        {
            camera.target.xz -= rl.GetMouseDelta() * cameraSpeed * rl.GetFrameTime();
            camera.position.xz -= rl.GetMouseDelta() * cameraSpeed * rl.GetFrameTime();
        }

        // Render game
        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);
        rl.BeginMode3D(camera);
        rl.BeginShaderMode(shader);

        rl.DrawModel(tower, position, 1.0, rl.WHITE);
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
        rl.DrawFPS(10, 10);
        rl.EndDrawing();
    }

    rl.UnloadModel(tower);
    rl.CloseWindow();
}
