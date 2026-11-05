# Tector

Första spelbara prototypen av ett eget actionspel i 3D ovanifrån för Windows 11.
Byggt med Godot **4.6.3**, utan externa tillägg eller inköpta resurser.

## Spela

Windows: packa upp Windows-utgåvan och starta `Tector.exe`.
Källkod: öppna `project.godot` i Godot 4.6.3 och tryck F6/F5 (F5 kör projektet).
Alternativt: `godot --path .`.

- Enter: starta uppdraget.
- WASD: rörelse. Mus: sikte. Vänster musknapp: automateld.
- E: aktivera terminalen / stig ombord på skeppet.
- Esc: pausa. R: börja om efter vinst eller förlust.

**Utpost 07, Kepler-186f:** Ta dig österut till den gula reservströmsterminalen.
När du trycker E börjar en 100 sekunder lång evakuering. Passera den östra
öppningen i första väggen, gå västerut genom mittsektionen och passera den
västra öppningen i andra väggen. Skytteln väntar i nordost. Tryck E nära skeppet.
Liv är grönt, ammunition gul och stormgeväret lila. Föremål tas upp automatiskt.

## Utveckling och kontroller

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --smoke-test
mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" build/windows/Tector.exe
```

Export kräver Godots officiella exportmallar för 4.6.3. Spelet har inga
nätverkstjänster, API-nycklar eller externa runtimeberoenden. Vid skrivskyddad
hemmapp kan XDG_DATA_HOME, XDG_CONFIG_HOME och XDG_CACHE_HOME sättas till
skrivbara kataloger utanför repot.

## Om första versionen

En bana, 3D-bas och planetterräng, soldat och sexbenta fiender, två vapen,
projektilkollisioner, upplockningar, reservström, evakueringslarm, paus och omstart.
Egna procedurgenererade stereoeffekter i 48 kHz / 16 bitar används för automateld,
upplockningar och larm. Samplingsfrekvens är ett tekniskt format; ljuden är
prototyper och behöver lyssning och bearbetning för slutlig ljudkvalitet.

Grafiken består av egna geometriska prototypmodeller. Detaljerade skulpterade
monster, animerade soldater, texturer, musik och fler banor återstår. Detta är
en spelmekanisk grund, inte den färdiga visuella kvaliteten. Windows-exporten
måste också speltestas på Windows 11; Linux-kontroller ersätter inte det.
