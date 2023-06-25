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
#include "database.h"
#include "worker.h"
#include <QDebug>
#include <ctime>
#include <QThread>


database::database(QObject* parent) : QObject(parent) {
    QSqlDatabase db = QSqlDatabase(QSqlDatabase::addDatabase("QSQLITE"));

    // Setup the database path
    QString dbName = "ruuviData.sqlite";
    //QString appName = "harbour-skruuvi";
    QString dbFolder = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    //QString dbFolder = data + "/" + appName;
    QString dbPath = dbFolder + "/" + dbName;

    // Check if the database directories exist
    if (!QDir(dbFolder).exists()) {
        qDebug() << "Database folder did not exist; creating it";
        QDir().mkpath(dbFolder);
    }

    // Open the database
    qDebug() << "Db path: " << dbPath;
    db.setDatabaseName(dbPath);
    if (!db.open()) {
        qDebug() << "Could not open database";
    }

    // Set the foreign keys pragma on
    executeQuery("PRAGMA foreign_keys = ON");

    // Create the tables if not yet created
    QString createDevicesTableQuery = "CREATE TABLE IF NOT EXISTS devices ("
                                      "mac VARCHAR(17) PRIMARY KEY UNIQUE,"
                                      "name TEXT)";
    executeQuery(createDevicesTableQuery);
    QString createTemperatureTableQuery = "CREATE TABLE IF NOT EXISTS temperature ("
                                          "device TEXT REFERENCES devices(mac),"
                                          "timestamp INT,"
                                          "value REAL,"
                                          "PRIMARY KEY (device, timestamp),"
                                          "FOREIGN KEY (device) REFERENCES devices(mac))";
    executeQuery(createTemperatureTableQuery);
    QString createHumidityTableQuery = "CREATE TABLE IF NOT EXISTS humidity ("
                                       "device TEXT REFERENCES devices(mac),"
                                       "timestamp INT,"
                                       "value REAL,"
                                       "PRIMARY KEY (device, timestamp),"
                                       "FOREIGN KEY (device) REFERENCES devices(mac))";
    executeQuery(createHumidityTableQuery);
    QString createAirPressureTableQuery = "CREATE TABLE IF NOT EXISTS air_pressure ("
                                          "device TEXT REFERENCES devices(mac),"
                                          "timestamp INT,"
                                          "value REAL,"
                                          "PRIMARY KEY (device, timestamp),"
                                          "FOREIGN KEY (device) REFERENCES devices(mac))";
    executeQuery(createAirPressureTableQuery);

}

void database::executeQuery(const QString& queryStr) {
    QSqlQuery query(db);
    if (!query.exec(queryStr)) {
        qDebug() << "Error executing query:" << query.lastError().text();
    }
}

void database::inputRawData(QString deviceAddress, QString deviceName, const QVariantList& data) {
    // Create a QThread to run the function in a separate thread
    QThread* thread = new QThread(this);
    // Create a worker object that will handle the execution of the function
    worker* workerObj = new worker(this, deviceAddress, deviceName, data);
    workerObj->moveToThread(thread);
    // Connect signals
    connect(thread, &QThread::started, workerObj, &worker::inputRawData);
    connect(workerObj, &worker::inputFinished, this, &database::inputFinished);
    connect(workerObj, &worker::inputFinished, thread, &QThread::quit);
    // Start the thread
    thread->start();
}

void database::insertSensorData(QString deviceAddress, QString sensor, const QList<QPair<int, double>>& sensorData) {
    // Loop over the sensor data and insert into the table
    for (const QPair<int, double>& item : sensorData) {
        int timestamp = item.first;
        double value = item.second;

        QString insertQuery = "INSERT OR IGNORE INTO " + sensor + " (device, timestamp, value) "
                              "VALUES ('" + deviceAddress + "', " + QString::number(timestamp) + ", " + QString::number(value) + ")";
        executeQuery(insertQuery);
    }
}

