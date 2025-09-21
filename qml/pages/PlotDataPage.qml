/*
    Skruuvi - Reader for Ruuvi sensors
    Copyright (C) 2023-2025  Miika Malin

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
import Sailfish.Share 1.0

import "../modules/GraphData"

Page {
    id: plotDataPage

    property var startTime: pageStack.pop().startTime
    property var endTime: pageStack.pop().endTime
    property var selectedDevice: pageStack.pop().selectedDevice
    property int leftMargin: Theme.horizontalPageMargin
    property int rightMargin: Theme.horizontalPageMargin

    // Use global data so we can redraw it
    property var tempData: []
    property var humidityData: []
    property var pressureData: []

    function calculateUnixTimestamp(minute, hour, day, month, year) {
        var date = new Date(year, month - 1, day);
        date.setHours(hour, minute, 0, 0);
        var unixTimestamp = Math.floor(date.getTime() / 1000);
        return unixTimestamp;
    }

    allowedOrientations: Orientation.All

    VerticalScrollDecorator {
            flickable: flickable
    }

    ShareAction {
        id: shareaction
        title: "CSV has been saved to Documents. Share it?"
        mimeType: "text/csv"
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: "Export as CSV"
                onClicked: {
                    // Save the CSV
                    var csv_path = db.exportCSV(selectedDevice.deviceAddress, selectedDevice.deviceName, startTime, endTime);
                    // Launch the share action
                    if (csv_path.length > 0) {
                        shareaction.resources = [csv_path];
                        shareaction.trigger();
                    }
                }
            }
            MenuItem {
                text: "Plot data"
                onClicked: {
                    // Check if custom plot time is defined
                    if (!startDateButton.clicked) {
                        // No start time; fetch all from the start
                        startTime = 1;
                    }
                    if (!endDateButton.clicked) {
                        // No end time; fetch up to current time
                        endTime = Math.floor(Date.now() / 1000);
                    }
                    // Fetch and plot the data
                    tempData = db.getSensorData(selectedDevice.deviceAddress, "temperature", startTime, endTime);
                    tempGraph.setPoints(tempData);
                    humidityData = db.getSensorData(selectedDevice.deviceAddress, "humidity", startTime, endTime);
                    humidityGraph.setPoints(humidityData);
                    pressureData = db.getSensorData(selectedDevice.deviceAddress, "air_pressure", startTime, endTime);
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
                onClicked: {
                                pageStack.push(
                                    Qt.resolvedUrl("GraphPage.qml"),
                                    {
                                       par_data: tempData,
                                       par_title: graphTitle,
                                       par_units: axisY.units
                                    }
                                );
                }
            }

            GraphData {
                id: humidityGraph
                graphTitle: qsTr("Humidity")
                width: parent.width
                scale: true
                axisY.units: "%rH"
                onClicked: {
                                pageStack.push(
                                    Qt.resolvedUrl("GraphPage.qml"),
                                    {
                                       par_data: humidityData,
                                       par_title: graphTitle,
                                       par_units: axisY.units
                                    }
                                );
                }
            }

            GraphData {
                id: pressureGraph
                graphTitle: qsTr("Air pressure")
                width: parent.width
                scale: true
                axisY.units: "mBar"
                onClicked: {
                                pageStack.push(
                                    Qt.resolvedUrl("GraphPage.qml"),
                                    {
                                       par_data: pressureData,
                                       par_title: graphTitle,
                                       par_units: axisY.units
                                    }
                                );
                }
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
                    text: "Start time"
                    property bool clicked: false

                    onClicked: {
                        var startDatePicker = pageStack.push("Sailfish.Silica.DatePickerDialog", {})
                        startDatePicker.accepted.connect(function() {
                            // Ask for time
                            var startTimePicker = pageStack.push("Sailfish.Silica.TimePickerDialog", {
                                hourMode: DateTime.TwentyFourHours,
                                hour: 0,
                                minute: 0
                            })
                            // Set plotDataPage as return destination on accept,
                            // otherwise we will return to datepicker
                            startTimePicker.acceptDestinationAction = PageStackAction.Pop
                            startTimePicker.acceptDestination = plotDataPage
                            startTimePicker.accepted.connect(function() {
                                startDateButton.text = "Start time: " + startDatePicker.dateText + " " + startTimePicker.timeText
                                startTime = calculateUnixTimestamp(startTimePicker.minute, startTimePicker.hour, startDatePicker.day, startDatePicker.month, startDatePicker.year)
                                startDateButton.clicked = true
                            })
                        })
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
                    text: "End time"
                    property bool clicked: false

                    onClicked: {
                        var endDatePicker = pageStack.push("Sailfish.Silica.DatePickerDialog", {})
                        endDatePicker.accepted.connect(function() {
                            // Ask for time
                            var endTimePicker = pageStack.push("Sailfish.Silica.TimePickerDialog", {
                                hourMode: DateTime.TwentyFourHours,
                                hour: 23,
                                minute: 59
                            })
                            endTimePicker.acceptDestinationAction = PageStackAction.Pop
                            endTimePicker.acceptDestination = plotDataPage
                            endTimePicker.accepted.connect(function() {
                                endDateButton.text = "End time: " + endDatePicker.dateText + " " + endTimePicker.timeText
                                endTime = calculateUnixTimestamp(endTimePicker.minute, endTimePicker.hour, endDatePicker.day, endDatePicker.month, endDatePicker.year)
                                endDateButton.clicked = true
                            })
                        })
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

