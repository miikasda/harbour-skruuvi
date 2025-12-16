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
#include "database.h" // Include the database header file

class worker : public QObject {
    Q_OBJECT

public:
    worker(database* db, QString deviceAddress, QString deviceName, const QVariantList& data);

public slots:
    void inputRawData();

signals:
    void inputFinished();
    void inputProgress(int step);

private:
    database* db; // Pointer to the database object
    QString deviceAddress;
    QString deviceName;
    QVariantList data;
};

#endif // WORKER_H
