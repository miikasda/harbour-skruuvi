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
    property var maxPoints: 0
    property bool aggregated: false
    property real bucketDuration: 0
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

    function formatBinSize(seconds) {
        if (seconds < 60)
            return Math.round(seconds) + " s";
        else if (seconds < 3600)
            return Math.round(seconds / 60) + " min";
        else if (seconds < 86400)
            return Math.round(seconds / 3600) + " h";
        else
            return Math.round(seconds / 86400) + " d";
    }

    function downsampleMinMax(points, maxPoints) {
        if (!points || points.length === 0) {
            // If no data, return empty
            plotDataPage.aggregated = false
            plotDataPage.bucketDuration = 0
            return [];
        }

        if (points.length <= 2 * maxPoints) {
            // No need to downsample
            // 2 x maxpoints = every bucket would have min and max value
            plotDataPage.aggregated = false
            plotDataPage.bucketDuration = 0
            return points;
        }

        // Determine total time range
        var minX = points[0].x;
        var maxX = points[points.length - 1].x;
        var range = maxX - minX;
        if (range <= 0) {
            // No meaningful time span, return original
            plotDataPage.aggregated = false
            plotDataPage.bucketDuration = 0
            return points;
        }

        // Each bucket spans this many seconds
        var bucketDuration = range / maxPoints;
        plotDataPage.bucketDuration = bucketDuration;

        var sampled = [];
        var bucketStart = minX;
        var bucketEnd = bucketStart + bucketDuration;
        var bucket = [];

        for (var i = 0; i < points.length; i++) {
            var p = points[i];

            // If point belongs to current bucket
            if (p.x <= bucketEnd) {
                bucket.push(p);
            } else {
                // Process the finished bucket
                if (bucket.length > 0) {
                    var minPoint = bucket[0];
                    var maxPoint = bucket[0];

                    // Find min and max for this bucket
                    for (var j = 1; j < bucket.length; j++) {
                        if (bucket[j].y < minPoint.y) minPoint = bucket[j];
                        if (bucket[j].y > maxPoint.y) maxPoint = bucket[j];
                    }

                    // Add in chronological order the min and max
                    if (minPoint === maxPoint) {
                        sampled.push(minPoint);
                    } else if (minPoint.x < maxPoint.x) {
                        sampled.push(minPoint);
                        sampled.push(maxPoint);
                    } else {
                        sampled.push(maxPoint);
                        sampled.push(minPoint);
                    }
                }

                // Start a new bucket
                bucket = [p];
                bucketStart = bucketEnd;
                bucketEnd = bucketStart + bucketDuration;
            }
        }

        // Process last bucket
        if (bucket.length > 0) {
            var minPoint = bucket[0];
            var maxPoint = bucket[0];
            for (var j = 1; j < bucket.length; j++) {
                if (bucket[j].y < minPoint.y) minPoint = bucket[j];
                if (bucket[j].y > maxPoint.y) maxPoint = bucket[j];
            }
            if (minPoint === maxPoint) {
                sampled.push(minPoint);
            } else if (minPoint.x < maxPoint.x) {
                sampled.push(minPoint);
                sampled.push(maxPoint);
            } else {
                sampled.push(maxPoint);
                sampled.push(minPoint);
            }
        }

        // DEBUG: log downsampling result
        var reduced = points.length - sampled.length;
        console.log(
            "Downsampled " + points.length + " → " + sampled.length +
            " points (reduced by " + reduced + ")" +
            " over " + formatBinSize(range) +
            " (bucketDuration ≈ " + formatBinSize(bucketDuration) + ")"
        );

        plotDataPage.aggregated = true
        return sampled;
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
                    maxPoints = tempGraph.width;
                    // Fetch and plot the data
                    tempData = db.getSensorData(selectedDevice.deviceAddress, "temperature", startTime, endTime);
                    tempGraph.setPoints(downsampleMinMax(tempData, maxPoints));
                    humidityData = db.getSensorData(selectedDevice.deviceAddress, "humidity", startTime, endTime);
                    humidityGraph.setPoints(downsampleMinMax(humidityData, maxPoints));
                    pressureData = db.getSensorData(selectedDevice.deviceAddress, "air_pressure", startTime, endTime);
                    pressureGraph.setPoints(downsampleMinMax(pressureData, maxPoints));
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

            Label {
            visible: aggregated
            leftPadding: leftMargin
            rightPadding: rightMargin
            wrapMode: Text.Wrap
            text: qsTr("Data is aggregated (bin ≈ %1).\nTap a graph to view full data")
                    .arg(formatBinSize(bucketDuration))
            color: Theme.secondaryHighlightColor
            font.pixelSize: Theme.fontSizeSmall
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
                maxPoints = tempGraph.width;
                tempData = db.getSensorData(selectedDevice.deviceAddress, "temperature", startTime, endTime);
                tempGraph.setPoints(downsampleMinMax(tempData, maxPoints));
                humidityData = db.getSensorData(selectedDevice.deviceAddress, "humidity", startTime, endTime);
                humidityGraph.setPoints(downsampleMinMax(humidityData, maxPoints));
                pressureData = db.getSensorData(selectedDevice.deviceAddress, "air_pressure", startTime, endTime);
                pressureGraph.setPoints(downsampleMinMax(pressureData, maxPoints));
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
                maxPoints = tempGraph.width;
                tempGraph.setPoints(downsampleMinMax(tempData, maxPoints));
                humidityGraph.setPoints(downsampleMinMax(humidityData, maxPoints));
                pressureGraph.setPoints(downsampleMinMax(pressureData, maxPoints));
            }
        }
    }
}

