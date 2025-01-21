package main

import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1600;
SCREEN_HEIGHT :: 900;
ROWS :: 30;
COLS :: 40;

TileID :: enum
{
    TILE_TREE_01,
    TILE_TREE_02
};

Tile :: struct
{
    tilePath: cstring,
    model: rl.Model
};

Tiles: [ROWS][COLS]TileID = {};

main :: proc()
{
    rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT});
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tower Defence");
    rl.SetTargetFPS(240);

    camera: rl.Camera = {};
    camera.position = { 0.0, 2.0, 3.0 };
    camera.target = { 0.0, 1.0, 0.0 };
    camera.up = { 0.0, 1.0, 0.0 };
    camera.fovy = 60.0;
    camera.projection = .PERSPECTIVE;

    tower := rl.LoadModel("assets/models/tower-round-crystals.glb");
    treeTile01 := rl.LoadModel("assets/models/tile-tree-double.glb");

    position := rl.Vector3{0.0, 0.2, 0.0};

    TileModels: [TileID]Tile = {
        .TILE_TREE_01 = {tilePath = "assets/models/tile-tree-double.glb"},
        .TILE_TREE_02 = {tilePath = "assets/models/tile-tree.glb"},
    };
    for &tile in TileModels
    {
        tile.model = rl.LoadModel(tile.tilePath);
    }

    // ------------------------------ Main game loop ------------------------------
    for !rl.WindowShouldClose()
    {
        rl.UpdateCamera(&camera, .CUSTOM);

        cameraSpeed :: 0.5;
        if rl.IsMouseButtonDown(.RIGHT) && rl.GetMouseDelta() != 0
        {
            camera.target.xz -= rl.GetMouseDelta() * cameraSpeed * rl.GetFrameTime();
            camera.position.xz -= rl.GetMouseDelta() * cameraSpeed * rl.GetFrameTime();
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode3D(camera);
        rl.DrawModel(tower, position, 1.0, rl.WHITE);
        for row in 0..<ROWS
        {
            for col in 0..<COLS
            {
                tile := TileModels[Tiles[row][col]];
                rl.DrawModel(tile.model, {-ROWS / 2 + f32(row), 0.0, -COLS / 2 + f32(col)}, 1.0, rl.WHITE);
            }
        }
        rl.EndMode3D();

        rl.EndDrawing();
    }

    rl.UnloadModel(tower);
    rl.CloseWindow();
}
