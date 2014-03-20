set version=%~dp0
gulp compile
git tag -a %version% -m "%version%"
git add .
git commit -m "%version%"
git push