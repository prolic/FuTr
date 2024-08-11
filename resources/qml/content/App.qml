import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import Futr 1.0

ApplicationWindow {
    id: root
    width: Constants.width
    height: Constants.height
    minimumWidth: 720
    minimumHeight: 525
    visible: true
    title: "Futr"
    font: Constants.font

    // Apply the Material theme
    Material.theme: Material.Light
    Material.accent: Material.Teal
    Material.primary: Material.BlueGrey

    WelcomeScreen {
        id: welcomeScreen
        anchors.fill: parent
        visible: currentScreen == "WelcomeScreen"
        //visible: false
    }

    KeysGeneratedScreen {

    }

    ErrorScreen {
        id: errorScreen
        visible: errorMsg != ""
    }

    ToolBar {
        id: statusBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 18

        Label {
            text: qsTr("Status: Ready")
            anchors.left: parent.left
            anchors.leftMargin: 10
            verticalAlignment: Text.AlignHCenter
        }
    }
}




/*##^##
Designer {
    D{i:0;formeditorZoom:0.33}D{i:1}D{i:3}D{i:2}
}
##^##*/
