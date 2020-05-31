// on initServer.sqf add: [] call vAiDriving_init;
vAiDriving_init = {
	if !(isServer) exitWith {}; // Run on Server Only
	waitUntil {sleep 1; time > 5};
	
	if !(isNil "vAiDrinvingScriptRunning") exitWith {}; //Script already running
	if (isNil "vAiDrinvingScriptRunning") then {vAiDrinvingScriptRunning = 1;}; // Prevent the loop from running several times.
	
	[{
		[] spawn vAiDriving_postInit;
	},[],5] call CBA_fnc_waitAndExecute; // Delay execution until all objects and vehicles are placed.
};

vAiDriving_postInit = {
	if !(isServer) exitWith {}; // Run on Server Only
	
	if (vAiDriving_handleBargates) then {
		[] spawn vAiDriving_handleBargatesFnc;
	};
	
	if (vAiDriving_handlePedestrians) then {
		[] spawn vAiDriving_handlePedestrianFnc;
	};
	
	private _aiDrivenVeh = [];
	_aiDrivenVeh = vehicles select {(alive driver _x && !(isPlayer driver _x) && (local driver _x) && (_x isKindOf "Car" || _x isKindOf "Motorcycle" || _x isKindOf "Tank"))}; //Select all vehicles being driven by Ai.
	if (_aiDrivenVeh isEqualTo []) exitWith {[vAiDriving_postInit,[],300] call CBA_fnc_waitAndExecute;}; //If no candidate found recheck 300 seconds later!
	
	{
		if (isNil {_x getVariable "vAiDrivingSet"}) then {
			_x setVariable ["vAiDrivingSet",0];
			_x setConvoySeparation 20;
			//_x forceFollowRoad true;
			_x setSpeedMode "LIMITED";
			//Add Event Handler
			_x addEventHandler ["GetIn", {_this spawn vAiDriving_loop;}];
			_x addEventHandler ["HandleDamage", {params ["","","","","_p","","",""]; if (_p isEqualTo "") exitWith {false};}];
			if (isNil {driver _x getVariable "vAiDrivingSet"}) then {
				driver _x setVariable ["vAiDrivingSet",0];
				driver _x addEventHandler ["GetOutMan", {_this spawn vAiDriving_restoreDriver;}];
				[driver _x] spawn vAiDriving_setDriver;
				//Start function if driver inside
				if !(isNull (driver _x)) then{null=[_x,"driver",(driver _x)] spawn vAiDriving_loop;};					
			};
		};
	} forEach _aiDrivenVeh;
	
	[vAiDriving_postInit,[],300] call CBA_fnc_waitAndExecute; // Check again Later if new veh or barGates were placed!
};

