@echo off 

set version=%~1
echo compiling..
call gulp compile

echo adding new files..
call git add .

echo commiting tag..
call git commit -m "%version%"

echo creating tag %version%..
call git tag -a %version% -m "%version%"

echo pushing..
call git push