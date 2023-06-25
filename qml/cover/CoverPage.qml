/*
    Skruuvi - Reader for Ruuvi sensors
    Copyright (C) 2023  Miika Malin

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see [http://www.gnu.org/licenses/].
*/
import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    // Function to populate the ListModel with devices
    function populateDeviceModel() {
        // Populate the ListModel with devices
        var devices = db.getDevices();
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i];
            deviceModel.append(device);
        }
        // Set the current index to display the first device
        if (devices.length > 0) {
            deviceListView.currentIndex = 0;
        }
    }

    function formatDateTime(timestamp) {
        var date = new Date(timestamp * 1000);
        //var year = date.getFullYear().toString().slice(-2);
        var month = ("0" + (date.getMonth() + 1)).slice(-2);
        var day = ("0" + date.getDate()).slice(-2);
        var hours = ("0" + date.getHours()).slice(-2);
        var minutes = ("0" + date.getMinutes()).slice(-2);
        var seconds = ("0" + date.getSeconds()).slice(-2);
        return day + "." + month + " " + hours + ":" + minutes;
    }


    SilicaListView {
        id: deviceListView
        anchors.fill: parent


        // Create a ListModel to hold the devices
        model: ListModel {
            id: deviceModel
        }

        delegate: ListItem {
            id: listItem
            width: parent.width
            height: listItem.visible ? Theme.itemSizeSmall : 0
            visible: index === deviceListView.currentIndex

            // Retrieve the device properties from the model
            property var device: deviceModel.get(index)

            // Retrieve the last measurement timestamp for each sensor of the current device
            property int tempTimestamp: device && device.deviceAddress ? db.getLastMeasurement(device.deviceAddress, "temperature") : -1
            property int humTimestamp: device && device.deviceAddress ? db.getLastMeasurement(device.deviceAddress, "humidity") : -1
            property int presTimestamp: device && device.deviceAddress ? db.getLastMeasurement(device.deviceAddress, "air_pressure") : -1

            // Retrieve the latest sensor data for the current device
            property var latestTemperature: device && device.deviceAddress ? db.getSensorData(device.deviceAddress, "temperature", tempTimestamp, tempTimestamp) : -1
            property var latestHumidity: device && device.deviceAddress ? db.getSensorData(device.deviceAddress, "humidity", humTimestamp, humTimestamp) : -1
            property var latestAirPressure: device && device.deviceAddress ? db.getSensorData(device.deviceAddress, "air_pressure", presTimestamp, presTimestamp) : -1

            Column {
                id: dataColumn
                // Display the device name
                Label {
                    text: device && device.deviceName ? device.deviceName : "No known devices"
                    color: Theme.highlightColor
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: Theme.paddingSmall
                    color: "transparent"
                }

                // Display the latest temperature
                Label {
                    text: "Temperature"
                    color: Theme.highlightColor
                }
                Label {
                    text: {
                        if (latestTemperature && latestTemperature.length > 0) {
                            var timestamp = latestTemperature[0].x;
                            var formattedDateTime = formatDateTime(timestamp);
                            var temperatureValue = latestTemperature[0].y
                            return formattedDateTime + " : " + temperatureValue;
                        } else {
                            return "";
                        }
                    }
                    color: Theme.highlightColor
                }

                Rectangle {
                    width: parent.width
                    height: Theme.paddingSmall
                    color: "transparent"
                }

                // Display the latest humidity
                 Label {
                     text: "Humidity"
                     color: Theme.highlightColor
                 }
                 Label {
                     text: {
                         if (latestHumidity && latestHumidity.length > 0) {
                             var timestamp = latestHumidity[0].x;
                             var formattedDateTime = formatDateTime(timestamp);
                             var humidityValue = latestHumidity[0].y;
                             return formattedDateTime + " : " + humidityValue;
                         } else {
                             return "";
                         }
                     }
                     color: Theme.highlightColor
                 }

                 Rectangle {
                     width: parent.width
                     height: Theme.paddingSmall
                     color: "transparent"
                 }

                 // Display the latest air pressure
                 Label {
                     text: "Air Pressure"
                     color: Theme.highlightColor
                 }
                 Label {
                     text: {
                         if (latestAirPressure && latestAirPressure.length > 0) {
                             var timestamp = latestAirPressure[0].x;
                             var formattedDateTime = formatDateTime(timestamp);
                             var airPressureValue = latestAirPressure[0].y;
                             return formattedDateTime + " : " + airPressureValue;
                         } else {
                             return "";
                         }
                     }
                     color: Theme.highlightColor
                 }
            }
        }

        Component.onCompleted: {
            // Populate the ListModel on component completion
            populateDeviceModel();
        }
    }



    CoverActionList {
        id: coverAction
        CoverAction {
            id: nextDeviceAction
            iconSource: "image://theme/icon-cover-next"
            onTriggered: {
                // Move to next device in the ListView
                var nextIndex = (deviceListView.currentIndex + 1) % deviceModel.count;
                deviceListView.currentIndex = nextIndex;
            }
        }
        CoverAction {
            id: refreshAction
            iconSource: "image://theme/icon-cover-refresh"
            onTriggered: {
                // Refresh the list view
                deviceModel.clear();
                populateDeviceModel();
            }
        }
    }
}