vAiDriving_loop = {
	if !(isServer) exitWith {}; // Run on Server Only
	if (diag_fps < 15) exitWith {[{[] spawn vAiDriving_loop;},[],60] call CBA_fnc_waitAndExecute;}; // Server FPS too low, save resources and restart the loop until FPS gets better
	params ["_car", "_role", "_driver"];
	if (!(_car isKindOf "Car" || _car isKindOf "Motorcycle" || _car isKindOf "Tank") || {!(_role isEqualTo "driver")} || {isPlayer _driver} || {!(local _driver)}) exitWith{};

	while {alive _driver && !(isNull (objectParent _driver))} do {
		
		// wait until a player is near.
		private _seenBy = [];
		
		if (vAiDriving_handleVehCache && random 100 > 95) then {		
			_seenBy = allPlayers select {_x distance _car < 500 || {(_x distance _car < 1000 && {([_x,"VIEW"] checkVisibility [eyePos _x, getPosASL _car]) > 0.5})}};
		} else { if (simulationEnabled _car) then {_seenBy = [0,0];} else {_seenBy = [];}; };	
		if	(_seenBy isEqualTo []) then {_car enableSimulationGlobal false; _driver enableSimulationGlobal false; sleep (6 + (random 6));} else {
		_car enableSimulationGlobal true; 
		_driver enableSimulationGlobal true;
		// If FPS too low let the Drivers be stupid again to save performance.
			if (diag_fps > 15) then {
				private _fuel = fuel _car;
				if (vAiDriving_vehUnlimitedFuel && _fuel < 0.5) then {_car setFuel 0.5;};
				if (_fuel isEqualTo 0) exitWith {private _crew = crew _car; {unassignVehicle _x} forEach _crew; _crew allowGetIn false;}; //Basically exit the while loop if out of fuel!
				_speed = speed _car;
				// Static Vehicles do not need brakes applied!
				if (_speed > 1) then {		
					_objectsIntersected = [];
					// Extra measure to reduce speed if a object is in the way, quite performance friendly!
					if (vAiDriving_useLinesIntersectWith) then {			
						private _carFrontPos = ATLToASL (_car modelToWorld [0, 2, -0.2]);
						private _distanceToCheck = 10;
						_distanceToCheck = ((_speed)*1.1);
						if (_distanceToCheck < 10) then {_distanceToCheck = 10;};
						private _carFrontDistanceToCheck = ATLToASL (_car modelToWorld [0, _distanceToCheck, 0.5]); //position far in front of vehicle
						_objectsIntersected = lineIntersectsWith [_carFrontPos, _carFrontDistanceToCheck, _car, _driver, true];
						if (vAiDriving_show3DLine) then {drawLine3D [ASLToATL _carFrontPos, ASLToATL _carFrontDistanceToCheck, [1,0,0,1]];};
					};
					// If vehicle already slowing down because of linesIntersect no point in searching for other Entities (Reduces resources usage!)
					if !(_objectsIntersected isEqualTo []) then {	
						_car setSpeedMode "LIMITED";
						_car forceSpeed 1;
						_car limitSpeed 5;
						//_car enableSimulationGlobal false;
						_car setVelocityModelSpace [0, 0, 0];
						if (vAiDriving_debug) then { systemChat format ["Car hit the BRAKE due to: LINESINTERSECT",""]; };
						sleep 1; // Do not overwhelm the server.			
					} else {
						_nearestObjects = [];
						private _radius = 6;
						_radius = _speed * 0.3;
						if (_radius < 6) then {_radius = 6;};
						if (_radius > 20) then {_radius = 20;};
						if (vAiDriving_handleBargates) then {
							_nearestObjects = ((nearestObjects[_car getRelPos [5,0],["CAManBase","Car","Wall_F"],_radius]) select {alive _x && !(_car isEqualTo _x)});
						} else {
							_nearestObjects = ((nearestObjects[_car getRelPos [5,0],["CAManBase","Car"],_radius]) select {alive _x && !(_car isEqualTo _x)});
						};
						sleep 0.5;
						if !(_nearestObjects isEqualTo []) then {
						if (vAiDriving_debug) then { systemChat format ["NEARESTOBJ COUNT: %1",count _nearestObjects]; };
							_car setSpeedMode "LIMITED";
							_car forceSpeed 1;
							_car limitSpeed 5;
							//_car enableSimulationGlobal false;
							_car setVelocityModelSpace [0, 0, 0];
							if (vAiDriving_debug) then { systemChat format ["Car hit the BRAKE due to: NEAROBJECT",""]; };
							if (random 5 > 4) then {driver _car forceWeaponFire [currentWeapon _car ,currentWeapon _car ];}; // Blow the horn for those pesky pedestrians!
							{
								switch (true) do {
									case (_x isKindOf "CAManBase" && {isNull (objectParent _x)}): {				// Pedestrian, try to save him!
										//if ((side _x isEqualTo "CIVILIAN" && (currentWeapon _x isEqualTo ""))) then {_x allowDamage false;};
										[_x, _car] spawn vAiPedestrian_runToNearestBuilding;
										if (vAiDriving_debug) then { systemChat format ["NEAROBJECTS: MEN",""]; };
									};
									case (_x isKindOf "Car" && !(isPlayer driver _x)): {											// Helps cars avoid other cars.
										if (speed _car < 5 && speed _x < 5) then {
											//_car setDir ((getposatl _car) getDir ((_x modelToWorld [-3, 0, 0])));			// This causes more troubles than it solves! Need a better way to unstuck vehicles.
											if (vAiDriving_debug) then { systemChat format ["NEAROBJECTS: CAR",""]; };
										};
									};
									case (vAiDriving_handleBargates && _x in vAiDriving_barGates): { // If it is a BarGate, open it!
										if (_x animationPhase "Door_1_rot" < 1 && {damage _x < 1}) then { //There's a gate ahead lowered undamaged
											_x animateSource ["Door_1_sound_source", 1];
										};	
									};	
								};
							sleep 0.3;
							} forEach _nearestObjects;
						} else {
							//_car enableSimulationGlobal true;
							_car forceSpeed -1;
							_car limitSpeed 30;						// Now restore speed
							_car setSpeedMode "NORMAL";
							if (((getPos _car) getEnvSoundController "houses") >= 0.7) then {
								_car limitSpeed 20;					// In cities reduce speed limit a little bit.
							};		
						};
					};
				};	
			};
		};	
	sleep 1; // Do not overwhelm the server.	
	};
};

vAiDriving_deleteWpFnc = {
	params ["_driver"];
	private _group = group _driver;
	for "_i" from count waypoints _group - 1 to 0 step -1 do {
		deleteWaypoint [_group, _i];
	};
};

vAiDriving_handleBargatesFnc = {
	if (diag_fps < 15) exitWith {};
	private _bargatetypes = ["Land_BarGate_01_open_F", "Land_BarGate_F", "Land_RoadBarrier_01_F"];
	vAiDriving_barGates = (allMissionObjects "Wall_F") select {private _object = _x; !(_bargatetypes findIf {_object isKindOf _x} isEqualTo -1)};
	//Add Event Handler
	{
		_x addEventHandler ["HandleDamage", {params ["","","","","_projectile","","",""]; if (_projectile isEqualTo "") then {_d=0; _d};}];
		sleep 1;	
	} forEach vAiDriving_barGates;
};

vAiDriving_setDriver = {
	params ["_driver"];
	if !(local _driver) exitWith {};
	if (isPlayer _driver) exitWith {};
	sleep 1;
	if !(isNil {_driver getVariable "vDriverSet"}) exitWith {};
	_driver setVariable ["vDriverSet", 0];
	_driver disableAi "ALL";
	{_driver enableAI _x} forEach ["MOVE","PATH","TEAMSWITCH"];
	[_driver] spawn {params ["_driver"]; sleep 2; _driver doMove (getPos _driver);};
	_driver setCombatMode "BLUE";
	_driver setBehaviour "CARELESS";
	_driver allowFleeing 0;
	_driver setSkill 0.0;
	_driver enableAttack false;
	(group _driver) enableDynamicSimulation true;
	(group _driver) deleteGroupWhenEmpty true;
	_driver setVariable ["BIS_noCoreConversations", true];
	_driver disableConversation true;
	_driver setSpeaker "NoVoice";
	_driver removeAllEventHandlers "HandleDamage";
	_driver addEventHandler ["HandleDamage", {params ["","","","","_projectile","","",""]; if (_projectile isEqualTo "") then {_d=0; _d};}];
	if (vAiDriving_handleVehWaypoints) then {
		[vehicle _driver,"driver",_driver, 300, 5, 120,10] spawn vAiDriving_handleVehMovementFnc;
	};	
	sleep (6 + (random 10));
	if (speed vehicle _driver < 2) then {[_driver] call {params ["_driver"]; _driver doMove (getPos _driver);}; };
	sleep (6 + (random 10));
	if (speed vehicle _driver < 2) then {[_driver] call {params ["_driver"]; _driver doMove (getPos _driver);}; };
};

