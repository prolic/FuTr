import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

import HsQML.Model 1.0
import Futr 1.0

Rectangle {
    id: chat
    color: Material.backgroundColor
    radius: 5
    border.color: Material.dividerColor
    border.width: 1

    property string npub: ""
    property var profileData

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: Material.primaryColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Image {
                    source: Util.getProfilePicture(profileData.picture, profileData.npub)
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    smooth: true
                    fillMode: Image.PreserveAspectCrop
                }

                Text {
                    text: profileData.displayName || profileData.name || npub
                    font.pixelSize: 16
                    color: Material.foreground
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        // Messages List
        ListView {
            id: messageListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            verticalLayoutDirection: ListView.TopToBottom
            layoutDirection: Qt.LeftToRight
            leftMargin: 10
            rightMargin: 10

            model: AutoListModel {
                id: messagesModel
                source: messages
                mode: AutoListModel.ByKey
            }

            delegate: Item {
                width: messageListView.width - messageListView.leftMargin - messageListView.rightMargin - (messageListView.ScrollBar.vertical ? messageListView.ScrollBar.vertical.width : 0)
                height: messageBubble.height + 5

                Rectangle {
                    id: messageBubble
                    anchors {
                        left: modelData.isOwnMessage ? undefined : parent.left
                        right: modelData.isOwnMessage ? parent.right : undefined
                        top: parent.top
                    }
                    width: Math.min(Math.max(messageContent.implicitWidth, timestampText.implicitWidth) + 24, parent.width * 0.8)
                    height: messageContent.height + timestampText.height + 20
                    color: modelData.isOwnMessage ? Material.accentColor : Material.dividerColor
                    radius: 10

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Text {
                            id: messageContent
                            Layout.fillWidth: true
                            text: modelData.content
                            wrapMode: Text.Wrap
                            color: Material.foreground
                        }

                        Text {
                            id: timestampText
                            Layout.alignment: modelData.isOwnMessage ? Qt.AlignRight : Qt.AlignLeft
                            text: modelData.timestamp
                            font.pixelSize: 10
                            color: Material.secondaryTextColor
                            opacity: 0.9
                        }
                    }
                }
            }

            onCountChanged: {
                positionViewAtEnd()
            }

            onContentHeightChanged: {
                positionViewAtEnd()
            }

            Component.onCompleted: {
                positionViewAtEnd()
            }

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }
        }

        // Message Input
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 10

            TextField {
                id: messageInput
                Layout.fillWidth: true
                placeholderText: qsTr("Type a message...")
                font.pixelSize: 14
                bottomPadding: 10
                leftPadding: 10
                onAccepted: sendMessageAndClear()
            }

            Button {
                text: qsTr("Send")
                highlighted: true
                bottomPadding: 10
                rightPadding: 10
                onClicked: sendMessageAndClear()
            }
        }
    }

    function sendMessageAndClear() {
        if (messageInput.text.trim() !== "") {
            sendMessage(messageInput.text)
            messageInput.text = ""
        }
    }
}
