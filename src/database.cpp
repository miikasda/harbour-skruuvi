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
#include "database.h"
#include "worker.h"
#include <QDebug>
#include <ctime>
#include <QThread>
#include <QFile>
#include <QTextStream>


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

    // Colums added after initial release needs to be appended
    checkAndAddColumn("devices", "voltage", "REAL");
    checkAndAddColumn("devices", "movement", "INT");

}

void database::executeQuery(const QString& queryStr) {
    QSqlQuery query(db);
    if (!query.exec(queryStr)) {
        qDebug() << "Error executing query:" << query.lastError().text();
    }
}

void database::checkAndAddColumn(const QString &tableName, const QString &columnName, const QString &columnType) {
    QSqlQuery query(db);
    query.exec("PRAGMA table_info(" + tableName + ")");
    bool columnExists = false;
    while (query.next()) {
        if (query.value(1).toString() == columnName) {
            columnExists = true;
            break;
        }
    }
    if (!columnExists) {
        qDebug() << "Adding column " << columnName << " to table " << tableName;
        QString alterTableQuery = "ALTER TABLE " + tableName + " ADD COLUMN " + columnName + " " + columnType;
        executeQuery(alterTableQuery);
    }
}

void database::setVoltage(const QString &mac, double voltage) {
    QSqlQuery query(db);
    query.prepare("UPDATE devices SET voltage = :voltage WHERE mac = :mac");
    query.bindValue(":voltage", voltage);
    query.bindValue(":mac", mac);

    if (!query.exec()) {
        qDebug() << "Error setting voltage:" << query.lastError().text();
    } else {
        emit voltageUpdated(mac, voltage); // Emit the new voltage reading
    }
}

void database::setMovement(const QString &mac, int movement) {
    QSqlQuery query(db);
    query.prepare("UPDATE devices SET movement = :movement WHERE mac = :mac");
    query.bindValue(":movement", movement);
    query.bindValue(":mac", mac);

    if (!query.exec()) {
        qDebug() << "Error setting movement:" << query.lastError().text();
    } else {
        emit movementUpdated(mac, movement); // Emit the new movement reading
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

    QString selectQuery = "SELECT mac, name, voltage, movement FROM devices";
    QSqlQuery query(db);
    if (query.exec(selectQuery)) {
        while (query.next()) {
            QString mac = query.value(0).toString();
            QString name = query.value(1).toString();
            QString voltage = query.value("voltage").isNull() ? "NA" : QString::number(query.value("voltage").toDouble());
            QString movement = query.value("movement").isNull() ? "NA" : QString::number(query.value("movement").toInt());

            QVariantMap device;
            device["deviceName"] = name;
            device["deviceAddress"] = mac;
            device["deviceVoltage"] = voltage;
            device["deviceMovement"] = movement;

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

QString database::exportCSV(const QString deviceAddress, const QString deviceName, int startTime, int endTime) {
    // Create the path for csv file
    std::time_t currentTimestamp = std::time(nullptr);
    std::tm* currentTime = std::localtime(&currentTimestamp);
    char timeStr[18];
    std::strftime(timeStr, sizeof(timeStr), "%d-%m-%y-%H-%M-%S", currentTime);
    QString modifiedDeviceAddress = deviceAddress;
    modifiedDeviceAddress.replace(":", "-");
    QString csvFolder = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    csvFolder = csvFolder + "/" + "skruuvi-exports";
    // Check that skruuviExports dir exists in Documents. If not, create it
    if (!QDir(csvFolder).exists()) {
        qDebug() << "skruuvi-exports folder did not exist; creating it";
        QDir().mkpath(csvFolder);
    }
    QString csvPath = csvFolder + "/" + modifiedDeviceAddress + "_" + deviceName + "_" + timeStr + ".csv";
    qDebug() << "Exporting data to" << csvPath;

    // Open the file for writing the csv
    QFile file(csvPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "Error opening file:" << file.errorString();
        return "";
    }
    QTextStream stream(&file);

    // Get all measurements from db
    QString selectQuery = "SELECT t.timestamp, temperature.value AS temperature, humidity.value AS humidity, air_pressure.value AS air_pressure"
                          " FROM ("
                          "     SELECT DISTINCT timestamp FROM temperature WHERE device = '" + deviceAddress + "' AND timestamp >= " + QString::number(startTime) +
                          "     AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM humidity WHERE device = '" + deviceAddress + "' AND timestamp >= " + QString::number(startTime) +
                          "     AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM air_pressure WHERE device = '" + deviceAddress + "' AND timestamp >= " + QString::number(startTime) +
                          "     AND timestamp <= " + QString::number(endTime) +
                          " ) t"
                          " LEFT JOIN temperature ON t.timestamp = temperature.timestamp AND temperature.device = '" + deviceAddress + "'"
                          " LEFT JOIN humidity ON t.timestamp = humidity.timestamp AND humidity.device = '" + deviceAddress + "'"
                          " LEFT JOIN air_pressure ON t.timestamp = air_pressure.timestamp AND air_pressure.device = '" + deviceAddress + "'"
                          " ORDER BY t.timestamp ASC";
    QSqlQuery query(db);

    // Write header to the CSV file
    stream << "mac,name,timestamp,temperature,humidity,air_pressure\n";
    // Loop through the query results
    if (query.exec(selectQuery)) {
        while (query.next()) {
            int timestamp = query.value(0).toInt();
            QString temperature = query.value(1).isNull() ? "-" : QString::number(query.value(1).toDouble());
            QString humidity = query.value(2).isNull() ? "-" : QString::number(query.value(2).toDouble());
            QString air_pressure = query.value(3).isNull() ? "-" : QString::number(query.value(3).toDouble());
            // Write the data to the CSV file
            stream << deviceAddress << "," << deviceName << "," << timestamp << "," << temperature << "," << humidity << "," << air_pressure << "\n";
        }
    } else {
        qDebug() << "Error executing sensor data query:" << query.lastError().text();
    }

    file.close();
    return csvPath;
}
