[CmdletBinding()]
$ErrorActionPreference = "Stop"
if (Test-Path -PathType Leaf -Path VERSION) {
    $BASE_STRING = Get-Content VERSION
    $MAJOR, $MINOR, $PATCH = $BASE_STRING -split "\."
    Write-Output "Current version : $BASE_STRING"
    $MINOR = [Int32]$MINOR + 1
    $PATCH = 0
    $SUGGESTED_VERSION = $MAJOR, $MINOR, $PATCH -join "."
    $INPUT_STRING = Read-Host "Enter a version number [$SUGGESTED_VERSION]: "
    if ($INPUT_STRING -eq "") {
        $INPUT_STRING = $SUGGESTED_VERSION
    }
    Write-Output "Will set new version to be $INPUT_STRING"
    $INPUT_STRING | Set-Content VERSION
    "Version $($INPUT_STRING):" | Set-Content tmpfile
    git log --pretty=format:" - %s" "v$BASE_STRING...HEAD" | Add-Content tmpfile
    "" | Add-Content tmpfile
    Get-Content CHANGES | Add-Content tmpfile
    Move-Item -Path tmpfile -Destination CHANGES -Force
    git add CHANGES VERSION
    git commit -m "Version bump to $INPUT_STRING"
    git tag -a -m "Tagging version $INPUT_STRING" "v$INPUT_STRING"
    #git push origin --tags
}
else {
    Write-Output "Could not find a VERSION file"
    $RESPONSE = Read-Host "Do you want to create a version file and start from scratch? [y]"
    if ($RESPONSE -in @("", "y", "yes")) {
        "0.1.0" | Set-Content VERSION
        "Version 0.1.0:" | Set-Content CHANGES
        git log --pretty=format:" - %s" | Add-Content CHANGES
        "" | Add-Content CHANGES
        git add VERSION CHANGES
        git commit -m "Added VERSION and CHANGES files, Version bump to v0.1.0"
        git tag -a -m "Tagging version 0.1.0" "v0.1.0"
        #git push origin --tags
    }
}
Clear-Variable -Name RESPONSE, INPUT_STRING