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
            MenuItem {
                text: "Scan"
                onClicked: {
                    clearBluetoothIcons();
                    busyIndicator.visible = true;
                    busyIndicator.running = true;
                    ld.startDiscovery();
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

        BusyIndicator {
             id: busyIndicator
             size: BusyIndicatorSize.Medium
             anchors.centerIn: deviceList
             visible: false  // Initially hidden
        }

        SilicaListView {
            id: deviceList
            width: parent.width - (leftMargin + rightMargin)
            height: parent.height - skruuviLogo.height - pHeader.height
            anchors.top: skruuviLogo.bottom
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
                        showBluetoothIcon: false
                    });
                }
            }

            Label {
                width: parent.width
                text: "No known devices, use the pull down menu to scan for new Ruuvi devices"
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
                contentHeight: Theme.itemSizeMedium
                width: parent.width

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
                        source: "images/ruuvitag-enclosure-bottom-768x768.jpg"
                        width: Theme.iconSizeLarge
                        height: Theme.iconSizeLarge

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: leftMargin
                    }

                    Image {
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

                    Label {
                        id: topLabel
                        text: model.deviceName
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -topLabel.height / 2
                        anchors.left: icon.right
                        anchors.leftMargin: Theme.paddingMedium
                    }

                    Label {
                        anchors.top: topLabel.bottom
                        text: model.deviceAddress
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.left: icon.right
                        anchors.leftMargin: Theme.paddingMedium
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
                                deviceAddress: model.deviceAddress
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
        target: ld
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
                    showBluetoothIcon: true
                });
            }
        }
        onDiscoveryStopped: {
            busyIndicator.visible = false;
        }
    }
}
