@ECHO OFF
set CASPER_PATH=.\casperjs
set CASPER_BIN=%CASPER_PATH%\bin\
set ARGV=%*
call phantomjs --ignore-ssl-errors="yes" "%CASPER_BIN%bootstrap.js" --casper-path="%CASPER_PATH%" --cli %ARGV%