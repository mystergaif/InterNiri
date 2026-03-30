import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: WlrLayershell {
            id: root
            property var modelData

            implicitWidth: 520
            implicitHeight: 620
            layer: WlrLayer.Overlay
            namespace: "launcher"
            anchors { top: false; bottom: false; left: false; right: false }
            keyboardFocus: WlrKeyboardFocus.Exclusive

            property var allApps: []
            property var filteredApps: []
            property string stdoutBuffer: ""
            property string searchQuery: ""

            Process {
                id: getAppsProc
                command: ["python3", "/home/myster_gaif/.config/quickshell/get_apps.py"]
                running: true
                stdout: SplitParser {
                    onRead: data => root.stdoutBuffer += data
                }
                onExited: {
                    try {
                        root.allApps = JSON.parse(root.stdoutBuffer);
                        root.filterApps("");
                    } catch(e) {
                        console.log("JSON Parse error: " + e);
                    }
                }
            }

            function filterApps(text) {
                searchQuery = text;
                var list = !text ? allApps : allApps.filter(function(app) {
                    return app.name.toLowerCase().indexOf(text.toLowerCase()) !== -1;
                });
                filteredApps = list;
                appsModel.clear();
                for (var i = 0; i < list.length; i++)
                    appsModel.append(list[i]);
            }

            function highlightName(name, query) {
                if (!query) return name;
                var idx = name.toLowerCase().indexOf(query.toLowerCase());
                if (idx === -1) return name;
                return name.substring(0, idx)
                    + '<span style="color:#CBA6F7;text-decoration:underline;font-weight:600">'
                    + name.substring(idx, idx + query.length)
                    + '</span>'
                    + name.substring(idx + query.length);
            }

            function launchApp(exec) {
                // 1. Record stats (fire and forget, don't wait)
                var stats = Qt.createQmlObject(
                    'import Quickshell.Io; Process {}', root);
                stats.command = ["python3",
                    "/home/myster_gaif/.config/quickshell/record_launch.py",
                    exec];
                stats.running = true;

                // 2. Launch app with nohup so it survives launcher closing
                var launch = Qt.createQmlObject(
                    'import Quickshell.Io; Process {}', root);
                launch.command = ["bash", "-c",
                    "nohup " + exec + " >/dev/null 2>&1 &"];
                launch.running = true;

                // 3. Close launcher immediately
                Qt.quit();
            }

            Rectangle {
                id: mainWindow
                anchors.fill: parent
                radius: 22
                color: Qt.rgba(24/255, 24/255, 37/255, 0.97)
                border.color: Qt.rgba(203/255, 166/255, 247/255, 0.35)
                border.width: 1
                clip: true
                opacity: 0
                scale: 0.93

                Component.onCompleted: appearAnim.start()

                ParallelAnimation {
                    id: appearAnim
                    NumberAnimation {
                        target: mainWindow; property: "opacity"
                        from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: mainWindow; property: "scale"
                        from: 0.93; to: 1.0; duration: 220; easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    // Search bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 52
                        radius: 26
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                        border.width: 1.5
                        border.color: searchInput.activeFocus
                            ? Qt.rgba(203/255, 166/255, 247/255, 0.75)
                            : Qt.rgba(255/255, 255/255, 255/255, 0.12)

                        Behavior on border.color {
                            ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 12

                            Text {
                                text: ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: "#CBA6F7"
                                opacity: searchInput.activeFocus ? 1.0 : 0.5
                                Behavior on opacity {
                                    NumberAnimation { duration: 160 }
                                }
                            }

                            TextField {
                                id: searchInput
                                Layout.fillWidth: true
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                color: "#CDD6F4"
                                background: Item {}
                                placeholderText: "Search apps..."
                                placeholderTextColor: Qt.rgba(205/255, 214/255, 244/255, 0.28)
                                focus: true

                                onTextChanged: root.filterApps(text)
                                Keys.onEscapePressed: Qt.quit()
                                Keys.onReturnPressed: {
                                    if (appsModel.count > 0)
                                        root.launchApp(appsModel.get(0).exec);
                                }
                            }
                        }
                    }

                    // 2-column grid
                    GridView {
                        id: appsGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        cellWidth: Math.floor(width / 2)
                        cellHeight: 160
                        clip: true
                        flickDeceleration: 1500
                        maximumFlickVelocity: 8000

                        WheelHandler {
                            onWheel: (event) => {
                                var delta = event.angleDelta.y > 0
                                    ? -appsGrid.cellHeight * 2
                                    :  appsGrid.cellHeight * 2;
                                appsGrid.contentY = Math.max(0, Math.min(
                                    appsGrid.contentY + delta,
                                    Math.max(0, appsGrid.contentHeight - appsGrid.height)
                                ));
                            }
                        }

                        model: ListModel { id: appsModel }

                        add: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "scale"; from: 0.82; to: 1; duration: 160; easing.type: Easing.OutBack }
                            }
                        }
                        remove: Transition {
                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90; easing.type: Easing.InCubic }
                        }
                        displaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: delegateRoot
                            width: appsGrid.cellWidth
                            height: appsGrid.cellHeight

                            property bool hovered: false
                            property int launchCount: model.launches || 0

                            Rectangle {
                                id: card
                                anchors.fill: parent
                                anchors.margins: 7
                                radius: 16

                                color: delegateRoot.hovered
                                    ? Qt.rgba(203/255, 166/255, 247/255, 0.11)
                                    : Qt.rgba(255/255, 255/255, 255/255, 0.03)

                                border.width: delegateRoot.launchCount > 0 ? 1.5 : 1
                                border.color: delegateRoot.hovered
                                    ? Qt.rgba(203/255, 166/255, 247/255, 0.45)
                                    : delegateRoot.launchCount > 5
                                        ? Qt.rgba(203/255, 166/255, 247/255, 0.25)
                                        : Qt.rgba(255/255, 255/255, 255/255, 0.06)

                                Behavior on color {
                                    ColorAnimation { duration: 130; easing.type: Easing.OutCubic }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: 130; easing.type: Easing.OutCubic }
                                }

                                scale: delegateRoot.hovered ? 1.04 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    width: parent.width - 20

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 88
                                        height: 88

                                        // Glow
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 80; height: 80; radius: 40
                                            color: Qt.rgba(203/255, 166/255, 247/255,
                                                delegateRoot.hovered ? 0.13 : 0.0)
                                            Behavior on color {
                                                ColorAnimation { duration: 200 }
                                            }
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            source: model.icon ? "file://" + model.icon : ""
                                            width: 72; height: 72
                                            fillMode: Image.PreserveAspectFit
                                            sourceSize.width: 128
                                            sourceSize.height: 128
                                            smooth: true
                                            asynchronous: true

                                            opacity: status === Image.Ready ? 1 : 0
                                            Behavior on opacity {
                                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                            }

                                            scale: delegateRoot.hovered ? 1.09 : 1.0
                                            Behavior on scale {
                                                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        // Popularity dot
                                        Rectangle {
                                            visible: delegateRoot.launchCount >= 3
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.rightMargin: 4
                                            anchors.topMargin: 4
                                            width: 8; height: 8; radius: 4
                                            color: delegateRoot.launchCount >= 10
                                                ? "#F38BA8" : "#CBA6F7"
                                            opacity: 0.85
                                        }
                                    }

                                    Text {
                                        id: appNameText
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: "#CDD6F4"
                                        textFormat: Text.RichText
                                        text: root.highlightName(model.name, root.searchQuery)

                                        property string lastQuery: ""
                                        onTextChanged: {
                                            if (root.searchQuery !== "" && root.searchQuery !== lastQuery) {
                                                lastQuery = root.searchQuery;
                                                pulseAnim.restart();
                                            }
                                        }

                                        SequentialAnimation {
                                            id: pulseAnim
                                            NumberAnimation {
                                                target: appNameText; property: "opacity"
                                                from: 1.0; to: 0.35; duration: 70
                                                easing.type: Easing.InCubic
                                            }
                                            NumberAnimation {
                                                target: appNameText; property: "opacity"
                                                from: 0.35; to: 1.0; duration: 130
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    Text {
                                        visible: delegateRoot.launchCount > 0
                                        Layout.alignment: Qt.AlignHCenter
                                        text: delegateRoot.launchCount + "×"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: Qt.rgba(203/255, 166/255, 247/255, 0.45)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: delegateRoot.hovered = true
                                    onExited:  delegateRoot.hovered = false
                                    onClicked: clickAnim.start()

                                    SequentialAnimation {
                                        id: clickAnim
                                        NumberAnimation {
                                            target: card; property: "scale"
                                            to: 0.91; duration: 70; easing.type: Easing.InCubic
                                        }
                                        NumberAnimation {
                                            target: card; property: "scale"
                                            to: 1.0; duration: 60; easing.type: Easing.OutCubic
                                        }
                                        ScriptAction {
                                            script: root.launchApp(model.exec)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
