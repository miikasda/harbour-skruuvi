![Skruuvi](qml/pages/images/skruuvi-logo.png?raw=true)

# Skruuvi

Skruuvi is a powerful application designed for Sailfish OS that allows you to effortlessly read and plot history data from [RuuviTags](https://ruuvi.com/). With Skruuvi, you can easily access and analyze sensor information from your RuuviTag devices right from your Sailfish OS smartphone.

<p align="center">
    <img alt="Select device" src="./screenshots/select_device.png?" width="30%"> &nbsp; &nbsp; &nbsp; &nbsp;
    <img alt="Fetch data" src="./screenshots/fetch_data.png?" width="30%"> &nbsp; &nbsp; &nbsp; &nbsp;
    <img alt="Plot data" src="./screenshots/plot_data.png?" width="30%">
</p>


## Notes

Skruuvi is an unofficial application and is not developed or maintained by Ruuvi. It is created by independent developers who are passionate about enabling RuuviTag users to maximize their sensor capabilities on Sailfish OS.

For any official RuuviTag support, firmware updates, or inquiries, please refer to the official Ruuvi website or consult the Ruuvi community forums.

## Supported architectures, SFOS versions and RuuviTags

Skruuvi supports the aarch64 and armv7hl architectures. OS versions are supported starting from 4.5. To add support for other architectures, I require physical devices to ensure that all Bluetooth connections work properly.

If you are aware that Skruuvi works on other architectures or older SFOS versions, please let me know.

Skruuvi supports all RuuviTag sensors with firmware starting from 3.30.x. If you cant see your Ruuvi in the device list, try [updating](https://ruuvi.com/software-update/) the firmware.

## Distribution

Supported architectures and SFOS versions of Skruuvi are distributed through the official Jolla application store (harbour).

The Chum community repository provides builds for unsupported architectures and SFOS versions, you can use these with your own risk.


## Dependencies

Skruuvi uses internally [bleak](https://github.com/hbldh/bleak), [async-timeout](https://github.com/aio-libs/async-timeout) and [dbus-fast](https://github.com/Bluetooth-Devices/dbus-fast) to get history data from RuuviTags with Bluetooth. Data graph plots (GraphData.qml and Axis.qml) are slightly modified versions from [systemmonitor](https://github.com/custodian/harbour-systemmonitor), and about page has been done by using [Opal](https://github.com/Pretty-SFOS/opal-about).

## License

Skruuvi is licensed under GPL-3.0. License is provided [here](LICENSE).

## To do list

To do list for Skruuvi is in the [wiki](https://github.com/miikasda/harbour-skruuvi/wiki/To-do-list). If you have a feature in mind which is not in the to do list, please open a [issue](https://github.com/miikasda/harbour-skruuvi/issues) with enhancement label.

## Local database location

The sensor readings are stored in local SQLite database. The database is located at `~/.local/share/org.malmi/harbour-skruuvi/ruuviData.sqlite`

For example if your username is defaultuser, the database can be pulled with rsync:

```
rsync defaultuser@192.168.1.98:/home/defaultuser/.local/share/org.malmi/harbour-skruuvi/ruuviData.sqlite ./
```
