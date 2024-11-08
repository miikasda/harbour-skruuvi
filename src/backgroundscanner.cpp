/*
    Skruuvi - Reader for Ruuvi sensors
    Copyright (C) 2024  Miika Malin

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
#include "backgroundscanner.h"
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDebug>
#include <QDBusConnection>
#include <QDBusArgument>
#include <QByteArray>

backgroundscanner::backgroundscanner(QObject *parent, database* db)
    : QObject(parent)
    , bus(QDBusConnection::systemBus())
    , db(db)
{
    // Connect the signal handler for DeviceFound signal
    bus.connect("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "InterfacesAdded",
                                         this, SLOT(onInterfacesAdded(QDBusObjectPath, QVariantMap)));
}

std::array<uint8_t, 24> backgroundscanner::parseManufacturerData(const QDBusArgument &dbusArg) {
    std::array<uint8_t, 24> manufacturerData = {0};  // Initialize array to zero

    // Parse the data
    dbusArg.beginMap();
    while (!dbusArg.atEnd()) {
        quint16 key;
        QDBusVariant valueVariant;
        dbusArg.beginMapEntry();
        dbusArg >> key >> valueVariant;
        QByteArray value = valueVariant.variant().toByteArray();
        dbusArg.endMapEntry();

        // Check if the length is exactly 24 bytes
        if (value.size() != 24) {
            qWarning() << "ManufacturerData length is" << value.size() << "bytes, expected 24 bytes.";
            return {};  // Return zero-filled array to indicate failure
        }

        // Copy data to the array, ensuring we don’t exceed 24 bytes
        int length = qMin(value.size(), 24);
        for (int i = 0; i < length; ++i) {
            manufacturerData[i] = static_cast<uint8_t>(value[i]);
        }
    }
    dbusArg.endMap();

    return manufacturerData;
}

void backgroundscanner::startScan()
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

    qDebug() << "Starting background scan...";
}

void backgroundscanner::stopScan()
{
    // Create the adapter interface
    QDBusInterface adapterInterface("org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", bus, this);
    QDBusMessage stopDiscovery = adapterInterface.call("StopDiscovery");
    if (stopDiscovery.type() == QDBusMessage::ErrorMessage) {
        qDebug() << "Failed to stop device discovery:" << stopDiscovery.errorMessage();
        return;
    }

    qDebug() << "Background scanning stopped";
    // Emit the discoveryStopped signal
    emit discoveryStopped();
}

void backgroundscanner::onInterfacesAdded(const QDBusObjectPath &objectPath, const QVariantMap &interfaces)
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

        // Only continue processing if name contains "Ruuvi"
        if (deviceName.contains("Ruuvi")) {
            // Parse BT advertisement data from ManufacturerData field
            // We need to read the ManufacturerData through org.freedesktop.DBus.Properties,
            // otherwise we will crash if read the property with deviceInterface.property, see
            // https://stackoverflow.com/questions/28345362/fatal-error-when-trying-to-get-a-dbus-property-with-custom-type
            QDBusInterface deviceProps("org.bluez", objectPath.path(), "org.freedesktop.DBus.Properties", bus);
            QDBusMessage reply = deviceProps.call("Get", "org.bluez.Device1", "ManufacturerData");
            // See https://stackoverflow.com/questions/20206376/how-do-i-extract-the-returned-data-from-qdbusmessage-in-a-qt-dbus-call
            // For explanation of the type switches below
            QVariant firstReply = reply.arguments().first();
            QVariant firstReplyVariant = firstReply.value<QDBusVariant>().variant();
            const QDBusArgument &dbusArgs = firstReplyVariant.value<QDBusArgument>();
            std::array<uint8_t, 24> manufacturerData = parseManufacturerData(dbusArgs);
            qDebug() << "Backgroundscanner: Got new ManufacturerData (onInterfacesAdded):";
            db->inputManufacturerData(manufacturerData);

            // Connect to PropertiesChanged for this specific device so we get the manufacturerData updates
            bus.connect("org.bluez", objectPath.path(), "org.freedesktop.DBus.Properties",
                        "PropertiesChanged", this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
        }
    }
}

void backgroundscanner::onPropertiesChanged(const QString &interface, const QVariantMap &changedProperties, const QStringList &) {
    if (interface.contains("org.bluez.Device1")) {
        // Check if "ManufacturerData" is in changedProperties
        if (!changedProperties.contains("ManufacturerData")) {
            qDebug() << "No ManufacturerData in changed properties.";
            return;
        }
        // Parse the ManufacturerData
        QVariant manufacturerDataVar = changedProperties.value("ManufacturerData");
        const QDBusArgument &dbusArg = manufacturerDataVar.value<QDBusArgument>();
        std::array<uint8_t, 24> manufacturerData = parseManufacturerData(dbusArg);
        qDebug() << "Backgroundscanner: Got new ManufacturerData (onPropertiesChanged):";
        db->inputManufacturerData(manufacturerData);
    }
}
