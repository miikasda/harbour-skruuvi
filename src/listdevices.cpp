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
#include "listdevices.h"
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDebug>
#include <QDBusConnection>
#include <QTimer>

listdevices::listdevices(QObject *parent)
    : QObject(parent)
    , bus(QDBusConnection::systemBus())
{
    // Connect the signal handler for DeviceFound signal
    bus.connect("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "InterfacesAdded",
                                         this, SLOT(onInterfacesAdded(QDBusObjectPath, QVariantMap)));
}

void listdevices::startDiscovery()
{
    // Create the adapter interface
    QDBusInterface adapterInterface("org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", bus, this);

    // Check if bluetooth adapter is on
    QVariant poweredVariant = adapterInterface.property("Powered");
    if (poweredVariant.isValid()) {
        bool powered = poweredVariant.toBool();
        if (!powered) {
            qDebug() << "Bluetooth is off";
            emit bluetoothOff();
            emit discoveryStopped();
            return;
        }
    }

    // Start the discovery
    QDBusMessage startDiscovery = adapterInterface.call("StartDiscovery");
    if (startDiscovery.type() == QDBusMessage::ErrorMessage) {
        qDebug() << "Failed to start device discovery:" << startDiscovery.errorMessage();
        emit discoveryStopped();
        return;
    }

    qDebug() << "Scanning for nearby Bluetooth devices...";

    // Stop discovery after 10 seconds
    QTimer::singleShot(10000, this, &listdevices::stopDiscovery);
}

void listdevices::stopDiscovery()
{
    // Create the adapter interface
    QDBusInterface adapterInterface("org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", bus, this);
    QDBusMessage stopDiscovery = adapterInterface.call("StopDiscovery");
    if (stopDiscovery.type() == QDBusMessage::ErrorMessage) {
        qDebug() << "Failed to stop device discovery:" << stopDiscovery.errorMessage();
        return;
    }

    qDebug() << "Device discovery stopped";
    // Emit the discoveryStopped signal
    emit discoveryStopped();
}

void listdevices::onInterfacesAdded(const QDBusObjectPath &objectPath, const QVariantMap &interfaces)
{
    if (interfaces.contains("org.bluez.Device1")) {
        QDBusInterface deviceInterface("org.bluez", objectPath.path(), "org.bluez.Device1", bus);

        // Get the device name
        QString deviceName;
        QVariant deviceNameVariant = deviceInterface.property("Name");
        if (deviceNameVariant.isValid()) {
            deviceName = deviceNameVariant.toString();
        }

        // Get the device MAC address
        QString deviceAddress;
        QVariant deviceAddressVariant = deviceInterface.property("Address");
        if (deviceAddressVariant.isValid()) {
            deviceAddress = deviceAddressVariant.toString();
        }

        // Only emit the signal if name contains "Ruuvi"
        if (deviceName.contains("Ruuvi")) {
            // Emit devicefound signal to be able to handle new devices in QML
            emit deviceFound(deviceName, deviceAddress);
        }
    }
}
