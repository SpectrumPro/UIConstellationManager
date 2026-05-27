# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name UIConstellationManagerSessionsTab extends PanelContainer
## UIConstellationManagerSessionsTab


## The Table Node to show all Constellation Nods
@onready var _table: Table = %SessionTable

## The CreateSession Button
@onready var _create_session_button: Button = %CreateSessionButton

## The LeaveSession Button
@onready var _leave_session_button: Button = %LeaveSessionButton

## The JoinSession Button
@onready var _join_session_button: Button = %JoinSessionButton


## Enum for each Columns
enum Columns {NAME, MEMBER_COUNT, MASTER}


## Config for each column
var _column_config: Dictionary[int, Dictionary] = {
	Columns.NAME: {"type": Data.Type.STRING},
	Columns.MEMBER_COUNT: {"type": Data.Type.INT},
	Columns.MASTER: {"type": Data.Type.OBJECT},
}

## The Constellation network instance
var _constellation: Constellation

## RefMap for ConstellationSession: Table.Row
var _session_rows: RefMap = RefMap.new()

## SignalGroup for each ConstellationSession
var _session_connections: SignalGroup = SignalGroup.new([], {
	"delete_requested": remove_session
})


## Ready
func _ready() -> void:
	_constellation = Network.get_active_handler_by_name("Constellation")
	
	_constellation.get_local_node().session_joined.connect(_on_session_joined)
	_constellation.get_local_node().session_left.connect(_on_session_left)
	
	for column_name: String in Columns:
		_table.add_column(column_name.capitalize(), _column_config[Columns[column_name]].type)


## Adds a ConstellationSession to the table
func add_session(p_session: ConstellationSession) -> void:
	_session_connections.connect_object(p_session)
	_session_rows.map(p_session, _table.add_row({
		Columns.NAME: p_session.get_settings().get_entry("Name"),
		Columns.MEMBER_COUNT: p_session.get_settings().get_entry("MemberCount"),
		Columns.MASTER: p_session.get_settings().get_entry("Master"),
	}))


## Removes a session from the table
func remove_session(p_session: ConstellationSession) -> void:
	var row: Table.Row = _session_rows.left(p_session)
	
	if not is_instance_valid(row):
		return
	
	_table.remove_row(row)
	_session_rows.erase_left(p_session)
	_session_connections.disconnect_object(p_session)


## Resets the UI, removing all nodes from the table
func reset() -> void:
	for session: ConstellationSession in _session_rows.get_left():
		_session_connections.disconnect_object(session, true)
	
	_session_rows.clear()
	_table.clear()


## Called when the localNode joins a session
func _on_session_joined(p_session: ConstellationSession) -> void:
	_leave_session_button.set_disabled(false)
	_create_session_button.set_disabled(true)


## Called when the localNode leaves a session
func _on_session_left() -> void:
	_leave_session_button.set_disabled(true)
	_create_session_button.set_disabled(false)


## Called when the create session button is pressed
func _on_create_session_button_pressed() -> void:
	Popups.show_data_input(self, Data.Type.STRING, "NewSession", "Session Name").then(func (p_name: String):
		_constellation.create_session(p_name)
	)


## Called when the LeaveSession button is pressed
func _on_leave_session_button_pressed() -> void:
	Popups.PopupDialog(self).preset(UIPopupDialog.Preset.CONFIRM, "Leave Session?").then(_constellation.leave_session)


## Called when the JoinSession button is pressed
func _on_join_session_button_pressed() -> void:
	_constellation.join_session(_session_rows.right(_table.get_selected_row()))


## Called when the selection is changed
func _on_table_selection_changed() -> void:
	var selected: ConstellationSession = _session_rows.right(_table.get_selected_row())
	
	if is_instance_valid(selected) and selected != _constellation.get_local_node().get_session():
		_join_session_button.set_disabled(false)
	else:
		_join_session_button.set_disabled(true)


## Called when the Reload Button is pressed
func _on_reload_pressed() -> void:
	_constellation._send_session_discovery()
