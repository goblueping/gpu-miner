## How to upgrade windows 10 21H2


**Step 1**: Switch to the `Release Preview` channel in your `Windows Insider settings`

**Step 2**: Download the the [enablement package](https://github.com/goblueping/gpu-miner/raw/main/windows10/windows1021H2/windows10.0-kb5003791-x64.cab) to your **Downloads** folder. (Note: The enablement package is a great option for installing a scoped feature update)

**Step 3**: Open either Powershell or Command Prompt as an admin and type: 

`cd C:\\Users\\%USERNAME%\\Downloads`

`DISM /online /add-package /packagepath:windows10.0-kb5003791-x64.cab`

**Step 4**: Restart your computer

**Step 5**: Verify. Open a Command Prompt and type: `winver`. You should see `21H2`

