# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name UIConstellationManagerSessionsTab extends PanelContainer
## UIConstellationManagerSessionsTab


## The Table Node to show all Constellation sessions
@onready var _session_table: Table = %SessionTable

## The Table Node to show all session members
@onready var _members_table: Table = %MembersTable

## The Label Node shown when no session is selected
@onready var _no_selected_session_label: Label = %NoSelectedSessionLabel

## The CreateSession Button
@onready var _create_session_button: Button = %CreateSessionButton

## The LeaveSession Button
@onready var _leave_session_button: Button = %LeaveSessionButton

## The JoinSession Button
@onready var _join_session_button: Button = %JoinSessionButton

## The RemoveNode Button
@onready var _remove_node_button: Button = %RemoveNode


## Enum for SessionColumns
enum SessionColumns {NAME, MEMBER_COUNT, MASTER}

## Enum for MembersColumns
enum MemberColumns {PRIORITY, NAME}


## Config for each column
var _session_column_config: Dictionary[int, Dictionary] = {
	SessionColumns.NAME: {"type": Data.Type.STRING},
	SessionColumns.MEMBER_COUNT: {"type": Data.Type.INT},
	SessionColumns.MASTER: {"type": Data.Type.OBJECT},
}

## Config for each column
var _member_column_config: Dictionary[int, Dictionary] = {
	MemberColumns.PRIORITY: {"type": Data.Type.INT, "expand": false},
	MemberColumns.NAME: {"type": Data.Type.STRING, "expand": true},
}

## The Constellation network instance
var _constellation: Constellation

## RefMap for ConstellationSession: Table.Row
var _session_rows: RefMap = RefMap.new()

## RefMap for ConstellationNode: Table.Row
var _member_rows: RefMap = RefMap.new()

## The current selected session in the members table
var _selected_session: ConstellationSession

## SignalGroup for each ConstellationSession
var _session_connections: SignalGroup = SignalGroup.new([], {
	"delete_requested": remove_session,
	"node_joined": _on_session_node_joined,
	"node_left": _on_session_node_left,
})


## Ready
func _ready() -> void:
	_constellation = Network.get_active_handler_by_name("Constellation")
	
	_constellation.get_local_node().session_joined.connect(_on_session_joined)
	_constellation.get_local_node().session_left.connect(_on_session_left)
	
	for column_name: String in SessionColumns:
		_session_table.add_column(column_name.capitalize(), _session_column_config[SessionColumns[column_name]].type)
	
	for column_name: String in MemberColumns:
		_members_table.add_column(column_name.capitalize(), _member_column_config[MemberColumns[column_name]].type)\
		.set_allow_expand(_member_column_config[MemberColumns[column_name]].expand)
	
	_members_table.set_multi_edit_mode(Table.MultiEditMode.MATCH_COLUMN_TYPE)
	_members_table.set_column_sort(_members_table.get_column(MemberColumns.PRIORITY), Table.SortDirection.ASCENDING)


## Adds a ConstellationSession to the table
func add_session(p_session: ConstellationSession) -> void:
	_session_connections.connect_object(p_session)
	_session_rows.map(p_session, _session_table.add_row({
		SessionColumns.NAME: p_session.get_settings().get_entry("Name"),
		SessionColumns.MEMBER_COUNT: p_session.get_settings().get_entry("MemberCount"),
		SessionColumns.MASTER: p_session.get_settings().get_entry("Master"),
	}))


## Removes a session from the table
func remove_session(p_session: ConstellationSession) -> void:
	var row: Table.Row = _session_rows.left(p_session)
	
	if not is_instance_valid(row):
		return
	
	_session_table.remove_row(row)
	_session_rows.erase_left(p_session)
	_session_connections.disconnect_object(p_session)


## Selects the given session
func select_session(p_session: ConstellationSession) -> void:
	_selected_session = null
	
	_member_rows.clear()
	_members_table.clear()
	
	_members_table.hide()
	_no_selected_session_label.show()
	
	if not _session_rows.has_left(p_session):
		return
	
	_selected_session = p_session
	_members_table.show()
	_no_selected_session_label.hide()
	
	for node: ConstellationNode in _selected_session.get_nodes():
		_add_session_member(node)


## Resets the UI, removing all nodes from the table
func reset() -> void:
	for session: ConstellationSession in _session_rows.get_left():
		_session_connections.disconnect_object(session, true)
	
	_session_rows.clear()
	_session_table.clear()


## Adds a node to the members table
func _add_session_member(p_node: ConstellationNode) -> void:
	if not is_instance_valid(_selected_session):
		return
	
	_member_rows.map(p_node, _members_table.add_row({
		MemberColumns.PRIORITY: p_node.get_settings().get_entry("Priority"),
		MemberColumns.NAME: p_node.get_settings().get_entry("Name"),
	}))


## Removes a node from the members table
func _remove_session_member(p_node: ConstellationNode) -> void:
	if not is_instance_valid(_selected_session) or not _member_rows.has_left(p_node):
		return
	
	_members_table.remove_row(_member_rows.left(p_node))
	_member_rows.erase_left(p_node)


## Called when the localNode joins a session
func _on_session_joined(p_session: ConstellationSession) -> void:
	_leave_session_button.set_disabled(false)
	_create_session_button.set_disabled(true)


## Called when the localNode leaves a session
func _on_session_left() -> void:
	_leave_session_button.set_disabled(true)
	_create_session_button.set_disabled(false)


## Called when a node joines a session
func _on_session_node_joined(p_node: ConstellationNode) -> void:
	if p_node.get_session() == _selected_session:
		_add_session_member(p_node)


## Called when a node leaves a session
func _on_session_node_left(p_node: ConstellationNode) -> void:
	if p_node.get_session() == _selected_session:
		_remove_session_member(p_node)


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
	_constellation.join_session(_session_rows.right(_session_table.get_selected_row()))


## Called when the selection is changed
func _on_table_selection_changed() -> void:
	var selected: ConstellationSession = _session_rows.right(_session_table.get_selected_row())
	
	if is_instance_valid(selected) and selected != _constellation.get_local_node().get_session():
		_join_session_button.set_disabled(false)
	else:
		_join_session_button.set_disabled(true)
	
	select_session(selected)


## Called when the members table selection is changed
func _on_members_table_selection_changed() -> void:
	_remove_node_button.set_disabled(not _members_table.is_any_selected())


## Called when the Reload Button is pressed
func _on_reload_pressed() -> void:
	_constellation._send_session_discovery()


## Called when the InviteNode button is pressed
func _on_invite_node_pressed() -> void:
	var selected_session: ConstellationSession = _selected_session
	
	Popups.ObjectSelector(self, NetworkItem, ConstellationNode).then(func (p_node: ConstellationNode):
		p_node.join_session(selected_session)
	)


## Called when the RemoveNode button is pressed
func _on_remove_node_pressed() -> void:
	var selected: Array = _members_table.get_selected_rows()
	
	if not selected:
		return
	
	for row: Table.Row in selected:
		var member: ConstellationNode = _member_rows.right(row)
		member.leave_session()
