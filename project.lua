require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.PixelFormat"
import "android.content.Context"
import "android.os.Handler"
import "android.os.Vibrator"
import "java.io.File"
import "android.media.MediaPlayer"
import "com.androlua.Http"
import "android.content.Intent"
import "android.net.Uri"

-- --- FILE SETUP ---
local folderPath = "/sdcard/Download/BubbleShooter/sounds/"
File(folderPath).mkdirs()
local moveSound = folderPath.."move.mp3"
local fireSound = folderPath.."fire.mp3"

local movePlayer = MediaPlayer()
local firePlayer = MediaPlayer()

local wm = service.getSystemService(service.WINDOW_SERVICE)
local vibrator = service.getSystemService(Context.VIBRATOR_SERVICE)
local handler = Handler()
local level = 1
local isPlaying = false
local currentPos = -1.0

-- --- SETTINGS VARIABLES ---
local useVibration = true
local useSound = true
local maxGoal = 100

-- --- MAIN UI LAYOUT ---
mainLayout = {
  LinearLayout,
  id="mainView",
  orientation="vertical",
  gravity="center",
  layout_width="fill",
  layout_height="fill",
  backgroundColor=0xFF000000,
  {TextView, text="Bubble Shooter V 1.0", textSize="30sp", textColor=0xFFFFFFFF},
  {View, layout_height="10dp"},
  {Button, id="aboutBtn", text="ABOUT", layout_width="250dp", layout_height="50dp"},
  {View, layout_height="10dp"},
  {Button, id="settingsBtn", text="SETTINGS", layout_width="250dp", layout_height="50dp"},
  {View, layout_height="20dp"},
  {TextView, id="lvlTxt", text="Level: 1", textSize="25sp", textColor=0xFF00FF00},
  {TextView, id="goalTxt", text="Goal: 100", textSize="14sp", textColor=0xFFAAAAAA},
  {View, layout_height="30dp"},
  {Button, id="startBtn", text="START MISSION", layout_width="250dp", layout_height="100dp"},
  {Button, id="shootBtn", text="FIRE!", layout_width="fill", layout_height="350dp", visibility=8},
  {View, layout_height="25dp"},
  {Button, id="exitBtn", text="EXIT", layout_width="120dp", layout_height="60dp"}
}

-- --- ABOUT UI LAYOUT ---
aboutLayout = {
  ScrollView,
  layout_width="fill",
  layout_height="fill",
  backgroundColor=0xFF000000,
  {LinearLayout,
    orientation="vertical",
    gravity="center",
    padding="20dp",
    {TextView, text="Bubble Shooter V 1.0", textSize="24sp", textColor=0xFF00FFFF, padding="10dp"},
    {TextView, text="FULL USER GUIDE", textSize="18sp", textColor=0xFFFFFFFF, padding="5dp"},
    {TextView, text="1. HOW TO PLAY: The bubble moves from the Left Speaker to the Right Speaker. Listen closely. When the sound is in the middle and you feel vibration, click FIRE.", textSize="14sp", textColor=0xFFFFFFFF, padding="5dp"},
    {TextView, text="2. LEVELING: Success increases speed. Failure drops you one level.", textSize="14sp", textColor=0xFFFFFFFF, padding="5dp"},
    {TextView, text="3. CHALLENGE: Set your target level in Settings to complete the mission.", textSize="14sp", textColor=0xFFFFFFFF, padding="5dp"},
    {View, layout_height="20dp"},
    {TextView, text="SETTINGS GUIDE", textSize="18sp", textColor=0xFF00FFFF},
    {TextView, text="- Vibration/Sound: Toggle haptic and audio feedback.\n- Target: Set goal (1-100).", textSize="14sp", textColor=0xFFFFFFFF, padding="5dp"},
    {View, layout_height="25dp"},
    {TextView, text="Developed by Nani", textSize="18sp", textColor=0xFFFFFFFF},
    {TextView, text="Special thanks to Vamsi Krishna for testing this project and for being a part of this project", textSize="14sp", textColor=0xFFAAAAAA, gravity="center", padding="10dp"},
    {View, layout_height="20dp"},
    {Button, id="tgJoin", text="Join Telegram Channel", layout_width="250dp", backgroundColor=0xFF0088CC},
    {View, layout_height="15dp"},
    {Button, id="closeAbout", text="BACK TO GAME", layout_width="200dp"},
    {View, layout_height="30dp"},
  }
}

-- --- SETTINGS UI LAYOUT ---
settingsLayout = {
  LinearLayout,
  orientation="vertical",
  gravity="center",
  layout_width="fill",
  layout_height="fill",
  backgroundColor=0xFF000000,
  padding="20dp",
  {TextView, text="GAME SETTINGS", textSize="24sp", textColor=0xFFFFFFFF},
  {View, layout_height="30dp"},
  {CheckBox, id="vibCb", text="Vibration Feedback", checked=true, textColor=0xFFFFFFFF},
  {CheckBox, id="sndCb", text="Sound Feedback", checked=true, textColor=0xFFFFFFFF},
  {View, layout_height="20dp"},
  {TextView, text="Set Level Challenge (1-100)", textColor=0xFFFFFFFF},
  {SeekBar, id="levelSeek", max=100, progress=100, layout_width="250dp"},
  {TextView, id="seekVal", text="Target: 100", textColor=0xFF00FF00},
  {View, layout_height="40dp"},
  {Button, id="saveSettings", text="SAVE & APPLY", layout_width="200dp", layout_height="60dp"},
}

