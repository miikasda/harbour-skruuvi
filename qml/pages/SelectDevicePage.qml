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

Page {

    property int leftMargin: Theme.horizontalPageMargin
    property int rightMargin: Theme.horizontalPageMargin

    function clearBluetoothIcons() {
        for (var i = 0; i < deviceModel.count; i++) {
            deviceModel.setProperty(i, "showBluetoothIcon", false);
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            id: topmenu
            MenuItem {
                property string menuText: bs.isScanning() ? "Stop scanning" : "Start scanning"
                text: menuText
                onClicked: {
                    if (bs.isScanning()) {
                        bs.stopScan()
                        clearBluetoothIcons()
                    } else {
                        btOffLabel.visible = false
                        bs.startScan()
                    }
                    menuText = bs.isScanning() ? "Stop scanning" : "Start scanning"
                }
            }
        }

        PageHeader {
            id: pHeader
            title: "Select Ruuvi device"
            anchors.top: parent.top
        }

        Image {
            id: skruuviLogo
            source: "images/skruuvi-logo.png"
            width: parent.width - (leftMargin + rightMargin)
            fillMode: Image.PreserveAspectFit
            //height: 0.2667 * skruuviLogo.width
            anchors.top: pHeader.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            MouseArea{
                anchors.fill: parent
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                }
           }
        }

        Label {
            id: btOffLabel
            text: "Bluetooth is off, please turn it on and use the pull down menu to scan for Ruuvi devices"
            width: parent.width - (leftMargin + rightMargin)
            height: visible ? contentHeight : 0
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: skruuviLogo.bottom
            visible: false
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        SilicaListView {
            id: deviceList
            width: parent.width - (leftMargin + rightMargin)
            height: parent.height - skruuviLogo.height - pHeader.height
            anchors.top: btOffLabel.bottom
            anchors.bottom: parent.bottom
            clip: true
            header: PageHeader {
                id: listHeader
                title: "Devices"
            }
            model: ListModel {
                id: deviceModel
            }
            VerticalScrollDecorator {}

            // Populate the list with known devices
            Component.onCompleted: {
                // Fetch devices from the database
                var devices = db.getDevices();

                // Add the fetched devices to the model
                for (var i = 0; i < devices.length; i++) {
                    var device = devices[i];
                    deviceModel.append({
                        deviceName: device.deviceName,
                        deviceAddress: device.deviceAddress,
                        deviceVoltage: Number(device.deviceVoltage).toFixed(2),
                        deviceMovement: device.deviceMovement,
                        temperature: Number(device.temperature).toFixed(2),
                        humidity: (device.humidity < 163)
                                        ? Number(device.humidity).toFixed(2)
                                        : "NA",
                        pressure: (device.pressure < 1155)
                                        ? Number(device.pressure).toFixed(2)
                                        : "NA",
                        accX: Number(device.accX).toFixed(2),
                        accY: Number(device.accY).toFixed(2),
                        accZ: Number(device.accZ).toFixed(2),
                        last_obs: device.last_obs,
                        meas_seq: device.meas_seq,
                        showBluetoothIcon: false
                    });
                }
            }

            Label {
                width: parent.width
                text: "No known devices"
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.highlightColor
                //anchors.centerIn: parent
                visible: deviceModel.count === 0
                wrapMode: Text.Wrap

                anchors {
                    left: parent.left
                    leftMargin: leftMargin
                    right: parent.right
                    rightMargin: rightMargin
                    verticalCenter: parent.verticalCenter
                }
            }

            // Define how the ListItems looks like
            delegate: ListItem {
                id: listItem
                contentHeight: listItem.expanded
                    ? Theme.itemSizeExtraLarge * 2
                    : Theme.itemSizeExtraLarge
                width: parent.width
                property bool expanded: false
                onClicked: expanded = !expanded

                Item {
                    width: parent.width
                    height: Theme.itemSizeMedium

                    ListView.onAdd: AddAnimation {
                         target: listItem
                     }
                     ListView.onRemove: RemoveAnimation {
                         target: listItem
                     }

                    Image {
                        id: icon
                        source: "images/ruuvi-tag-menu-v2.png"
                        width: Theme.iconSizeExtraLarge
                        fillMode: Image.PreserveAspectFit

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: leftMargin
                    }

                    Image {
                        id: btIcon
                        source: "image://theme/icon-s-bluetooth"
                        width: Theme.iconSizeSmall
                        height: Theme.iconSizeSmall
                        visible: showBluetoothIcon
                        anchors {
                            right: parent.right
                            rightMargin: Theme.paddingMedium
                            verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        anchors.left: icon.right
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            id: topLabel
                            text: model.deviceName
                        }

                        Label {
                            text: model.deviceAddress
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryHighlightColor
                        }

                        Row {
                            spacing: Theme.paddingSmall

                            Image {
                                source: "image://theme/icon-s-sync"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: lastMeasLabel
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter

                                property int now: Math.floor(Date.now() / 1000) // keeps ticking

                                Timer {
                                    interval: 1000
                                    running: true
                                    repeat: true
                                    onTriggered: lastMeasLabel.now = Math.floor(Date.now() / 1000)
                                }

                                text: {
                                    if (model.last_obs === "NA" || model.meas_seq === "NA") {
                                        return "Never"
                                    }
                                    var diff = Math.max(0, now - model.last_obs)
                                    var result = ""
                                    if (diff < 60) {
                                        result = diff + "s ago"
                                    } else if (diff < 3600) {
                                        result = Math.floor(diff / 60) + "m ago"
                                    } else if (diff < 86400) {
                                        result = Math.floor(diff / 3600) + "h ago"
                                    } else if (diff < 31536000) {
                                        result = Math.floor(diff / 86400) + "d ago"
                                    } else {
                                        result = Math.floor(diff / 31536000) + "y ago"
                                    }
                                    return result + " (" + model.meas_seq + ")"
                                }
                            }
                        }
                    }


                    // New column for latest readings
                    Column {
                        visible: listItem.expanded
                        anchors.top: icon.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: leftMargin
                        anchors.topMargin: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            spacing: Theme.paddingSmall

                            Image {
                                source: Theme.colorScheme === Theme.DarkOnLight
                                        ? "icons/celsius-black.png"            // Black icon for light background
                                        : "icons/celsius-white.png"      // White icon for dark background
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: tempLabel
                                text: model.temperature + " °C"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Image {
                                source: "icons/humidity-" + (Theme.colorScheme === Theme.DarkOnLight ? "black" : "white") + ".png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: humLabel
                                text: model.humidity + " %rH"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Image {
                                source: "icons/pressure-" + (Theme.colorScheme === Theme.DarkOnLight ? "black" : "white") + ".png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: presLabel
                                text: model.pressure + " mBar"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: Theme.paddingSmall

                            Image {
                                source: "icons/x-" + (Theme.colorScheme === Theme.DarkOnLight ? "black" : "white") + ".png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: accXLabel
                                text: model.accX + " g"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Image {
                                source: "icons/y-" + (Theme.colorScheme === Theme.DarkOnLight ? "black" : "white") + ".png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: accYLabel
                                text: model.accY + " g"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Image {
                                source: "icons/z-" + (Theme.colorScheme === Theme.DarkOnLight ? "black" : "white") + ".png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: accZLabel
                                text: model.accZ + " g"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: Theme.paddingSmall

                            Image {
                                id: batteryIcon
                                source: "icons/battery-" + (Theme.colorScheme === Theme.DarkOnLight ? "black" : "white") + ".png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: voltageLabel
                                text: model.deviceVoltage + " V"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Image {
                                id: movementIcon
                                source: "icons/movement-" + (Theme.colorScheme === Theme.DarkOnLight ? "black" : "white") + ".png"
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                id: movementLabel
                                text: model.deviceMovement + " Moves"
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                menu: ContextMenu {
                    id: deviceMenu
                    closeOnActivation: true

                    MenuItem {
                        text: "Show data"
                        onClicked: {
                            var selectedDevice = {
                                deviceName: model.deviceName,
                                deviceAddress: model.deviceAddress,
                                deviceVoltage: model.deviceVoltage,
                                deviceMovement: model.deviceMovement
                            }
                            // On default show last 24h data
                            var currentTime = Math.floor(Date.now() / 1000);
                            pageStack.push(Qt.resolvedUrl("PlotDataPage.qml"),
                                           {
                                               startTime: currentTime - 86400,
                                               endTime: currentTime,
                                               selectedDevice: selectedDevice
                                           })
                        }
                    }
                    MenuItem {
                        text: "Fetch data"
                        onClicked: {
                            var selectedDevice = {
                                deviceName: model.deviceName,
                                deviceAddress: model.deviceAddress
                            }
                            // Handle button click to navigate to the page displaying data fetch setup
                            pageStack.push(Qt.resolvedUrl("GetDataPage.qml"), {selectedDevice: selectedDevice})
                        }
                    }
                    MenuItem {
                        id: renameMenuItem
                        text: "Rename device"
                        onClicked: {
                            // Prevent the menu from closing when Rename device is clicked
                            deviceMenu.closeOnActivation = false

                            var selectedDevice = {
                                deviceName: model.deviceName,
                                deviceAddress: model.deviceAddress
                            }
                            renameFieldItem.visible = true
                            // Set the textfield as active
                            newDeviceName.forceActiveFocus()
                        }
                    }
                    MenuItem {
                        id: renameFieldItem
                        visible: false
                        clip: true
                        height: newDeviceName.height

                        TextField {
                            width: parent.width - renameOkButton.width
                            id: newDeviceName
                            placeholderText: "Enter new name"
                            label: "New name"
                            EnterKey.enabled: text.length > 0
                            EnterKey.iconSource: "image://theme/icon-m-accept"
                            EnterKey.onClicked: {
                                var newName = newDeviceName.text;
                                // Update the device name in the database
                                db.renameDevice(deviceAddress, newName);
                                // Update the name in the listView
                                if (newName !== "") {
                                 deviceModel.setProperty(index, "deviceName", newName);
                                }
                                // Restore menu item activation and hide text field and button
                                deviceMenu.closeOnActivation = true
                                deviceMenu.close()
                                renameFieldItem.visible = false
                             }
                        }
                        IconButton {
                            id: renameOkButton
                            anchors.left: newDeviceName.right
                            icon.source: "image://theme/icon-m-accept"
                            onClicked: {
                                var newName = newDeviceName.text;
                                // Update the device name in the database
                                db.renameDevice(deviceAddress, newName);
                                // Update the name in the listView
                                if (newName !== "") {
                                    deviceModel.setProperty(index, "deviceName", newName);
                                }
                                // Restore menu item activation and hide text field and button
                                deviceMenu.closeOnActivation = true
                                deviceMenu.close()
                                renameFieldItem.visible = false
                            }
                        }
                    }
                    MenuItem {
                         text: "Remove device"
                         onClicked: listItem.remorseDelete(function() {
                             // Remove device and device data from database
                             db.removeDevice(deviceAddress)
                             // Remove device from the list
                             deviceModel.remove(index)
                         })
                    }
                }
            }
        }
    }

    Connections {
        target: db
        onVoltageUpdated: {
            // Find the device with the matching mac address in the model
            var deviceFound = false;
            for (var i = 0; i < deviceModel.count; i++) {
                var device = deviceModel.get(i);
                if (device.deviceAddress === mac) {
                    deviceFound = true;
                    // Update the voltage for the matched device
                    deviceModel.setProperty(i, "deviceVoltage", voltage.toString());
                    console.log("Voltage updated for " + mac);
                    break;
                }
            }
        }
        onMovementUpdated: {
            var deviceFound = false;
            for (var i = 0; i < deviceModel.count; i++) {
                var device = deviceModel.get(i);
                if (device.deviceAddress === mac) {
                    deviceFound = true;
                    // Update the movement for the matched device
                    deviceModel.setProperty(i, "deviceMovement", movement.toString());
                    console.log("Movement updated for " + mac);
                    break;
                }
            }
        }
        onDeviceDataUpdated: {
            console.log("Device data updated for " + mac);
            for (var i = 0; i < deviceModel.count; i++) {
                var device = deviceModel.get(i);
                if (device.deviceAddress === mac) {
                    deviceModel.setProperty(i, "temperature", temperature.toFixed(2));
                    if (humidity < 163) {
                        deviceModel.setProperty(i, "humidity", humidity.toFixed(2));
                    }
                    if (pressure < 1155) {
                        deviceModel.setProperty(i, "pressure", pressure.toFixed(2));
                    }
                    deviceModel.setProperty(i, "accX", accX.toFixed(2));
                    deviceModel.setProperty(i, "accY", accY.toFixed(2));
                    deviceModel.setProperty(i, "accZ", accZ.toFixed(2));
                    deviceModel.setProperty(i, "deviceVoltage", voltage.toFixed(2));
                    deviceModel.setProperty(i, "deviceMovement", movementCounter.toString());
                    deviceModel.setProperty(i, "meas_seq", measurementSequenceNumber.toString());
                    deviceModel.setProperty(i, "last_obs", timestamp.toString());
                    deviceModel.setProperty(i, "showBluetoothIcon", true);
                    break;
                }
            }
        }
    }

    Connections {
        target: bs
        onBluetoothOff: {
            btOffLabel.visible = true;
        }
        onDeviceFound: {
            // Check if a device with the same address already exists in the model
            var existingDeviceIndex = -1;
            for (var i = 0; i < deviceModel.count; i++) {
                if (deviceModel.get(i).deviceAddress === deviceAddress) {
                    existingDeviceIndex = i;
                    // Update the existing device to show the Bluetooth icon
                    deviceModel.setProperty(existingDeviceIndex, "showBluetoothIcon", true);
                    break;
                }
            }

            if (existingDeviceIndex === -1) {
                // Add the found device to the model
                deviceModel.append({
                    deviceName: deviceName,
                    deviceAddress: deviceAddress,
                    deviceVoltage: "NA",
                    deviceMovement: "NA",
                    temperature: "NA",
                    humidity: "NA",
                    pressure: "NA",
                    accX: "NA",
                    accY: "NA",
                    accZ: "NA",
                    last_obs: "NA",
                    meas_seq: "NA",
                    showBluetoothIcon: true
                });
            }
        }
    }
}
