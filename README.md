# Aquarea & WH-MDC05F3E5_comm_v3.0
Geisha (WH-MDC05f3e5) communicates via USB with FHEM on an RaspberryPi4 [https://www.raspberrypi.org]

http://aquarea.smallsolutions.de/index.php?title=WH-MDC05f3e5

https://github.com/pemue-git/pcb/tree/master/WH-MDC05F3E5_comm

# Manipulate the Baudrate to 960 on the Raspberry via shell (ssh)

We need to enable 960Baud Communication setting to bring the USB Adapter to a working condition.

Install pyusb on the raspberry:

$ sudo apt-get update

$ sudo apt-get install python-pip  

$ sudo pip install pyusb

Download CP210x programmer from Sourceforge:
https://sourceforge.net/projects/cp210x-program/files/latest/download

unpack the Download:

$ sudo tar -xvzf /cp210x-program-1.0.tar.gz


Download the content from the eeprom:

$ cd cp210x-program-1.0

$ sudo ./cp210x-program -f eeprom.hex

If you want - you can do a backup of the Original content.


set the Baudrate in the 2102s eeprom Baudrate-Table (@1200Baud position) to 960

$ sudo ./cp210x-program -p -F eeprom.hex -w --set-baudrate 1200:9E58,FE0C,1

Change the USB-Device Product String (not necessary but nice to identify the USB-Device)

$ sudo ./cp210x-program -w --set-product-string='1200=960 for GeishaCom'

Doublecheck the effect of the settings:

$ sudo ./cp210x-program

Reboot the System in order to make the changes known for the Kernel 

Check the USB-Device connection via lsusb:

$ lsusb

Check the USB Device ID at /dev/serial/by-id



# Update add 67_Aquarea.pm

let FHEM Download the 67_Aquarea.pm modul and add this github Account to your update library.

update add https://raw.githubusercontent.com/der-lolo/aquarea/master/controls_aquarea.txt


