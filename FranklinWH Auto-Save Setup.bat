@echo off
title FranklinWH Auto-Save Setup
color 0A
powershell -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/FranklinWH-US/team-setup/main/setup-autosave.ps1' | iex"
