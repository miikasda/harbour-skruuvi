/*
    Skruuvi - Reader for Ruuvi sensors
    Copyright (C) 2024-2025  Miika Malin

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
#include <QDBusMetaType>
#include <QDBusReply>
#include <QByteArray>
#include <QMap>

typedef QMap<QString, QVariantMap> BluezInterfaceMap;
typedef QMap<QDBusObjectPath, BluezInterfaceMap> BluezManagedObjectMap;

Q_DECLARE_METATYPE(BluezInterfaceMap)
Q_DECLARE_METATYPE(BluezManagedObjectMap)

backgroundscanner::backgroundscanner(QObject *parent, database* db)
    : QObject(parent)
    , bus(QDBusConnection::systemBus())
    , db(db)
    , scanning(false)
{
    qDBusRegisterMetaType<BluezInterfaceMap>();
    qDBusRegisterMetaType<BluezManagedObjectMap>();

    startScan();
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

        // Accept either DF5 (24 bytes) or DF6 (20 bytes)
        if (value.size() != 24 && value.size() != 20) {
            qWarning() << "ManufacturerData length is" << value.size() << "bytes, expected 20 or 24 bytes";
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

QString backgroundscanner::findAdapterPath()
{
    QDBusInterface objectManager("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", bus);
    QDBusReply<BluezManagedObjectMap> reply = objectManager.call("GetManagedObjects");
    if (!reply.isValid()) {
        qWarning() << "Failed to query Bluetooth adapters:" << reply.error().message();
        return {};
    }

    QString firstAdapter;
    const BluezManagedObjectMap objects = reply.value();
    for (auto object = objects.constBegin(); object != objects.constEnd(); ++object) {
        const auto adapter = object.value().constFind("org.bluez.Adapter1");
        if (adapter == object.value().constEnd()) {
            continue;
        }

        const QString path = object.key().path();
        if (firstAdapter.isEmpty()) {
            firstAdapter = path;
        }
        if (adapter.value().value("Powered").toBool()) {
            return path;
        }
    }

    return firstAdapter;
}

void backgroundscanner::loadKnownDevices()
{
    QDBusInterface objectManager("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", bus);
    QDBusReply<BluezManagedObjectMap> reply = objectManager.call("GetManagedObjects");
    if (!reply.isValid()) {
        qWarning() << "Failed to query known Bluetooth devices:" << reply.error().message();
        return;
    }

    const QString devicePathPrefix = adapterPath + "/";
    const BluezManagedObjectMap objects = reply.value();
    for (auto object = objects.constBegin(); object != objects.constEnd(); ++object) {
        if (object.key().path().startsWith(devicePathPrefix)
                && object.value().contains("org.bluez.Device1")) {
            processDevice(object.key());
        }
    }
}

void backgroundscanner::processDevice(const QDBusObjectPath &objectPath)
{
    QDBusInterface deviceInterface("org.bluez", objectPath.path(), "org.bluez.Device1", bus);

    const QString deviceName = deviceInterface.property("Name").toString();
    const QString deviceAddress = deviceInterface.property("Address").toString();
    if (!deviceName.contains("Ruuvi") || deviceAddress.isEmpty()) {
        return;
    }

    emit deviceFound(deviceName, deviceAddress);
    db->addDevice(deviceAddress, deviceName);

    // Cached devices may receive fresh ManufacturerData after this method returns.
    if (!monitoredDevicePaths.contains(objectPath.path())) {
        const bool connected = bus.connect(
            "org.bluez", objectPath.path(), "org.freedesktop.DBus.Properties",
            "PropertiesChanged", this,
            SLOT(onPropertiesChanged(QString, QVariantMap, QStringList, QDBusMessage)));
        if (connected) {
            monitoredDevicePaths.insert(objectPath.path());
        } else {
            qWarning() << "Failed to monitor Ruuvi device at path" << objectPath.path();
        }
    }

    // Read the current advertisement data if BlueZ already has it.
    QDBusInterface deviceProps("org.bluez", objectPath.path(), "org.freedesktop.DBus.Properties", bus);
    QDBusMessage reply = deviceProps.call("Get", "org.bluez.Device1", "ManufacturerData");
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty()) {
        return;
    }

    const QVariant firstReply = reply.arguments().first();
    const QVariant firstReplyVariant = firstReply.value<QDBusVariant>().variant();
    const QDBusArgument &dbusArgs = firstReplyVariant.value<QDBusArgument>();
    const std::array<uint8_t, 24> manufacturerData = parseManufacturerData(dbusArgs);
    qDebug() << "Backgroundscanner: Got new ManufacturerData (processDevice):";
    db->inputManufacturerData(deviceAddress, manufacturerData);
}

QString backgroundscanner::macFromObjectPath(const QString &path)
{
    // Expected format: "/org/bluez/<adapter>/dev_XX_XX_XX_XX_XX_XX"
    QString base = path.section('/', -1); // get last segment "dev_xx_xx..."
    if (!base.startsWith("dev_"))
        return {};
    base = base.mid(4); // Remove "dev_"
    base.replace('_', ':');
    return base.toUpper();
}

void backgroundscanner::startScan()
{
    qDebug() << "Starting background scan...";
    adapterPath = findAdapterPath();
    if (adapterPath.isEmpty()) {
        qWarning() << "No Bluetooth adapter found";
        emit discoveryStopped();
        return;
    }

    // Create the adapter interface
    QDBusInterface adapterInterface("org.bluez", adapterPath, "org.bluez.Adapter1", bus, this);

    // Check if bluetooth adapter is on
    QVariant poweredVariant = adapterInterface.property("Powered");
    if (poweredVariant.isValid()) {
        bool powered = poweredVariant.toBool();
        if (!powered) {
            qDebug() << "Bluetooth is off";
            emit bluetoothOff();
            emit discoveryStopped();
            scanning = false;
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

    // Connect the signal handler for DeviceFound signal
    bus.connect("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "InterfacesAdded",
                this, SLOT(onInterfacesAdded(QDBusObjectPath, QVariantMap)));
    scanning = true;
    loadKnownDevices();
}

void backgroundscanner::stopScan()
{
    // Create the adapter interface
    QDBusInterface adapterInterface("org.bluez", adapterPath, "org.bluez.Adapter1", bus, this);
    QDBusMessage stopDiscovery = adapterInterface.call("StopDiscovery");
    if (stopDiscovery.type() == QDBusMessage::ErrorMessage) {
        qDebug() << "Failed to stop device discovery:" << stopDiscovery.errorMessage();
        return;
    }

    qDebug() << "Background scanning stopped";
    scanning = false;
    // Emit the discoveryStopped signal
    emit discoveryStopped();
}

void backgroundscanner::onInterfacesAdded(const QDBusObjectPath &objectPath, const QVariantMap &interfaces)
{
    if (!scanning) {
        qDebug() << "Received InterfacesAdded signal, but background scanner is not active.";
        return;  // Ignore signals if not scanning
    }
    if (interfaces.contains("org.bluez.Device1")) {
        processDevice(objectPath);
    }
}

void backgroundscanner::onPropertiesChanged(const QString &interface, const QVariantMap &changedProperties, const QStringList &, const QDBusMessage &msg) {
    if (!scanning) {
        qDebug() << "Received PropertiesChanged signal, but background scanner is not active.";
        return;  // Ignore signals if not scanning
    }
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
        const QString objectPath = msg.path();
        QString deviceAddress = macFromObjectPath(objectPath);
        db->inputManufacturerData(deviceAddress, manufacturerData);
    }
}

bool backgroundscanner::isScanning() const {
    return scanning;
}
