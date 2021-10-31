#include <sourcemod>

#include <clientprefs>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "2.0"
#define PAINT_DISTANCE_SQ 1.0

Menu g_hPaintMenu;
Menu g_hPaintSizeMenu;

float g_fLastPaint[MAXPLAYERS + 1][3];
bool g_bIsPainting[MAXPLAYERS + 1];

int gI_PaintColour[MAXPLAYERS + 1];
int gI_PaintSize[MAXPLAYERS + 1];

Handle gH_PaintColour;
Handle gH_PaintSize;

/* COLOURS! */
/* Colour name, file name */
char g_cPaintColours[][][64] = // Modify this to add/change colours
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

/* Size name, size suffix */
char g_cPaintSizes[][][64] = // Modify this to add more sizes
{
	{ "Small", "" },
	{ "Medium", "_med" },
	{ "Large", "_large" },
};

int  g_Sprites[sizeof(g_cPaintColours) - 1][sizeof(g_cPaintSizes)];

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

	RegConsoleCmd("+paint", cmd_EnablePaint);
	RegConsoleCmd("-paint", cmd_DisablePaint);
	RegConsoleCmd("sm_paintcolour", cmd_PaintColour);
	RegConsoleCmd("sm_paintcolor", cmd_PaintColour);
	RegConsoleCmd("sm_paintsize", cmd_PaintSize);

	CreatePaintMenus();

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
	char buffer[PLATFORM_MAX_PATH];

	AddFileToDownloadsTable("materials/decals/paint/paint_decal.vtf");
	for (int colour = 1; colour < sizeof(g_cPaintColours); colour++)
	{
		for (int size = 0; size < sizeof(g_cPaintSizes); size++)
		{
			Format(buffer, sizeof(buffer), "decals/paint/%s%s.vmt", g_cPaintColours[colour][1], g_cPaintSizes[size][1]);
			g_Sprites[colour - 1][size] = PrecachePaint(buffer); // colour - 1 because starts from [1], [0] is reserved for random
		}
	}

	CreateTimer(0.1, Timer_Paint, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action cmd_EnablePaint(int client, int args)
{
	TraceEye(client, g_fLastPaint[client]);
	g_bIsPainting[client] = true;

	return Plugin_Handled;
}

public Action cmd_DisablePaint(int client, int args)
{
	g_bIsPainting[client] = false;

	return Plugin_Handled;
}

public Action cmd_PaintColour(int client, int args)
{
	g_hPaintMenu.Display(client, 20);

	return Plugin_Handled;
}

public Action cmd_PaintSize(int client, int args)
{
	g_hPaintSizeMenu.Display(client, 20);

	return Plugin_Handled;
}

public Action Timer_Paint(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && g_bIsPainting[i])
		{
			static float pos[3];
			TraceEye(i, pos);

			if (GetVectorDistance(pos, g_fLastPaint[i], true) > PAINT_DISTANCE_SQ)
			{
				AddPaint(pos, gI_PaintColour[i], gI_PaintSize[i]);

				g_fLastPaint[i] = pos;
			}
		}
	}
}

void AddPaint(float pos[3], int paint = 0, int size = 0)
{
	if (paint == 0)
	{
		paint = GetRandomInt(1, sizeof(g_cPaintColours) - 1);
	}

	TE_SetupWorldDecal(pos, g_Sprites[paint - 1][size]);
	TE_SendToAll();
}

int PrecachePaint(char[] filename)
{
	char tmpPath[PLATFORM_MAX_PATH];
	Format(tmpPath, sizeof(tmpPath), "materials/%s", filename);
	AddFileToDownloadsTable(tmpPath);

	return PrecacheDecal(filename, true);
}

void CreatePaintMenus()
{
	/* COLOURS MENU */
	delete g_hPaintMenu;
	g_hPaintMenu = new Menu(PaintColourMenuHandle);

	g_hPaintMenu.SetTitle("Select Paint Colour:");

	for (int i = 0; i < sizeof(g_cPaintColours); i++)
	{
		g_hPaintMenu.AddItem(g_cPaintColours[i][0], g_cPaintColours[i][0]);
	}

	/* SIZE MENU */
	delete g_hPaintSizeMenu;
	g_hPaintSizeMenu = new Menu(PaintSizeMenuHandle);

	g_hPaintSizeMenu.SetTitle("Select Paint Size:");

	for (int i = 0; i < sizeof(g_cPaintSizes); i++)
	{
		g_hPaintSizeMenu.AddItem(g_cPaintSizes[i][0], g_cPaintSizes[i][0]);
	}
}

public int PaintColourMenuHandle(Menu menu, MenuAction menuAction, int param1, int param2)
{
	if (menuAction == MenuAction_Select)
	{
		SetClientPaintColour(param1, param2);
	}
}

public int PaintSizeMenuHandle(Menu menu, MenuAction menuAction, int param1, int param2)
{
	if (menuAction == MenuAction_Select)
	{
		SetClientPaintSize(param1, param2);
	}
}

void SetClientPaintColour(int client, int colour)
{
	gI_PaintColour[client] = colour;
	SetClientCookieInt(param1, gH_PaintColour, colour);

	PrintToChat(client, "[SM] Paint colour now: %s", g_cPaintColours[colour][0]);
}

void SetClientPaintSize(int client, int size)
{
	gI_PaintSize[client] = size;
	SetClientCookieInt(param1, gH_PaintSize, size);

	PrintToChat(client, "[SM] Paint size now: %s", g_cPaintSizes[size][0]);
}

stock void TE_SetupWorldDecal(const float vecOrigin[3], int index)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nIndex", index);
}

stock void TraceEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit())
	{
		TR_GetEndPosition(pos);
	}
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return (entity > MaxClients || !entity);
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