vAiDriving_restoreDriver = {
	params ["_unit", "_role", "_vehicle", ""];
	if !(local _unit) exitWith {};
	if (isPlayer _unit) exitWith {};
	if (isNil {_unit getVariable "vDriverSet"}) exitWith {};
	_unit setVariable ["vDriverSet", nil];
	{_unit enableAI _x} forEach ["MOVE","PATH","ANIM","TEAMSWITCH"];
	_unit setCombatMode "YELLOW";
	_unit setBehaviour "SAFE";
	_unit allowFleeing 0;
	_unit enableAttack true;
	if (side group _unit isEqualTo CIVILIAN) then {
		[group _unit, getPos _unit, 100] call BIS_fnc_taskPatrol;
	} else {
		{_unit enableAi _x} forEach ["WEAPONAIM","FSM","AIMINGERROR","SUPPRESSION","AUTOCOMBAT","CHECKVISIBLE","TARGET","AUTOTARGET"];
	};
};

vAiDriving_rdmPos = {
	// Init
	params [
		["_position", "", ["", [], objNull, grpNull]],
		["_radius", 500, [0]]
	];

	// Create random position from center & radius
	private _position_X = (_position # 0) + (_radius - (random (1.5 *_radius)));
	private _position_Y = (_position # 1) + (_radius - (random (1.5 *_radius)));

	// Return position
	[_position_X, _position_Y, 0]
};

vAiDriving_rdmPosMax = {
	// Init
	params [
		["_position", "", ["", [], objNull, grpNull]],
		["_radius", 500, [0]],
		["_direction", -1, [0]]
	];

	// Set direction
	private _d = if (_direction == -1) then {random 360} else {_direction};

	// Create random position from center & radius
	private _position_X = (_position # 0) + (_radius * sin _d);
	private _position_Y = (_position # 1) + (_radius * cos _d);

	// Return position
	[_position_X, _position_Y, 0]
};

vAiDriving_roadPos = {
	// Init
	params [
		["_position", "", ["", [], objNull, grpNull]],
		["_radius", 150, [0]],
		["_result", [], [[]]]
	];

	// Check nearby roads from passed position
	private _allRoads	= _position nearRoads _radius;

	// if road position found, use it else use original position
	if (count _allRoads > 0) then {_result = getPos (selectRandom _allRoads)} else {_result = _position};

	// return the position
	_result
};

vAiDriving_addWayPoint = {
	// init	
	params [
		["_group", grpNull, [grpNull]],
		["_position", [0,0,0], [[]], [3]],
		["_radius", 500, [0]],
		["_wp_type", "MOVE", [""]],
		["_wp_behaviour", "SAFE", [""]],
		["_wp_combatMode", "WHITE", [""]],
		["_wp_speed", "LIMITED", [""]],
		["_wp_formation", "NO CHANGE", [""]],
		["_wp_complRadius", 5, [0]], 
		["_mode", "foot", [""]],
		["_searchBuildings", false, [true]],
		["_wp_timeOut", [0,0,0], [[]], [3]],
		["_index", 0, [0]]
	];
	private _direction = random 360;

	// Check valid vars
	if (_group == grpNull) exitWith {};
	if (_wp_complRadius > 500) then {_wp_complRadius = 500;};
	if !((toLowerANSI _mode) in ["foot", "road", "air", "sea"]) then {_mode = "foot";};
	if !((toUpperANSI _wp_type) in ["MOVE", "DESTROY", "GETIN", "SAD", "JOIN", "LEADER", "GETOUT", "CYCLE", "LOAD", "UNLOAD", "TR UNLOAD", "HOLD", "SENTRY", "GUARD", "TALK", "SCRIPTED", "SUPPORT", "GETIN NEAREST", "DISMISS", "AND", "OR"]) then {_wp_type = "MOVE";};
	if !((toUpperANSI _wp_behaviour) in ["UNCHANGED", "CARELESS", "SAFE", "AWARE", "COMBAT", "STEALTH"]) then {_wp_behaviour = "SAFE";};
	if !((toUpperANSI _wp_combatMode) in ["NO CHANGE" ,"BLUE", "GREEN" ,"WHITE", "YELLOW", "RED"]) then {_wp_combatMode = "WHITE";};
	if !((toUpperANSI _wp_speed) in ["UNCHANGED", "LIMITED", "NORMAL", "FULL"]) then {_wp_speed = "LIMITED";};
	if !((toUpperANSI _wp_formation) in ["NO CHANGE", "COLUMN", "STAG COLUMN", "WEDGE", "ECH LEFT", "ECH RIGHT", "VEE", "LINE", "FILE", "DIAMOND"]) then {_wp_formation = "FILE";};

	// Check if the location is at [0,0,0] lower left side of the map (0,0)
	if (_position isEqualTo [0,0,0]) exitWith {};

	// Find a suitable waypoint location based on the type of object/vehicle that will be using the waypoint
	switch _mode do {
		case "foot"	: {
			private "_i";
			for "_i" from 1 to 3 do {
				private _find = selectRandom [vAiDriving_rdmPosMax, vAiDriving_rdmPos];
				private _result = [_position, _radius, _direction] call _find;				
				if !(surfaceIsWater _result) exitWith {_position = _result};
				_radius = _radius + 25;
			};
		};
		case "road"	: {
			private _road = [];

			// Find road position within the parameters (near to the random position)
			for "_i" from 1 to 4 do {
				private _find = selectRandom [vAiDriving_rdmPosMax, vAiDriving_rdmPos];
				private _result = [_position, _radius, random 360] call _find;
				_road = [_result, _radius] call vAiDriving_roadPos;		
				if (isOnRoad _road) exitWith {_position = _road};
				_radius = _radius + 150;
				if (_i == 4) then {_position = [_position, _radius, (random 180) + (random 180)] call vAiDriving_rdmPosMax;};
			};
		};
		case "air"	: {
			private _find = selectRandom [vAiDriving_rdmPosMax, vAiDriving_rdmPos];
			_position = [_position, _radius, (random 180) + (random 180)] call _find;
		};
		case "sea"	: {
			// Find a location with a depth of at least 10 meters		
			private _dummy = "Sign_Sphere10cm_F" createVehicle [0,0,0];
			
			for "_i" from 1 to 25 do {
				private _find = selectRandom [vAiDriving_rdmPosMax, vAiDriving_rdmPos];
				private _result = [_position, _radius, random 360] call _find;
				_dummy setPosASL _result;
				private _d = abs (getTerrainHeightASL (getPos _dummy));				
				if ((surfaceIsWater _result) && {(_d > 10)}) exitWith {_position = _result};
				_radius = _radius + 50;
			};
			
			deleteVehicle _dummy;
		};
	};
	
	if (vAiDriving_showWpMrks) then {
		//debug markers
		private _marker = createMarker[format["wp%1%2", time,_index], _position];
		_marker setMarkerSize [.7, .7];
		_marker setMarkerShape "ICON";
		_marker setMarkerType "mil_triangle";
		_marker setMarkerColor "ColorRed";
		_marker setMarkerText format ["%1", _index];
	};
	
	// Create the waypoint
	private _waypoint = _group addWaypoint [_position, 0];
	_waypoint setWaypointType _wp_type;
	_waypoint setWaypointBehaviour _wp_behaviour;
	_waypoint setWaypointCombatMode _wp_combatMode;
	_waypoint setWaypointSpeed _wp_speed;
	_waypoint setWaypointFormation _wp_formation;
	_waypoint setWaypointCompletionRadius _wp_complRadius;
	_waypoint setWaypointTimeout _wp_timeOut;
	//if (_searchBuildings) then {_waypoint setWaypointStatements ["TRUE", "this spawn fnc_searchBuilding"]};

	// return the waypoint
	_waypoint
};

// _wDistance must always be lower than _checkRadius.
// [cursorTarget,"", driver cursorTarget, 300, 5, 120,10] spawn vAiDriving_handleVehMovementFnc;
vAiDriving_handleVehMovementFnc = {
	if !(isServer) exitWith {}; // Run on Server Only
	params ["_vehicle", "_role", "_driver", "_checkRadius", "_nberOfWayPoints", "_wDistance", "_wTimeout"];
	
	if !(local _vehicle) exitWith {};
	if (isNull driver _vehicle) exitWith {};
	if !(alive _driver) exitWith {};
	
	if !(isNil {_driver getVariable "vVehMovementSet"}) exitWith {};
	_driver setVariable ["vVehMovementSet", 0];
	
	if (_nberOfWayPoints > 10) then {_nberOfWayPoints = 10};
	if (_nberOfWayPoints < 2) then {_nberOfWayPoints = 2};
	
	if (_checkRadius > 800) then {_checkRadius = 800;};
	if (_checkRadius < 100) then {_checkRadius = 100;};
	
	[_driver] call vAiDriving_deleteWpFnc;
	_vehicle allowDamage false;
	_pos = getPos _vehicle;
	private _roadList = [];
	_roadList = _pos nearRoads _checkRadius;
	if (_roadList isEqualTo []) exitWith {};
	
//	{
//		private _roadConnectedTo = roadsConnectedTo _x;
//		if (count _roadConnectedTo > 2) then {	
//			//_roadList=_roadList - [_x];
//			_roadList deleteAt (_roadList find _x);
//		};
//		sleep 0.2;
//	} foreach _roadList;

	_roadList = _roadList select {count roadsConnectedTo _x < 2.1};
	
	private _nearestRoad = objNull;
	_nearestRoad = [getPosATL _vehicle, 30, getPosATL _vehicle nearRoads 0.5] call BIS_fnc_nearestRoad;
	sleep 0.2;
	if (isNull _nearestRoad) then {
		_roadListSorted = [_roadList, [], { _vehicle distance2D _x }, "ASCEND"] call BIS_fnc_sortBy;
		_nearestRoad = _roadListSorted select 0;
	};
	private _roadPos = getPosATL _nearestRoad;
	private _emptyPos = [0,0,0];
	private _emptyPos = _roadPos findEmptyPosition [0,10];
	if !(_emptyPos isEqualTo [0,0,0]) then {_vehicle setPosATL _emptyPos;} else {_vehicle setPosATL (getPosATL _roadPos);};
	
	private _roadConnectedTo = roadsConnectedTo _nearestRoad;
	private _connectedRoad = _roadConnectedTo select 0;
	private _roadDir = ((getposatl _nearestRoad) getDir (getposatl _connectedRoad));
	_vehicle setDir _roadDir;
	_vehicle setPos [(getPos _vehicle select 0)-3.0, getPos _vehicle select 1, getPos _vehicle select 2]; // Set the veh to the right of the road.
	
	// ADD VEHICLE WAYPOINTS
	
	private _group = group driver _vehicle;
	private _position = _pos;
	private _radius = _checkRadius;
	private _wp_type = "MOVE";
	private _wp_behaviour = "SAFE";
	private _wp_combatMode = "WHITE";
	private _wp_speed = "NORMAL";
	private _wp_complRadius = 25;
	private _wp_timeOut = [1,5,10];
	private _index = -1;
	
	// Loop through the number of waypoints needed
	for "_i" from 0 to (_nberOfWayPoints - 1) do {
		_index = _index + 1;
		[_group, _position, _radius, _wp_type, _wp_behaviour, _wp_combatMode, _wp_speed, "COLUMN", _wp_complRadius, "road", false, _wp_timeOut, _index] call vAiDriving_addWayPoint;
	};

	// Add a cycle waypoint
	[_group, _position, _radius, "CYCLE", _wp_behaviour, _wp_combatMode, _wp_speed, "COLUMN", _wp_complRadius, "road", false, _wp_timeOut, _index + 1] call vAiDriving_addWayPoint;

	// Remove the spawn/start waypoint
	deleteWaypoint ((waypoints _group) # 0);
	
	_vehicle allowDamage true;
};

vAiDriving_setConvoy = {
	params ["_vehicle"];

};

vAiDriving_isInFrontFnc = {
	params ["_vehicle", "_nearVehicle"];
	private _inFrontArc= false;
	_inFrontArc=[getPosATL _vehicle,(getDir _vehicle)-0,90,getPosATL _nearVehicle]call BIS_fnc_inAngleSector;
	_inFrontArc
};

vAiDriving_isBehindFnc = {
	params ["_vehicle", "_nearVehicle"];
	private _inBehindArc= false;
	_inBehindArc=[getPosATL _vehicle,(getDir _vehicle)-180,90,getPosATL _nearVehicle]call BIS_fnc_inAngleSector;
	_inBehindArc
};

vAiDriving_comingFromBehindFnc = {
	params ["_vehicle", "_nearVehicle"];
	private _comingFromBehindVeh = false;
	private _carFrontPos = _vehicle modelToWorld [0,5,0]; //position of front of vehicle (hood)
	private _cardir = getDir _vehicle;

	private _reldir = (_carfrontpos getDir _nearVehicle) - _cardir;
	private _heading = [abs _reldir, 360 - (abs _reldir)] select (abs _reldir > 180);
	if ((_heading + abs _delta) % 360 < 90 ) then{ //Facing both left and right
		_comingFromBehindVeh = true;	//we're behind them
	};
	_comingFromBehindVeh
};

vAiDriving_comingFromFrontFnc = {
	params ["_vehicle", "_nearVehicle"];
	private _comingTowardsVeh = false;
	private _carDir = getDir _vehicle;
	private _delta = [getDir _nearVehicle, _cardir] call BIS_fnc_getAngleDelta; //180º-0ºR -180º-0ºL

	if (abs _delta > 150) exitWith{ //oncoming traffic at < 30º rotation
		_comingTowardsVeh = true; //they're coming towards us
	};
	_comingTowardsVeh
};

vAiDriving_handlePedestrianFnc = {
	private _aiPedestrians = [];
	_aiPedestrians = allUnits select {(alive _x && (_x isKindOf "CAManBase") && !(isAgent teamMember _x) && !(isPlayer _x) && (local _x) && (isNull (objectParent _x)) && !(_x in playableUnits) && (currentWeapon _x isEqualTo "") && (side group _x isEqualTo CIVILIAN))}; //Select all Ai Civs.
	if !(_aiPedestrians isEqualTo []) then {
		{
			if (isNil {_x getVariable "vAiPedestrianSet"}) then {
				_x setVariable ["vAiPedestrianSet",0];
				[_x] call vAiDriving_setPedestrian;
			};
		sleep (1 + (random 1));
		} forEach _aiPedestrians;
	};
};

vAiDriving_setPedestrian = {
	params ["_aiPedestrian"];
	if !(local _aiPedestrian) exitWith {};
	if (isPlayer _aiPedestrian) exitWith {};
	if (_aiPedestrian in playableUnits) exitWith {};
	if !(side group _aiPedestrian isEqualTo CIVILIAN) exitWith {};
	
	[group _aiPedestrian, getPos _aiPedestrian, 100] call BIS_fnc_taskPatrol; // Set the Pedestrian WayPoints
	private _unitType = typeOf _aiPedestrian;
	private _aiPedestrianPos = getPos _aiPedestrian;
	private _aiPedestrianDir = getDir _aiPedestrian;
	
	// just in case
	private _attachMents = attachedObjects _aiPedestrian;
	if (count _attachMents > 0) then {
		{detach _x;} forEach _attachMents;
		{deleteVehicle _x;} forEach _attachMents;
	};
	
	private _agentPedestrian = objNull;
	_agentPedestrian = createAgent [_unitType, [0,0,0], [], 0, "CAN_COLLIDE"];
	_agentPedestrian disableAi "ALL";
	{_agentPedestrian enableAI _x} forEach ["MOVE","PATH","ANIM","TEAMSWITCH"];
	[_agentPedestrian] spawn {params ["_unit"]; sleep 3; _unit moveTo (getPos _unit);};
	removeAllWeapons _agentPedestrian;
	removeAllItems _agentPedestrian;
	removeAllAssignedItems _agentPedestrian;
	removeVest _agentPedestrian;
	removeBackpack _agentPedestrian;
	removeHeadgear _agentPedestrian;
	removeGoggles _agentPedestrian;
	_agentPedestrian disablecollisionwith _aiPedestrian;
	_aiPedestrian disablecollisionwith _agentPedestrian;
	_agentPedestrian switchMove "";
	_agentPedestrian enableStamina false;
	_agentPedestrian setanimspeedcoef 0.7;
	_agentPedestrian setCombatMode "BLUE";
	_agentPedestrian setBehaviour "CARELESS";
	_agentPedestrian setSpeedMode "LIMITED";
	_agentPedestrian forcespeed -1;
	_agentPedestrian allowFleeing 0;
	_agentPedestrian setSkill 0.0;
	(_agentPedestrian) enableDynamicSimulation true;
	(group _agentPedestrian) deleteGroupWhenEmpty true;
	_agentPedestrian setVariable ["BIS_noCoreConversations", true];
	_agentPedestrian disableConversation true;
	_agentPedestrian setSpeaker "NoVoice";
	_agentPedestrian removeAllEventHandlers "HandleDamage";
	_agentPedestrian addEventHandler ["HandleDamage", {params ["","","","","_projectile","","",""]; if (_projectile isEqualTo "") then {_d=0; _d};}];
	deleteVehicle _aiPedestrian;
	if (vAiDriving_dressPedestrians) then {
		if (count vAiDriving_civUniforms < 2) then {vAiDriving_civUniforms = vAiDriving_civUniformsOriginal;};
		private _rdmUniform = selectRandom vAiDriving_civUniforms;
		vAiDriving_civUniforms deleteAt (vAiDriving_civUniforms find _rdmUniform);
		_agentPedestrian forceAddUniform _rdmUniform;
		if (random 10 > 8) then {private _rdmHeadgear = selectRandom vAiDriving_civHeadgear; _agentPedestrian addHeadgear _rdmHeadgear;};
		if (random 10 > 9) then {private _rdmVest = selectRandom vAiDriving_civVest; _agentPedestrian addVest _rdmVest;};
		if (random 10 > 6) then {private _rdmGoggles = selectRandom vAiDriving_civGoggles; _agentPedestrian addGoggles _rdmGoggles;};
		[_agentPedestrian] spawn {params ["_unit"]; sleep 6; if (uniform _unit isEqualTo "") then {_unit forceAddUniform (selectRandom vAiDriving_civUniformsOriginal)}; };
	};	
	_agentPedestrian setpos _aiPedestrianPos;
	_agentPedestrian setdir _aiPedestrianDir;
	_agentPedestrian setVariable ["vAiPedestrianSet",0];
	[_agentPedestrian,50,8,8] spawn vPedestrianPatrol;
};

vPedestrianPatrol = {
	params ["_agent","_radius","_waypoints","_timeOut"];
	if !(isAgent teamMember _agent) exitWith {};
	private _agentMoveCount = _waypoints;
	private _origAgentPos = getPos _agent;
	while {alive _agent} do {
		// wait until a player is near.
		private _seenBy = [];
		if (vAiDriving_handleVehCache && random 100 > 95) then {
			_seenBy = allPlayers select {_x distance _agent < 500 || {(_x distance _agent < 1000 && {([_x,"VIEW"] checkVisibility [eyePos _x, getPosASL _agent]) > 0.5})}};
		} else { if (simulationEnabled _agent) then {_seenBy = [0,0];} else {_seenBy = [];}; };
		if	(_seenBy isEqualTo []) then {_agent enableSimulationGlobal false; sleep (6 + (random 6));} else {
		_agent enableSimulationGlobal true;
			if (simulationEnabled _agent && diag_fps > 15 && speed _agent < 2) then {
				if (random 10>1) then {
					private _nOa = [];
					_nOa = nearestObjects [_agent, ["house"], _radius];
					if !(_nOa isEqualTo []) then {
						private _rdmO = selectRandom _nOa; 
						private _aDest = getPos _rdmO;
						if !(surfaceIsWater _aDest) then {
							_agent setDestination [_aDest, "LEADER PLANNED", true]; if (random 3 > 1) then {_agent forceWalk false;} else {_agent forceWalk true;};
							private _forcedTimeOut = time + 60;
							waitUntil {sleep (2 + (random 4)); (_agent distance2d _aDest < 10 OR time > _forcedTimeOut)};
							if (isOnRoad (ASLToAGL getPosASL _agent)) then {sleep 0.1;} else {sleep _timeOut;};
						};
					};
				} else {
					_goTalkTo = objNull;
					_goTalkTo = nearestObject [_agent, "CAManBase"];
					if (!(isNull _goTalkTo) && (_goTalkTo distance2d _agent < _radius) && (side _goTalkTo isEqualTo side _agent)) then {
						if (vAiDriving_debug) then { systemChat format ["GOTALKTO: %1",name _goTalkTo]; };
						private _goTalkToPos = getPos _goTalkTo;
						_agent setDestination [_goTalkToPos, "LEADER PLANNED", true]; if (random 3 > 1) then {_agent forceWalk false;} else {_agent forceWalk true;};
						private _forcedTimeOutB = time + 60;
						waitUntil {sleep (2 + (random 4)); (_agent distance2d _goTalkToPos < 10 OR time > _forcedTimeOutB)};
						waitUntil {sleep (2 + (random 2)); (speed _agent < 2 OR time > _forcedTimeOutB)};
						if (_agent distance2d _goTalkTo < 5) then {_agent setDir (getDir _goTalkTo + 180); _agent setFormDir (getDir _goTalkTo + 180); _goTalkTo setDir (getDir _agent + 180); _goTalkTo setFormDir (getDir _agent + 180);};
						if (isOnRoad (ASLToAGL getPosASL _agent)) then {sleep 0.1;} else {sleep _timeOut;};
					};
				};
				_agentMoveCount = _agentMoveCount - 1;
				if (vAiDriving_debug) then { systemChat format ["AGENT MOVE COUNT: %1",_agentMoveCount]; };
				if (_agentMoveCount < 1) then {_agent setDestination [_origAgentPos, "LEADER PLANNED", true]; _agentMoveCount = _waypoints; sleep (10 + (random 10));};
				sleep (2 + (random 2));
			} else {sleep (5 + (random 5));};
		};	
	 sleep (1 + (random 1));
	};
};

vAiPedestrian_runToNearestBuilding = {
	params ["_aiPedestrian", "_car"];
	if !(isNil {_aiPedestrian getVariable "vIsAvoidingVeh"}) exitWith {};
	if (lifeState _aiPedestrian isEqualTo "INCAPACITATED" OR !(canStand _aiPedestrian)) exitWith {};
	private _onFoot = isNull (objectParent _aiPedestrian); // check for vehicle
	if (!_onFoot) exitWith {}; 	// no further action if unit in vehicle
	if (isPlayer _aiPedestrian) exitWith {};
	
	_aiPedestrian setVariable ["vIsAvoidingVeh", 0];
	if (vAiDriving_debug) then { systemChat format ["PEDESTRIAN RUNNING!",""]; };
	
	private _fleeDir = 180 + (_aiPedestrian getDir _car); //direction opposite to car
	private _fleePos = _aiPedestrian getrelPos [30,_fleeDir]; //finds location at 30 mtrs in established direction.
	
	// nearBuildings
	_NearestBuilding = [];
	_NearestBuilding = _fleePos call CBA_fnc_getNearestBuilding;
	sleep 1;
	if (_NearestBuilding isEqualTo []) exitWith {};
	private _Building = _NearestBuilding select 0;
	if (_aiPedestrian distance2D _Building > 30) exitWith {};
	private _BuildingPositions = [];
	_BuildingPositionsCount = _NearestBuilding select 1;
	
	// pick a random building spot and move!
	_BuildingPosition = getPos _aiPedestrian;
	if (_BuildingPositionsCount > 1) then {_BuildingPosition = (selectRandom (_Building buildingPos -1));} else {_BuildingPosition = getPos _Building;};
	private _previousGroup = group _aiPedestrian;
	
	// Just in case...
	if (count attachedObjects _aiPedestrian > 0) then {
		{detach _x;} forEach attachedObjects _aiPedestrian;
	};	
	// Prepare the Civie so he is able to run!
	_previousGroup deleteGroupWhenEmpty false;
	[_aiPedestrian] join grpNull;
	{_aiPedestrian enableAI _x} forEach ["MOVE","PATH","ANIM","AUTOTARGET","TARGET"];
	_aiPedestrian forceWalk false;
	_aiPedestrian switchMove "";
	_aiPedestrian setUnitPos "UP";
	_aiPedestrian setBehaviour "CARELESS";
	_aiPedestrian forceSpeed -1;
	_aiPedestrian forcespeed 30;
	_aiPedestrian setSpeedMode "FULL";
	if (isAgent teamMember _aiPedestrian) then {
		_aiPedestrian moveTo _BuildingPosition; // agents only move with moveTo.
	} else {
		_aiPedestrian doMove _BuildingPosition;
	};
	[_aiPedestrian, _previousGroup] spawn {
		params ["_aiPedestrian", "_previousGroup"];
		sleep 20;
		_aiPedestrian switchMove "";
		_aiPedestrian allowDamage true;
		_aiPedestrian setVariable ["vIsAvoidingVeh", nil];
		_aiPedestrian setBehaviour "AWARE";
		[_aiPedestrian] join _previousGroup;
		_previousGroup deleteGroupWhenEmpty true;
		_aiPedestrian setUnitPos "AUTO";
		_aiPedestrian forceSpeed -1;
		[group _aiPedestrian, getPos _aiPedestrian, 100] call BIS_fnc_taskPatrol;
	};
};

vAiDriving_civUniformsOriginal = [
	//"U_C_man_sport_1_F", 
	//"U_C_man_sport_2_F", 
	//"U_C_man_sport_3_F",
	"U_C_Man_casual_1_F",
	"U_C_Man_casual_2_F",
	"U_C_Man_casual_3_F",
	"U_C_Poloshirt_blue",
	"U_C_Poloshirt_burgundy",
	"U_C_Poloshirt_tricolour",
	"U_C_Poloshirt_salmon",
	"U_C_Poloshirt_redwhite",
	"U_C_Poloshirt_stripped",
	"U_C_HunterBody_grn",
	// "U_C_HunterBody_brn", //Does not work!
	"U_IG_Guerilla2_1",
	"U_IG_Guerilla2_2",
	"U_IG_Guerilla2_3",
	"U_IG_Guerilla3_1",
	//"U_IG_Guerilla3_2",
	//"U_OG_Guerilla2_1",
	//"U_OG_Guerilla2_2",
	//"U_OG_Guerilla2_3",
	//"U_OG_Guerilla3_1",
	//"U_OG_Guerilla3_2",
	"U_C_WorkerCoveralls",
	"U_C_Journalist",
	"U_I_G_resistanceLeader_F",
	"U_C_Scientist",
	"U_NikosAgedBody",
	"U_C_Paramedic_01_F",
	"U_C_Mechanic_01_F",
	"U_C_Man_casual_1_F",
	"U_I_C_Soldier_Bandit_3_F",
	"U_C_Poor_1",
	"U_C_Poor_2",
	"U_Rangemaster",
	"U_NikosBody",
	"U_Marshal",
	//"U_B_HeliPilotCoveralls",
	//"U_I_HeliPilotCoveralls",
	//"U_BG_Guerilla2_3",
	//"U_BG_Guerilla2_1",
	//"U_BG_Guerilla_6_1",
	"U_C_IDAP_Man_cargo_F",
	"U_C_IDAP_Man_casual_F",
	"U_C_IDAP_Man_Tee_F",
	"U_C_IDAP_Man_Jeans_F",
	"U_C_ConstructionCoverall_Red_F",
	"U_C_ConstructionCoverall_Vrana_F",
	"U_C_ConstructionCoverall_Black_F",
	"U_C_ConstructionCoverall_Blue_F",
	"U_C_Uniform_Scientist_01_F",
	"U_C_Uniform_Scientist_01_formal_F",
	"U_C_Uniform_Scientist_02_formal_F",
	"U_C_Uniform_Scientist_02_F",
	"U_C_Uniform_Farmer_01_F",
	"U_I_L_Uniform_01_tshirt_sport_F",
	"U_I_L_Uniform_01_tshirt_black_F",
	"U_I_L_Uniform_01_tshirt_skull_F",
	"U_O_R_Gorka_01_black_F",
	"U_C_E_LooterJacket_01_F"
];

vAiDriving_civUniforms = [
	"U_C_Man_casual_1_F",
	"U_C_Man_casual_2_F",
	"U_C_Man_casual_3_F",
	"U_C_Poloshirt_blue",
	"U_C_Poloshirt_burgundy",
	"U_C_Poloshirt_tricolour",
	"U_C_Poloshirt_salmon",
	"U_C_Poloshirt_redwhite",
	"U_C_Poloshirt_stripped",
	"U_C_HunterBody_grn",
	"U_IG_Guerilla2_1",
	"U_IG_Guerilla2_2",
	"U_IG_Guerilla2_3",
	"U_IG_Guerilla3_1",
	"U_C_WorkerCoveralls",
	"U_C_Journalist",
	"U_I_G_resistanceLeader_F",
	"U_C_Scientist",
	"U_NikosAgedBody",
	"U_C_Paramedic_01_F",
	"U_C_Mechanic_01_F",
	"U_C_Man_casual_1_F",
	"U_I_C_Soldier_Bandit_3_F",
	"U_C_Poor_1",
	"U_C_Poor_2",
	"U_Rangemaster",
	"U_NikosBody",
	"U_Marshal",
	"U_C_IDAP_Man_cargo_F",
	"U_C_IDAP_Man_casual_F",
	"U_C_IDAP_Man_Tee_F",
	"U_C_IDAP_Man_Jeans_F",
	"U_C_ConstructionCoverall_Red_F",
	"U_C_ConstructionCoverall_Vrana_F",
	"U_C_ConstructionCoverall_Black_F",
	"U_C_ConstructionCoverall_Blue_F",
	"U_C_Uniform_Scientist_01_F",
	"U_C_Uniform_Scientist_01_formal_F",
	"U_C_Uniform_Scientist_02_formal_F",
	"U_C_Uniform_Scientist_02_F",
	"U_C_Uniform_Farmer_01_F",
	"U_I_L_Uniform_01_tshirt_sport_F",
	"U_I_L_Uniform_01_tshirt_black_F",
	"U_I_L_Uniform_01_tshirt_skull_F",
	"U_O_R_Gorka_01_black_F",
	"U_C_E_LooterJacket_01_F"
];

vAiDriving_civHeadgear = [
	"H_Bandanna_gry",
	"H_Bandanna_blu",
	"H_Bandanna_cbr",
	"H_Bandanna_surfer",
	"H_Bandanna_surfer_grn",
	"H_Watchcap_khk",
	"H_Watchcap_camo",
	"H_Watchcap_cbr",
	"H_Watchcap_blk",
	"H_Booniehat_tan",
	"H_Cap_blk",
	"H_Cap_blu",
	"H_Cap_grn",
	"H_Cap_red",
	"H_Cap_police",
	"H_Cap_press",
	"H_Cap_surfer",
	"H_Cap_tan",
	"H_Construction_basic_black_F",
	"H_Construction_basic_orange_F",
	"H_Construction_basic_red_F",
	"H_Construction_basic_white_F",
	"H_Construction_basic_yellow_F",
	"H_Hat_blue",
	"H_Hat_brown",
	"H_Hat_checker",
	"H_Hat_grey",
	"H_Hat_tan",
	"H_HeadBandage_clean_F",
	"H_HeadBandage_stained_F",
	"H_HeadBandage_bloody_F",
	"H_Hat_Safari_olive_F",
	"H_Hat_Safari_sand_F",
	"H_Helmet_Skate",
	"H_StrawHat"
];

vAiDriving_civVest =
[
	"V_LegStrapBag_black_F",
	"V_LegStrapBag_coyote_F",
	"V_LegStrapBag_olive_F",
	"V_Pocketed_black_F",
	"V_Pocketed_coyote_F",
	"V_Pocketed_olive_F",
	"V_Safety_blue_F",
	"V_Safety_orange_F",
	"V_Safety_yellow_F",
	"V_Press_F"
];

vAiDriving_civGoggles = 
[
	"G_Aviator",
	"G_Lady_Blue",
	"G_Respirator_blue_F",
	"G_Respirator_white_F",
	"G_Respirator_yellow_F",
	"G_Shades_Black",
	"G_Spectacles",
	"G_Squares_Tinted",
	"G_Sport_Blackred",
	"G_EyeProtectors_F"
];