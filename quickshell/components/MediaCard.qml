import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs

// Android-style media card: album art as the background, app icon, output chip,
// title/artist, big play button and a squiggly progress line. Used by the bar popup and the start menu.
ClippingRectangle {
    id: root

    required property MprisPlayer player
    property bool bordered: true
    readonly property bool hovered: hover.hovered

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var appEntry: player ? DesktopEntries.heuristicLookup(player.desktopEntry || player.identity) : null
    readonly property real progress: player && player.length > 0 ? Math.min(1, player.position / player.length) : 0

    // Browsers (e.g. YouTube in chromium) can't skip tracks; the skip buttons then jump 10s instead.
    function skip(direction) {
        const canSkip = direction > 0 ? player.canGoNext : player.canGoPrevious;
        if (canSkip)
            direction > 0 ? player.next() : player.previous();
        else if (player.canSeek)
            player.position = Math.max(0, Math.min(player.length, player.position + 10 * direction));
    }

    radius: 12 // same as hyprland windows (look.lua rounding)
    color: Theme.surface_container_highest

    HoverHandler {
        id: hover
    }

    // MprisPlayer.position only updates when asked to.
    Timer {
        running: root.visible && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    Image {
        id: art
        anchors.fill: parent
        source: root.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 720
        asynchronous: true
    }

    // scrim: darker on the left where the text sits
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.surface, 0.8)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.surface, art.status === Image.Ready ? 0.35 : 0.8)
            }
        }
    }

    // fade at the top and bottom so the icon, chip and controls stay readable on any art
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.surface, 0.6)
            }
            GradientStop {
                position: 0.3
                color: Qt.alpha(Theme.surface, 0)
            }
            GradientStop {
                position: 0.55
                color: Qt.alpha(Theme.surface, 0)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.surface, 0.92)
            }
        }
    }

    // ── top: app icon + output chip ──
    Rectangle {
        x: 16
        y: 14
        width: 30
        height: 30
        radius: 15
        color: Theme.primary

        IconImage {
            id: appIcon
            anchors.centerIn: parent
            implicitSize: 18
            visible: root.appEntry !== null
            source: root.appEntry ? Quickshell.iconPath(root.appEntry.icon, true) : ""
        }

        Text {
            anchors.centerIn: parent
            visible: !appIcon.visible
            text: Theme.g(0xf075a)
            color: Theme.on_primary
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }
    }

    Rectangle {
        id: chip

        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 14
        height: 30
        width: Math.min(170, chipRow.implicitWidth + 22)
        radius: 15
        color: Theme.primary
        visible: root.sink !== null

        RowLayout {
            id: chipRow

            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 6

            // fixed box: nerd-font glyphs are wider than their advance and would overlap the text
            Item {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18

                Text {
                    anchors.centerIn: parent
                    text: Theme.g((root.sink?.name ?? "").startsWith("bluez") ? 0xf0970 : 0xf04c3)
                    color: Theme.on_primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.sink?.description || root.sink?.nickname || "Output"
                elide: Text.ElideRight
                color: Theme.on_primary
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["pavucontrol"])
        }
    }

    // ── middle: title/artist + play button ──
    Column {
        x: 18
        anchors.verticalCenter: playButton.verticalCenter
        width: playButton.x - x - 12
        spacing: 2

        Text {
            width: parent.width
            text: root.player?.trackTitle || "Unknown title"
            elide: Text.ElideRight
            color: Theme.on_surface
            font.family: Theme.uiFont
            font.pixelSize: 16
            font.weight: Font.Medium
        }
        Text {
            width: parent.width
            text: root.player?.trackArtist || root.player?.identity || ""
            elide: Text.ElideRight
            color: Qt.alpha(Theme.on_surface, 0.7)
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }

    Rectangle {
        id: playButton

        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 62
        width: 52
        height: 52
        radius: 16
        color: playMouse.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary
        opacity: root.player?.canTogglePlaying ? 1 : 0.5

        Text {
            anchors.centerIn: parent
            text: Theme.g(root.player?.isPlaying ? 0xf03e4 : 0xf040a)
            color: Theme.on_primary
            font.family: Theme.fontFamily
            font.pixelSize: 24
        }

        MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.togglePlaying()
        }
    }

    // ── bottom: prev, squiggly progress, next, shuffle, repeat ──
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 8
        height: 30
        spacing: 4

        IconButton {
            glyph: root.player?.canGoPrevious ? 0xf04ae : 0xf0d2a // skip previous / rewind 10
            enabled: (root.player?.canGoPrevious || root.player?.canSeek) ?? false
            onClicked: root.skip(-1)
        }

        WaveProgress {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            progress: root.progress
            playing: root.player?.isPlaying ?? false
            visible: root.player?.lengthSupported ?? false
            onSeek: fraction => {
                if (root.player?.canSeek)
                    root.player.position = root.player.length * fraction;
            }
        }

        Item {
            Layout.fillWidth: true
            visible: !(root.player?.lengthSupported ?? false)
        }

        IconButton {
            glyph: root.player?.canGoNext ? 0xf04ad : 0xf0d71 // skip next / fast-forward 10
            enabled: (root.player?.canGoNext || root.player?.canSeek) ?? false
            onClicked: root.skip(1)
        }
        IconButton {
            glyph: root.player?.shuffle ? 0xf049d : 0xf049e
            active: root.player?.shuffle ?? false
            visible: root.player?.shuffleSupported ?? false
            onClicked: root.player.shuffle = !root.player.shuffle
        }
        IconButton {
            glyph: {
                switch (root.player?.loopState) {
                case MprisLoopState.Track:
                    return 0xf0458;
                case MprisLoopState.Playlist:
                    return 0xf0456;
                default:
                    return 0xf0457;
                }
            }
            active: root.player && root.player.loopState !== MprisLoopState.None
            visible: root.player?.loopSupported ?? false
            onClicked: {
                // none -> playlist -> track -> none
                const s = root.player.loopState;
                root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
            }
        }
    }

    // border on top of the art, like hyprland's window border
    Rectangle {
        anchors.fill: parent
        visible: root.bordered
        radius: root.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
    }

    component IconButton: Rectangle {
        id: button

        property int glyph
        property bool active: true
        signal clicked

        implicitWidth: 30
        implicitHeight: 30
        radius: 15
        color: mouse.containsMouse && enabled ? Qt.alpha(Theme.on_surface, 0.12) : "transparent"
        opacity: enabled ? (active ? 1 : 0.55) : 0.3

        Text {
            anchors.centerIn: parent
            text: Theme.g(button.glyph)
            color: Theme.on_surface
            font.family: Theme.fontFamily
            font.pixelSize: 17
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    // The played part is a moving sine wave while playing (flat when paused), the rest a thin line.
    component WaveProgress: Item {
        id: wave

        property real progress: 0
        property bool playing: false
        property real phase: 0
        property real amplitude: playing ? 2.5 : 0
        signal seek(real fraction)

        Behavior on progress {
            NumberAnimation {
                duration: 1000
            }
        }
        Behavior on amplitude {
            NumberAnimation {
                duration: 250
            }
        }

        NumberAnimation on phase {
            running: wave.playing && wave.visible
            from: 0
            to: 2 * Math.PI
            duration: 1400
            loops: Animation.Infinite
        }

        onProgressChanged: canvas.requestPaint()
        onPhaseChanged: canvas.requestPaint()
        onAmplitudeChanged: canvas.requestPaint()
        onWidthChanged: canvas.requestPaint()

        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const mid = height / 2, end = width * wave.progress, wavelength = 18;
                ctx.lineCap = "round";
                ctx.lineWidth = 2.5;

                ctx.strokeStyle = Qt.alpha(Theme.on_surface, 0.35);
                ctx.beginPath();
                ctx.moveTo(Math.max(end, 2), mid);
                ctx.lineTo(width - 2, mid);
                ctx.stroke();

                ctx.strokeStyle = Theme.on_surface;
                ctx.beginPath();
                ctx.moveTo(2, mid + wave.amplitude * Math.sin(wave.phase));
                for (let x = 2; x <= end; x += 1)
                    ctx.lineTo(x, mid + wave.amplitude * Math.sin(2 * Math.PI * x / wavelength - wave.phase));
                ctx.stroke();

                // knob
                ctx.fillStyle = Theme.on_surface;
                ctx.beginPath();
                ctx.arc(Math.max(end, 2), mid, 4, 0, 2 * Math.PI);
                ctx.fill();
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: event => wave.seek(Math.max(0, Math.min(1, event.x / width)))
        }
    }
}
