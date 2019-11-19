Update Kit
==========

Version overview
----------------

Type        File name             Flash Target      Version_Date
Firmware    abclw.rom             8K                VB1.06_20120601
WEB UI      abclapp.cob           WEB4              V01.16_20120404
FW Ext. 1   sg.bin                WEB2              VA9.19_20120531
FW Ext. 2   fs.bin                WEB1              V02.06_20110322
FW Ext. 3   bclio.bin             WEB9              V01.23_20120329
ES Module   esnd.rom              WEB8              V00.05_20091230
Bootloader  UNIFULL.SPB           serial only       V99.26_20120223



Content
-------

The Update Kit comes in a ZIP file format and contains 5 sub folders:

A) update_rescue    update via web browser or rescue via serial cable
B) versionhistory   version history of each part
C) webuidevkit      web ui development kit
D) bcldevkit        BCL example applications and development kit
E) tools            helper tools for webuidevkit and bcldevkit
F) gold_unit        files for the Gold Unit update procedure


Documentation
-------------
This version of ABCL implements BCL language as described in the BCL Programmers Manual version 1.17.


Installation
------------

First extract the Update Kit using a zip tool like WinZIP or the like.



A1.1) How to update your device (requires a standard web browser)
-----------------------------------------------------------------
Please Note:
The update described below will NOT change the current configuration settings!
Reverting to Factory Defaults is not needed but recommended.

1. Open a browser and type the IP address announced into the URL field and hit
   the ENTER key.
2. Click on the UPDATE button to enter the update page.
3. Click on "Please click here to continue" to launch the update process.
   The device will restart in a special mode called Bootloader showing a
   number counting down. Upon start up the following screen appears ready
   for the update process.
   (The word Browse may differ depending on browser and language).
____________________________________________________
Update  Barix Bootloader version date               |
                                                    |
---------------------------------------------       |
Resource                               Browse       |
                                       Upload       |
                                       Reboot       |
---------------------------------------------       |
                                                    |
Advanced Update                                     |
---------------                                     |
____________________________________________________|

4. To update the software click "Browse" to locate the file you want to upload.
   Browse to the folder "update_rescue" and choose the file compound.bin.
5. Once selected, click "Upload". This process can take a few minutes.
   After a successful upload click the "update" link and when the Update
   window reappears click the "Reboot" button or if there is no button, click
   Browse and select the file "reboot". The device will reboot with the new
   firmware.

A1.2) Advanced update
---------------------
Individual files may be loaded using the Advanced Update.

1-3 Steps 1-3 above
4. Click "Advanced Update" and the following screen appears ready for the
   advanced update process. (The word Browse may differ).
____________________________________________________
Advanced Update                                     |
                                                    |
---------------------------------------------       |
Target                                 Browse       |
Resource                               Upload       |
                                       Reboot       |
---------------------------------------------       |
                                                    |
Update                                              |
------                                              |
____________________________________________________|

5. For advanced updates an additional "Target" parameter is required.
   This specifies where in the Flash to load the file.
   Refer to "Version overview" above for a list of flash targets.
   The bootloader is not intended for web uploads but is included in a serial
   "rescue". (see A2 below). 
6. To make an update type in the Target and then click "Browse" to locate
   the corresponding file in the "update_rescue" folder.
7. Once selected, click "Upload". This process can take up to one minute.
   After a successful upload click the "update" link and when the Update
   window reappears click the "Reboot" button.
   The device will reboot with the new resource file.

A2) To rescue your device using Windows XP/2000/NT and serial port
------------------------------------------------------------------
Please Note:
The update described below will CHANGE the current configuration settings!
Open a browser and type the announced IP address followed by "/status" into 
the URL field and hit the ENTER key. Print this page which contains the 
current configuration settings of the device in order to reenter them
after the update.

1.  Unplug power supply.
2.  Use a serial crossover cable to connect your device's serial port to
    that of the PC. 
3.  Start one of the following scripts in the folder "update_rescue"
    depending on the COM port you are using.
    Either use one of the prepared batch files for serial ports COM1-COM4
    or use the serial.bat file directly with a serial port parameter   
     
    serial port  	Use 
    -----------		-----------
    COM 1        	serial1.bat
    COM 2        	serial2.bat
    COM 3        	serial3.bat
    COM 4        	serial4.bat    
    COM n        	serial COMn  

    Also included in the folder "update_rescue" is a "legacy" batch file.
    For a "Legacy Product" use the "legacy" script instead of "serial".
    A description of the "Legacy Products" is provided in the download
    section at www.barix.com.
            
