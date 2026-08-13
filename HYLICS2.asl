//HYLICS 2 ASL by MorganMustDie with assistance from jbzdarkid, thearst3rd, Illomorpho, and the Speedrun Tools Discord
//Message me @morganmustdie on Discord for additions, issues or changes

state("Hylics2_Windows")
{
  //NewGame and LoadTime memory values provided by Illomorpho
  //Unfortunately they were found via CheatEngine bruteforce so we don't actually know what they're pointing at
  int NewGame: 0x64C740, 0x0;
  int LoadTime: 0x10CD1F0, 0x30, 0x24, 0xA4, 0x4, 0x44, 0x0, 0x48;
}

startup
{
  //https://github.com/ero-qt/asl-help
  Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");

  //I've set this up so any fight you want to split on can be made a split, and any boolean variable change (so long as Hylics 2 keeps track of it) can be made into a split.
  //I'm also tracking gestures and the state of the end game button. Other things, like scene changes or item pickups, are theoretically possible but would need to have their memory addresses hunted down.


  //BATTLES
  //All fights are uniquely defined by the name of the scene they occur in and their ID within that scene, which will print in DebugView whenever you enter a battle.
  //These are the specific scene name/ID pairings for boss fights and encounters that I considered significant. This dictionary isn't strictly necessary, but I found it much nicer to
  //refer to fights by a recognisable name than by their scene name and ID.
  vars.bosses = new Dictionary<Tuple<string, int>, string>
  {
    {Tuple.Create("BanditFort_Scene",10),             "Viewmax"},
    {Tuple.Create("BanditFort_Scene",31),             "Galliform"},
    {Tuple.Create("SomsnosaHouse_Scene",5),           "Somsnosa"},
    {Tuple.Create("MazeScene1",4),                    "Worm"},
    {Tuple.Create("Foglast_Exterior_Dry",9999),       "Odozier"},
    {Tuple.Create("SarcophagousCutscene",0),          "Gibbylet"},
    {Tuple.Create("Dungeon_Labyrinth_Scene_Final",5), "Motor Hunter"},
    {Tuple.Create("FlyingPalaceDungeon_Scene",9999),  "Gibby"},
  };

  //These two variables are used later to refer back to this dictionary in order to keep track of the most recent boss encounter.
  vars.bossKey = Tuple.Create("", 0);
  vars.boss = "";

  //This dictionary enumerates all of the gestures according to their in-game ID #
  vars.gestures = new Dictionary<int, string>
  {{4, "Poromer Bleb"},{14, "Soul Crisper"},{18, "Time Sigil"},{29, "Fate Sandbox"},{31, "Nematode Interface"},{37, "Teledenudate"},{43, "Link Mollusc"},{68, "Charge Up"},{72, "Bombo-Genesis"}};


  //SETTINGS

  //Along with the settingId, name and tooltip, there is a "trigger" field containing a key phrase we can use to trigger splits later. Rather than check the value of every single split setting on each frame,
  //we create a Dictionary of splits that sorts each split by its trigger phrase and check that dictionary every time an event in game is triggered.
  //That allows me to keep multiple duplicates of settings in different categories with the same split names and triggers without needing to check them individually.
  
  //For battles, the trigger phrase is the name of the boss found in the bosses dictionary above.
  //For booleans, the trigger phrase is the in-game key value of the boolean variable we read out of Hylics 2's variableHandler. You can see each of these as they're triggered in DebugView if you're curious.
  //The "End" split works slightly differently, as I'm reading the state of the ending button directly. It has it's own "End" trigger phrase that's activated when the button is pressed.

  vars.splits = new Dictionary<string, List<string>>();
  var addSetting = (Action<string, string, string, string>)((string settingId, string name, string trigger, string tooltip) => {
    settings.Add(settingId, false, name);
    settings.SetToolTip(settingId, tooltip);
    
    List<string> splitsValue;
    if(!vars.splits.TryGetValue(trigger, out splitsValue)){
      splitsValue = new List<string>();
      vars.splits[trigger] = splitsValue;
    }
    splitsValue.Add(settingId);
  });

  settings.Add("any", true, "Any%");
  settings.CurrentDefaultParent = "any";
           //settingId,           name,                         trigger,                                            tooltip
  addSetting("any_pongorma",      "Pongorma",                   "Pongorma_Joined",                                  "Pongorma joins your party");
  addSetting("any_dedusmuln",     "Dedusmuln",                  "Dedusmuln_Joined",                                 "Dedusmuln joins your party");
  addSetting("any_crisper",       "Soul Crisper",               "Soul Crisper",                                     "Learn Soul Crisper");
  addSetting("any_airship",       "Airship",                    "InAirship",                                        "Board the airship");
  addSetting("any_somsnosa",      "Somsnosa",                   "Somsnosa",                                         "Defeat the enemies in Somsnosa's house");
  addSetting("any_worm",          "Worm",                       "Worm",                                             "Defeat Fonthintrelpine");
  addSetting("any_odozier",       "Odozier",                    "Odozier",                                          "Defeat Odozier and Carsoro");
  addSetting("any_drain",         "Drain Reservoir",            "UpperFluid_Deactivated",                           "Drain the Upper Reservoir");
  addSetting("any_gibby",         "Lord Gibby",                 "Gibby",                                            "Defeat Lord Gibby");
  addSetting("any_ending",        "Ending",                     "End",                                              "Press the button to end the game");
  settings.CurrentDefaultParent = null;

  settings.Add("gest", false, "All Gestures");
  settings.CurrentDefaultParent = "gest";
  addSetting("gest_poromer",      "Poromer Bleb",               "Poromer Bleb",                                     "Learn Poromer Bleb");
  addSetting("gest_sage1",        "First Sage",                 "FirstSageVisited",                                 "Visit the first Sage");
  addSetting("gest_sigil",        "Time Sigil",                 "Time Sigil",                                       "Learn Time Sigil");
  addSetting("gest_crisper",      "Soul Crisper",               "Soul Crisper",                                     "Learn Soul Crisper");
  addSetting("gest_fate",         "Fate Sandbox",               "Fate Sandbox",                                     "Learn Fate Sandbox");
  addSetting("gest_worm",         "Worm",                       "Worm",                                             "Defeat Fonthintrelpine");
  addSetting("gest_charge",       "Charge Up",                  "Charge Up",                                        "Learn Charge Up");
  addSetting("gest_arcade2",      "Enter Underground Arcade",   "ORKVariable_spawnPositionHasBeenSet_CarpetLevel",  "Enter Underground Arcade");
  addSetting("gest_arcade2End",   "Finish Underground Arcade",  "Second_Arcade_Completed",                          "Complete Underground Arcade");
  addSetting("gest_link",         "Link Mollusc",               "Link Mollusc",                                     "Learn Link Mollusc");
  addSetting("gest_sage2",        "Second Sage",                "SecondSageVisited",                                "Visit the second Sage");
  addSetting("gest_odozier",      "Odozier",                    "Odozier",                                          "Defeat Odozier and Carsoro");
  addSetting("gest_teledenudate", "Teledenudate",               "Teledenudate",                                     "Learn Teledenudate");
  addSetting("gest_nematode",     "Nematode Interface",         "Nematode Interface",                               "Learn Nematode Interface");
  addSetting("gest_dungeon",      "Enter Dungeon",              "ORK_DungeonPlayerPositionInitialized",             "Enter the Drill Site Dungeon");
  addSetting("gest_sage3",        "Third Sage",                 "ThirdSageVisited",                                 "Visit the third Sage");
  addSetting("gest_motor",        "Motor Hunter",               "Motor Hunter",                                     "Defeat Motor Hunter");
  addSetting("gest_bombo",        "Bombo-Genesis",              "Bombo-Genesis",                                    "Bombo-Genesis");
  addSetting("gest_gibby",        "Lord Gibby",                 "Gibby",                                            "Defeat Lord Gibby");
  addSetting("gest_ending",       "Ending",                     "End",                                              "Press the button to end the game");
  settings.CurrentDefaultParent = null;

  settings.Add("allboss", false, "All Bosses");
  settings.CurrentDefaultParent = "allboss";
  addSetting("allboss_viewmax",   "Viewmax",                    "Viewmax",                                          "Defeat Viewmax");
  addSetting("allboss_galliform", "Galliform",                  "Galliform",                                        "Defeat the Galliform in Viewmax' Edifice");
  addSetting("allboss_somsnosa",  "Somsnosa",                   "Somsnosa",                                         "Defeat the enemies in Somsnosa's house");
  addSetting("allboss_worm",      "Worm",                       "Worm",                                             "Defeat Fonthintrelpine");
  addSetting("allboss_odozier",   "Odozier",                    "Odozier",                                          "Defeat Odozier and Carsoro");
  addSetting("allboss_motor",     "Motor Hunter",               "Motor Hunter",                                     "Defeat Motor Hunter");
  addSetting("allboss_gibby",     "Lord Gibby",                 "Gibby",                                            "Defeat Lord Gibby");
  addSetting("allboss_ending",    "Ending",                     "End",                                              "Press the button to end the game");
  settings.CurrentDefaultParent = null;

  settings.Add("misc", false, "Misc (Silly ones I added because I could)");
  settings.CurrentDefaultParent = "misc";
  addSetting("misc_runsetting",   "Run setting",                "ORK_JoystickRunSwitchBool",                        "Yeah I'm serious. There's a split for changing your run setting.");
  addSetting("misc_blerol",       "Free Blerol",                "BanditPrisonerFreed",                              "Speak to Blerol in his cell");
  addSetting("misc_arcade",       "Enter Viewmax Arcade",       "ORKVariable_spawnPositionHasBeenSet",              "Enter the Arcade in Viewmax' Edifice");
  addSetting("misc_arcadeEnd",    "Finish Viewmax Arcade",      "BanditFort_Arcade_Completed",                      "Complete the Arcade in Viewmax' Edifice");
  addSetting("misc_bath",         "Bathe",                      "ORK_BathHasBeenUsed_Bool",                         "Take a bath");
  addSetting("misc_juice",        "Juice Guy",                  "MinerJuiceGiven_Variable",                         "Give the guy his juice.");
  addSetting("misc_wormdoor",     "Worm Door Opened",           "WormRoomDoorOpened",                               "Enter the Worm Building");
  addSetting("misc_xylem",        "Gibbylet",                   "Xylem_Active",                                     "Lose the Gibbylet fight");
  settings.CurrentDefaultParent = null;

  settings.Add("all_battles", false, "Split after all battles (If ticked, don't tick any other boss splits)");
  settings.CurrentDefaultParent = "all_battles";
  settings.Add("all_battles_but_gibbylet", false, "Exclude Gibbylet");
  settings.CurrentDefaultParent = null;  
}

