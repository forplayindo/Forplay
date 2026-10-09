return {
    enableClient = true, -- disable to create your own client interface
    engineOn = true, -- If true, the engine will be on upon taking the vehicle out.
    debugPoly = false, -- Draws the garage zones, useful while setting up zone points
    interactKey = 'E', -- Default key to park / open the garage while inside a zone (players can rebind it in settings)

    -- Command that copies your position as `vec2(x, y),` to the clipboard and prints the z in F8.
    -- Use it to collect zone corners. Set to false to disable.
    pointHelperCommand = 'garagepoint',
}
