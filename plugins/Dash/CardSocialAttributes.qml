/*
 * Copyright 2016 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import "../../../qml/Components/ListItems" as ListItems

Column {
    id: socialAttributes
    spacing: units.gu(0.5)
    height: divider.height + spacing + grid.height

    property alias model: repeater.model
    property color color: theme.palette.normal.baseText
    property real fontScale: 1.0

    signal clicked(var result)

    ListItems.ThinDivider {
        id: divider
        visible: repeater.count > 0
        anchors { left: parent.left; right: parent.right; }
    }

    GridLayout {
        id: grid
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: units.gu(1)
            rightMargin: units.gu(1)
        }
        columns: 2 + repeater.count % 2
        rowSpacing: units.gu(.5)

        Repeater {
            id: repeater
            delegate: Row {
                objectName: "delegate" + index
                spacing: units.gu(0.5)
                readonly property int column: index % grid.columns;
                Layout.alignment: {
                    if (column == 0) return Qt.AlignLeft;
                    if (column == grid.columns - 1 || index == repeater.count - 1) return Qt.AlignRight;
                    if (column == 1) return Qt.AlignHCenter;
                }
                Layout.column: index % grid.columns
                Layout.row: index / grid.columns
                Layout.columnSpan: index == repeater.count - 1 && grid.columns == 3 && column == 1 ? 2 : 1
                Layout.maximumWidth: Math.max(icon.width, label.x + label.implicitWidth)
                Layout.fillWidth: true
                height: units.gu(2)
                AbstractButton {
                    height: units.gu(2)
                    width: icon.width
                    Icon {
                        id: icon
                        objectName: "icon"

                        property url urlIcon: "icon" in modelData && modelData["icon"] || ""
                        property url urlTemporaryIcon: "temporaryIcon" in modelData && modelData["temporaryIcon"] || ""

                        height: units.gu(2)
                        // FIXME Workaround for bug https://bugs.launchpad.net/ubuntu/+source/ubuntu-ui-toolkit/+bug/1421293
                        width: implicitWidth > 0 && implicitHeight > 0 ? (implicitWidth / implicitHeight * height) : implicitWidth
                        source: urlIcon
                        color: socialAttributes.color

                        onUrlIconChanged: if (urlIcon) source = urlIcon
                    }

                    onClicked: socialAttributes.clicked(modelData["id"]);
                    onPressedChanged: if (pressed && icon.urlTemporaryIcon != "") icon.source = icon.urlTemporaryIcon
                }
                Label {
                    id: label
                    width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    text: "label" in modelData && modelData["label"] || "";
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.weight: "style" in modelData && modelData["style"] === "highlighted" ? Font.Bold : Font.Light
                    fontSize: "x-small"
                    font.pixelSize: Math.round(FontUtils.sizeToPixels(fontSize) * fontScale)
                    color: socialAttributes.color
                }
            }
        }
    }
}
