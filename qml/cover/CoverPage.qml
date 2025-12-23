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

CoverBackground {
    // Which group of 3 metrics we show on the cover
    property int metricsPage: 0

    function cycleMetrics() {
        // 0: temp/hum/pres
        // 1: pm25/co2/voc
        // 2: nox/iaqs/(blank)
        metricsPage = (metricsPage + 1) % 3
    }

    // Helper to hide "NA" cleanly
    function hasValue(v) {
        return v !== undefined && v !== "NA" && v !== ""
    }

    // Function to populate the ListModel with devices
    function populateDeviceModel() {
        var devices = db.getDevices();
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i];
            deviceModel.append({
                deviceName: d.deviceName,
                deviceAddress: d.deviceAddress,

                temperature: (d.temperature !== undefined && d.temperature !== "NA")
                                ? Number(d.temperature).toFixed(2)
                                : "NA",
                humidity: (d.humidity !== undefined && d.humidity !== "NA" && d.humidity < 163)
                                ? Number(d.humidity).toFixed(2)
                                : "NA",
                pressure: (d.pressure !== undefined && d.pressure !== "NA" && d.pressure < 1155)
                                ? Number(d.pressure).toFixed(2)
                                : "NA",

                pm25: (d.pm25 !== undefined && d.pm25 !== "NA")
                                ? Number(d.pm25).toFixed(2)
                                : "NA",
                co2:  (d.co2  !== undefined && d.co2  !== "NA")
                                ? d.co2.toString()
                                : "NA",
                voc:  (d.voc  !== undefined && d.voc  !== "NA")
                                ? d.voc.toString()
                                : "NA",
                nox:  (d.nox  !== undefined && d.nox  !== "NA")
                                ? d.nox.toString()
                                : "NA",
                iaqs: (d.iaqs !== undefined && d.iaqs !== "NA")
                                ? d.iaqs.toString()
                                : "NA",

                last_obs: (d.last_obs !== undefined) ? d.last_obs : "NA"
            });
        }
        if (devices.length > 0) deviceListView.currentIndex = 0;
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

        Label {
            anchors.centerIn: parent
            text: "No known devices"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
            visible: deviceModel.count === 0
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
        }

        delegate: ListItem {
            id: listItem
            width: parent.width
            contentHeight: ListView.isCurrentItem ? deviceListView.height : 0
            height: contentHeight
            visible: ListView.isCurrentItem

            // When switching devices, reset inner scroll
            //onVisibleChanged: if (visible) flick.contentY = 0

            property bool isAir: (model.co2 !== undefined && model.co2 !== "NA")

            // Always 2 decimals for numeric values
            function fmt2(v) {
                if (v === undefined || v === "NA" || v === "") return v
                var n = Number(v)
                return isNaN(n) ? v : n.toFixed(2)
            }

            function updatedText() {
                if (model.last_obs === undefined || model.last_obs === "NA") return ""
                var ts = parseInt(model.last_obs, 10)
                return isNaN(ts) ? "" : ("Updated " + formatDateTime(ts))
            }

            Column {
                id: dataColumn
                width: parent.width - Theme.paddingMedium
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingMedium   // small left margin

                Label {
                    text: model.deviceName ? model.deviceName : "No known devices"
                    color: Theme.highlightColor
                    font.bold: true
                }

                Label {
                    text: listItem.updatedText()
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    visible: text.length > 0
                }

                Rectangle { width: parent.width; height: Theme.paddingSmall; color: "transparent" }

                // --- 3-slot view, controlled by metricsPage ---

                // Slot 1
                Label {
                    color: Theme.highlightColor
                    text: metricsPage === 0 ? "Temperature"
                        : metricsPage === 1 ? "PM2.5"
                        : "NOx"
                    visible: metricsPage === 0 || listItem.isAir
                }
                Label {
                    color: Theme.secondaryHighlightColor
                    text: metricsPage === 0
                            ? (hasValue(model.temperature) ? (listItem.fmt2(model.temperature) + " °C") : "")
                        : metricsPage === 1
                            ? (hasValue(model.pm25) ? (listItem.fmt2(model.pm25) + " µg/m³") : "")
                        : (hasValue(model.nox) ? (model.nox + " idx") : "")
                    visible: metricsPage === 0 || listItem.isAir
                }

                Rectangle { width: parent.width; height: Theme.paddingSmall; color: "transparent" }

                // Slot 2
                Label {
                color: Theme.highlightColor
                text: metricsPage === 0 ? "Humidity"
                    : metricsPage === 1 ? "CO₂"
                    : "VOC"
                visible: metricsPage === 0 || listItem.isAir
                }
                Label {
                    color: Theme.secondaryHighlightColor
                    text: metricsPage === 0
                            ? (hasValue(model.humidity) ? (listItem.fmt2(model.humidity) + " %rH") : "")
                        : metricsPage === 1
                            ? (hasValue(model.co2) ? (model.co2 + " ppm") : "")
                        : (hasValue(model.voc) ? (model.voc + " idx") : "")
                    visible: metricsPage === 0 || listItem.isAir
                }

                Rectangle { width: parent.width; height: Theme.paddingSmall; color: "transparent" }

                // Slot 3
                Label {
                    color: Theme.highlightColor
                    text: metricsPage === 0 ? "Air Pressure"
                        : metricsPage === 1 ? "IAQS"
                        : ""
                    visible: metricsPage !== 2 && (metricsPage === 0 || listItem.isAir)
                }
                Label {
                    color: Theme.secondaryHighlightColor
                    text: metricsPage === 0
                            ? (hasValue(model.pressure) ? (listItem.fmt2(model.pressure) + " mBar") : "")
                        : metricsPage === 1
                            ? (hasValue(model.iaqs) ? (model.iaqs) : "")
                        : ""
                    visible: metricsPage !== 2 && (metricsPage === 0 || listItem.isAir)
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
            iconSource: "image://theme/icon-cover-subview"
            onTriggered: {
                // If not an Air device, keep the cover on page 0
                if (!deviceListView.currentItem || !deviceListView.currentItem.isAir) {
                    metricsPage = 0
                    return
                }
                // Show next 3 values
                cycleMetrics()
            }
        }
        CoverAction {
            id: nextDeviceAction
            iconSource: "image://theme/icon-cover-next"
            onTriggered: {
                // Move to next device in the ListView
                var nextIndex = (deviceListView.currentIndex + 1) % deviceModel.count;
                deviceListView.currentIndex = nextIndex;
                metricsPage = 0;
            }
        }
    }

    Connections {
        target: db

        onDeviceDataUpdated: {
            for (var i = 0; i < deviceModel.count; i++) {
                var d = deviceModel.get(i);
                if (d.deviceAddress === mac) {
                    deviceModel.setProperty(i, "temperature", temperature.toFixed(2));
                    deviceModel.setProperty(i, "humidity", (humidity < 163) ? humidity.toFixed(2) : "NA");
                    deviceModel.setProperty(i, "pressure", (pressure < 1155) ? pressure.toFixed(2) : "NA");
                    deviceModel.setProperty(i, "last_obs", timestamp.toString());
                    break;
                }
            }
        }

        onAirDeviceDataUpdated: {
            for (var i = 0; i < deviceModel.count; i++) {
                var d = deviceModel.get(i);
                if (d.deviceAddress === mac) {
                    deviceModel.setProperty(i, "temperature", temperature.toFixed(2));
                    deviceModel.setProperty(i, "humidity", humidity.toFixed(2));
                    deviceModel.setProperty(i, "pressure", pressure.toFixed(2));

                    deviceModel.setProperty(i, "pm25", pm25.toFixed(2));
                    deviceModel.setProperty(i, "co2",  co2.toString());
                    deviceModel.setProperty(i, "voc",  voc.toString());
                    deviceModel.setProperty(i, "nox",  nox.toString());
                    deviceModel.setProperty(i, "iaqs", iaqs.toString());

                    deviceModel.setProperty(i, "last_obs", timestamp.toString());
                    break;
                }
            }
        }
    }

    Connections {
        target: bs

        onDeviceFound: {
            // Don’t add duplicates
            for (var i = 0; i < deviceModel.count; i++) {
                if (deviceModel.get(i).deviceAddress === deviceAddress) {
                    return;
                }
            }

            // Add new device with placeholder values
            deviceModel.append({
                deviceName: deviceName,
                deviceAddress: deviceAddress,
                temperature: "NA",
                humidity: "NA",
                pressure: "NA",
                pm25: "NA",
                co2:  "NA",
                voc:  "NA",
                nox:  "NA",
                iaqs: "NA",
                last_obs: "NA"
            })

            // If this is the first device, show it
            if (deviceModel.count === 1) {
                deviceListView.currentIndex = 0
                metricsPage = 0
            }
        }
    }
}
