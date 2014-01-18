@echo off

setlocal enabledelayedexpansion

rem Setup the classpath
call "%~dp0setclasspath.bat"

rem Setup the JVM
if not "%JAVA_HOME%"=="" (
  SET JAVA=%JAVA_HOME%\bin\java
) else (
  SET JAVA=java
)

"%JAVA%" -cp "%_CLASSPATH%" com.soasta.tools.scommand.Main %*
