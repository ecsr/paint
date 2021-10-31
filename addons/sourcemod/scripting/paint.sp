#include <sourcemod>

#include <clientprefs>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "2.0"
#define PAINT_DISTANCE_SQ 1.0

// Colour name, file name.
char gC_PaintColours[][][64] = // Modify this to add/change colours.
{
	{ "Random", "random" },
	{ "White", "paint_white" },
	{ "Black", "paint_black" },
	{ "Blue", "paint_blue" },
	{ "Light Blue", "paint_lightblue" },
	{ "Brown", "paint_brown" },
	{ "Cyan", "paint_cyan" },
	{ "Green", "paint_green" },
	{ "Dark Green", "paint_darkgreen" },
	{ "Red", "paint_red" },
	{ "Orange", "paint_orange" },
	{ "Yellow", "paint_yellow" },
	{ "Pink", "paint_pink" },
	{ "Light Pink", "paint_lightpink" },
	{ "Purple", "paint_purple" },
};

// Size name, size suffix.
char gC_PaintSizes[][][64] = // Modify this to add more sizes.
{
	{ "Small", "" },
	{ "Medium", "_med" },
	{ "Large", "_large" },
};

int gI_Sprites[sizeof(gC_PaintColours) - 1][sizeof(gC_PaintSizes)];

bool gB_IsPainting[MAXPLAYERS + 1];
float gF_LastPaintPosition[MAXPLAYERS + 1][3];

int gI_PaintColour[MAXPLAYERS + 1];
int gI_PaintSize[MAXPLAYERS + 1];

Handle gH_PaintColour;
Handle gH_PaintSize;

public Plugin myinfo =
{
	name = "Paint!",
	author = "SlidyBat",
	description = "Allow players to paint on walls",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("paint_version", PLUGIN_VERSION, "Paint plugin version", FCVAR_NOTIFY);

	RegConsoleCmd("+paint", Command_EnablePaint);
	RegConsoleCmd("-paint", Command_DisablePaint);
	RegConsoleCmd("sm_paint", Command_Paint);

	gH_PaintColour = RegClientCookie("paint_colour", "Paint colour", CookieAccess_Protected);
	gH_PaintSize = RegClientCookie("paint_size", "Paint size", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	if (!GetClientCookieInt(client, gH_PaintColour, gI_PaintColour[client]))
	{
		gI_PaintColour[client] = 0;
		SetClientCookieInt(client, gH_PaintColour, 0);
	}

	if (!GetClientCookieInt(client, gH_PaintSize, gI_PaintSize[client]))
	{
		gI_PaintSize[client] = 0;
		SetClientCookieInt(client, gH_PaintSize, 0);
	}
}

public void OnMapStart()
{
	AddFileToDownloadsTable("materials/decals/paint/paint_decal.vtf");

	char buffer[PLATFORM_MAX_PATH];
	for (int colour = 1; colour < sizeof(gC_PaintColours); colour++)
	{
		for (int size = 0; size < sizeof(gC_PaintSizes); size++)
		{
			Format(buffer, sizeof(buffer), "decals/paint/%s%s.vmt", gC_PaintColours[colour][1], gC_PaintSizes[size][1]);
			gI_Sprites[colour - 1][size] = PrecachePaint(buffer); // colour - 1 because starts from [1], [0] is reserved for random.
		}
	}

	CreateTimer(0.1, Timer_Paint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Paint(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && gB_IsPainting[i])
		{
			static float position[3];
			TraceEye(i, position);

			if (GetVectorDistance(position, gF_LastPaintPosition[i], true) > PAINT_DISTANCE_SQ)
			{
				AddPaint(position, gI_PaintColour[i], gI_PaintSize[i]);

				gF_LastPaintPosition[i] = position;
			}
		}
	}
}

void AddPaint(float position[3], int colour = 0, int size = 0)
{
	if (colour == 0)
	{
		colour = GetRandomInt(1, sizeof(gC_PaintColours) - 1);
	}

	TE_SetupWorldDecal(position, gI_Sprites[colour - 1][size]);
	TE_SendToAll();
}

public Action Command_EnablePaint(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_IsPainting[client] = true;

	return Plugin_Handled;
}

public Action Command_DisablePaint(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_IsPainting[client] = false;

	return Plugin_Handled;
}

public Action Command_Paint(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu_Paint(client);

	return Plugin_Handled;
}

void Menu_Paint(int client)
{
	Menu menu = new Menu(MenuHandler_Paint);

	menu.SetTitle("Paint");
	menu.AddItem("paint", gB_IsPainting[client] ? "-paint" : "+paint");
	menu.AddItem("colour", "Select colour");
	menu.AddItem("size", "Select size");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Paint(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if (StrEqual(info, "paint"))
		{
			gB_IsPainting[param1] = !gB_IsPainting[param1];
			Menu_Paint(param1);
		}
		else if (StrEqual(info, "colour"))
		{
			Menu_PaintColour(param1);
		}
		else if (StrEqual(info, "size"))
		{
			Menu_PaintSize(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void Menu_PaintColour(int client)
{
	Menu menu = new Menu(MenuHandler_PaintColour);

	menu.SetTitle("Paint - Select Colour");

	for (int i = 0; i < sizeof(gC_PaintColours); i++)
	{
		menu.AddItem(gC_PaintColours[i][0], gC_PaintColours[i][0]);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PaintColour(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		gI_PaintColour[param1] = param2;
		SetClientCookieInt(param1, gH_PaintColour, param2);
		PrintToChat(param1, "[SM] Paint colour: %s", gC_PaintColours[param2][0]);

		Menu_PaintColour(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			Menu_Paint(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void Menu_PaintSize(int client)
{
	Menu menu = new Menu(MenuHandler_PaintSize);

	menu.SetTitle("Paint - Select Size");

	for (int i = 0; i < sizeof(gC_PaintSizes); i++)
	{
		menu.AddItem(gC_PaintSizes[i][0], gC_PaintSizes[i][0]);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PaintSize(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		gI_PaintSize[param1] = param2;
		SetClientCookieInt(param1, gH_PaintSize, param2);
		PrintToChat(param1, "[SM] Paint size: %s", gC_PaintSizes[param2][0]);

		Menu_PaintSize(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			Menu_Paint(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

int PrecachePaint(char[] filename)
{
	char path[PLATFORM_MAX_PATH];
	Format(path, sizeof(path), "materials/%s", filename);
	AddFileToDownloadsTable(path);

	return PrecacheDecal(filename, true);
}

stock void TE_SetupWorldDecal(const float origin[3], int index)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", origin);
	TE_WriteNum("m_nIndex", index);
}

stock void TraceEye(int client, float position[3])
{
	float origin[3];
	GetClientEyePosition(client, origin);

	float angles[3];
	GetClientEyeAngles(client, angles);

	TR_TraceRayFilter(origin, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit())
	{
		TR_GetEndPosition(position);
	}
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return (entity > MaxClients || !entity);
}

stock bool IsValidClient(int client)
{
	return (0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

stock void SetClientCookieInt(int client, Handle cookie, int value)
{
	char buffer[8];
	IntToString(value, buffer, sizeof(buffer));

	SetClientCookie(client, cookie, buffer);
}

stock bool GetClientCookieInt(int client, Handle cookie, int& value)
{
	char buffer[8];
	GetClientCookie(client, cookie, buffer, sizeof(buffer));

	if (buffer[0] == '\0')
	{
		return false;
	}

	value = StringToInt(buffer);
	return true;
}
