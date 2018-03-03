<#

.SYNOPSIS
	Set-SleepTimer
    Copyright 2018 James Harmison <jharmison@gmail.com>
	Enumerates the target system using a combination of WMI objects, native
	PowerShell cmdlets, and external commands before formatting output into
	tables and writing to a file for later comparison.
.DESCRIPTION
	Uses .NET Forms to prompt the user to enter a sleep timer duration,
    launches a process to manage a five-minute warning popup, and puts the
    computer to sleep after the specified duration. Utilizes a registry key
    to maintain seperate GUIDs for each instance, allowing multiple timers
    to theoretically be set, but reaping them when they are overdue.
.PARAMETER Path
	The path to the .
.PARAMETER LiteralPath
	Specifies a path to one or more locations. Unlike Path, the value of
	LiteralPath is used exactly as it is typed. No characters are interpreted
	as wildcards. If the path includes escape characters, enclose it in single
	quotation marks. Single quotation marks tell Windows PowerShell not to
	interpret any characters as escape sequences.
.NOTES
    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
    BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
    ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
.LINK
    https://www.github.com/solacelost

#>

param (
    # In debug mode, the sleep action never occurs and the console is visible
    [switch]$debug,
    # Should only be used inside the script, indicates that process is subordinate to a main run
    [switch]$confirmRun,
    # Pre-defined GUID, for tracking existing runs through confirmRun. Will be overwritten in main application.
    [string]$myGuid=''
)

# Uncomment the following line to hard-code debug behavior
#$debug = $true

# Add ability to draw  windows
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# This function removes the powershell window from the background
function Hide-Window () {
    $t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
    add-type -name win -member $t -namespace native
    [native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)
}

# Draw a text-input box
function Show-TextBox([int]$x=293,[int]$y=103,[int]$boxW=54,[string]$title='Default Textbox',[string]$text='Default Text',[string]$defaultVal='',[string]$boxLabel='') {
    Write-Host "Displaying text box title:"
    Write-Host "    $title"
    # Basic centered form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size($x,$y)
    $form.StartPosition = "CenterScreen"

    # Draw our OK button near the bottom right
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point($(${x}-125),$(${y}-73))
    $OKButton.Size = New-Object System.Drawing.Size(68,21)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    # Our prompt text, above our input box
    $prompt = New-Object System.Windows.Forms.Label
    $prompt.Location = New-Object System.Drawing.Point(5,7)
    $prompt.Size = New-Object System.Drawing.Size($(${x}-10),20)
    $prompt.Text = $text
    $form.Controls.Add($prompt)

    # Our actual input box drawn
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(5,33)
    $textBox.Size = New-Object System.Drawing.Size($boxW,20)
    $textBox.Text = $defaultVal
    $form.Controls.Add($textBox)

    # An optional label, to the right of the input box
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($(${boxW}+10),33)
    $label.Size = New-Object System.Drawing.Size($(${x}-${boxW}-15),20)
    $label.Text = $boxLabel
    $form.Controls.Add($label)

    $form.Topmost = $True

    # Put the cursor in the textbox
    $form.Add_Shown({$textBox.Select()})

    $result = $form.ShowDialog()

    # Accept the result if OK pressed
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host 'Text box selection:'
        Write-Host "    $($textBox.Text)"
        $textBox.Text
    } else {
        # Return a hard false if they exit
        Write-Host 'Text box selection:'
        Write-Host "    <cancelled>"
        $false
    }
    $form.Dispose()
}

# Draw a popup, optionally with a cancel button
function Show-Popup ([int]$x=373,[int]$y=87,[string]$title='Default Popup',[string]$text='Default Text',[switch]$showCancelButton) {
    Write-Host "Displaying message box title:"
    Write-Host "    $title"
    # Basic centered form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size($x,$y)
    $form.StartPosition = "CenterScreen"

    # Draw our OK button near the bottom right
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point($(${x}-125),$(${y}-73))
    $OKButton.Size = New-Object System.Drawing.Size(68,21)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    # Optional Cancel button placed left of OK
    if ( $showCancelButton ) {
        $CancelButton = New-Object System.Windows.Forms.Button
        $CancelButton.Location = New-Object System.Drawing.Point($(${x}-198),$(${y}-73))
        $CancelButton.Size = New-Object System.Drawing.Size(68,21)
        $CancelButton.Text = "Cancel"
        $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.CancelButton = $CancelButton
        $form.Controls.Add($CancelButton)
    }

    # The text content of our popup
    $message = New-Object System.Windows.Forms.Label
    $message.Location = New-Object System.Drawing.Point(5,7)
    $message.Size = New-Object System.Drawing.Size($(${x}-10),$(${y}-47))
    $message.Text = $text
    $form.Controls.Add($message)

    $form.Topmost = $True

    $result = $form.ShowDialog()

    # If they press OK, just return $true
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host 'Message box selection:'
        Write-Host "    OK"
        $true
    }
    # This will catch Cancel behavior as well as window-exits identically
    else {
        Write-Host 'Message box selection:'
        Write-Host "    <cancelled>"
        $false
    }
    $form.Dispose()
}

