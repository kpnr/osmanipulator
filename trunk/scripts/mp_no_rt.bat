@echo off
echo osm to no-route-mp convertion with map cover polygon
echo Usage:
echo mp_no_rt.bat "osm file.osm" "output file.mp" "osm2mp extended params"
echo Current config:
echo osm=%1
echo out=%2
echo ext params=%~3
pushd
%~d0
cd "%~p0"
@echo on
osm2mp.pl --config=navitel-ru.cfg --load-settings=settings-navitel.yml %~3 --output=%2 %1
if errorlevel 1 goto end
mp-postprocess-navitel.pl %2
:end
popd
exit /B %errorlevel%