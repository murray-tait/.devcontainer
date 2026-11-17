@echo off
echo Initializing on Windows...
if not exist "%USERPROFILE%.aws" mkdir "%USERPROFILE%.aws"
if not exist "%USERPROFILE%.ssh" mkdir "%USERPROFILE%.ssh"
if not exist "%USERPROFILE%.config" mkdir "%USERPROFILE%.config"
if not exist "%USERPROFILE%.gitconfig" type nul > "%USERPROFILE%.gitconfig"