class CfgPatches {
  class vAiDriving {
    units[] = {};
    weapons[] = {};
    requiredVersion = 1.82;
    requiredAddons[] = {
		"cba_settings",
		"cba_main",
		"cba_common"
	};
	
    version = 2;
    versionStr = "1.3";
    author = "Valmont";
    authorUrl = "https://forums.bohemia.net/forums/topic/229362-vaidriving-multiplayer-script-v13-updated-05262020/";
  };
};

class cfgFunctions {
    class vAiDriving {
        project = "vAiDriving";
        tag = "vAiDriving";
        class scripts {
            class script {
                file        = "\z\Valmont\addons\vAiDriving\functions\vAiDriving.sqf";
            };
        };
    };
};

class Extended_PreInit_EventHandlers
{
	class vAiDriving
	{
		init="call compile preProcessFileLineNumbers 'z\Valmont\addons\vAiDriving\cba_settings.sqf'";
	};
};
class Extended_PostInit_EventHandlers
{
	class vAiDriving
	{
		init="[] call vAiDriving_fnc_script";
	};
};