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
#ifndef DATABASE_H
#define DATABASE_H

#include <QObject>
#include <QVariant>
#include <QVariantList>
#include <QtSql>

class database : public QObject {
    Q_OBJECT

public:
    explicit database(QObject* parent = nullptr);
    Q_INVOKABLE void inputRawData(QString deviceAddress, QString deviceName, const QVariantList& data);
    void inputManufacturerData(const std::array<uint8_t, 24> &manufacturerData);
    Q_INVOKABLE QVariantList getSensorData(QString deviceAddress, QString sensor, int startTime, int endTime);
    void executeQuery(const QString& queryStr);
    void insertSensorData(QString deviceAddress, QString sensor, const QList<QPair<int, double>>& sensorData);
    Q_INVOKABLE QVariantList getDevices();
    Q_INVOKABLE int getLastMeasurement(const QString deviceAddress, const QString sensor);
    Q_INVOKABLE void renameDevice(const QString deviceAddress, const QString newDeviceName);
    Q_INVOKABLE void removeDevice(const QString deviceAddress);
    Q_INVOKABLE QString exportCSV(const QString deviceAddress, const QString deviceName, int startTime, int endTime);
    Q_INVOKABLE void setVoltage(const QString &mac, double voltage);
    Q_INVOKABLE void setMovement(const QString &mac, int movement);

private:
    QSqlDatabase db;
    void checkAndAddColumn(const QString &tableName, const QString &columnName, const QString &columnType);

signals:
    void inputFinished();
    void voltageUpdated(const QString &mac, double voltage);
    void movementUpdated(const QString &mac, int movement);
};

#endif // DATABASE_H