# Some tiny functions for working with our date/timestamp specification
function genTimeStamp([int]$minutes = 0) {
    [int64]$( $( $( Get-Date -second 0 -millisecond 0 ).addminutes($($minutes + 1)) ).tofiletime() )
}
function genDateTime([string]$path, [string]$name) {
    [DateTime]::FromFileTime( $( Get-ItemProperty -path $path -name $name).$name )
}
function endIt([int]$code=0) {
    if ( $debug ) { pause }
    exit $code
}

########################################################################
#   End function definitions
########################################################################

Write-Host 'Set-SleepTimer

    Copyright 2018 James Harmison <jharmison@gmail.com>

	Enumerates the target system using a combination of WMI objects, native
	PowerShell cmdlets, and external commands before formatting output into
	tables and writing to a file for later comparison.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'

# Hide our pretty blue box
if ( -not $debug ) { Hide-Window }
Write-Host "$(Get-Date)"
Write-Host 'This is the beginning of the console log.'

# Set our registry key and entries up
$regPath = 'HKCU:\Software\Harmisoft'
Write-Host $('Registry Path: ' + $regPath)

Write-Host "`n`n"

if ( -not $confirmRun ) {
    Write-Host 'Beginning configuration of a new timer'
    # If the path doesn't exist, we should make it.
    $exists = Get-ChildItem $regPath
    if ( -not $? ) {
        Write-Host 'Registry path does not exist. Creating it.'
        New-Item $regPath
        $current = 0
    } else {
        # If it exists, we should clean out old and malformed entries.
        Write-Host 'Enumerating invalid timers:'
        Get-Item $regPath | Select-Object -ExpandProperty Property | ForEach-Object {
            if ( $( New-Timespan -end $( genDateTime -path $regPath -name $_ ) ).TotalMinutes -lt 0 ) {
                Write-Host "    Removing old entry:       $_"
                Remove-ItemProperty -path $regPath -name $_
            }
            if ( -not $? ) {
                Write-Host "    Removing malformed entry: $_"
                Remove-ItemProperty -path $regPath -name $_
            }
        }
        # And count the ones left
        $current = $(Get-ItemProperty $regPath | Measure-Object).count
        Write-Host "Detected $current existing valid entries."
    }

    # There's an existing entry
    if ( $current -ne 0 ) {
        # Build a message displaying them
        Write-Host 'Enumerating existing timers:'
        $text = @("Existing timers:")
        Get-Item $regPath | Select-Object -ExpandProperty Property | ForEach-Object {
            Write-Host "    Valid timer entry:            $_"
            $text += "    $($(genDateTime -path $regPath -name $_).DateTime)"
        }
        $text += "There appears to be one or more sleep timers already."
        $text += ' '
        $text += "Press OK to remove them all, cancel to add another."
        # Figure out how tall to make the box
        $myY = 87 - 40 + ( $($text | Measure-Object).count * 22 )
        $clearTimers = Show-Popup -y $myY -title 'Alert' -text $( $text -join "`n" ) -showCancelButton
        if ( $clearTimers ) {
            Write-Host 'Clearing existing entries'
            Get-Item $regPath | Select-Object -ExpandProperty Property | ForEach-Object {
                Remove-ItemProperty -path $regPath -name $_
            }
        } else { Write-Host 'Keeping existing entries' }
    }

    # New sleep timer needs a GUID for tracking
    $myGuid = [guid]::NewGuid().guid
    Write-Host "New timer ID:"
    Write-Host "    $myGuid"
    $defaultSleep = 90

    # Actually collect the sleep duration
    Write-Host 'Collecting timer info now'
    $sleepTime = Show-TextBox -title 'Sleep Timer' -text 'Enter the duration before sleep:' -defaultVal $defaultSleep -boxLabel 'minutes'
    # If they didn't abort
    if ( $sleepTime -ne $false ) {
        # Let's make sure it's a positive integer
        $sleepDur = [int]$sleepTime
        if ( $sleepDur -ne $sleepTime ) {
            Write-Host 'Non-integer passed'
            Show-Popup -title 'Error' -text 'You entered a non-digit'
            endIt 1
        }
        if ( $sleepDur -le 0 ) {
            Write-Host 'Negative/zero number passed'
            Show-Popup -title 'Error' -text 'Your number must be greater than zero.'
            endIt 1
        }
        # Get our filetime timestamp in the future
        $sleepTime = genTimeStamp -minutes $sleepDur
        Write-Host 'Sleep timer will be set for:'
        Write-Host "    $sleepTime"
        # Set our registry entry for tracking
        New-ItemProperty -path $regPath -name $myGuid -propertytype Qword -value $sleepTime
        # Get the 5-minute warning started
        if ( $sleepDur -gt 5 ) {
            Write-Host 'Starting confirmation process'
            $confProc = Start-Process powershell.exe -ArgumentList "-command $($MyInvocation.MyCommand.Definition) -confirmRun -myGuid $myGuid $(if ($debug) {'-debug'})" -passthru
        } else {
            Write-Host 'No confirmation job necessary'
        }
        Write-Host 'Awaiting sleep time:'
        Write-Host "    $(genDateTime -path $regPath -name $myGuid)"

        while ( $true ) {
            # Always wait at least one minute
            Start-Sleep 60
            # If our GUID exists
            if ( $myGuid -in $(Get-Item $regPath | Select-Object -ExpandProperty Property) ) {
                # Record the time remaining
                $timeLeft = [int]$( New-Timespan -end $( genDateTime -path $regPath -name $myGuid ) ).TotalMinutes
                # If time's up
                if ( $timeLeft -le 0 ) {
                    # Tear everything down
                    Write-Host 'Executing sleep'
                    Remove-ItemProperty -path $regPath -name $myGuid
                    if ( Test-Path variable:global:confProc ) {
                        Stop-Process $confProc -force
                    }
                    if ( -not $debug ) {
                        # Actually suspend
                        & rundll32.exe powrprof.dll,SetSuspendState 0,1,0
                    }
                    endIt
                }
            } else {
                Write-Host 'Entry appears to have been removed:'
                Write-Host "    $myGuid"
                endIt
            }
        }
    } else {
        Write-Host 'Sleep timer aborted.'
        endIt
    }
} else {
    Write-Host "Confirmation run of GUID:"
    Write-Host "    $myGuid"
    Write-Host "Projected sleep time:"
    Write-Host "    $(genDateTime -path $regPath -name $myGuid)`n"
    while ($true) {
        # Every minute or so, check to see if our timer exists and is at 5 minutes
        Start-Sleep 60
        if ( $myGuid -in $(Get-Item $regPath | Select-Object -ExpandProperty Property) ) {
            $timeLeft = [int]$( New-Timespan -end $( genDateTime -path $regPath -name $myGuid ) ).TotalMinutes
            if ( $timeLeft -eq 5 ) {
                # Confirmation dialog to cancel or continue our sleep timer
                $continue = Show-Popup -y 107 -title 'Sleep Timer' -text 'You have five minutes remaining. Press OK to close, Cancel to abort sleep timer.' -showCancelButton
                if ( -not $continue ) {
                    Write-Host "Cancel Requested!"
                    Write-Host "    Removing entry $myGuid"
                    Remove-ItemProperty -path $regPath -name $myGuid
                    endIt
                } else {
                    endIt
                }
            }
            # If we get an error, I anticipate it will be on the New-Timespan line, and the value is propbably malformed
            if ( -not $? ) {
                Write-Host "    Removing malformed entry: $myGuid"
                Remove-ItemProperty -path $regPath -name $myGuid
                endIt
            }
        } else {
            Write-Host "Entry appears to have been removed:"
            Write-Host "    $myGuid"
            endIt
        }
    }
}
