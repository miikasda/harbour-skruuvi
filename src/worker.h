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
#ifndef WORKER_H
#define WORKER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include "database.h" // Include the database header file

class worker : public QObject {
    Q_OBJECT

public:
    worker(database* db, QString deviceAddress, QString deviceName, const QVariantList& data);
    worker(database* db, const QString& deviceAddress, bool isAir, int startTime, int endTime, int maxPoints);

public slots:
    void inputRawData();
    void plotData();

signals:
    void inputFinished();
    void inputProgress(int step);
    void plotReady(QVariantMap result);

private:
    database* db; // Pointer to the database object
    QString deviceAddress;
    QString deviceName;
    QVariantList data;
    bool plotIsAir = false;
    int plotStartTime = 0;
    int plotEndTime = 0;
    int plotMaxPoints = 0;
    struct DsPoint { double x; double y; };
    static QVariantList downsampleMinMax(const QVariantList& pointsIn, int maxPoints,
        bool* aggregatedOut = nullptr, double* bucketDurationOut = nullptr);
    static void flushBucketToOutput(const QVector<DsPoint>& bucket, QVariantList& out);
    static bool tryParsePointMap(const QVariant& v, DsPoint& out);
    static QVariant makePointVariant(const DsPoint& p);
};

#endif // WORKER_H
