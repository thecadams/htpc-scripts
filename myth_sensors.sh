#!/bin/bash

# Read CPU temps
echo -n "Current CPU temperatures:<ul>"
sensors|grep Core|sed -e 's/\([0-9]\.[0-9]\) C/\1\&deg;C/g' -e "s/\xC2\xB0/\&deg;/g" -e 's@^@<li>@' -e 's@$@</li>@'|tr -d \\n
echo -n "</ul>"

echo -n "Current GPU temperature:<ul>"
sudo sh -c "nvidia-settings -c :0 -q GPUCoreTemp 2>/dev/null" myth|grep Attribute|sed -e 's/.*: //' -e 's/\([0-9]*\).$/\1/' -e 's/$/\&deg;C/g' -e 's@^@<li>GPU 1 (Nvidia): @' -e 's@$@</li>@'|tr -d \\n
echo -n "</ul>"

echo -n "Current hard drive temperature:<ul>"
sudo hddtemp /dev/sda|sed -e 's@:.*:@:@' -e 's/\([0-9]\) C/\1\&deg;C/g' -e "s/\xC2\xB0/\&deg;/g" -e 's@^@<li>@' -e 's@$@</li>@'|tr -d \\n
sudo hddtemp /dev/sdb|sed -e 's@:.*:@:@' -e 's/\([0-9]\) C/\1\&deg;C/g' -e "s/\xC2\xB0/\&deg;/g" -e 's@^@<li>@' -e 's@$@</li>@'|tr -d \\n
echo -n "</ul>"
