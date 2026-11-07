# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name UIConstellationSessions extends UIBase
## UIConstellationManagerSessions


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

## The InviteNode Button
@onready var _invite_node_button: Button = %InviteNode

## The RemoveNode Button
@onready var _remove_node_button: Button = %RemoveNode


## Enum for SessionColumns
enum SessionColumns {NAME, MEMBER_COUNT, MASTER}

## Enum for MembersColumns
enum MemberColumns {PRIORITY, NAME, CONNECTION_STATUS}


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
	MemberColumns.CONNECTION_STATUS: {"type": Data.Type.ENUM, "expand": false}
}

## The Constellation network instance
var _constellation: Constellation

## RefMap for ConstellationSession: Table.Row
var _session_rows: RefMap = RefMap.new()

## RefMap for ConstellationNode: Table.Row
var _member_rows: RefMap = RefMap.new()

## The current selected session in the members table
var _selected_session: ConstellationSession

## Current selected members in a session
var _selected_members: Array[ConstellationNode]

## SignalGroup for Constellation
var _constellation_connections: SignalGroup = SignalGroup.new([
	_on_session_created
])

## SignalGroup for the local node
var _local_node_connections: SignalGroup = SignalGroup.new([
	_on_local_session_changed
]).set_prefix("_on_local_")

## SignalGroup for each ConstellationSession
var _session_connections: SignalGroup = SignalGroup.new([
	_on_session_delete_requested,
	_on_session_node_joined,
	_on_session_node_left,
]).set_prefix("_on_session_")


## ready
func _ready() -> void:
	_constellation = Network.get_active_handler_by_name("Constellation")
	
	_constellation_connections.connect_object(_constellation)
	_local_node_connections.connect_object(_constellation.get_local_node())
	
	for column_name: String in SessionColumns:
		_session_table.add_column(column_name.capitalize(), _session_column_config[SessionColumns[column_name]].type)
	
	for column_name: String in MemberColumns:
		_members_table.add_column(column_name.capitalize(), _member_column_config[MemberColumns[column_name]].type)\
		.set_allow_expand(_member_column_config[MemberColumns[column_name]].expand)
	
	_members_table.set_multi_edit_mode(Table.MultiEditMode.MATCH_COLUMN_TYPE)
	_members_table.set_column_sort(_members_table.get_column(MemberColumns.PRIORITY), Table.SortDirection.ASCENDING)
	
	for session: ConstellationSession in _constellation.get_all_sessions():
		_add_session(session)


## Adds the given ConstellationSession to the list
func _add_session(p_session: ConstellationSession) -> bool:
	if _session_rows.has_left(p_session):
		return false
	
	var settings: SettingsManager = p_session.get_settings()
	_session_connections.connect_object(p_session)
	
	_session_rows.map(p_session, _session_table.add_row({
		SessionColumns.NAME: 			settings.get_entry("Name"),
		SessionColumns.MEMBER_COUNT: 	settings.get_entry("MemberCount"),
		SessionColumns.MASTER: 			settings.get_entry("Master"),
	}))
	
	return true


## Removes the given ConstellationSession from the list
func _remove_session(p_session: ConstellationSession) -> bool:
	if not _session_rows.has_left(p_session):
		return false
	
	_session_table.remove_row(_session_rows.left(p_session))
	_session_rows.erase_left(p_session)
	_session_connections.disconnect_object(p_session)
	
	return true


## Selects the given ConstellationSession
func _select_session(p_session: ConstellationSession) -> void:
	_selected_session = null
	_selected_members.clear()
	
	_member_rows.clear()
	_members_table.clear()
	
	_members_table.hide()
	_no_selected_session_label.show()
	
	queue(_update_buttons)
	
	if not _session_rows.has_left(p_session):
		return

	_selected_session = p_session
	_members_table.show()
	_no_selected_session_label.hide()
	
	for node: ConstellationNode in _selected_session.get_nodes():
		_add_session_member(node)


## Adds a node to the members table
func _add_session_member(p_node: ConstellationNode) -> bool:
	if _member_rows.has_left(p_node):
		return false
	
	var settings: SettingsManager = p_node.get_settings()
	
	_member_rows.map(p_node, _members_table.add_row({
		MemberColumns.PRIORITY: settings.get_entry("Priority"),
		MemberColumns.NAME: 	settings.get_entry("Name"),
		MemberColumns.CONNECTION_STATUS: 	settings.get_entry("ConnectionState")
	}))
	
	return true


## Removes a node from the members table
func _remove_session_member(p_node: ConstellationNode) -> bool:
	if not _member_rows.has_left(p_node):
		return false
	
	_members_table.remove_row(_member_rows.left(p_node))
	_member_rows.erase_left(p_node)
	
	return true


## Updates buttons disabled status
func _update_buttons() -> void:
	_create_session_button.set_disabled(
		is_instance_valid(_constellation.get_local_node().get_session())
	)
	_join_session_button.set_disabled(
		not is_instance_valid(_selected_session) or _selected_session.is_active_session()
	)
	_leave_session_button.set_disabled(
		not is_instance_valid(_constellation.get_local_node().get_session())
	)
	
	_invite_node_button.set_disabled(
		not is_instance_valid(_selected_session)
	)
	_remove_node_button.set_disabled(
		not _selected_members
	)


## Called when a session is created on the network
func _on_session_created(p_session: ConstellationSession) -> void:
	_add_session(p_session)


## Called when the local node's session is changed
func _on_local_session_changed(_p_session: ConstellationSession) -> void:
	queue(_update_buttons)


## Called when a ConstellationSession requests to be deleted
func _on_session_delete_requested(p_session: ConstellationSession) -> void:
	_remove_session(p_session)


## Called when a nodes joins a session
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
	_select_session(selected)


## Called when the members table selection is changed
func _on_members_table_selection_changed() -> void:
	var selected: Array = _members_table.get_selected_rows()
	_selected_members.clear()
	
	for row: Table.Row in selected:
		_selected_members.append(_member_rows.right(row))
	
	queue(_update_buttons)


## Called when the Reload Button is pressed
func _on_reload_pressed() -> void:
	_constellation.send_discovery()


## Called when the InviteNode button is pressed
func _on_invite_node_pressed() -> void:
	var selected_session: ConstellationSession = _selected_session
	
	Popups.ObjectSelector(self, NetworkItem, ConstellationNode).then(func (p_node: ConstellationNode):
		p_node.join_session(selected_session)
	)


## Called when the RemoveNode button is pressed
func _on_remove_node_pressed() -> void:
	for node: ConstellationNode in _selected_members:
		node.leave_session()