QVariantList database::getSensorData(QString deviceAddress, QString sensor, int startTime, int endTime) {
    QVariantList sensorDataList;

    QString selectQuery = "SELECT timestamp, value FROM " + sensor +
                          " WHERE device = '" + deviceAddress + "' AND timestamp >= " + QString::number(startTime) +
                          " AND timestamp <= " + QString::number(endTime) +
                          " ORDER BY timestamp ASC";
    QSqlQuery query(db);
    if (query.exec(selectQuery)) {
        while (query.next()) {
            int timestamp = query.value(0).toInt();
            double value = query.value(1).toDouble();

            QVariantMap sensorData;
            sensorData["x"] = timestamp;
            sensorData["y"] = value;
            sensorDataList.append(sensorData);
        }
    } else {
        qDebug() << "Error executing sensor data query:" << query.lastError().text();
    }

    return sensorDataList;
}

QVariantList database::getDevices()
{
    QVariantList devices;

    QString selectQuery = "SELECT mac, name FROM devices";
    QSqlQuery query(db);
    if (query.exec(selectQuery)) {
        while (query.next()) {
            QString mac = query.value(0).toString();
            QString name = query.value(1).toString();

            QVariantMap device;
            device["deviceName"] = name;
            device["deviceAddress"] = mac;

            devices.append(device);
        }
    } else {
        qDebug() << "Error executing devices query:" << query.lastError().text();
    }

    return devices;
}

int database::getLastMeasurement(const QString deviceAddress, const QString sensor) {
    QString selectQuery;
    if (sensor == "all") {
        // Find the minimum timestamp among the maximum timestamps of each sensor
        selectQuery = "SELECT MIN(max_timestamp) FROM "
                      "(SELECT MAX(timestamp) AS max_timestamp FROM temperature WHERE device = '" + deviceAddress + "' "
                      "UNION SELECT MAX(timestamp) AS max_timestamp FROM humidity WHERE device = '" + deviceAddress + "' "
                      "UNION SELECT MAX(timestamp) AS max_timestamp FROM air_pressure WHERE device = '" + deviceAddress + "')";
    } else if (sensor == "air pressure") {
        // Find the maximum timestamp for the air_pressure sensor
        selectQuery = "SELECT MAX(timestamp) FROM air_pressure WHERE device = '" + deviceAddress + "'";
    } else {
        // Find the maximum timestamp for the specified sensor
        selectQuery = "SELECT MAX(timestamp) FROM " + sensor + " WHERE device = '" + deviceAddress + "'";
    }

    QSqlQuery query(db);
    if (query.exec(selectQuery)) {
        if (query.next()) {
            return query.value(0).toInt();
        }
    } else {
        qDebug() << "Error executing getLastMeasurement query:" << query.lastError().text();
    }
    return 1; // Return 1 if an error occurred or no measurement was found
}

void database::renameDevice(const QString deviceAddress, const QString newDeviceName) {
    // Check if the device already exists in the devices table
    QString selectQuery = "SELECT mac FROM devices WHERE mac = '" + deviceAddress + "'";
    QSqlQuery query(db);
    if (query.exec(selectQuery)) {
        if (!query.next()) {
            // Device does not exist, so insert it into the devices table
            QString insertQuery = "INSERT INTO devices (mac, name) VALUES ('" + deviceAddress + "', '" + newDeviceName + "')";
            executeQuery(insertQuery);
        } else {
            // Device exist, update the name
            QString updateQuery = "UPDATE devices SET name = '" + newDeviceName + "' WHERE mac = '" + deviceAddress + "'";
            executeQuery(updateQuery);
        }
    } else {
        qDebug() << "Error executing selectQuery in renameDevice:" << query.lastError().text();
        return;
    }
}

void database::removeDevice(const QString deviceAddress) {
    // Remove sensor readings from temperature table
    QString deleteTemperatureQuery = "DELETE FROM temperature WHERE device = '" + deviceAddress + "'";
    executeQuery(deleteTemperatureQuery);

    // Remove sensor readings from humidity table
    QString deleteHumidityQuery = "DELETE FROM humidity WHERE device = '" + deviceAddress + "'";
    executeQuery(deleteHumidityQuery);

    // Remove sensor readings from air_pressure table
    QString deleteAirPressureQuery = "DELETE FROM air_pressure WHERE device = '" + deviceAddress + "'";
    executeQuery(deleteAirPressureQuery);

    // Remove device from devices table
    QString deleteDeviceQuery = "DELETE FROM devices WHERE mac = '" + deviceAddress + "'";
    executeQuery(deleteDeviceQuery);
}