local view = loadlayout(mainLayout)
local sView = loadlayout(settingsLayout)
local aView = loadlayout(aboutLayout)
local lp = WindowManager_LayoutParams()
lp.type = WindowManager_LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
lp.format = PixelFormat.TRANSLUCENT

-- --- NAVIGATION ---
aboutBtn.onClick = function() wm.removeView(view); wm.addView(aView, lp) end
closeAbout.onClick = function() wm.removeView(aView); wm.addView(view, lp) end
settingsBtn.onClick = function() wm.removeView(view); wm.addView(sView, lp) end

saveSettings.onClick = function()
  useVibration = vibCb.isChecked()
  useSound = sndCb.isChecked()
  maxGoal = levelSeek.getProgress()
  if maxGoal == 0 then maxGoal = 1 end
  goalTxt.setText("Goal: "..maxGoal)
  wm.removeView(sView)
  wm.addView(view, lp)
  -- If sound is turned off, stop any playing sound immediately
  if not useSound then movePlayer.stop() end
end

levelSeek.setOnSeekBarChangeListener{
  onProgressChanged=function(v,p) seekVal.setText("Target: "..p) end
}

tgJoin.onClick = function()
  pcall(function() wm.removeView(aView) end)
  local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/JieshuoStudioHub"))
  intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
  service.startActivity(intent)
end

-- --- GAME ENGINE ---
gameRunnable = Runnable{
  run=function()
    if not isPlaying then return end
    currentPos = currentPos + (0.020 + (level * 0.005))
    
    if useSound then
      local leftVol = 1.0 - ((currentPos + 1) / 2)
      local rightVol = (currentPos + 1) / 2
      movePlayer.setVolume(leftVol, rightVol)
      if not movePlayer.isPlaying() then
        pcall(function()
          movePlayer.reset()
          movePlayer.setDataSource(moveSound)
          movePlayer.prepare()
          movePlayer.setLooping(true)
          movePlayer.start()
        end)
      end
    end

    if useVibration and currentPos > -0.2 and currentPos < 0.2 then
      vibrator.vibrate(60)
    end

    if currentPos >= 1.0 then
      failGame()
    else
      handler.postDelayed(gameRunnable, 60)
    end
  end
}

function failGame()
  isPlaying = false
  movePlayer.stop()
  level = math.max(1, level - 1)
  lvlTxt.setText("Level: " .. level)
  startBtn.setVisibility(0); aboutBtn.setVisibility(0); settingsBtn.setVisibility(0); exitBtn.setVisibility(0); shootBtn.setVisibility(8)
end

startBtn.onClick = function()
  if not File(moveSound).exists() then print("Wait, sounds still downloading...") return end
  startBtn.setVisibility(8); aboutBtn.setVisibility(8); settingsBtn.setVisibility(8); exitBtn.setVisibility(8); shootBtn.setVisibility(0)
  currentPos = -1.0; isPlaying = true; handler.post(gameRunnable)
end

shootBtn.onClick = function()
  if currentPos > -0.25 and currentPos < 0.25 then
    isPlaying = false
    movePlayer.stop() 
    
    -- Updated to check useSound before playing success bubble sound
    if useSound then
      pcall(function()
        firePlayer.reset()
        firePlayer.setDataSource(fireSound)
        firePlayer.prepare()
        firePlayer.start()
      end)
    end
    
    if level >= maxGoal then
      print("Challenge completed! Target "..maxGoal.." reached.")
      level = 1
      lvlTxt.setText("Level: 1")
      failGame()
    else
      level = level + 1
      lvlTxt.setText("Level: " .. level)
      handler.postDelayed(Runnable{run=function() startBtn.performClick() end}, 1200)
    end
  else
    failGame()
  end
end

exitBtn.onClick = function()
  isPlaying = false; movePlayer.release(); firePlayer.release()
  pcall(function() wm.removeView(view) end)
  pcall(function() wm.removeView(aView) end)
  pcall(function() wm.removeView(sView) end)
end

-- --- INSTANT LOAD LOGIC ---
function initGame()
  wm.addView(view, lp)
  local f1, f2 = File(moveSound), File(fireSound)
  if not f1.exists() or f1.length() == 0 then
    Http.download("https://docs.google.com/uc?export=download&id=1KNcTLRDvSPTSe7jHfzEwW5sQkDR6rxiG", moveSound, function() end)
  end
  if not f2.exists() or f2.length() == 0 then
    Http.download("https://docs.google.com/uc?export=download&id=1x2tj5VPdn11Wmo_ROhTzGqT5sObd5Mxz", fireSound, function() end)
  end
end

initGame()
