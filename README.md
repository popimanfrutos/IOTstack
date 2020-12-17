# IOT Stack
IOTstack is a builder for docker-compose to easily make and maintain IoT stacks on the Raspberry Pi.

## UPDATES

17/12/2020
----------
- fixed many small bugs
- added warning and important messages during deployment
- Docker status
- ZAbbix Server stack ( Docker ) and navive agent install.
- Important: Detection of used ports
- new implementation of web access page/server
- new implementation of ngnix proxy panager

14/12/2020
----------
- Update HASSIO INSTALL
- Install cockpit
- Install netdata
- Added messages in stack install
- Added comfiguration of HASSIO storage


## Video
https://youtu.be/kv3fqcbAtns
https://youtu.be/91bnu8zDeNU

## Installation
1. On the (RPi) lite image you will need to install git first

```
sudo apt-get install git -y
```

2. Download the repository with:
```
git clone https://github.com/cayetano/IOTstack.git ~/IOTstack
```

Due to some script restraints, this project needs to be stored in ~/IOTstack

3. To enter the directory and run menu for installation options:
```
cd ~/IOTstack && bash ./menu.sh
```

4. Install docker with the menu, restart your system.

5. Run menu again to select your build options, then start docker-compose with
```
docker-compose up -d
```

## Migrating from the old repo?
```
cd ~/IOTstack/
git remote set-url origin https://github.com/cayetano/IOTstack.git
git pull origin master
docker-compose down
./menu.sh
docker-compose up -d
```
