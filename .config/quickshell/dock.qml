import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: WlrLayershell {
            id: shell

            implicitWidth: dockBar.width
            implicitHeight: 80

            anchors.bottom: true

            exclusionMode: ExclusionMode.Ignore
            layer: WlrLayer.Overlay
            namespace: "dock"

            color: "transparent"

            property bool dockVisible: false
            property bool dockHovered: false
            property string stdoutBuffer: ""
            property var appsData: []  // JS-массив с полными данными включая windows

            Timer {
                id: hideTimer
                interval: 500
                onTriggered: {
                    if (!shell.dockHovered) shell.dockVisible = false
                }
            }

            MouseArea {
                id: triggerZone
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 4
                hoverEnabled: true
                onEntered: {
                    hideTimer.stop()
                    shell.dockVisible = true
                }
                onExited: hideTimer.restart()
            }

            Timer {
                interval: 2000
                running: true
                repeat: true
                onTriggered: fetchAppsProc.running = true
            }

            Process {
                id: fetchAppsProc
                command: ["bash", "-c",
                    "python3 /home/myster_gaif/.config/quickshell/get_running_apps.py"]
                running: false
                stdout: SplitParser {
                    onRead: data => shell.stdoutBuffer += data
                }
                onExited: {
                    try {
                        if (shell.stdoutBuffer) {
                            var parsed = JSON.parse(shell.stdoutBuffer)
                            shell.appsData = parsed  // сохраняем полный массив
                            appsModel.clear()
                            for (var i = 0; i < parsed.length; i++)
                                appsModel.append({
                                    app_id:  parsed[i].app_id  || "",
                                    icon:    parsed[i].icon    || "",
                                    focused: parsed[i].focused || false
                                    // windows НЕ кладём в ListModel — берём из appsData
                                })
                        }
                    } catch(e) {
                        console.log("JSON error: " + e)
                    }
                    shell.stdoutBuffer = ""
                }
            }

            Component.onCompleted: fetchAppsProc.running = true

            function focusApp(app) {
                if (!app || !app.windows || app.windows.length === 0) {
                    console.log("focusApp: no windows for " + JSON.stringify(app))
                    return
                }
                var winId = app.windows[0].id
                console.log("Focusing window ID: " + winId)
                var proc = Qt.createQmlObject(
                    'import Quickshell.Io; Process {}', shell)
                proc.command = ["niri", "msg", "action", "focus-window",
                                "--id", winId.toString()]
                proc.running = true
            }

            Rectangle {
                id: dockBar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                anchors.bottomMargin: shell.dockVisible ? 8 : -(height + 10)
                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }

                width: itemsView.contentWidth + 40
                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                height: 64
                radius: 20
                color: Qt.rgba(30/255, 30/255, 46/255, 0.9)
                border.width: 1
                border.color: Qt.rgba(203/255, 166/255, 247/255, 0.3)

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        shell.dockHovered = true
                        hideTimer.stop()
                        shell.dockVisible = true
                    }
                    onExited: {
                        shell.dockHovered = false
                        hideTimer.restart()
                    }
                    propagateComposedEvents: true
                }

                ListView {
                    id: itemsView
                    anchors.centerIn: parent
                    height: 48
                    width: contentWidth
                    orientation: ListView.Horizontal
                    spacing: 12
                    interactive: false
                    clip: false

                    model: ListModel { id: appsModel }

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                        NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: 250;
                                         easing.type: Easing.OutBack }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                        NumberAnimation { property: "scale"; to: 0.5; duration: 150 }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 200;
                                         easing.type: Easing.OutQuint }
                    }

                    delegate: Item {
                        id: delegateRoot
                        width: 48
                        height: 48

                        property bool iconHovered: false
                        property bool isFocused: model.focused || false

                        Rectangle {
                            id: iconContainer
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            radius: 12
                            color: delegateRoot.iconHovered
                                   ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            scale: delegateRoot.iconHovered ? 1.25 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                            }

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 36; height: 36
                                source: model.icon ? "file://" + model.icon
                                        : "image://icon/application-x-executable"
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true

                                Text {
                                    visible: appIcon.status !== Image.Ready
                                    anchors.centerIn: parent
                                    text: model.app_id
                                          ? model.app_id[0].toUpperCase() : "?"
                                    color: "white"
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -6
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: delegateRoot.isFocused ? 16 : 4
                                height: 4; radius: 2
                                color: delegateRoot.isFocused ? "#CBA6F7" : "#6C7086"
                                Behavior on width {
                                    NumberAnimation { duration: 200;
                                                     easing.type: Easing.OutQuint }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: delegateRoot.iconHovered = true
                            onExited:  delegateRoot.iconHovered = false
                            onClicked: {
                                clickAnim.start()
                                // Берём из JS-массива — там windows сохранён
                                shell.focusApp(shell.appsData[index])
                            }

                            SequentialAnimation {
                                id: clickAnim
                                NumberAnimation {
                                    target: iconContainer; property: "scale"
                                    to: 0.8; duration: 100
                                }
                                NumberAnimation {
                                    target: iconContainer; property: "scale"
                                    to: 1.25; duration: 100
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}