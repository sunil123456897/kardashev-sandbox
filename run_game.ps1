$godot = (Resolve-Path "C:\Users\vanya\Desktop\*\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe").Path
$proj = (Resolve-Path "E:\Godot*\1").Path
Start-Process -FilePath $godot -ArgumentList @("--path", $proj)
