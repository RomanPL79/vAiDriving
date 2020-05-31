#define SETTINGS "vAIDriving Settings"

[
    "vAiDriving_handleVehWaypoints", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Handle Veh Waypoints", "If set to true the script will create 'vehicle optimized' waypoints for each vehicle automatically."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Main"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_handleVehCache", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Handle Veh Cache", "If set to true the script will automatically cache (Disable Simulations) vehicles that the players cannot see."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Main"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    false, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_vehUnlimitedFuel", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Veh Unlimited Fuel", "If set to true the vehicles handled by vAiDriving will never run out of fuel."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Main"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    false, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_useLinesIntersectWith", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Use LinesIntersectWith", "Helps vehicles brake better when facing obstacles other than vehicles and pedestrians (Such as buildings, walls etc)."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Main"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_handlePedestrians", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Handle Pedestrians", "Set to true to optimize Ai Civilian units, turning them into agents and gives them 'realistic' movement routines."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Main"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_dressPedestrians", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Dress Pedestrians", "If set to true the script will give each Civilian a different uniform, googles and headgear for unit variety. (Requires vAiDriving_handlePedestrians)"], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Main"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    false, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_handleBargates", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Handle Bargates", "Should the vehicles open BarGates automatically?"], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Main"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    true, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_debug", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Debug", "If true will show when Ai Drivers hit the brakes and/or their nearObjects."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Debug"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    false, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_show3DLine", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Show 3D Line", "Set to true to draw a visual line for the LINES INTERSECT."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Debug"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    false, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;

[
    "vAiDriving_showWpMrks", // Internal setting name, should always contain a tag! This will be the global variable which takes the value of the setting.
    "CHECKBOX", // setting type
    ["Show WP Markers", "Set to true to show vehicle waypoints on the map."], // Pretty name shown inside the ingame settings menu. Can be stringtable entry.
    ["vAiDriving", "Debug"], // Pretty name of the category where the setting can be found. Can be stringtable entry.
    false, // data for this setting: [min, max, default, number of shown trailing decimals]
    true, // "_isGlobal" flag. Set this to true to always have this setting synchronized between all clients in multiplayer
    {} // function that will be executed once on mission start and every time the setting is changed.
] call CBA_Settings_fnc_init;