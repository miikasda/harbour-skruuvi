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
    db->addDevice(deviceAddress, deviceName);

    // Create lists for each sensor
    QList<QPair<int, double>> temperatureList;
    QList<QPair<int, double>> humidityList;
    QList<QPair<int, double>> airPressureList;
    QList<QPair<int, double>> pm25List;
    QList<QPair<int, double>> co2List;
    QList<QPair<int, double>> vocList;
    QList<QPair<int, double>> noxList;

    // Loop over the data
    foreach (const QVariant& item, data) {
        // The first item is the keyword "data", skip that
        if (item.type() == QVariant::String) {
            continue;
        }

        // Parse the data
        QVariantList itemList = item.toList();
        if (itemList.size() == 5) {
            // RuuviTag
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
        } else {
            // RuuviAir, Data format E1
            // https://docs.ruuvi.com/communication/bluetooth-advertisements/data-format-e1
            const int ts = itemList[3].toInt();
            const int tempRaw = itemList[4].toInt();   // int16
            const int humRaw  = itemList[5].toInt();   // uint16
            const int presRaw = itemList[6].toInt();   // uint16
            const int pm25Raw = itemList[7].toInt();   // uint16
            const int co2Raw  = itemList[8].toInt();   // uint16

            const int vocByte = itemList[9].toInt()  & 0xFF;  // uint8
            const int noxByte = itemList[10].toInt() & 0xFF;  // uint8
            const int flags   = itemList[11].toInt() & 0xFF;  // uint8

            // Reconstruct 9-bit VOC/NOx using flags bits 6 and 7 (bit9 extension)
            const int vocRaw = (vocByte << 1) | ((flags >> 6) & 0x01);
            const int noxRaw = (noxByte << 1) | ((flags >> 7) & 0x01);

            // Convert to real values + handle invalid
            const double tempC = (tempRaw == -32768) ? std::numeric_limits<double>::quiet_NaN()
                                                    : static_cast<double>(tempRaw) / 200.0;
            const double humPct = (humRaw == 0xFFFF) ? std::numeric_limits<double>::quiet_NaN()
                                                    : static_cast<double>(humRaw) / 400.0;
            const double presPa = (presRaw == 0xFFFF) ? std::numeric_limits<double>::quiet_NaN()
                                                    : static_cast<double>(presRaw + 50000);
            const double presHpa = std::isnan(presPa) ? std::numeric_limits<double>::quiet_NaN()
                                                    : presPa / 100.0;
            const double pm25 = (pm25Raw == 0xFFFF) ? std::numeric_limits<double>::quiet_NaN()
                                                    : static_cast<double>(pm25Raw) / 10.0;
            const double co2 = (co2Raw == 0xFFFF) ? std::numeric_limits<double>::quiet_NaN()
                                                : static_cast<double>(co2Raw);
            const double voc = (vocRaw == 0x1FF) ? -1 : vocRaw;
            const double nox = (noxRaw == 0x1FF) ? -1 : noxRaw;

            // Collect to lists (skip invalids)
            if (!std::isnan(tempC)) {
                temperatureList.append(qMakePair(ts, tempC));
            }
            if (!std::isnan(humPct) && humPct >= 0.0 && humPct <= 100.0) {
                humidityList.append(qMakePair(ts, humPct));
            }
            if (!std::isnan(presHpa) && presHpa >= 0.0 && presHpa <= 10000.0) {
                airPressureList.append(qMakePair(ts, presHpa));
            }
            if (!std::isnan(pm25)) {
                pm25List.append(qMakePair(ts, pm25));
            }
            if (!std::isnan(co2)) {
                co2List.append(qMakePair(ts, co2));
            }
            if (!std::isnan(voc)) {
                vocList.append(qMakePair(ts, voc));
            }
            if (!std::isnan(nox)) {
                noxList.append(qMakePair(ts, nox));
            }
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
    if (!pm25List.isEmpty()) {
        db->insertSensorData(deviceAddress, "pm25", pm25List);
    }
    if (!co2List.isEmpty()) {
        db->insertSensorData(deviceAddress, "co2", co2List);
    }
    if (!vocList.isEmpty()) {
        db->insertSensorData(deviceAddress, "voc", vocList);
    }
    if (!noxList.isEmpty()) {
        db->insertSensorData(deviceAddress, "nox", noxList);
    }
    qDebug() << "Inserted sensor data";

    // Emit the inputFinished signal to indicate that the operation is completed
    emit inputFinished();
}
