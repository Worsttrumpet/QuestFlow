:: Run this batch script to update this repo and all of its submodules with a single button press.
@echo off
setlocal

:: Update all relative repos first.
for /d %%d in (*) do (
	pushd %%d
	call :update_repo
	popd
)

:: Update the AllTheThings repo last.
pushd ..
call :update_repo
EXIT /B 0

:update_repo
if exist .git (
	@echo %cd%
	git pull --recurse-submodules
	git submodule update --remote --recursive
)
EXIT /B 0