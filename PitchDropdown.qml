// A single-select dropdown, painted with the kit's control chrome but with its
// own popup height policy.
// The kit's own Dropdown sets the popup's total height to the height its rows
// need, and the popup then subtracts its border and padding from that to size
// the list -- so the list is always a few pixels shorter than its content and
// every menu scrolls by exactly that sliver. A list that can be dragged two
// pixels reads as broken rather than as scrollable, which is the reason this
// component exists.
// The policy here is: size the popup's *content* box, and give it either the
// whole list or a half-row of the next one.
//   rows <= maxVisibleRows   the exact height of the rows, and the list is
//                            made non-interactive, so it cannot move at all
//   rows >  maxVisibleRows   one row short of the cap plus half of the next,
//                            so the cut-off row is itself the affordance
//
// The screen has the last word on both the side the popup opens on and how
// much of that policy survives. A bar at the bottom of the display puts the
// panel's lowest control a few pixels above the edge, so a menu that only ever
// opened downward lost most of its rows off the end of the screen -- and to no
// scrollbar, because the list itself was not overflowing. See
// measurePlacement.

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import qs.Commons
import qs.Ui

// `options` takes { value, label } rows, which is the shape Tunings.js
// already produces. Keyboard handling matches the kit so the panel's own
// cursor rules still apply: Enter or Space opens, Esc closes, j/k or the
// arrows walk, Enter selects.
Item {
    id: root

    property string label: ""
    // Input only: the component never writes it. See selectCurrent below.
    property string value: ""
    property var options: []
    property color foreground: Color.popups.text
    property color background: Color.popups.background
    property color popupBorder: Color.popups.border
    property color accent: Color.accent
    property string fontFamily: Style.font.family
    property int rowHeight: Style.spacing.controlHeight
    property int popupRowHeight: Style.spacing.popupRowHeight
    property int rowSpacing: Style.spacing.labelGap
    // How many rows may be shown in full. Nine or more inputs is where the
    // half-row peek starts; below that every menu fits exactly.
    property int maxVisibleRows: 8
    // Panel-cursor flag, as on the kit's controls: a panel that runs its own
    // keyboard cursor paints the trigger through this rather than through Qt
    // focus.
    property bool hasCursor: false
    // How close the popup may come to the edge of the screen before it is
    // shortened. The same gap the panel itself keeps from the bar.
    property int edgeMargin: Style.gapsOut
    readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", root.popupBorder, Color.popups.border, Style.normalBorderWidth)
    readonly property bool popupOpen: popup.opened
    readonly property int rowCount: root.options.length
    readonly property real rowStep: root.popupRowHeight + root.rowSpacing
    // Every row at once, with no policy applied.
    readonly property real fullListHeight: Math.max(root.popupRowHeight, root.rowCount * root.rowStep - root.rowSpacing)
    // The policy above, before the screen has a say.
    readonly property real naturalListHeight: root.rowCount > root.maxVisibleRows ? (root.maxVisibleRows - 1) * root.rowStep + root.popupRowHeight / 2 : root.fullListHeight
    // Room the chosen side actually has for rows, set by measurePlacement on
    // every open. Zero until the first measurement, which reads as "the screen
    // has not constrained anything".
    property real availableListHeight: 0
    readonly property real listHeight: (root.availableListHeight > 0 && root.availableListHeight < root.naturalListHeight) ? root.snappedListHeight(root.availableListHeight) : root.naturalListHeight
    // A list the screen forced shorter than its own content scrolls, even when
    // the row count alone would have fitted the policy.
    readonly property bool overflowing: root.listHeight < root.fullListHeight - 0.5
    // Which side of the trigger the popup opens on.
    property bool openUpward: false
    readonly property real popupChrome: popup.topPadding + popup.bottomPadding
    readonly property real popupOuterHeight: root.listHeight + root.popupChrome

    signal changed(string value)
    signal hovered(bool isHovered)

    // Rounds a height the screen imposed down to the shape the policy already
    // uses -- whole rows plus half of the next -- so a capped list still ends
    // on the half row that says "there is more below" rather than on an
    // arbitrary slice of one.
    function snappedListHeight(available) {
        var whole = Math.floor((available - root.popupRowHeight / 2) / root.rowStep);
        if (whole < 1)
            return Math.min(available, root.popupRowHeight);

        return whole * root.rowStep + root.popupRowHeight / 2;
    }

    // Chooses the side and the cap, in window coordinates, once per open. A
    // binding would not help: mapToItem is a one-shot, and the panel does not
    // move while a menu is up.
    function measurePlacement() {
        var window = trigger.Window.window;
        if (!window || window.height <= 0) {
            root.openUpward = false;
            root.availableListHeight = 0;
            return ;
        }

        var top = trigger.mapToItem(null, 0, 0).y;
        var gap = Style.spacing.xxs;
        var roomBelow = Math.max(0, window.height - top - trigger.height - gap - root.edgeMargin);
        var roomAbove = Math.max(0, top - gap - root.edgeMargin);
        // Downward is where a dropdown is looked for, so it stays the default
        // and the flip happens only when the menu does not fit there and the
        // other side is roomier.
        root.openUpward = roomBelow < root.naturalListHeight + root.popupChrome && roomAbove > roomBelow;
        var room = root.openUpward ? roomAbove : roomBelow;
        // Never below a row and a half. The half row is the scroll
        // affordance, and a popup shorter than that states nothing at all.
        root.availableListHeight = Math.max(root.rowStep + root.popupRowHeight / 2, room - root.popupChrome);
    }

    function open() {
        popup.open();
    }

    function close() {
        popup.close();
    }

    function optionValue(option) {
        return (option && typeof option === "object") ? String(option.value) : String(option);
    }

    function optionLabel(option) {
        return (option && typeof option === "object") ? String(option.label) : String(option);
    }

    function currentLabel() {
        for (var index = 0; index < root.options.length; index++) {
            if (root.optionValue(root.options[index]) === root.value)
                return root.optionLabel(root.options[index]);

        }
        return root.value;
    }

    implicitWidth: Style.spacing.dropdownWidth
    implicitHeight: root.label !== "" ? root.rowHeight + Style.spacing.huge : root.rowHeight

    Column {
        anchors.fill: parent
        spacing: Style.spacing.labelGap

        Text {
            textFormat: Text.PlainText
            visible: root.label !== ""
            text: root.label
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }

        BorderSurface {
            id: trigger

            readonly property bool focused: trigger.activeFocus
            readonly property bool hot: triggerHover.hovered || root.hasCursor

            width: parent.width
            height: root.rowHeight
            radius: Style.cornerRadius
            color: Style.controlFill(trigger.focused, trigger.hot, root.foreground, root.accent)
            borderSpec: Border.controlSpec(trigger.focused ? "focus" : (trigger.hot ? "hover-cursor" : "normal"), root.foreground, root.accent)
            activeFocusOnTab: true
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                    if (popup.opened)
                        popup.close();
                    else
                        popup.open();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape && popup.opened) {
                    popup.close();
                    event.accepted = true;
                }
            }

            HoverHandler {
                id: triggerHover

                onHoveredChanged: root.hovered(hovered)
            }

            Text {
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.right: chevron.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
                anchors.rightMargin: trigger.borderRight + Style.spacing.md
                text: root.currentLabel()
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
            }

            Text {
                id: chevron

                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
                text: popup.opened ? "󰅃" : "󰅀"
                color: Qt.darker(root.foreground, 1.2)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    trigger.forceActiveFocus();
                    if (popup.opened)
                        popup.close();
                    else
                        popup.open();
                }
            }

            Popup {
                id: popup

                x: 0
                y: root.openUpward ? -(root.popupOuterHeight + Style.spacing.xxs) : trigger.height + Style.spacing.xxs
                width: trigger.width
                // The content box, not the outer height: the padding below is
                // then added on top of it rather than eaten out of it.
                contentHeight: root.listHeight
                padding: Style.spacing.hairline
                leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
                rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
                topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
                bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
                focus: true
                // Before the popup is shown, so the first frame is already on
                // the right side of the trigger and already the right height.
                onAboutToShow: root.measurePlacement()
                onOpened: {
                    optionList.currentIndex = Math.max(0, optionList.indexOfValue(root.value));
                    optionList.positionViewAtIndex(optionList.currentIndex, ListView.Contain);
                    optionList.forceActiveFocus();
                }

                background: BorderSurface {
                    color: root.background
                    borderSpec: root.popupBorderSpec
                    radius: Style.cornerRadius
                }

                contentItem: ListView {
                    id: optionList

                    function indexOfValue(wanted) {
                        for (var index = 0; index < root.options.length; index++) {
                            if (root.optionValue(root.options[index]) === wanted)
                                return index;

                        }
                        return -1;
                    }

                    // Emits and does not assign. The kit's dropdown writes
                    // the new value onto its own `value` property, which
                    // destroys the caller's binding to it -- and the panel
                    // needs that binding intact, because choosing an
                    // instrument can reset the tuning row underneath it and
                    // the trigger has to follow.
                    function selectCurrent() {
                        if (optionList.currentIndex < 0 || optionList.currentIndex >= root.options.length)
                            return ;

                        root.changed(root.optionValue(root.options[optionList.currentIndex]));
                        popup.close();
                    }

                    spacing: root.rowSpacing
                    model: root.options
                    currentIndex: -1
                    clip: true
                    // A list that fits has nothing to scroll, so it does not
                    // accept a drag or a wheel event either. "Fits" includes
                    // the screen's verdict, not only the row count: a menu cut
                    // short to reach the edge of the display must scroll even
                    // when its four rows would have fitted the policy.
                    interactive: root.overflowing
                    boundsBehavior: Flickable.StopAtBounds
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            popup.close();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || event.text === "j") {
                            optionList.currentIndex = Math.min(root.options.length - 1, optionList.currentIndex + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || event.text === "k") {
                            optionList.currentIndex = Math.max(0, optionList.currentIndex - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            optionList.selectCurrent();
                            event.accepted = true;
                        }
                    }

                    delegate: Rectangle {
                        id: option

                        required property var modelData
                        required property int index
                        readonly property bool onCursor: option.index === optionList.currentIndex
                        readonly property bool isCurrent: root.optionValue(option.modelData) === root.value

                        width: optionList.width
                        height: root.popupRowHeight
                        radius: Style.cornerRadius
                        color: option.onCursor ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

                        // Which row is in force, shown alongside which row the
                        // cursor is on. The kit's dropdown paints only the
                        // cursor, so an open menu says where you are but not
                        // what you already chose.
                        Text {
                            id: mark

                            textFormat: Text.PlainText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Style.spacing.controlPaddingX
                            text: option.isCurrent ? "󰄬" : ""
                            color: root.accent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.left: mark.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Style.spacing.huge
                            anchors.rightMargin: Style.spacing.controlPaddingX
                            text: root.optionLabel(option.modelData)
                            color: option.onCursor ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            font.bold: option.isCurrent
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: optionList.currentIndex = option.index
                            onClicked: optionList.selectCurrent()
                        }

                    }

                }

            }

        }

    }

}