4.  A message 'Waiting for the device' will be shown on the bottom of the
    screen.
5.  Plug in the power supply now.
6.  Wait until a message 'SUCCESSFUL' appears on the second line.
7.  Close the rescue program.
8.  Unplug power supply.
9.  Plug in the power supply.
10. Your device is set to factory defaults and should work now.
    If it does not work, please contact info@barix.com.
11. Reconfigure the unit to your last configuration
    (see note above).

A3) To rescue your device using Linux and other POSIX systems and serial port.
------------------------------------------------------------------------------
1.  Unplug the power supply
2.  Use a serial crossover cable to connect your device's serial port to
    that of the PC. 
3.  Change directory to update_rescue/linux_mac (cd update_rescue/linux_mac)
4.  Start the program according to the instructions in the README file
5.  Plug in the power supply as requested by the program.
6.  Wait until the program finishes
7.  Your device is set to factory defaults and should work now. If it doesn't
    work please contact info@barix.com
8.  Reconfigure the device to your last configuration (see note above).

A4) To rescue your device on a MAC
----------------------------------
Please refer to the instructions in update_rescue/linux_mac/MAC_README.



B) Version history
------------------

The folder "versionhistory" contains a version history text file for each part
of the Update Kit.



C) WEB UI Development Kit (to customize UI appearance)
------------------------------------------------------

Download the WEB UI Development Kit Manual from www.barix.com, read it
carefully and follow the steps to customize the devices UI (User Interface).



D) BCL Development Kit
----------------------

Contains demo applications and compilation tools. To learn how to use the
BCL development kit refer to the ABCL Technical Documentation you can 
download from www.barix.com. A quick howto follows.

D1) Requirements
----------------

The BCL Development Kit is distributed with necessary tools and scripts for
compilation running on both Linux and Windows platforms.

However on Linux operating systems other external programs are required:
  - the DOS emulator "dosemu" (see http://www.dosemu.org/)
  - the Windows emulator "wine" (see http://www.wine.org/) 
  - the Advanced TFTP client "atftp" (see http://freshmeat.net/projects/atftp/) 

All the mentioned programs are expected to be in the system path. If they are
not, modify the scripts accordingly.

D2) How to compile custom BCL application and load into your device
-------------------------------------------------------------------

Attention
Please note that the below procedure will OVERWRITE the original custom
application in the device!

1.  Enter the "custom1" subdirectory of the "bcldevkit" directory
2a. Modify custom1.bas and/or UI files or optionally 
2b  Copy over an existing application and rename files to the custom1 scheme
3.  Switch the device into the update mode either over the WEB interface (3a) 
    or using the reset button (3b)
3a. - Open a web browser window
    - Type in the IP address of your device
    - Click on the "Update" button on the top of the page
    - Click the "Please click here to continue" link in the lower frame
    - Wait until the counter counts down and the Update page appears
3b. - Unplug the power
    - Hold the reset button
    - Plug in the power
    - Wait until the Red LED starts blinking
    - Release the reset button
    - Wait until the Green LED goes on and the Red LED will be blinking
4.  Enter the "bcldevkit" directory and continue with either 4a (Windows users)
    or 4b (Linux users):
4a. On Windows run: 
                     bcl.bat custom1 <ip address of your device>
4b. On Linux run: 
                     ./bcl.sh custom1 <ip address of your device>
5.  Reboot the device by pressing the reset button



E) Tools
--------
The folder "tools" contains the tokenizer, web2cob and additional conversion
tools.


F) Gold Unit
-------------
Please refer to the _readme1st.txt file in the gold_unit folder



Copyright information
------------------------

GPL-covered files
---------------------
The file update_rescue/cygwin1.dll is copyright 2000-2005 Red Hat, Inc.

GPL files are free software; you can redistribute them and/or modify them
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option) any
later version. These files are distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
Public License for more details. You should have received a copy of the GNU
General Public License along with this program in update_rescue/GPL; if not,
write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA  02110-1301, USA.

Remaining files
-------------------
The remaining files are copyright (C) 2006-2010, Barix AG. All rights reserved.

-------------------------------------------------------------------------------
This document is copyright (C) 2010, Barix AG. All rights reserved.

Barix AG assumes no responsibility for errors or omissions in this document.
Nor does Barix make any commitment to update the information contained herein.

Other product and corporate names may be trademarks of other companies and are
used only for explanation and to the owners' benefit, without intent to
infringe.


