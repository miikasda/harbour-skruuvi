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

import "."

Page {

    property var startTime: pageStack.pop().startTime
    property var endTime: pageStack.pop().endTime
    property var selectedDevice: pageStack.pop().selectedDevice
    property int leftMargin: Theme.horizontalPageMargin
    property int rightMargin: Theme.horizontalPageMargin
    property int startTimestamp: -1
    property int endTimestamp: -1

    // Use global data so we can redraw it
    property var tempData: []
    property var humidityData: []
    property var pressureData: []

    function calculateUnixTimestamp(day, month, year, start) {
        var date = new Date(year, month - 1, day);
        if (start) {
            // Set the time to the start of the day (00:00:00)
            date.setHours(0, 0, 0, 0);
        } else {
            // Set the time to the end of the day (23:59:59)
            date.setHours(23, 59, 59, 999);
        }
        var unixTimestamp = Math.floor(date.getTime() / 1000);
        return unixTimestamp;
    }

    allowedOrientations: Orientation.All

    VerticalScrollDecorator {
            flickable: flickable
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: "Plot data"
                onClicked: {
                    // Check if custom plot time is defined
                    if (!startDateButton.clicked) {
                        // No start time; fetch all from the start
                        startTimestamp = 1;
                    }
                    if (!endDateButton.clicked) {
                        // No end time; fetch up to current time
                        endTimestamp = Math.floor(Date.now() / 1000);
                    }
                    // Fetch and plot the data
                    tempData = db.getSensorData(selectedDevice.deviceAddress, "temperature", startTimestamp, endTimestamp);
                    tempGraph.setPoints(tempData);
                    humidityData = db.getSensorData(selectedDevice.deviceAddress, "humidity", startTimestamp, endTimestamp);
                    humidityGraph.setPoints(humidityData);
                    pressureData = db.getSensorData(selectedDevice.deviceAddress, "air_pressure", startTimestamp, endTimestamp);
                    pressureGraph.setPoints(pressureData);
                }
            }
         }

        Column {
            // Put everything inside column, so the flickable
            // works in landscape mode
            id: column
            width: parent.width

            PageHeader {
                id: pHeader
                title: "Plot data"
            }

            SectionHeader {
                id: selectedLabel
                text: "Selected device"
            }

            Label {
                id: deviceNameLabel
                leftPadding: leftMargin
                color: Theme.highlightColor
                text: selectedDevice.deviceName
            }

            Label {
                id: deviceAddressLabel
                leftPadding: leftMargin
                color: Theme.highlightColor
                text: selectedDevice.deviceAddress
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionHeader {
                id: dataPlotHeader
                text: "Data plots"
            }

            GraphData {
                id: tempGraph
                graphTitle: qsTr("Temperature")
                width: parent.width
                scale: true
                axisY.units: "°C"
            }

            GraphData {
                id: humidityGraph
                graphTitle: qsTr("Humidity")
                width: parent.width
                scale: true
                axisY.units: "%rH"
            }

            GraphData {
                id: pressureGraph
                graphTitle: qsTr("Air pressure")
                width: parent.width
                scale: true
                axisY.units: "mBar"
            }

            Component.onCompleted: {
                tempData = db.getSensorData(selectedDevice.deviceAddress, "temperature", startTime, endTime);
                tempGraph.setPoints(tempData);
                humidityData = db.getSensorData(selectedDevice.deviceAddress, "humidity", startTime, endTime);
                humidityGraph.setPoints(humidityData);
                pressureData = db.getSensorData(selectedDevice.deviceAddress, "air_pressure", startTime, endTime);
                pressureGraph.setPoints(pressureData);
            }

            SectionHeader {
                id: configureDataPlotHeader
                text: "Configure data plot"
            }

            Item {
                // We need buttom item to get whitespace for buttons
                height: startDateButton.height + whiteSpace.height + endDateButton.height
                width: parent.width
                Button {
                    id: startDateButton
                    anchors.top: parent.top
                    width: parent.width - leftMargin - rightMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Start date"
                    property bool clicked: false

                    onClicked: {
                        var dialog = pageStack.push(startPicker, {})
                        dialog.accepted.connect(function() {
                            startDateButton.text = "Start date: " + dialog.dateText
                            startTimestamp = calculateUnixTimestamp(dialog.day, dialog.month, dialog.year, true)
                            startDateButton.clicked = true
                        })
                    }

                    Component {
                        id: startPicker
                        DatePickerDialog {}
                    }
                }

                // Whitespace inbetween buttons
                Rectangle {
                    id: whiteSpace
                    anchors.top: startDateButton.bottom
                    height: Theme.paddingMedium
                    color: "transparent"
                }

                Button {
                    id: endDateButton
                    anchors.top: whiteSpace.bottom
                    width: parent.width - leftMargin - rightMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "End date"
                    property bool clicked: false

                    onClicked: {
                        var dialog = pageStack.push(endPicker, {})
                        dialog.accepted.connect(function() {
                            endDateButton.text = "End date: " + dialog.dateText
                            endTimestamp = calculateUnixTimestamp(dialog.day, dialog.month, dialog.year, false)
                            endDateButton.clicked = true
                        })
                    }

                    Component {
                        id: endPicker
                        DatePickerDialog {}
                    }
                }
            }
        }

        onVisibleChanged: {
            if (status === PageStatus.Active & visible) {
                // Lines are not shown when app is background
                // redraw the graphs when the page is visible again
                tempGraph.setPoints(tempData);
                humidityGraph.setPoints(humidityData);
                pressureGraph.setPoints(pressureData);
            }
        }
    }
}

