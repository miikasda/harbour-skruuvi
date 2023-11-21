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
#include "worker.h"
#include <QDebug>

worker::worker(database* db, QString deviceAddress, QString deviceName, const QVariantList& data)
    : db(db), deviceAddress(deviceAddress), deviceName(deviceName), data(data) {}

void worker::inputRawData() {
    // Define sensor values
    constexpr int TEMPERATURE = 0x30;
    constexpr int HUMIDITY = 0x31;
    constexpr int AIR_PRESSURE = 0x32;

    // Add the device into the database if it's not there yet
    QString createDeviceQuery = "INSERT OR IGNORE INTO devices (mac, name) "
                                "VALUES ('" + deviceAddress + "', '" + deviceName + "')";
    db->executeQuery(createDeviceQuery);

    // Create lists for each sensor
    QList<QPair<int, double>> temperatureList;
    QList<QPair<int, double>> humidityList;
    QList<QPair<int, double>> airPressureList;

    // Loop over the data
    foreach (const QVariant& item, data) {
        // The first item is the keyword "data", skip that
        if (item.type() == QVariant::String) {
            continue;
        }

        // Parse the data
        QVariantList itemList = item.toList();
        int sensor = itemList[1].toInt();
        int timestamp = itemList[3].toInt();
        double value = static_cast<double>(itemList[4].toInt()) / 100.0;

        // Collect the data to sensor lists
        switch (sensor) {
            case TEMPERATURE:
                temperatureList.append(qMakePair(timestamp, value));
                break;
            case HUMIDITY:
                if (value >= 0 && value <= 100) {
                    humidityList.append(qMakePair(timestamp, value));
                }
                break;
            case AIR_PRESSURE:
                if (value >= 0 && value <= 10000) {
                    airPressureList.append(qMakePair(timestamp, value));
                }
                break;
        }
    }

    // Insert the sensor data if the corresponding lists are not empty
    if (!temperatureList.isEmpty()) {
        db->insertSensorData(deviceAddress, "temperature", temperatureList);
    }
    if (!humidityList.isEmpty()) {
        db->insertSensorData(deviceAddress, "humidity", humidityList);
    }
    if (!airPressureList.isEmpty()) {
        db->insertSensorData(deviceAddress, "air_pressure", airPressureList);
    }
    qDebug() << "Inserted sensor data";

    // Emit the inputFinished signal to indicate that the operation is completed
    emit inputFinished();
}
