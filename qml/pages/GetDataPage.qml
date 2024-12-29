/*
    Skruuvi - Reader for Ruuvi sensors
    Copyright (C) 2023-2024  Miika Malin

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
import io.thp.pyotherside 1.4

Page {

    property int leftMargin: Theme.horizontalPageMargin
    property int rightMargin: Theme.horizontalPageMargin

    property var selectedDevice: pageStack.pop().selectedDevice

    property int pickedHour: -1
    property int pickedMinute: -1
    property int logStart: 0
    property int syncStart: 0

    function constructUnixTimestamp(minute, hour, day, month, year) {
        var date = new Date(year, month - 1, day, hour, minute);
        var unixTimestamp = Math.floor(date.getTime() / 1000);
        return unixTimestamp;
    }

    function formatLastSyncLabel(timestamp) {
        if (timestamp === 0) {
            return "Last sync: Never";
        }
        var options = {
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
            hour12: false
        };
        // Convert seconds to milliseconds for JavaScript Date
        return "Last sync: " + new Date(timestamp * 1000).toLocaleString(undefined, options);
    }

    Connections {
        target: db

        onInputFinished: {
            // Handle the database input finish
            loadingScreen.running = false;

            // Change to the page displaying the data
            var currentTime = Math.floor(Date.now() / 1000);
            pageStack.push(Qt.resolvedUrl("PlotDataPage.qml"), {
                startTime: logStart,
                endTime: currentTime,
                selectedDevice: selectedDevice
            });
        }
    }

    VerticalScrollDecorator {
            flickable: flickable
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            id: pdMenu
            visible: fetchAllSwitch.checked || (pickedHour !== -1 && pickedMinute !== -1)
            MenuItem {
                text: "Fetch data"
                onClicked: {
                    python.getLogs();
                }
            }
         }
        Column {
            id: column
            width: parent.width
            // Can't set column visibility here to follow loadingScreen
            // because we manually set it on error cases.

            PageHeader {
                //id: pHeader
                title: "Set up data fetch"
                visible: !loadingScreen.running
            }

            SectionHeader {
                //id: selectedLabel
                text: "Selected device"
                visible: !loadingScreen.running
            }

            Label {
                //id: deviceNameLabel
                leftPadding: leftMargin
                color: Theme.highlightColor
                text: selectedDevice.deviceName
                visible: !loadingScreen.running
            }

            Label {
                //id: deviceAddressLabel
                leftPadding: leftMargin
                color: Theme.highlightColor
                text: selectedDevice.deviceAddress
                font.pixelSize: Theme.fontSizeSmall
                visible: !loadingScreen.running
            }

            Label {
                id: lastSyncLabel
                leftPadding: leftMargin
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                visible: !loadingScreen.running
                text: formatLastSyncLabel(db.getLastSync(selectedDevice.deviceAddress))
            }

            SectionHeader {
                //id: dataLabel
                text: "Data to fetch"
                visible: !loadingScreen.running
            }

            ComboBox {
                id: dataSelection
                label: "Data to fetch:"
                visible: !loadingScreen.running

                menu: ContextMenu {
                    MenuItem { text: "all" }
                    MenuItem { text: "temperature" }
                    MenuItem { text: "humidity" }
                    MenuItem { text: "air pressure" }
                }
            }


            TextSwitch {
                id: fetchAllSwitch
                text: "Fetch all new measurements"
                description: "Fetches all new measurements from the device, if not activated custom start time for data fetch can be defined"
                checked: true
                visible: !loadingScreen.running
            }

            SectionHeader {
                //id: configureTimeLabel
                text: "Fetch start time"
                visible: !loadingScreen.running
            }

            Label {
                //id: dateLabel
                leftPadding: leftMargin
                color: Theme.highlightColor
                text: "Select date"
                visible: !loadingScreen.running
            }

            DatePicker {
                id: dateChosen
                daysVisible: true
                visible: !loadingScreen.running
                enabled: !fetchAllSwitch.checked
            }

            Button {
                id: timeButton
                text: "Choose a time"
                enabled: !fetchAllSwitch.checked
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !loadingScreen.running
                onClicked: {
                    var timeChosen = pageStack.push("Sailfish.Silica.TimePickerDialog", {
                        hourMode: DateTime.TwentyFourHours,
                        hour: 12,
                        minute: 00
                    })
                    timeChosen.accepted.connect(function() {
                        timeButton.text = "Time chosen: " + timeChosen.timeText
                        pickedHour = timeChosen.hour
                        pickedMinute = timeChosen.minute
                    })
                }
            }
        }

        // Loading screen on data fetch
        BusyLabel {
            id: loadingScreen
            running: false
        }
    }

    // Show that the data fetch failed
    Item {
        id: failureOverlay
        width: parent.width
        height: parent.height
        visible: false

        Rectangle {
            anchors.fill: parent
            color: "red"
            opacity: 0.6
        }

        Label{
            text: "Data fetch failed"
            font.pixelSize: Theme.fontSizeHuge
            color: Theme.highlightColor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.paddingLarge
        }

        Text {
            id: failureText
            width: parent.width - leftMargin - rightMargin
            wrapMode: Text.Wrap
            clip: true
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
            anchors.centerIn: parent
        }

        Button {
            text: "OK"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: failureText.bottom
            onClicked: {
                failureOverlay.visible = false;
                column.visible = true;
                pdMenu.visible = true;
            }
        }
    }

    Python {
        id: python

        Component.onCompleted: {
                addImportPath(Qt.resolvedUrl('.'));
                importModule('ruuvi_read', function () {});
            }

        function getLogs() {
            loadingScreen.text = "Connecting to Ruuvi"
            loadingScreen.running = true
            if (fetchAllSwitch.checked) {
                logStart = db.getLastSync(selectedDevice.deviceAddress);
            } else {
                logStart = constructUnixTimestamp(pickedMinute, pickedHour, dateChosen.day, dateChosen.month, dateChosen.year)
            }
            syncStart = Math.floor(Date.now() / 1000);
            call('ruuvi_read.ruuvi_tag_reader.get_logs', [selectedDevice.deviceAddress, logStart, dataSelection.value], function() {});
        }

        onReceived: {
            // asychronous messages from Python arrive here
            // in Python, this can be accomplished via pyotherside.send()

            //console.log("Type of received data: " + typeof data)
            //console.log(JSON.stringify(data))
            // Data is array inside array, convert to array
            data = data[0]

            // Check if the first keyword is "data" indicating returned readings
            if (data[0] === "data") {
                loadingScreen.text = "Data fetched, appending to database"
                // Call the C++ function with the values
                db.inputRawData(selectedDevice.deviceAddress, selectedDevice.deviceName, data);
                // Update the sync time to database and to the label
                db.setLastSync(selectedDevice.deviceAddress, selectedDevice.deviceName, syncStart);
                lastSyncLabel.text = formatLastSyncLabel(syncStart);
            } else if (data[0] === "connected") {
                loadingScreen.text = "Connected, fetching data"
            } else if (data[0] === "data_received_amount") {
                loadingScreen.text = "Connected, received " + data[1] + " readings"
            } else if (data[0] === "extra_data") {
                // Update voltage and movement counter
                db.setVoltage(selectedDevice.deviceAddress, data[1])
                selectedDevice.deviceVoltage = data[1]
                db.setMovement(selectedDevice.deviceAddress, data[2])
                selectedDevice.deviceMovement = data[2]
            } else if (data[0] === "failed") {
                loadingScreen.running = false;
                failureOverlay.visible = true;
                column.visible = false;
                pdMenu.visible = false;
                failureText.text = data[1]
            }
       }
    }

}
