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
    property bool airInfoExpanded: false
    property bool plotting: false
    // Use global data so we can redraw it
    property var tempData: []
    property var humidityData: []
    property var pressureData: []
    property var pm25Data: []
    property var co2Data: []
    property var vocData: []
    property var noxData: []
    property var iaqsData: []
    property var tempPlotData: []
    property var humidityPlotData: []
    property var pressurePlotData: []
    property var pm25PlotData: []
    property var co2PlotData: []
    property var vocPlotData: []
    property var noxPlotData: []
    property var iaqsPlotData: []

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
        visible: !plotting

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
                    maxPoints = tempGraph.width
                    plotting = true
                    db.requestPlotData(selectedDevice.deviceAddress, selectedDevice.isAir, startTime, endTime, maxPoints)
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

            // --- Ruuvi Air info block ---
            SectionHeader {
                visible: selectedDevice.isAir
                text: qsTr("Indoor air measurements")
            }

            Button {
                visible: selectedDevice.isAir
                width: parent.width - leftMargin - rightMargin
                anchors.horizontalCenter: parent.horizontalCenter
                text: airInfoExpanded
                    ? qsTr("Hide measurement info")
                    : qsTr("Show measurement info")
                onClicked: airInfoExpanded = !airInfoExpanded
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

            // Temperature
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("Temperature")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Temperature shows how warm or cool your environment is. It affects comfort and energy use.")
            }
            GraphData {
                id: tempGraph
                graphTitle: qsTr("Temperature")
                width: parent.width
                scale: true
                axisY.units: "°C"
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: tempData, par_title: graphTitle, par_units: axisY.units })
                }
            }

            // Humidity
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("Humidity")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Humidity affects comfort, breathing and building health. Very dry or humid air can both feel uncomfortable.")
            }
            GraphData {
                id: humidityGraph
                graphTitle: qsTr("Humidity")
                width: parent.width
                scale: true
                axisY.units: "%rH"
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: humidityData, par_title: graphTitle, par_units: axisY.units })
                }
            }

            // Air pressure
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("Air pressure")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Air pressure gives hints about weather changes and can influence how you feel.")
            }
            GraphData {
                id: pressureGraph
                graphTitle: qsTr("Air pressure")
                width: parent.width
                scale: true
                axisY.units: "mBar"
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: pressureData, par_title: graphTitle, par_units: axisY.units })
                }
            }

            /* ------------------------
                Ruuvi Air graphs
            ------------------------ */

            // PM2.5
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("Particles (PM2.5)")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("PM2.5 shows how many fine particles are in the air. High values may irritate lungs even if the air looks clean.")
            }
            GraphData {
                visible: selectedDevice.isAir
                id: pm25Graph
                graphTitle: qsTr("PM2.5")
                width: parent.width
                scale: true
                axisY.units: "µg/m³"
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: pm25Data, par_title: graphTitle, par_units: axisY.units })
                }
            }

            // CO2
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("Carbon dioxide (CO\u2082)")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("CO\u2082 levels reflect ventilation quality. High values can make you tired and reduce focus.")
            }
            GraphData {
                visible: selectedDevice.isAir
                id: co2Graph
                graphTitle: qsTr("CO₂")
                width: parent.width
                scale: true
                axisY.units: "ppm"
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: co2Data, par_title: graphTitle, par_units: axisY.units })
                }
            }

            // VOC
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("VOC (Index)")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("The VOC index indicates how many volatile compounds are present. Values above 100 signal increased VOCs.")
            }
            GraphData {
                visible: selectedDevice.isAir
                id: vocGraph
                graphTitle: qsTr("VOC Index")
                width: parent.width
                scale: true
                axisY.units: ""
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: vocData, par_title: graphTitle, par_units: axisY.units })
                }
            }

            // NOX
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("NOx (Index)")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("The NOx index tracks nitrogen oxides from traffic and combustion. Higher values mean poorer air quality.")
            }
            GraphData {
                visible: selectedDevice.isAir
                id: noxGraph
                graphTitle: qsTr("NOx Index")
                width: parent.width
                scale: true
                axisY.units: ""
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: noxData, par_title: graphTitle, par_units: axisY.units })
                }
            }

            //IAQS
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                leftPadding: leftMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: qsTr("Indoor Air Quality Score (IAQS)")
            }
            Label {
                visible: selectedDevice.isAir && airInfoExpanded
                width: parent.width
                wrapMode: Text.Wrap
                leftPadding: leftMargin
                rightPadding: rightMargin
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("The IAQS considers CO₂ and PM₂.₅, providing values between 0-100. Higher value means better air quality.")
            }
            GraphData {
                visible: selectedDevice.isAir
                id: iaqsGraph
                graphTitle: qsTr("Indoor Air Quality Score (IAQS)")
                width: parent.width
                scale: true
                axisY.units: ""
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GraphPage.qml"),
                                { par_data: iaqsData, par_title: graphTitle, par_units: axisY.units })
                }
            }

            Component.onCompleted: {
                maxPoints = tempGraph.width
                plotting = true
                db.requestPlotData(selectedDevice.deviceAddress, selectedDevice.isAir, startTime, endTime, maxPoints)
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
                tempGraph.setPoints(tempPlotData)
                humidityGraph.setPoints(humidityPlotData)
                pressureGraph.setPoints(pressurePlotData)
                if (selectedDevice.isAir) {
                    pm25Graph.setPoints(pm25PlotData)
                    co2Graph.setPoints(co2PlotData)
                    vocGraph.setPoints(vocPlotData)
                    noxGraph.setPoints(noxPlotData)
                    iaqsGraph.setPoints(iaqsPlotData)
                }
            }
        }
    }
    BusyLabel {
        id: plotLoading
        running: plotting
        text: "Plotting data..."
        anchors.centerIn: parent
        visible: plotting
    }

    Connections {
        target: db
        onPlotDataReady: {
            // Raw for "tap graph → full data"
            tempData = result["temperature_raw"]
            humidityData = result["humidity_raw"]
            pressureData = result["air_pressure_raw"]
            // Downsampled for display
            tempPlotData = result["temperature_ds"]
            humidityPlotData = result["humidity_ds"]
            pressurePlotData = result["air_pressure_ds"]
            aggregated = result["aggregated"]
            bucketDuration = result["bucketDuration"]
            tempGraph.setPoints(tempPlotData)
            humidityGraph.setPoints(humidityPlotData)
            pressureGraph.setPoints(pressurePlotData)
            if (selectedDevice.isAir) {
                pm25Data = result["pm25_raw"]
                co2Data  = result["co2_raw"]
                vocData  = result["voc_raw"]
                noxData  = result["nox_raw"]
                iaqsData = result["iaqs_raw"]
                pm25PlotData = result["pm25_ds"]
                co2PlotData  = result["co2_ds"]
                vocPlotData  = result["voc_ds"]
                noxPlotData  = result["nox_ds"]
                iaqsPlotData = result["iaqs_ds"]
                pm25Graph.setPoints(pm25PlotData)
                co2Graph.setPoints(co2PlotData)
                vocGraph.setPoints(vocPlotData)
                noxGraph.setPoints(noxPlotData)
                iaqsGraph.setPoints(iaqsPlotData)
            }
            plotting = false
        }
    }
}

