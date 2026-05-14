@echo off
title FranklinWH Auto-Save Setup
color 0A
powershell -ExecutionPolicy Bypass -Command "irm 'https://gist.githubusercontent.com/CBullardFranklin/8d3039adb923785068d76d3138d9a5d3/raw/setup-autosave.ps1' | iex"
