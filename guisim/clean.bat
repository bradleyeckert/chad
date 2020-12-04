rem Copy executable to the bin folder and delete the intermediate files
copy .\Release\gui.exe ..\bin
rmdir Release /s /q