init
{
  vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
  {
    //A lot of game information is found in ORKFramework.dll rather than the base C# Assembly
  	var battle = mono["ORKFramework", "Battle"];
    var gh = mono["ORKFramework", "GameHandler"];
    print("Successfully loaded Battle and GameHandler");

    //BATTLES
    //These asl-help variables point to memory locations containing relevant battle information that we can piece together to work out what the most recent battle is
	  vars.Helper["inBattle"] = mono.Make<bool>(battle, "instance", "inBattle"); //switches from 0 to 1 when in-game battle UI is active
	  vars.Helper["battleSceneName"] = mono.MakeString(battle, "instance", "battleArena", "sceneName"); //name of the scene a battle takes place in
	  vars.Helper["battleSceneID"] = mono.Make<int>(battle, "instance", "battleArena", "sceneID"); //ID of battle - not completely unique, but each ID only appears once in a given scene
    print("Successfully loaded Battle info");

    //BOOLEANS
    //ORK stores a heap of very useful variables in the variableHandler, in separate dictionaries for each data type and very nicely labelled!
    //Unfortunately the items in those dictionaries don't have permanent positions, but are just added to the end of the dictionary the first time they're set
    //This means, depending on the order the player does things, the values will wind up in different spots. Instead of pulling directly from memory, we'll
    //observe how long the dictionary is and check to see what each new addition is whenever that length updates.
    vars.Helper["boolVars"] = mono.Make<IntPtr>(gh, "instance", "variableHandler", "boolVars");
    //The value for whether or not the end button is pressed lives in a separate dictionary for objects. Since we're looking its boolean value, and not just when it loads in, we create a variable to get it's eventual position
    vars.Helper["objectVars"] = mono.Make<IntPtr>(gh, "instance", "sceneHandler", "objectVariables");
    vars.endButtonLocation = 0;
    print("Successfully loaded boolVars");

	//This points to the list of gestures the player has learned. Specifically, the list is of the gesture IDs, which we convert back into the gesture name with the dictionary above
    vars.Helper["gesturesArray"] = mono.Make<IntPtr>(gh, "instance", "playerHandler", "playerGroup", 0x14, 0x10, 0x10, 0x10);
    print("Successfully loaded gesturesArray");

    //Trigger is the key phrase we check for to see if in-game events are tied to splits. The names of triggers are stored once checked, so you can't split on the same trigger twice in a run
    //Handy when things like save/load spam accidentally read the same variables or pickups twice, but does mean you'll have to manually split if a split is triggered by mistake. I'm working on it.
    vars.trigger = "";
    vars.triggersChecked = new List<string>();

    vars.endButtonLoaded = false;
    vars.endSplit = false;

    return true;
  });
}

