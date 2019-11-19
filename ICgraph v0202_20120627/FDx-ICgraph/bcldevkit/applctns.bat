set WEB2COB=..\tools\web2cob
set CPCRLF=..\tools\cpcrlf

set APPLICATIONS=annunfdx

mkdir bla
for %%n in (%APPLICATIONS%) ; do (
	cd %%n
	del *.bak
	if exist %%n.bcl (
		mkdir bcl
		copy *.bcl bcl
		..\..\tools\tokenizer audio %%n.bcl
		del %%n.bas
		rmdir /s /q bcl
	) else (
		..\..\tools\tokenizer audio %%n.bas
	)
	cd ..)

for %%n in (%APPLICATIONS%) ; do copy %%n\*.* bla

copy appconfig.bin bla

%WEB2COB% /o applications.cob /d bla

rmdir /s /q bla
set WEB2COB=
set CPCRLF=
set APPLICATIONS=
