set _profile=%USERPROFILE%
MKLINK /D c:\USERS\Administrator c:\USERS\�����������
set USERPROFILE=C:\Users\Administrator

REM mkdir build
REM mkdir build\src
REM mkdir build\src\models
REM mkdir node_modules
REM MKLINK /D node_modules\models ..\build\src\models

call npm install

set USERPROFILE=%_profile%

