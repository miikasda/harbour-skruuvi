
import QtQuick 2.0
import QtQml 2.1
import Sailfish.Silica 1.0

import "."

Item {
    id: root
    anchors {
        left: (parent)? parent.left : undefined
        right: (parent)? parent.right : undefined
    }
    height: graphHeight + (doubleAxisXLables ? Theme.itemSizeMedium : Theme.itemSizeSmall)

    signal clicked

    property alias clickEnabled: backgroundArea.enabled
    property string graphTitle: ""

    property alias axisX: _axisXobject
    Axis {
        id: _axisXobject
        mask: "hh:mm"
        grid: 4
    }

    property alias axisY: _axisYobject
    Axis {
        id: _axisYobject
        mask: "%1"
        units: "%"
        grid: 4
    }

    property var valueConverter
    property bool valueTotal: false

    property int graphHeight: 250
    property int graphWidth: canvas.width
    property bool doubleAxisXLables: false

    property bool scale: false
    property color lineColor: Theme.highlightColor
    property int lineWidth: 3

    property real minY: 0 //Always 0
    property real maxY: 0

    property int minX: 0
    property int maxX: 0

    property var points: []
    onPointsChanged: {
        noData = (points.length == 0);
    }
    property bool noData: true

    function setPoints(data) {
        if (!data) return;

        var pointMaxY = Number.NEGATIVE_INFINITY;
        var pointMinY = Number.POSITIVE_INFINITY;
        if (data.length > 0) {
            minX = data[0].x;
            maxX = data[data.length-1].x;
        }
        data.forEach(function(point) {
            if (point.y > pointMaxY) {
                pointMaxY = point.y;
            }
            if (point.y < pointMinY) {
                pointMinY = point.y;
            }
        });
        points = data;
        if (scale) {
            // Set the y-axis limits to the nearest integer
            maxY = Math.ceil(pointMaxY);
            minY = Math.floor(pointMinY);
        }
        doubleAxisXLables = ((maxX - minX) > 129600); // 1.5 days

        canvas.requestPaint();
    }

    function createYLabel(value) {
        var v = value;
        if (valueConverter) {
            v = valueConverter(value);
        }
        return axisY.mask.arg(v);
    }

    function createXLabel(value) {
        var d = new Date(value * 1000);
        return Qt.formatTime(d, axisX.mask);
    }

    Column {
        anchors {
            top: parent.top
            left: parent.left
            leftMargin: 3 * Theme.paddingLarge
            right: parent.right
            rightMargin: Theme.paddingLarge
        }

        Label {
            width: parent.width
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeSmall
            text: graphTitle
            wrapMode: Text.Wrap

            Label {
                id: labelLastValue
                anchors {
                    right: parent.right
                }
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                visible: !noData
            }
        }

        Rectangle {
            width: parent.width
            height: graphHeight
            border.color: Theme.secondaryHighlightColor
            color: "transparent"

            BackgroundItem {
                id: backgroundArea
                anchors.fill: parent
                onClicked: {
                    root.clicked();
                }
            }

            Label {
                text: "No data"
                anchors.centerIn: parent
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeLarge
                visible: noData
            }

            Label {
                text: axisY.units
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: Theme.paddingSmall
                }
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                visible: !noData
            }

            Repeater {
                model: noData ? 0 : (axisY.grid + 1)
                delegate: Label {
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeLarge / 2
                    text: createYLabel( (maxY-minY)/axisY.grid * index + minY)
                    anchors {
                        top: (index == axisY.grid) ? parent.top : undefined
                        bottom: (index == axisY.grid) ? undefined : parent.bottom
                        bottomMargin: (index) ? parent.height / axisY.grid * index - height/2 : 0
                        right: parent.left
                        rightMargin: Theme.paddingSmall
                    }
                }
            }

            Repeater {
                model: noData ? 0 : (axisX.grid + 1)
                delegate: Label {
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeLarge / 2
                    text: createXLabel(minX + index * ((maxX - minX) / axisX.grid))
                    anchors {
                        top: parent.bottom
                        topMargin: Theme.paddingSmall
                        left: (index == axisX.grid) ? undefined : parent.left
                        right: (index == axisX.grid) ? parent.right : undefined
                        leftMargin: (index) ? (parent.width / axisX.grid * index - width/2): 0
                    }
                    x: index * (parent.width / axisX.grid) - width / 2 // Adjust for center alignment
                    Label {
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeLarge / 2
                        anchors {
                            top: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }
                        text: Qt.formatDate(new Date( ((maxX-minX)/axisX.grid * index + minX) * 1000), "ddd dd.MM");
                        visible: doubleAxisXLables
                    }
                }
            }

            Canvas {
                id: canvas
                anchors {
                    fill: parent
                }

                function drawGrid(ctx) {
                    ctx.save();
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = lineColor;
                    ctx.globalAlpha = 0.4;

                    for (var i = 1; i < axisY.grid; i++) {
                        ctx.beginPath();
                        ctx.moveTo(0, height / axisY.grid * i);
                        ctx.lineTo(width, height / axisY.grid * i);
                        ctx.stroke();
                    }
                    ctx.restore();
                }

                function drawPoints(ctx, points) {
                    if (points.length === 0) return;
                    ctx.save();
                    ctx.strokeStyle = lineColor;
                    ctx.lineWidth = lineWidth;
                    ctx.beginPath();

                    var xFactor = width / (maxX - minX);
                    for (var i = 0; i < points.length; i++) {
                        var x = (points[i].x - minX) * xFactor;
                        var y = height - ((points[i].y - minY) / (maxY - minY)) * height;
                        if (i === 0) {
                            ctx.moveTo(x, y);
                        } else {
                            ctx.lineTo(x, y);
                        }
                    }
                    ctx.stroke();
                    ctx.restore();
                }

                onPaint: {
                    var ctx = canvas.getContext("2d");
                    ctx.globalCompositeOperation = "source-over";
                    ctx.clearRect(0, 0, width, height);

                    if (points.length > 0) {
                        drawGrid(ctx);
                        drawPoints(ctx, points);
                        // Add latest value top of the graph
                        var lastValue = points[points.length-1].y;
                        labelLastValue.text = root.createYLabel(lastValue)+root.axisY.units;
                    }
                }
            }
        }
    }
}
