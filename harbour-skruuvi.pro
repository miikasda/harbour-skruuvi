# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-skruuvi

CONFIG += sailfishapp

QT += dbus sql

HEADERS += \
    src/database.h \
    src/listdevices.h \
    src/worker.h

SOURCES += src/harbour-skruuvi.cpp \
    src/database.cpp \
    src/listdevices.cpp \
    src/worker.cpp

DISTFILES += qml/harbour-skruuvi.qml \
    qml/cover/CoverPage.qml \
    qml/pages/AboutPage.qml \
    qml/pages/GetDataPage.qml \
    qml/pages/SelectDevicePage.qml \
    qml/pages/PlotDataPage.qml \
    qml/modules/GraphData/GraphData.qml \
    qml/modules/GraphData/Axis.qml \
    rpm/harbour-skruuvi.changes.in \
    rpm/harbour-skruuvi.changes.run.in \
    rpm/harbour-skruuvi.spec \
    harbour-skruuvi.desktop

OTHER_FILES += qml/pages/ruuvi_read.py \

SAILFISHAPP_ICONS = 256x256 172x172 128x128 108x108 86x86

# to disable building translations every time, comment out the
# following CONFIG line
#CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
#TRANSLATIONS += translations/harbour-skruuvi-de.ts

# Install python packages
bleak.files = ./python_packages/bleak/bleak
bleak.path = /usr/share/$${TARGET}
async-timeout.files = ./python_packages/async_timeout/async_timeout
async-timeout.path = /usr/share/$${TARGET}
dbus-fast.files = ./python_packages/dbus_fast/src/dbus_fast
dbus-fast.path = /usr/share/$${TARGET}
INSTALLS += bleak \
    async-timeout \
    dbus-fast
