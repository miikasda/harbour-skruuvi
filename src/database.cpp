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
#include "database.h"
#include "worker.h"
#include <QDebug>
#include <ctime>
#include <QThread>
#include <QFile>
#include <QTextStream>
#include <cmath>


database::database(QObject* parent) : QObject(parent) {
    db = QSqlDatabase::addDatabase("QSQLITE");

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
    executeQuery("CREATE TABLE IF NOT EXISTS pm25 ("
                "device TEXT REFERENCES devices(mac),"
                "timestamp INT,"
                "value REAL,"
                "PRIMARY KEY (device, timestamp))");
    executeQuery("CREATE TABLE IF NOT EXISTS co2 ("
                "device TEXT REFERENCES devices(mac),"
                "timestamp INT,"
                "value INT,"
                "PRIMARY KEY (device, timestamp))");
    executeQuery("CREATE TABLE IF NOT EXISTS voc ("
                "device TEXT REFERENCES devices(mac),"
                "timestamp INT,"
                "value INT,"
                "PRIMARY KEY (device, timestamp))");
    executeQuery("CREATE TABLE IF NOT EXISTS nox ("
                "device TEXT REFERENCES devices(mac),"
                "timestamp INT,"
                "value INT,"
                "PRIMARY KEY (device, timestamp))");

    // Colums added after initial release needs to be appended
    checkAndAddColumn("devices", "voltage", "REAL");
    checkAndAddColumn("devices", "movement", "INT");
    checkAndAddColumn("devices", "sync_time", "INT");
    checkAndAddColumn("devices", "temperature", "REAL");
    checkAndAddColumn("devices", "humidity", "REAL");
    checkAndAddColumn("devices", "pressure", "REAL");
    checkAndAddColumn("devices", "tx", "REAL");
    checkAndAddColumn("devices", "acc_x", "REAL");
    checkAndAddColumn("devices", "acc_y", "REAL");
    checkAndAddColumn("devices", "acc_z", "REAL");
    checkAndAddColumn("devices", "last_obs", "int");
    checkAndAddColumn("devices", "meas_seq", "int");
    checkAndAddColumn("devices", "pm25", "REAL");
    checkAndAddColumn("devices", "co2", "INT");
    checkAndAddColumn("devices", "voc", "INT");
    checkAndAddColumn("devices", "nox", "INT");
    checkAndAddColumn("devices", "calibrating", "INT");
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

void database::addDevice(const QString &deviceAddress, const QString &deviceName) {
    qDebug() << "Adding device to db: " << deviceAddress << " " << deviceName;
    QString createDeviceQuery = "INSERT OR IGNORE INTO devices (mac, name) "
                                "VALUES ('" + deviceAddress + "', '" + deviceName + "')";
    executeQuery(createDeviceQuery);
}

void database::updateDevice(const QString &mac, double temperature, double humidity, double pressure, double accX, double accY,
                            double accZ, double voltage, double txPower, int movementCounter, int measurementSequenceNumber, int timestamp)
{
    QSqlQuery query(db);
    query.prepare(
        "UPDATE devices SET "
        "temperature = :temperature, "
        "humidity = :humidity, "
        "pressure = :pressure, "
        "acc_x = :accX, "
        "acc_y = :accY, "
        "acc_z = :accZ, "
        "voltage = :voltage, "
        "tx = :txPower, "
        "movement = :movementCounter, "
        "meas_seq = :measurementSequenceNumber, "
        "last_obs = :timestamp "
        "WHERE mac = :mac"
    );

    query.bindValue(":temperature", temperature);
    query.bindValue(":humidity", humidity);
    query.bindValue(":pressure", pressure);
    query.bindValue(":accX", accX);
    query.bindValue(":accY", accY);
    query.bindValue(":accZ", accZ);
    query.bindValue(":voltage", voltage);
    query.bindValue(":txPower", txPower);
    query.bindValue(":movementCounter", movementCounter);
    query.bindValue(":measurementSequenceNumber", measurementSequenceNumber);
    query.bindValue(":timestamp", timestamp);

    query.bindValue(":mac", mac);

    if (!query.exec()) {
        qDebug() << "Error updating manufacturerdata to deviceDB:" << query.lastError().text();
    }
}

double database::calculateIAQS(double pm25, double co2){
    // Documentation: https://docs.ruuvi.com/ruuvi-air-firmware/ruuvi-indoor-air-quality-score-iaqs

    // Return NaN if inputs are invalid
    if (!std::isfinite(pm25) || !std::isfinite(co2)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    if (pm25 < 0 || co2 < 1) {
        return std::numeric_limits<double>::quiet_NaN();
    }

    // Constants (from Ruuvi IAQS reference implementation)
    const double AQI_MAX = 100.0;
    const double PM25_MIN   = 0.0;
    const double PM25_MAX   = 60.0;
    const double PM25_SCALE = AQI_MAX / (PM25_MAX - PM25_MIN); // ~1.6667
    const double CO2_MIN    = 420.0;
    const double CO2_MAX    = 2300.0;
    const double CO2_SCALE  = AQI_MAX / (CO2_MAX - CO2_MIN);   // ~0.05319

    // Clamp helper
    auto clamp = [](double v, double lo, double hi) {
        return std::min(std::max(v, lo), hi);
    };

    // Clamp values to valid input range
    pm25 = clamp(pm25, PM25_MIN, PM25_MAX);
    co2  = clamp(co2,  CO2_MIN,  CO2_MAX);

    // Convert into normalized distances
    double dx = (pm25 - PM25_MIN) * PM25_SCALE;  // 0..100
    double dy = (co2  - CO2_MIN)  * CO2_SCALE;   // 0..100

    // Hypotenuse = combined pollution index
    double r = std::hypot(dx, dy);

    // IAQS is 100 - distance
    double iaqs = AQI_MAX - r;

    // Clamp 0–100
    iaqs = clamp(iaqs, 0.0, AQI_MAX);

    // Ruuvi specification: round to nearest integer
    return std::round(iaqs);
}

QVariantList database::calculateIAQSList(const QVariantList &pm25Data,
                                         const QVariantList &co2Data)
{
    // Matches timestamps on pm25 and co2 data, and calculates IAQS based on the matched timestamps
    QVariantList result;

    int i = 0, j = 0;
    while (i < pm25Data.size() && j < co2Data.size()) {
        const QVariantMap p = pm25Data[i].toMap();
        const QVariantMap c = co2Data[j].toMap();

        int t1 = p["x"].toInt();
        int t2 = c["x"].toInt();

        if (t1 == t2) {
            double pm25 = p["y"].toDouble();
            double co2  = c["y"].toDouble();

            int iaqs = calculateIAQS(pm25, co2);

            QVariantMap v;
            v["x"] = t1;
            v["y"] = iaqs >= 0 ? iaqs : QVariant(); // null if invalid
            result.append(v);

            ++i; ++j;
        }
        else if (t1 < t2) {
            ++i;
        }
        else {
            ++j;
        }
    }
    return result;
}

void database::updateRuuviAir(const QString &mac, double temperature, double humidity, double pressure, double pm25,
                              int co2, int voc, int nox, int calibrating, int sequence, int timestamp)
{
    QSqlQuery query(db);
    query.prepare(
        "UPDATE devices SET "
        "temperature = :temperature, "
        "humidity = :humidity, "
        "pressure = :pressure, "
        "pm25 = :pm25, "
        "co2 = :co2, "
        "voc = :voc, "
        "nox = :nox, "
        "calibrating = :calibrating, "
        "meas_seq = :sequence, "
        "last_obs = :timestamp "
        "WHERE mac = :mac"
    );

    query.bindValue(":temperature", temperature);
    query.bindValue(":humidity", humidity);
    query.bindValue(":pressure", pressure);
    query.bindValue(":pm25", pm25);
    query.bindValue(":co2", co2);
    query.bindValue(":voc", voc);
    query.bindValue(":nox", nox);
    query.bindValue(":calibrating", calibrating);
    query.bindValue(":sequence", sequence);
    query.bindValue(":timestamp", timestamp);
    query.bindValue(":mac", mac);

    if (!query.exec())
        qWarning() << "Error updating Ruuvi Air device data:" << query.lastError().text();
}

void database::setLastSync(const QString& deviceAddress, const QString& deviceName, int timestamp) {
    addDevice(deviceAddress, deviceName);
    QString updateQuery = "UPDATE devices SET sync_time = " + QString::number(timestamp) +
                          " WHERE mac = '" + deviceAddress + "'";
    executeQuery(updateQuery);
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
    connect(workerObj, &worker::inputProgress, this, &database::inputProgress);
    // Start the thread
    thread->start();
}

void database::inputManufacturerData(const QString &deviceAddress, const std::array<uint8_t, 24> &manufacturerData) {
    int dataFormat = manufacturerData[0];
    int timestamp = QDateTime::currentDateTime().toTime_t();
    if (dataFormat == 5) {
        // Documentation for DF5 is at https://docs.ruuvi.com/communication/bluetooth-advertisements/data-format-5-rawv2
        int16_t temperatureData = (manufacturerData[1] << 8) | manufacturerData[2];
        float temperature = static_cast<float>(temperatureData) * 0.005;
        uint16_t humidityData = (manufacturerData[3] << 8) | manufacturerData[4];
        float humidity = static_cast<float>(humidityData) * 0.0025;
        uint16_t pressureData = (manufacturerData[5] << 8) | manufacturerData[6];
        float pressure = (static_cast<int>(pressureData) + 50000) / 100.0;
        int16_t accDataX = (manufacturerData[7] << 8) | manufacturerData[8];
        float accX = static_cast<float>(accDataX) / 1000;
        int16_t accDataY = (manufacturerData[9] << 8) | manufacturerData[10];
        float accY = static_cast<float>(accDataY) / 1000;
        int16_t accDataZ = (manufacturerData[11] << 8) | manufacturerData[12];
        float accZ = static_cast<float>(accDataZ) / 1000;
        uint16_t BatteryAndTxData = (manufacturerData[13] << 8) | manufacturerData[14];
        int txPower = ((BatteryAndTxData & 0x1F) * 2) - 40;
        float battery = (static_cast<float>(BatteryAndTxData >> 5) / 1000) + 1.6;
        int movementCounter = manufacturerData[15];
        int measurementSequenceNumber = (manufacturerData[16] << 8) | manufacturerData[17];
        char macAddress[18];
        sprintf(macAddress, "%02X:%02X:%02X:%02X:%02X:%02X",
                manufacturerData[18], manufacturerData[19], manufacturerData[20], manufacturerData[21], manufacturerData[22], manufacturerData[23]);

        // Update the device database with updateDevice
        updateDevice(macAddress, temperature, humidity, pressure, accX, accY, accZ, battery, txPower, movementCounter, measurementSequenceNumber, timestamp);

        // Send to database
        insertSensorData(macAddress, "temperature", {qMakePair(timestamp, temperature)});
        if (humidityData != 0xFFFF) {
            insertSensorData(macAddress, "humidity", {qMakePair(timestamp, humidity)});
        }
        if (pressureData != 0xFFFF) {
            insertSensorData(macAddress, "air_pressure", {qMakePair(timestamp, pressure)});
        }

        // Emit signal with new readings
        emit deviceDataUpdated(macAddress, temperature, humidity, pressure, accX, accY, accZ, battery, txPower, movementCounter, measurementSequenceNumber, timestamp);
    }
    else if (dataFormat == 6) {
        // Documentation for DF6 is at https://docs.ruuvi.com/communication/bluetooth-advertisements/data-format-6
        qDebug() << "[DF6] From" << deviceAddress;
        qDebug() << "Raw (first 20 bytes):"
         << QByteArray(reinterpret_cast<const char*>(manufacturerData.data()), 20).toHex();

        // Parse values according to DF6 specification
        int16_t tRaw  = (manufacturerData[1] << 8) | manufacturerData[2];
        uint16_t hRaw  = (manufacturerData[3] << 8) | manufacturerData[4];
        uint16_t pRaw  = (manufacturerData[5] << 8) | manufacturerData[6];
        uint16_t pmRaw = (manufacturerData[7] << 8) | manufacturerData[8];
        uint16_t co2Raw = (manufacturerData[9] << 8) | manufacturerData[10];
        uint8_t vocHi  = manufacturerData[11];
        uint8_t noxHi  = manufacturerData[12];
        uint8_t sequence = manufacturerData[15];
        uint8_t flags = manufacturerData[16];
        float temperature = tRaw * 0.005f;
        float humidity    = hRaw * 0.0025f;
        float pressure    = (pRaw + 50000) / 100.0f;    // hPa
        float pm25        = pmRaw / 10.0f;              // µg/m³
        int co2         = co2Raw;                     // ppm
        int voc = (vocHi << 1) | ((flags >> 6) & 1);
        int nox = (noxHi << 1) | ((flags >> 7) & 1);
        bool calibrationInProgress = (flags & 0x01);

        // Update device db
        updateRuuviAir(deviceAddress, temperature, humidity, pressure, pm25, co2, voc, nox, calibrationInProgress, sequence, timestamp);

        // Send to database
        if (tRaw != 0x7FFF) {
            insertSensorData(deviceAddress, "temperature", {{timestamp, temperature}});
        }
        if (hRaw != 0xFFFF) {
            insertSensorData(deviceAddress, "humidity", {{timestamp, humidity}});
        }
        if (pRaw != 0xFFFF) {
            insertSensorData(deviceAddress, "air_pressure", {{timestamp, pressure}});
        }
        if (pmRaw != 0xFFFF) {
            insertSensorData(deviceAddress, "pm25", {{timestamp, pm25}});
        }
        if (co2Raw != 0xFFFF) {
            insertSensorData(deviceAddress, "co2", {{timestamp, double(co2)}});
        }
        if (voc != 0x1FF) {
            insertSensorData(deviceAddress, "voc", {{timestamp, double(voc)}});
        }
        if (nox != 0x1FF) {
            insertSensorData(deviceAddress, "nox", {{timestamp, double(nox)}});
        }

        // Calculate IAQS
        double iaqs = calculateIAQS(pm25, co2);

        // Emit signal with new readings
        emit airDeviceDataUpdated(deviceAddress, temperature, humidity, pressure, pm25, co2, voc, nox, iaqs, calibrationInProgress, sequence, timestamp);
    }
    else {
        qDebug() << "Unknown data format:" << dataFormat;
    }
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

    QString selectQuery = "SELECT * FROM devices";
    QSqlQuery query(db);
    if (query.exec(selectQuery)) {
        while (query.next()) {
            QString mac = query.value(0).toString();
            QString name = query.value(1).toString();
            QString voltage = query.value("voltage").isNull() ? "NA" : QString::number(query.value("voltage").toDouble());
            QString movement = query.value("movement").isNull() ? "NA" : QString::number(query.value("movement").toInt());
            QString temperature = query.value("temperature").isNull() ? "NA" : QString::number(query.value("temperature").toDouble());
            QString humidity = query.value("humidity").isNull() ? "NA" : QString::number(query.value("humidity").toDouble());
            QString pressure = query.value("pressure").isNull() ? "NA" : QString::number(query.value("pressure").toDouble());
            QString tx = query.value("tx").isNull() ? "NA" : QString::number(query.value("tx").toDouble());
            QString acc_x = query.value("acc_x").isNull() ? "NA" : QString::number(query.value("acc_x").toDouble());
            QString acc_y = query.value("acc_y").isNull() ? "NA" : QString::number(query.value("acc_y").toDouble());
            QString acc_z = query.value("acc_z").isNull() ? "NA" : QString::number(query.value("acc_z").toDouble());
            QString last_obs = query.value("last_obs").isNull() ? "NA" : QString::number(query.value("last_obs").toInt());
            QString meas_seq = query.value("meas_seq").isNull() ? "NA" : QString::number(query.value("meas_seq").toInt());
            QString pm25 = query.value("pm25").isNull() ? "NA" : QString::number(query.value("pm25").toDouble());
            QString co2 = query.value("co2").isNull() ? "NA" : QString::number(query.value("co2").toInt());
            QString voc = query.value("voc").isNull() ? "NA" : QString::number(query.value("voc").toInt());
            QString nox = query.value("nox").isNull() ? "NA" : QString::number(query.value("nox").toInt());
            QString calibrating = query.value("calibrating").isNull() ? "NA" : QString::number(query.value("calibrating").toInt());
            QString iaqs = "NA";
            if (!query.value("pm25").isNull() && !query.value("co2").isNull()) {
                iaqs = QString::number(
                    calculateIAQS(query.value("pm25").toDouble(), query.value("co2").toDouble())
                );
            }

            // TODO Remove the device prefix...
            QVariantMap device;
            device["deviceName"] = name;
            device["deviceAddress"] = mac;
            device["deviceVoltage"] = voltage;
            device["deviceMovement"] = movement;
            device["temperature"] = temperature;
            device["humidity"] = humidity;
            device["pressure"] = pressure;
            device["tx"] = tx;
            device["accX"] = acc_x;
            device["accY"] = acc_y;
            device["accZ"] = acc_z;
            device["last_obs"] = last_obs;
            device["meas_seq"] = meas_seq;
            device["pm25"] = pm25;
            device["co2"] = co2;
            device["voc"] = voc;
            device["nox"] = nox;
            device["calibrating"] = calibrating;
            device["iaqs"] = iaqs;
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

int database::getLastSync(const QString deviceAddress) {
    QString selectQuery = "SELECT sync_time FROM devices WHERE mac = '" + deviceAddress + "'";
    QSqlQuery query(db);
    if (query.exec(selectQuery)) {
        if (query.next()) {
            return query.value(0).toInt();
        }
    } else {
        qDebug() << "Error executing getLastMeasurement query:" << query.lastError().text();
    }
    return 0; // Return 0 if an error occurred or no sync time available
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

    // Remove from RuuviAir related tables
    executeQuery("DELETE FROM pm25 WHERE device = '" + deviceAddress + "'");
    executeQuery("DELETE FROM co2 WHERE device = '" + deviceAddress + "'");
    executeQuery("DELETE FROM voc WHERE device = '" + deviceAddress + "'");
    executeQuery("DELETE FROM nox WHERE device = '" + deviceAddress + "'");

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
    QString selectQuery = "SELECT t.timestamp, temperature.value AS temperature, humidity.value AS humidity, air_pressure.value AS air_pressure,"
                          " pm25.value AS pm25, co2.value AS co2, voc.value AS voc, nox.value AS nox"
                          " FROM ("
                          "     SELECT DISTINCT timestamp FROM temperature WHERE device = '" + deviceAddress + "' AND timestamp >= " + QString::number(startTime) +
                          "     AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM humidity WHERE device = '" + deviceAddress + "' AND timestamp >= " + QString::number(startTime) +
                          "     AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM air_pressure WHERE device = '" + deviceAddress + "' AND timestamp >= " + QString::number(startTime) +
                          "     AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM pm25 WHERE device = '" + deviceAddress + "'"
                          "         AND timestamp >= " + QString::number(startTime) + " AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM co2 WHERE device = '" + deviceAddress + "'"
                          "         AND timestamp >= " + QString::number(startTime) + " AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM voc WHERE device = '" + deviceAddress + "'"
                          "         AND timestamp >= " + QString::number(startTime) + " AND timestamp <= " + QString::number(endTime) +
                          "     UNION"
                          "     SELECT DISTINCT timestamp FROM nox WHERE device = '" + deviceAddress + "'"
                          "         AND timestamp >= " + QString::number(startTime) + " AND timestamp <= " + QString::number(endTime) +
                          " ) t"
                          " LEFT JOIN temperature ON t.timestamp = temperature.timestamp AND temperature.device = '" + deviceAddress + "'"
                          " LEFT JOIN humidity ON t.timestamp = humidity.timestamp AND humidity.device = '" + deviceAddress + "'"
                          " LEFT JOIN air_pressure ON t.timestamp = air_pressure.timestamp AND air_pressure.device = '" + deviceAddress + "'"
                          " LEFT JOIN pm25 ON t.timestamp = pm25.timestamp AND pm25.device = '" + deviceAddress + "'"
                          " LEFT JOIN co2 ON t.timestamp = co2.timestamp AND co2.device = '" + deviceAddress + "'"
                          " LEFT JOIN voc ON t.timestamp = voc.timestamp AND voc.device = '" + deviceAddress + "'"
                          " LEFT JOIN nox ON t.timestamp = nox.timestamp AND nox.device = '" + deviceAddress + "'"
                          " ORDER BY t.timestamp ASC";
    QSqlQuery query(db);

    // Write header to the CSV file
    stream << "mac,name,timestamp,temperature,humidity,air_pressure,pm25,co2,voc,nox,iaqs\n";
    // Loop through the query results
    if (query.exec(selectQuery)) {
        while (query.next()) {
            int timestamp = query.value(0).toInt();
            QString temperature = query.value(1).isNull() ? "-" : QString::number(query.value(1).toDouble());
            QString humidity = query.value(2).isNull() ? "-" : QString::number(query.value(2).toDouble());
            QString air_pressure = query.value(3).isNull() ? "-" : QString::number(query.value(3).toDouble());
            QString pm25  = query.value(4).isNull() ? "-" : QString::number(query.value(4).toDouble());
            QString co2   = query.value(5).isNull() ? "-" : QString::number(query.value(5).toDouble());
            QString voc   = query.value(6).isNull() ? "-" : QString::number(query.value(6).toDouble());
            QString nox   = query.value(7).isNull() ? "-" : QString::number(query.value(7).toDouble());
            QString iaqs = "-";
            if (!query.value(4).isNull() && !query.value(5).isNull()) {
                iaqs = QString::number(
                    calculateIAQS(query.value(4).toDouble(),
                                query.value(5).toDouble())
                );
            }
            // Write the data to the CSV file
            stream << deviceAddress << "," << deviceName << "," << timestamp << "," << temperature << "," << humidity << ","
                   << air_pressure << "," << pm25 << "," << co2 << "," << voc << "," << nox << "," << iaqs << "\n";
        }
    } else {
        qDebug() << "Error executing sensor data query:" << query.lastError().text();
    }

    file.close();
    return csvPath;
}

void database::requestPlotData(QString deviceAddress, bool isAir, int startTime, int endTime, int maxPoints) {
    QThread* thread = new QThread(this);

    worker* workerObj = new worker(this, deviceAddress, isAir, startTime, endTime, maxPoints);
    workerObj->moveToThread(thread);

    connect(thread, &QThread::started, workerObj, &worker::plotData);
    connect(workerObj, &worker::plotReady, this, &database::plotDataReady);

    connect(workerObj, &worker::plotReady, thread, &QThread::quit);
    connect(thread, &QThread::finished, workerObj, &QObject::deleteLater);
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);

    thread->start();
}