update
{
  //Battle entered
  if(current.inBattle & !old.inBattle){
    print("Entered battle" + '\n' + "Battle ID: " + current.battleSceneID + '\n' + "Battle scene: " + current.battleSceneName);
    //Create a bossKey out of the battle scene name and ID and check if that battle is contained in the boss dictionary
    vars.bossKey = Tuple.Create(current.battleSceneName.ToString(), current.battleSceneID);
    if(vars.bosses.ContainsKey(vars.bossKey)){
      vars.bossname = vars.bosses[vars.bossKey];
      print("You are fighting " + vars.bossname);
    }else{
      vars.boss = "";
      print("There is no split associated with this encounter.");
    }
  }

  if(!current.inBattle & old.inBattle){
    if(vars.bosses.ContainsKey(vars.bossKey)){
      vars.trigger = vars.bossname;
    }
  }

  //Check how long the game's boolean dictionary is
  current.BoolsCount = vars.Helper.Read<int>(current.boolVars + 0x20);
  if(old.BoolsCount != current.BoolsCount){ //New boolean detected!
    vars.trigger = vars.Helper.ReadString(current.boolVars + 0x10, 0x10 + 0x4 * (current.BoolsCount - 1));
    print("New boolean added to dictionary: " + vars.trigger);
  }


  //Check how many gestures have been unlocked
  current.GesturesCount = vars.Helper.Read<int>(current.gesturesArray + 0xC);
  if(old.GesturesCount != current.GesturesCount){ //New gesture detected!
    var gesture = vars.Helper.Read<int>(current.gesturesArray + 0x8, 0x10 + 0x04 * (current.GesturesCount - 1));
    print("New gesture learned, ID #:" + gesture);
    if(vars.gestures.ContainsKey(gesture)){
      vars.trigger = vars.gestures[gesture];
      print("You learned " + vars.trigger);
    }else{
      print(gesture + " is not a valid gesture ID");
    }
  }

  //Check how long the game's object dictionary is
  current.ObjectsCount = vars.Helper.Read<int>(current.objectVars + 0x20);
  if(old.ObjectsCount != current.ObjectsCount){
    var newestObject = vars.Helper.ReadString(current.objectVars + 0x10, 0x10 + 0x4 * (current.ObjectsCount - 1));
    print("New object added to dictionary: " + newestObject);
    
    //If Ending button loads in
    if(newestObject == "7db159ea-e4f0-470c-aa6b-80a34042ab09"){
      vars.endButtonLocation = current.ObjectsCount - 1;
      print("Ending button loaded in at: " + vars.endButtonLocation);
      vars.endButtonLoaded = true;
      print("endSplit: " + vars.endSplit);
    }
  }

  if(vars.endButtonLoaded){
    vars.endSplit = vars.Helper.Read<bool>(current.objectVars + 0x14, 0x10 + 0x4 * (vars.endButtonLocation), 0xC, 0x14, 0x10); //The location of the ending button's pressed status
    if(vars.endSplit){
      print("End button pressed!");
      vars.trigger = "End";
    }
  }
}

