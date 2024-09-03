import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: root

    icon.source: "qrc:/icons/edit.svg"

    width: 10
    height: 10

    flat: true

    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.timeout: 5000
    ToolTip.text: qsTr("Edit")
}
