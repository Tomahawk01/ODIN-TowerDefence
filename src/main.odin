package main

import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800;
SCREEN_HEIGHT :: 450;

main :: proc()
{
    rl.SetConfigFlags({.VSYNC_HINT});
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tower Defence");
    rl.SetTargetFPS(240);

    camera :rl.Camera = {};
    camera.position = (rl.Vector3){ 6.0, 6.0, 6.0 };
    camera.target = (rl.Vector3){ 0.0, 2.0, 0.0 };
    camera.up = (rl.Vector3){ 0.0, 1.0, 0.0 };
    camera.fovy = 60.0;
    camera.projection = .PERSPECTIVE;

    model := rl.LoadModel("assets/models/tile-tree.glb");
    position := rl.Vector3{0.0, 0.0, 0.0};

    // ------------------------------ Main game loop ------------------------------
    for !rl.WindowShouldClose()
    {
        rl.UpdateCamera(&camera, .FREE);

        rl.BeginDrawing();
        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode3D(camera);
        rl.DrawModel(model, position, 1.0, rl.WHITE);
        rl.DrawGrid(10, 1.0);
        rl.EndMode3D();

        rl.DrawFPS(10, 10);
        rl.EndDrawing();
    }

    rl.UnloadModel(model);
    rl.CloseWindow();
}
