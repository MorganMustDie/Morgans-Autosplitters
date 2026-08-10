//CLEANING UP THE PUZZLE GALLERY ASL by MorganMustDie
//Message me @morganmustdie on Discord for additions, issues or changes

state("CleaningUpThePuzzleGallery")
{

}

startup
{
  //https://github.com/ero-qt/asl-help
  Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
  vars.Helper.LoadSceneManager = true;

  //SETTINGS
  //Along with the settingId, name and tooltip, there is a "trigger" field containing a key phrase we can use to trigger splits later. Rather than check the value of every single split setting on each frame,
  //we create a Dictionary of splits that sorts each split by its trigger phrase and check that dictionary every time an event in game is triggered.
  //That allows me to keep multiple duplicates of settings in different categories with the same split names and triggers without needing to check them individually.

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

  settings.Add("igt", true, "Use the in-game timer (Skips tutorial, pauses when menu open)");
  addSetting("tutorial", "Tutorial (Only check if using RTA and not IGT)", "Tutorial", "Finish the tutorial and enter the main gallery");
  addSetting("allpaint", "Split on all completed paintings (Overwrites other painting splits)", "paint", "Split on every completed painting");
  
  settings.Add("paintings", false, "Split by number of completed paintings");
  settings.CurrentDefaultParent = "paintings";
           //settingId,         name,                trigger,      tooltip
  addSetting("paintings_1",     "1 Painting",        "paint1",     "Complete 1 painting");
  addSetting("paintings_5",     "5 Paintings",       "paint5",     "Complete 5 paintings");
  addSetting("paintings_10",    "10 Paintings",      "paint10",    "Complete 10 paintings");
  addSetting("paintings_20",    "20 Paintings",      "paint20",    "Complete 20 paintings");
  addSetting("paintings_30",    "30 Paintings",      "paint30",    "Complete 30 paintings");
  addSetting("paintings_50",    "50 Paintings",      "paint50",    "Complete 50 paintings");
  addSetting("paintings_60",    "60 Paintings",      "paint60",    "Complete 60 paintings");
  addSetting("paintings_70",    "70 Paintings",      "paint10",    "Complete 70 paintings");
  addSetting("paintings_83",    "83 Paintings",      "paint83",    "Complete all paintings");
  settings.CurrentDefaultParent = null;

  settings.Add("pieces", true, "Split by number of placed pieces (Overwrites painting splits)");
  settings.CurrentDefaultParent = "pieces";
  addSetting("pieces_10",       "10 Pieces",         "0010",       "Placed 10 pieces");
  addSetting("pieces_25",       "25 Pieces",         "0025",       "Placed 25 pieces");
  addSetting("pieces_50",       "50 Pieces",         "0050",       "Placed 50 pieces");
  addSetting("pieces_100",      "100 Pieces",        "0100",       "Placed 100 pieces");
  addSetting("pieces_200",      "200 Pieces",        "0200",       "Placed 200 pieces");
  addSetting("pieces_300",      "300 Pieces",        "0300",       "Placed 300 pieces");
  addSetting("pieces_500",      "500 Pieces",        "0500",       "Placed 500 pieces");
  addSetting("pieces_750",      "750 Pieces",        "0750",       "Placed 750 pieces");
  addSetting("pieces_1000",     "1000 Pieces",       "1000",       "Placed 1000 pieces");
  addSetting("pieces_1500",     "1500 Pieces",       "1500",       "Placed 1500 pieces");
  addSetting("pieces_2034",     "2034 Pieces",       "2034",       "Placed 2034 pieces");
  settings.CurrentDefaultParent = null;
}

init
{
  vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
  {
    var gf = mono["Assembly-CSharp", "GameFlow"];//The main game handler in CUTPG is called the GameFlow. Sick as fuck.
    print("Successfully loaded GameFlow.");

    vars.Helper["state"] = mono.Make<bool>(gf, "Instance", "State");//0 when on the main menu, 1 when in-game
    vars.Helper["tutorialOver"] = mono.Make<bool>(gf, "Instance", "intro", "door", "IsOpen");//Triggers on the door opening to enter the main gallery

    //For some reason the game stores a ton of information in its HUD object regardless of whether or not it's displayed on screen
    vars.Helper["timerRunning"] = mono.Make<bool>(gf, "Instance", "hud", "timerRunning"); //Turns to 1 once the in game timer starts
    vars.Helper["gameTimer"] = mono.Make<float>(gf, "Instance", "hud", "elapsed");//Counts the number of seconds elapsed
	vars.Helper["pieceCount"] = mono.MakeString(gf, "Instance", "hud", "placedText", 0xC8);//Counts the number of pieces placed in the correct spot and orientation
    vars.Helper["paintingCount"] = mono.Make<int>(gf, "Instance", "hud", "donePuzzles");//Counts the number of completed puzzles
    print("Successfully found all variables.");

    //Trigger is the key phrase we check for to see if in-game events are tied to splits. The names of triggers are stored once checked, so you can't split on the same trigger twice in a run
    vars.trigger = "";
    vars.triggersChecked = new List<string>();

    return true;
  });
}

update
{
  if(settings["pieces"]){//Pieces setting overwrites painting splits
    if(current.pieceCount != null && (current.pieceCount != old.pieceCount)){
      print("Piece count updated: " + current.pieceCount);
      vars.trigger = current.pieceCount.Substring(0, 4);
      //Literally the only accessible place in the game that the piece count is stored is the text on the HUD. When you place a piece, it updates the HUD text directly, so I need to cut the " / 2034" off the end. Bizarre!
    }
  }else{
    if(current.paintingCount != null && (current.paintingCount != old.paintingCount)){
      print("Painting count updated: " + current.paintingCount);
      vars.trigger = "paint";
      if(!settings["allpaint"]){ //"paint" is the trigger phrase for the allpaintings setting, so if allpaintings is turned off, the number of the most recent painting is appended to the end instead
        vars.trigger += current.paintingCount;
      }
    }
  }

  if(!old.tutorialOver && current.tutorialOver){
    vars.trigger = "Tutorial";
  }
}

start
{
  if(settings["igt"]){
    if(!old.timerRunning && current.timerRunning){//In game timer doesn't run during tutorial or when the game is paused
      print("Speedrun starting!");
      return true;
    }
  }else{
    if(!old.state && current.state){//Activates the second you hit new game
      print("Speedrun starting!");
      return true;
    }
  }
}

gameTime{
  if(settings["igt"]){
    if(current.timerRunning != null && old.timerRunning){
      return TimeSpan.FromSeconds(current.gameTimer); //In game timer is stored as a float, meaning it can sometimes look jittery on livesplit
    }
  }
}

isLoading
{
  if(settings["igt"]){
    return true;
  }
}

reset
{
  if(old.state && !current.state){//Reset if you return to the menu, clears checked triggers
    vars.triggersChecked.Clear();
    return true;
  }
}

exit
{

}

split
{
  //Regardless of what kind of event has been activated, the trigger variable should now be set to something noteworthy.
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
