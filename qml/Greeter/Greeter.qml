/*
 * Copyright (C) 2013 Canonical, Ltd.
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

import QtQuick 2.0
import Ubuntu.Components 0.1
import Ubuntu.Gestures 0.1
import LightDM 0.1 as LightDM
import "../Components"

Showable {
    id: greeter
    enabled: shown
    created: greeterContentLoader.status == Loader.Ready && greeterContentLoader.item.ready

    property url defaultBackground

    // 1 when fully shown and 0 when fully hidden
    property real showProgress: MathUtils.clamp((width + x) / width, 0, 1)

    showAnimation: StandardAnimation { property: "x"; to: 0 }
    hideAnimation: __leftHideAnimation

    property alias dragHandleWidth: dragHandle.width
    property alias model: greeterContentLoader.model
    property bool locked: shown && !LightDM.Greeter.promptless

    readonly property bool narrowMode: !multiUser && height > width
    readonly property bool multiUser: LightDM.Users.count > 1

    readonly property int currentIndex: greeterContentLoader.currentIndex

    property var __leftHideAnimation: StandardAnimation { property: "x"; to: -width }
    property var __rightHideAnimation: StandardAnimation { property: "x"; to: width }

    signal selected(int uid)
    signal unlocked(int uid)
    signal tease()

    function hideRight() {
        hideAnimation = __rightHideAnimation
        hide()
    }

    Connections {
        target: __rightHideAnimation
        // Reset hide animation to default once we're finished with it
        onRunningChanged: if (!__rightHideAnimation.running) greeter.hideAnimation = __leftHideAnimation
    }

    Loader {
        id: greeterContentLoader
        objectName: "greeterContentLoader"
        anchors.fill: parent
        property var model: LightDM.Users
        property int currentIndex: 0
        property var infographicModel: LightDM.Infographic
        readonly property int backgroundTopMargin: -greeter.y

        source: required ? "GreeterContent.qml" : ""

        onLoaded: {
            selected(currentIndex);
        }

        Connections {
            target: greeterContentLoader.item

            onSelected: {
                greeter.selected(uid);
                greeterContentLoader.currentIndex = uid;
            }
            onUnlocked: greeter.unlocked(uid);
        }
    }

    onTease: showLabelAnimation.start()

    Label {
        id: swipeHint
        visible: greeter.shown
        property real baseOpacity: 0.6
        opacity: 0.0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: units.gu(5)
        text: i18n.tr("Swipe to unlock")
        color: "white"
    }

    SequentialAnimation {
        id: showLabelAnimation

        PropertyAnimation {
            target: swipeHint
            property: "opacity"
            from: 0.0
            to: swipeHint.baseOpacity
            duration: UbuntuAnimation.SlowDuration
        }
        PropertyAnimation {
            duration: 10000
        }
        PropertyAnimation {
            target: swipeHint
            property: "opacity"
            from: swipeHint.baseOpacity
            to: 0.0
            duration: UbuntuAnimation.SlowDuration
        }
    }

    // Bi-directional revealer
    DraggingArea {
        id: dragHandle
        anchors.fill: greeterContentLoader
        enabled: greeter.narrowMode || !greeter.locked
        orientation: Qt.Horizontal
        propagateComposedEvents: true

        Component.onCompleted: {
            // set evaluators to baseline of dragValue == 0
            leftEvaluator.reset()
            rightEvaluator.reset()
        }

        function maybeTease() {
            if ((!greeter.locked || greeter.narrowMode) && greeter.x == 0)
                greeter.tease();
        }

        onPressAndHold: maybeTease()
        onClicked: maybeTease()

        onDragEnd: {
            if (rightEvaluator.shouldAutoComplete())
                greeter.hideRight()
            else if (leftEvaluator.shouldAutoComplete())
                greeter.hide();
            else
                greeter.show(); // undo drag
        }

        onDragValueChanged: {
            // dragValue is kept as a "step" value since we do this x adjusting on the fly
            greeter.x += dragValue
        }

        EdgeDragEvaluator {
            id: rightEvaluator
            trackedPosition: dragHandle.dragValue + greeter.x
            maxDragDistance: parent.width
            direction: Direction.Rightwards
        }

        EdgeDragEvaluator {
            id: leftEvaluator
            trackedPosition: dragHandle.dragValue + greeter.x
            maxDragDistance: parent.width
            direction: Direction.Leftwards
        }
    }
}
