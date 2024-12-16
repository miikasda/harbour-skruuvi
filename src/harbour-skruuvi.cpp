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
#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QtQml>

#include "listdevices.h"
#include "database.h"
#include "backgroundscanner.h"

int main(int argc, char *argv[])
{
    // SailfishApp::main() will display "qml/harbour-skruuvi.qml", if you need more
    // control over initialization, you can use:
    //
    //   - SailfishApp::application(int, char *[]) to get the QGuiApplication *
    //   - SailfishApp::createView() to get a new QQuickView * instance
    //   - SailfishApp::pathTo(QString) to get a QUrl to a resource file
    //   - SailfishApp::pathToMainQml() to get a QUrl to the main QML file
    //
    // To display the view, call "show()" (will show fullscreen on device).

    // Set up QML engine.
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QScopedPointer<QQuickView> v(SailfishApp::createView());

    // Register c++ classes for QML
    listdevices ld;
    v->engine()->rootContext()->setContextProperty("ld", &ld);
    database db;
    v->engine()->rootContext()->setContextProperty("db", &db);
    backgroundscanner bs(nullptr, &db);
    v->engine()->rootContext()->setContextProperty("bs", &bs);

    // Start the application.
    v->setSource(SailfishApp::pathTo("qml/harbour-skruuvi.qml"));
    v->show();
    return app->exec();
}