start
{
  //start autosplitter on first cutscene
  if(old.NewGame == 0 && current.NewGame == 1){
    print("Speedrun started!");
    return true;
  }
}

isLoading
{
  //pause autosplitter when loading
  if(current.LoadTime == 1){
    return true;
  } else{
    return false;
  }
}

reset
{
  //resets autosplitter on main menu
  if(current.NewGame == 0){
    return true;
  }
}

exit
{
  print("Hylics 2 exited!");
}

split
{
  //End of battle splits
  if(old.inBattle & !current.inBattle){ //Battle is over
    //If all battles ticked
    if(settings["all_battles"]){
      print("Split after all battles is on.");
      if(settings["all_battles_but_gibbylet"]){
        if(vars.trigger != "Gibbylet"){
          return true;
        }else{
          print("Gibbylet fight excluded. No split.");
        }
      }else{
        return true;
      }
    }
  }

  //Regardless of what kind of event we've just activated, the trigger variable should now be set to something noteworthy. 
  if(vars.trigger == null){
    print("Trigger is null!");
    vars.trigger = "";
  }else{
    if(vars.trigger != ""){
      print("Checking trigger: " + vars.trigger);
      //Check if there are any splits in our dictionary with an accompanying trigger phrase and split if the answer is yes
      if (vars.splits.ContainsKey(vars.trigger)){
        if(!vars.triggersChecked.Contains(vars.trigger)){
          vars.triggersChecked.Add(vars.trigger);
          List<string> settingIds = vars.splits[vars.trigger];
          print("You have triggered the following splits:");
          foreach(string settingId in settingIds){
            print("Setting " + settingId + " is " + settings[settingId]);
            vars.trigger = "";
            if (settings[settingId]) return true;
          }
        }else{
          print("This trigger has already been split.");
          vars.trigger = "";
        }
      }else{
        print("This trigger is not associated with any splits.");
        vars.trigger = "";
      }
    }
  }
}
