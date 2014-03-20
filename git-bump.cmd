set version=%~1
echo compiling..
call gulp compile

echo creating tag %version%..
call git tag -a %version% -m "%version%"

echo adding new files..
git add .

echo commiting tag..
git commit -m "%version%"

echo pushing..
git push