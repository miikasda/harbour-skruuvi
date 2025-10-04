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
import QtQuick 2.0
import Sailfish.Silica 1.0
import "../modules/GraphData"

Page {
    allowedOrientations: Orientation.LandscapeMask

    property var par_data
    property string par_title
    property string par_units

    GraphData {
        id: graph
        graphTitle: par_title
        //anchors.fill: parent
        scale: true
        axisY.units: par_units
        graphHeight: Screen.width - Theme.itemSizeMedium
        width: Screen.height
    }

    Component.onCompleted: {
        graph.setPoints(par_data);
    }

    onVisibleChanged: {
        if (status === PageStatus.Active & visible) {
            // Lines are not shown when app is background
            // redraw the graph when the page is visible again
            graph.setPoints(par_data);
        }
    }
}
