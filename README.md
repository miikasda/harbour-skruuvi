![Skruuvi](qml/pages/images/skruuvi-logo.png?raw=true)

# Skruuvi

Skruuvi is a powerful application designed for Sailfish OS that allows you to effortlessly read and plot history data from RuuviTags. With Skruuvi, you can easily access and analyze sensor information from your RuuviTag devices right from your Sailfish OS smartphone.

<p align="center">
    <img alt="Select device" src="./screenshots/select_device.png?" width="30%"> &nbsp; &nbsp; &nbsp; &nbsp;
    <img alt="Fetch data" src="./screenshots/fetch_data.png?" width="30%"> &nbsp; &nbsp; &nbsp; &nbsp;
    <img alt="Plot data" src="./screenshots/plot_data.png?" width="30%">
</p>


## Notes

Skruuvi is an unofficial application and is not developed or maintained by Ruuvi. It is created by independent developers who are passionate about enabling RuuviTag users to maximize their sensor capabilities on Sailfish OS.

For any official RuuviTag support, firmware updates, or inquiries, please refer to the official Ruuvi website or consult the Ruuvi community forums.

## Dependencies

Skruuvi uses internally [bleak](https://github.com/hbldh/bleak), [async-timeout](https://github.com/aio-libs/async-timeout) and [dbus-fast](https://github.com/Bluetooth-Devices/dbus-fast) to get history data from RuuviTags with Bluetooth. Data graph plots (GraphData.qml and Axis.qml) are slightly modified versions from [systemmonitor](https://github.com/custodian/harbour-systemmonitor).


## License

Skruuvi is licensed under GPL-3.0