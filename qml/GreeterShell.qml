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

import AccountsService 0.1
import GSettings 1.0
import LightDM 0.1 as LightDM
import Powerd 0.1
import QtQuick 2.0
import SessionBroadcast 0.1
import Ubuntu.Components 0.1
import Unity.Application 0.1
import Unity.Launcher 0.1
import "Components"
import "Greeter"
import "Launcher"
import "Panel"
import "Notifications"
import Unity.Notifications 1.0 as NotificationBackend

BasicShell {
    id: shell

    function activateApplication(appId) {
        SessionBroadcast.requestApplicationStart(LightDM.Greeter.authenticationUser, appId)
        greeter.hide()
    }

    GSettings {
        id: backgroundSettings
        schema.id: "org.gnome.desktop.background"
    }
    backgroundFallbackSource: backgroundSettings.pictureUri // for ease of customization by system builders
    backgroundSource: AccountsService.backgroundFile

    Lockscreen {
        id: lockscreen
        objectName: "lockscreen"

        hides: [launcher, panel.indicators]
        shown: false
        enabled: true
        showAnimation: StandardAnimation { property: "opacity"; to: 1 }
        hideAnimation: StandardAnimation { property: "opacity"; to: 0 }
        y: panel.panelHeight
        x: required ? 0 : - width
        width: parent.width
        height: parent.height - panel.panelHeight
        pinLength: 4

        onEntered: LightDM.Greeter.respond(passphrase);
        onCancel: greeter.show()

        Component.onCompleted: {
            if (LightDM.Users.count == 1) {
                LightDM.Greeter.authenticate(LightDM.Users.data(0, LightDM.UserRoles.NameRole))
                greeter.selected(0)
            }
        }
    }

    Connections {
        target: LightDM.Greeter

        onShowPrompt: {
            if (LightDM.Users.count == 1) {
                // TODO: There's no better way for now to determine if its a PIN or a passphrase.
                if (text == "PIN") {
                    lockscreen.alphaNumeric = false
                } else {
                    lockscreen.alphaNumeric = true
                }
                lockscreen.placeholderText = i18n.tr("Please enter %1").arg(text);
                lockscreen.show();
            }
        }

        onAuthenticationComplete: {
            if (LightDM.Greeter.promptless) {
                return;
            }
            if (LightDM.Greeter.authenticated) {
                lockscreen.hide();
            } else {
                lockscreen.clear(true);
            }
        }
    }

    Greeter {
        id: greeter
        objectName: "greeter"

        available: true
        hides: [launcher, panel.indicators]
        shown: true
        background: shell.background

        y: panel.panelHeight
        width: parent.width
        height: parent.height - panel.panelHeight

        dragHandleWidth: shell.edgeSize

        function login() {
            enabled = false;
            LightDM.Greeter.startSessionSync();
        }

        onShownChanged: {
            if (shown) {
                lockscreen.reset();
                // If there is only one user, we start authenticating with that one here.
                // If there are more users, the Greeter will handle that
                if (LightDM.Users.count == 1) {
                    LightDM.Greeter.authenticate(LightDM.Users.data(0, LightDM.UserRoles.NameRole));
                    greeter.selected(0);
                }
                greeter.forceActiveFocus();
            }
        }

        onShowProgressChanged: if (LightDM.Greeter.promptless && showProgress == 0) login()

        onUnlocked: login()
        onSelected: {
            // Update launcher items for new user
            var user = LightDM.Users.data(uid, LightDM.UserRoles.NameRole);
            AccountsService.user = user;
            LauncherModel.setUser(user);
        }

        onLeftTeaserPressedChanged: {
            if (leftTeaserPressed) {
                launcher.tease();
            }
        }
    }

    InputFilterArea {
        anchors.fill: parent
        blockInput: true
    }

    Revealer {
        id: greeterRevealer
        objectName: "greeterRevealer"

        property real animatedProgress: MathUtils.clamp(-dragPosition / closedValue, 0, 1)
        target: greeter
        width: greeter.width
        height: greeter.height
        handleSize: shell.edgeSize
        orientation: Qt.Horizontal
        enabled: !greeter.locked
    }

    Item {
        id: overlay

        anchors.fill: parent

        Panel {
            id: panel
            anchors.fill: parent //because this draws indicator menus
            indicatorsMenuWidth: parent.width > units.gu(60) ? units.gu(40) : parent.width
            indicators {
                hides: [launcher]
                available: !edgeDemo.active
            }
            fullscreenMode: false
            searchVisible: false
        }

        Launcher {
            id: launcher

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            dragAreaWidth: shell.edgeSize
            available: greeter.narrowMode && !edgeDemo.active
            onLauncherApplicationSelected: {
                shell.activateApplication(appId)
            }
            onShownChanged: {
                if (shown) {
                    panel.indicators.hide()
                }
            }
            onShowDashHome: greeter.show()
        }

        Notifications {
            id: notifications

            model: NotificationBackend.Model
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
                leftMargin: units.gu(1)
                rightMargin: units.gu(1)
                topMargin: panel.panelHeight + units.gu(1)
            }
            states: [
                State {
                    name: "narrow"
                    when: overlay.width <= units.gu(60)
                    AnchorChanges { target: notifications; anchors.left: parent.left }
                },
                State {
                    name: "wide"
                    when: overlay.width > units.gu(60)
                    AnchorChanges { target: notifications; anchors.left: undefined }
                    PropertyChanges { target: notifications; width: units.gu(38) }
                }
            ]

            InputFilterArea {
                anchors { left: parent.left; right: parent.right }
                height: parent.contentHeight
                blockInput: height > 0
            }
        }
    }

    Connections {
        id: powerConnection
        target: Powerd

        onDisplayPowerStateChange: {
            if (status == Powerd.Off) {
                greeter.show();
                edgeDemo.paused = true;
            } else if (status == Powerd.On) {
                edgeDemo.paused = false;
            }
        }
    }

/*
    Connections {
        target: applicationManager
        ignoreUnknownSignals: true
        // If any app is focused when greeter is open, it's due to a user action
        // like a snap decision (say, an incoming call).
        // TODO: these should be protected to only unlock for certain applications / certain usecases
        // potentially only in connection with a notification.
        // TODO: what about the app the shell will restore focus to by itself?
        onMainStageFocusedApplicationChanged: greeter.hide()
        onSideStageFocusedApplicationChanged: greeter.hide()
    }
*/

    Connections {
        target: LightDM.Upstart
        onDispatchURL: shell.activateApplication(url)
    }

    GreeterEdgeDemo {
        id: edgeDemo
        greeter: greeter
    }
}
