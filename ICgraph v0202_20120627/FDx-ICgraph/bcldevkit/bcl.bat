set TARGET=%1.bas
set IS_BCL=0

cd %1
del *.bak
if exist %1.bcl (
	mkdir bcl
	copy *.bcl bcl
	set TARGET=%1.bcl
	set IS_BCL=1
)

..\..\tools\tokenizer.exe audio %TARGET%
if errorlevel 1 goto quit
if "%IS_BCL%"=="1" del %1.bas
cd ..
..\tools\web2cob /o %1.cob /d %1
if !%2==! goto endit
tftp -i %2 put %1.cob WEB6
goto endit
:quit
echo "ERROR - TOKENIZER REPORTS FAILURE"
cd ..
:endit
