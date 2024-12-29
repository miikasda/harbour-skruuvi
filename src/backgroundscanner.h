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
#include <QObject>
#include <QDBusConnection>
#include <QDBusObjectPath>
#include <QDBusArgument>
#include "database.h"

class backgroundscanner : public QObject
{
    Q_OBJECT

public:
    explicit backgroundscanner(QObject *parent = nullptr, database* db = nullptr);
    Q_INVOKABLE void startScan();
    Q_INVOKABLE void stopScan();


signals:
    void discoveryStopped();
    void bluetoothOff();

private slots:
    void onInterfacesAdded(const QDBusObjectPath &objectPath, const QVariantMap &interfaces);
    void onPropertiesChanged(const QString &interface, const QVariantMap &changedProperties, const QStringList &);
    std::array<uint8_t, 24> parseManufacturerData(const QDBusArgument &dbusArg);

private:
    QDBusConnection bus;
    database* db;
    bool scanning;
};
